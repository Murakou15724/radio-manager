# デプロイおよびDB管理方法（Supabase + Render）

本書は、Radio Manager を **DB: Supabase（PostgreSQL）** ／ **アプリ実行: Render** の構成で本番運用するための手順書である。リポジトリの現状（`Gemfile` の `pg` gem、`config/database.yml` の `production` が `DATABASE_URL` を参照する構成、`Procfile`、`bin/render-build.sh`）に基づいて、追加の実装変更なしにデプロイできる手順を記載する。

- 対象読者: このアプリを初めて Supabase / Render にデプロイする人
- 前提: GitHub リポジトリ（`Murakou15724/radio-manager`）に本番用ブランチ（通常 `main`）があること

## 1. 全体構成

```mermaid
flowchart LR
    GH[GitHub: main ブランチ] -- push --> Render[Render Web Service<br/>Rails + Puma]
    Render -- DATABASE_URL 経由で接続 --> Supabase[(Supabase<br/>PostgreSQL)]
    User[ブラウザ] -- HTTPS --> Render
```

- Render が GitHub の push を検知して自動ビルド・デプロイする
- アプリの永続データ（`programs` テーブル）は Supabase の PostgreSQL に保存する
- ログインはパスワード不要（ボタン押下のみ）の仕様のため、公開範囲の管理は §6 を必ず確認すること

## 2. Supabase 側の設定

### 2.1 プロジェクト作成

