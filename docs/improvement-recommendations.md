# 改善提案（2026-08-12）

本書は Radio Manager のコードレビューで見つかった、修正を検討すべき点をまとめたものである。事実関係は [`application-overview.md`](./application-overview.md) と一致させている。優先度は「放置した場合の影響の大きさ」を基準にした目安であり、対応順は開発者の判断による。

このドキュメントの作成と同時に、**ログイン処理からパスワード照合を撤廃する対応（`login_0812` ブランチ）** を実施済みである。以降の記載はその対応後の状態を前提とする。

## 優先度: 高

### 1. 設定画面が DB 接続パスワードを画面に平文表示している

- 該当: `app/controllers/settings_controller.rb`、`app/views/settings/index.html.erb`（`@db_config[:password]` を出力）
- 問題: ログインさえしていれば誰でも DB の接続パスワードを閲覧できる。パスワード不要ログインへの変更後は、この画面に到達するハードルがさらに下がっている。
- 提案: 少なくとも `password` フィールドは画面から除外する。接続確認が目的なら「接続できているか（真偽値）」のみを表示すれば足りる。

### 2. ログインがパスワード照合なしで成立する（今回の対応そのものについての注意）

- 該当: `app/controllers/sessions_controller.rb#create`
- 内容: ユーザーの明示的な要望により、`POST /login` を受けるだけで無条件に `session[:authenticated] = true` となる。これはアプリの利用者制限を実質的に撤廃する変更である。
- 提案（要検討）: このアプリをインターネット上に公開する場合は、ネットワークレベルでのアクセス制限（Basic 認証をリバースプロキシ側に置く、IP 制限、VPN 内限定公開など）と組み合わせることを推奨する。個人利用でローカル・私的ネットワーク限定であれば現状のままでも実用上の問題は小さい。

### 3. `docker-compose.yml` が壊れている

- 該当: `docker-compose.yml` 末尾
- 内容: ファイル末尾に `</content>` および `parameter name="filePath">...` という、AIツールの出力がそのまま混入したとみられる不正な文字列がある。YAML として不正なため `docker compose` コマンドが失敗する。
- 提案: 末尾の不正な行を削除する。

### 4. Docker イメージのビルドが `storage/` ディレクトリ不在で失敗する

- 該当: `Dockerfile`（`chown -R rails:rails db log storage tmp`）
- 内容: リポジトリに `storage/` ディレクトリが存在しないため、`docker build` 実行時にこの行で失敗する可能性が高い。
- 提案: `storage/.keep` を追加するか、`chown` 対象から `storage` を外す（Active Storage を使わないなら不要）。

## 優先度: 中

### 5. `GET /` `/programs` が参照だけでなく DB を更新する

- 該当: `app/controllers/programs_controller.rb#index`
- 内容: 一覧表示のたびに聴取済みレコードを走査し、更新回が変わっていれば `listened=false` に自動更新している。GET は安全（副作用なし）であるべきという Rails/HTTP の原則に反しており、監視やプリフェッチ、ブラウザの先読みでも状態が変わり得る。
- 提案: 自動リセット処理は `before_action` ではなく明示的なバッチ処理（Rake タスクや `ActiveJob`）に切り出す。表示ロジックと状態変更ロジックを分離する。

### 6. `resources :programs` が未実装の `new` / `show` ルートを公開している

- 該当: `config/routes.rb`、`app/controllers/programs_controller.rb`
- 内容: ルーティングは生成されるが、対応する view・処理がない。アクセスするとエラーになる。
- 提案: 使わないなら `resources :programs, except: [:new, :show]` のように制限する。

### 7. `programs` テーブルにバリデーション・DB制約がない

- 該当: `app/models/program.rb`、`db/schema.rb`
- 内容: `name`、`weekday` などの業務カラムが全て NULL 許可で、`validates` も定義されていない。日付計算が不可能なレコードでも保存できてしまう。
- 提案: 最低限 `validates :name, presence: true` 等を追加し、頻度種別ごとに必須カラム（`weekday`、`base_date`、`week_of_month`）の組み合わせを検証する。