1. [supabase.com](https://supabase.com) にログインし、New Project を作成する
2. リージョンは Render のリージョン（デフォルトは Oregon / US West）になるべく近いものを選ぶ（レイテンシ低減のため）
3. データベースパスワードを設定する（後で使うので控えておく。忘れた場合は Project Settings → Database から再発行できる）

### 2.2 接続文字列の取得

Supabase の **Project Settings → Database → Connection string** から接続情報を取得する。Supabase は用途に応じて複数の接続先を提供している。

| 接続方式 | ポート | 用途 |
|---|---|---|
| Direct connection | 5432 | マイグレーションなど、短時間・低頻度の接続向け |
| Transaction pooler (Supavisor) | 6543 | Web アプリの通常のリクエスト処理向け（推奨） |

**推奨構成**: Render の Web サービス（Puma、複数スレッド/ワーカー）から常時接続するため、コネクション数の上限に達しないよう **Transaction pooler（6543番ポート）** を使う。

取得した接続文字列は次のような形式になる。

```
postgres://postgres.xxxxxxxxxxxx:[YOUR-PASSWORD]@aws-0-ap-northeast-1.pooler.supabase.com:6543/postgres
```

これを Render の `DATABASE_URL` 環境変数にそのまま設定する（`[YOUR-PASSWORD]` は実際のパスワードに置き換える）。

### 2.3 pgbouncer（トランザクションプーリング）使用時の注意

Supabase の Transaction pooler は内部で pgbouncer のトランザクションモードを使っている。このモードでは PostgreSQL の **prepared statement がセッションをまたいで使えない** という制約があり、Rails の `pg` gem はデフォルトで prepared statement を使うため、そのままだと稀に `prepared statement "a1" already exists` のようなエラーが起きることがある。

`config/database.yml` の `production` セクションに以下を追記して無効化しておくと安全である（`url:` と併記できる）。

```yaml
production:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>
  prepared_statements: false
```

（マイグレーションなど Direct connection の 5432 番ポートだけを使う運用にする場合はこの設定は必須ではないが、Web リクエストで pooler を使う本構成では入れておくことを推奨する。）

### 2.4 無料プランの注意点

Supabase の Free プランは、一定期間（目安として1週間）データベースへのアクセスがないとプロジェクトが自動的に一時停止する。個人利用でアクセス頻度が低い場合は、Supabase ダッシュボードで停止に気づいたら手動で再開（Restore）する必要がある。

## 3. Render 側の設定

このリポジトリには `Procfile` と `bin/render-build.sh` が既にあり、Render の **Ruby（ネイティブ）環境**でのデプロイを想定した構成になっている。`Dockerfile` も存在するが、まずはシンプルなネイティブ環境での手順を示す（Docker を使う場合は §7 を参照）。

### 3.1 Web Service の作成

1. Render ダッシュボードで **New → Web Service** を選択
2. GitHub リポジトリ `radio-manager` を接続し、デプロイ対象のブランチ（`main`）を選ぶ
3. **Language** は `Ruby` を選択（`.ruby-version` の `3.2.0` が自動的に使われる）
4. **Build Command** に以下を設定する

   ```
   ./bin/render-build.sh
   ```

5. **Start Command** に以下を設定する（`Procfile` と同じ内容）

   ```
   bundle exec puma -C config/puma.rb
   ```

`bin/render-build.sh` は `bundle install` → アセットのプリコンパイル → 不要アセットの削除 → **`bundle exec rake db:migrate`** まで一括で行う。つまり **Render に push するたびに自動でマイグレーションが実行される**。マイグレーションを含む変更を本番にデプロイする際は、この前提を踏まえておくこと。

### 3.2 環境変数の設定

Render の **Environment** タブで以下を設定する。

| 変数名 | 値 | 備考 |
|---|---|---|
| `DATABASE_URL` | Supabase の接続文字列（§2.2） | 必須。Web 実行時だけでなくビルド時（`db:migrate`）にも使われる |
| `RAILS_MASTER_KEY` | ローカルの `config/master.key` の中身 | 必須。`config.require_master_key = true`（`config/environments/production.rb`）のため、これがないと起動しない。ローカルで `cat config/master.key` の内容をコピーし、Render 側では "Secret" として登録する（このファイル自体は `.gitignore` によりリポジトリには含まれていない） |
| `RAILS_ENV` | `production` | Render の Ruby 環境では自動設定されないため明示する |
| `RAILS_SERVE_STATIC_FILES` | `true` | `config/environments/production.rb` の `config.public_file_server.enabled` がこれを見て静的ファイル配信を有効にする |
| `RAILS_LOG_LEVEL` | `info`（任意） | 未設定時は `info` がデフォルト |
| `WEB_CONCURRENCY` | 未設定でも可 | Puma のワーカー数。未設定時はマシンの物理コア数が使われる（`config/puma.rb`） |
| `RAILS_MAX_THREADS` | 未設定でも可（デフォルト5） | Supabase 側のコネクション数上限と合わせて調整する |

`PORT` は Render が自動的に注入するため設定不要（`config/puma.rb` が `ENV["PORT"]` を参照する）。

### 3.3 ヘルスチェックパスの設定（重要）

このアプリの `config/routes.rb` には Rails 標準の `/up` ヘルスチェック用ルートが定義されていない。また `ApplicationController#require_login` により **未ログイン状態で `/`（ルート）にアクセスすると `/login` へ 302 リダイレクトされる**。

Render のヘルスチェックがルートパス（`/`）に対して「200 が返ること」を期待する設定になっていると、302 を異常とみなしてデプロイが unhealthy 判定になる可能性がある。Render の **Health Check Path** は次のいずれかに設定すること。

- `/login`（ログイン不要でアクセスでき、常に 200 を返す）

### 3.4 デプロイ確認

デプロイ完了後、以下を確認する。

1. Render のログで `bundle exec rake db:migrate` が成功していること（Supabase 側に `programs` テーブルが作成される）
2. 発行された URL（`https://xxxx.onrender.com`）の `/login` にアクセスし、ログイン画面が表示されること
3. ログインボタンを押してメイン画面に遷移できること
4. 番組を1件登録し、Supabase の Table Editor で `programs` テーブルに行が増えることを確認する

## 4. マイグレーションの運用

- 通常のデプロイ: `bin/render-build.sh` が毎回 `db:migrate` を実行するため、`db/migrate/` にファイルを追加して push するだけでよい
- 手動でマイグレーションを実行したい場合: Render ダッシュボードの **Shell** タブから `bundle exec rails db:migrate` を実行できる
- ロールバックしたい場合も同様に Shell から `bundle exec rails db:rollback` を実行する（Render の自動ビルドにはロールバック手順は組み込まれていないため、必要な場合は手動対応する）

## 5. ローカルの Supabase 接続確認（任意）

Render にデプロイする前に、ローカル環境から Supabase に接続できるかを確認したい場合は、以下のように一時的に環境変数を渡して起動する。

```bash
RAILS_ENV=production RAILS_MASTER_KEY=xxxxxxxx DATABASE_URL="postgres://postgres.xxxx:PASSWORD@xxxx.pooler.supabase.com:6543/postgres" bin/rails db:migrate
```

`RAILS_MASTER_KEY` はローカルの `config/master.key` の値を使う。実行後、Supabase の Table Editor で `programs` テーブルが作成されていれば接続は成功している。

## 6. 公開前に確認すべきこと（セキュリティ）

このアプリは [`docs/improvement-recommendations.md`](./improvement-recommendations.md) に記載の通り、**ログインにパスワード照合がない**（ボタン押下のみで誰でもログインできる）仕様になっている。Render にデプロイすると URL を知っている人は誰でもアプリを操作できる状態になるため、個人利用を想定する場合は以下のいずれかを検討すること。

- URL を第三者に共有しない（実質的な非公開運用）
- Render の有料プランで利用できる IP 許可リストなど、ネットワークレベルでのアクセス制限を設定する
- リバースプロキシや Cloudflare Access 等、Render の手前に認証レイヤーを追加する

また `/settings` 画面は DB のホスト名・データベース名・ユーザー名を表示する仕様が残っている（パスワードは非表示化済み）。本番の Supabase 接続情報が画面に出ること自体が許容できない場合は、`app/controllers/settings_controller.rb` と `app/views/settings/index.html.erb` の該当箇所を無効化すること。

## 7. （代替手段）Dockerfile を使ったデプロイ

リポジトリには `Dockerfile` と `docker-compose.yml`（ローカルで PostgreSQL コンテナと合わせて動かすため）も用意されている。Render で Docker ベースのデプロイをしたい場合は、Web Service 作成時に **Language** で `Docker` を選択すればよい。この場合、

- `bin/render-build.sh` は使われず、`Dockerfile` の `ENTRYPOINT`（`bin/docker-entrypoint`）が起動時に `db:prepare` を実行する
- 環境変数（`DATABASE_URL`、`RAILS_MASTER_KEY` 等）の設定は §3.2 と同様に必要
- `docker-compose.yml` はあくまでローカル開発用（Supabase ではなく自前の PostgreSQL コンテナに接続する構成）であり、Render の本番デプロイには使われない

特別な理由がなければ、ビルドが速く構成がシンプルな §3 のネイティブ Ruby 環境でのデプロイを推奨する。