### 8. `docker-compose.yml` の DB と `Dockerfile` のパッケージが不一致

- 該当: `docker-compose.yml`（PostgreSQL 15）、`Dockerfile`（`default-libmysqlclient-dev` / `default-mysql-client` を導入）
- 内容: production は `pg` gem・PostgreSQL 前提だが、Dockerfile は MySQL クライアントパッケージを入れている。不要な依存であり、意図とも食い違う。
- 提案: Dockerfile のパッケージを PostgreSQL 用（`libpq-dev` 等、alpine/slim系なら該当パッケージ）に揃える。

### 9. `config/routes.rb` に scaffold 由来と思われる重複ルートがある

- 該当: `config/routes.rb` 2行目 `get 'programs/index'`
- 内容: 3行目の `root "programs#index"` および `resources :programs` が生成する `/programs` と役割が重複しており、実質使われていない可能性が高い。
- 提案: 不要であれば削除する。

### 10. 隔週（biweekly）計算とテストの期待値がズレている可能性

- 該当: `app/models/program.rb`（`next_update_date` の biweekly 分岐）、`test/models/program_test.rb`
- 内容: 基準日と指定曜日が異なる入力の場合、コードを静的に追うとテストが期待する日付と 2 日ズレる可能性がある（テスト未実行のため実測未確認）。
- 提案: 該当テストを実行して実際の挙動を確認し、コードとテスト期待値のどちらが仕様として正しいかを明確にする。

## 優先度: 低

### 11. ログイン成功時に `reset_session` を呼んでいない

- 該当: `app/controllers/sessions_controller.rb#create`
- 内容: ログイン前後でセッション ID が変わらないため、セッション固定化 (session fixation) のリスクが残る。パスワード照合がなくなった現状でも、認証状態を切り替えるタイミングでセッションを再生成する習慣は維持した方がよい。
- 提案: `create` アクションの先頭で `reset_session` を呼んでから `session[:authenticated] = true` を設定する。

### 12. ログイン・ログアウトのルーティングが非 RESTful

- 該当: `config/routes.rb`（`get/post 'login'`, `delete 'logout'`）
- 内容: Rails の慣習である `resource :session` 形式ではなく個別定義になっている。動作上の問題はないが一貫性に欠ける。
- 提案: 優先度は低いが、書き換えるなら `resource :session, only: [:new, :create, :destroy]` 等に統一する。

### 13. `ProgramsController` でアプリ側 `sort_by` を使っている

- 該当: `app/controllers/programs_controller.rb`
- 内容: DB 側でソート可能な内容をロード後に Ruby でソートしており、件数が増えるとパフォーマンス上不利。
- 提案: `order` 句を使った DB ソートに置き換える。

### 14. controller テストが認証を考慮していない

- 該当: `test/controllers/programs_controller_test.rb`
- 内容: 未認証セッションのまま `:success` を期待しており、`ApplicationController#require_login` によるリダイレクトと衝突する可能性が高い（未実行のため実測未確認）。
- 提案: `session[:authenticated] = true` を設定してからリクエストするヘルパーを用意する。

### 15. `config/credentials.yml.enc.bak` がリポジトリに残っている

- 該当: リポジトリ直下 `config/credentials.yml.enc.bak`
- 内容: 暗号化済みファイルとはいえ、運用上不要なバックアップファイルがコミットされている。
- 提案: 不要であれば削除する。

### 16. README がフレームワーク生成時のままである

- 該当: `README.md`
- 内容: 環境構築、必要な環境変数、起動手順、デプロイ手順が書かれていない。
- 提案: 最低限のセットアップ手順とデプロイ手順を追記する。

## 対応済み（本ブランチでの必須対応）

- ログイン画面からパスワード入力欄を削除し、`SessionsController#create` のパスワード照合ロジックを撤廃した。
  - 変更ファイル: `app/controllers/sessions_controller.rb`、`app/views/sessions/new.html.erb`
  - 影響: `ENV["APP_PASSWORD"]` は参照されなくなったため、デプロイ環境の環境変数設定からも削除して問題ない。
