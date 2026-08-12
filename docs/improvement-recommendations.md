# 改善提案（2026-08-12）

本書は Radio Manager のコードレビューで見つかった、修正を検討すべき点をまとめたものである。事実関係は [`application-overview.md`](./application-overview.md) と一致させている。優先度は「放置した場合の影響の大きさ」を基準にした目安であり、対応順は開発者の判断による。

各項目について、後日改めてコードと突き合わせて検証し、対応可能なものは同じブランチで修正した。対応状況を各項目に明記している。

## 優先度: 高

### 1. 設定画面が DB 接続パスワードを画面に平文表示している【対応済み】

- 該当: `app/controllers/settings_controller.rb`、`app/views/settings/index.html.erb`
- 内容: ログインさえしていれば誰でも DB の接続パスワードを閲覧できた。
- 対応: `SettingsController#index` で `password` キーを除外し、画面からパスワード表示自体を削除した。

### 2. ログインがパスワード照合なしで成立する（前回対応についての注意）【対応方針: 運用でカバー】

- 該当: `app/controllers/sessions_controller.rb#create`
- 内容: ユーザーの明示的な要望により、`POST /login` を受けるだけで無条件に `session[:authenticated] = true` となる。これはアプリの利用者制限を実質的に撤廃する変更である。
- 対応方針: コードは変更しない。このアプリをインターネット上に公開する場合は、ネットワークレベルでのアクセス制限（リバースプロキシでの Basic 認証、IP 制限、VPN 内限定公開など）と組み合わせることを推奨する。個人利用でローカル・私的ネットワーク限定であれば現状のままで実用上の問題は小さい。

### 3. `docker-compose.yml` が壊れている【対応済み】

- 該当: `docker-compose.yml` 末尾
- 内容: ファイル末尾に `</content>` および `parameter name="filePath">...` という、AIツールの出力がそのまま混入したとみられる不正な文字列があり、YAML として不正だった。
- 対応: 末尾の不正な行を削除し、`YAML.load_file` でパース可能なことを確認した。

### 4. Docker イメージのビルドが `storage/` ディレクトリ不在で失敗する【対応済み】

- 該当: `Dockerfile`（`chown -R rails:rails db log storage tmp`）
- 内容: リポジトリに `storage/` ディレクトリが存在せず、`docker build` 実行時にこの行で失敗する状態だった。
- 対応: `storage/.keep` を追加した。あわせて、`.gitignore` に `/storage/*` を除外した直後で再度 `/storage/*` を除外する重複記述があり、`!/storage/.keep` の例外が無効化されていたため、この重複ブロックを削除した（このままでは `storage/.keep` を追加してもコミットできない状態だった）。

## 優先度: 中

### 5. `GET /` `/programs` が参照だけでなく DB を更新する【一部対応】

- 該当: `app/controllers/programs_controller.rb#index`
- 内容: 一覧表示のたびに聴取済みレコードを走査し、更新回が変わっていれば `listened=false` に自動更新していた。GET は安全（副作用なし）であるべきという原則に反する。
- 対応: 自動リセット処理を `Program.reset_stale_listened!` というモデルのクラスメソッドに抽出し、コントローラーからは1行で呼び出す形にした（`app/models/program.rb`、`app/controllers/programs_controller.rb`）。ロジックのテスト容易性・可読性は改善したが、**GET リクエストで状態変更が起きる点自体は変更していない**。完全に解消するには、定期実行（cron・ActiveJob 等のジョブ基盤）に切り出す設計変更が必要で、現状のアプリにはジョブキュー基盤がないため、別途方針の検討が必要である。

### 6. `resources :programs` が未実装の `new` / `show` ルートを公開している【対応済み】

- 該当: `config/routes.rb`
- 内容: ルーティングは生成されるが、対応する view・処理がなくアクセスするとエラーになっていた。
- 対応: `resources :programs, except: [:new, :show]` に変更した。`program_path`（`show`/`destroy`で共有）や `edit_program_path` は引き続き利用可能なことを確認済み。

### 7. `programs` テーブルにバリデーションがない【一部対応】

- 該当: `app/models/program.rb`
- 内容: `name` を含む業務カラムが全て NULL 許可で、`validates` も定義されていなかった。
- 検証結果: `weekday`・`base_date` を必須化する案は、テストコード（`test/models/program_test.rb`）が「未設定のまま保存できること」「その場合に `next_update_date` 等が `nil` を返すこと」を前提に書かれており、意図的に許容された仕様と判断した。presence 必須化は既存の設計・テストと矛盾するため見送った。
- 対応: `name`・`frequency_type` の presence 検証と、`weekday`（0〜6）・`week_of_month`（1〜5）の値が入力されている場合の範囲チェックを追加した。値が不正な範囲（例: `weekday: 7`）で保存されることは防げるようになった。

### 8. `docker-compose.yml` の DB と `Dockerfile` のパッケージが不一致【対応済み】

- 該当: `Dockerfile`
- 内容: production は `pg` gem・PostgreSQL 前提だが、`default-libmysqlclient-dev` / `default-mysql-client` という MySQL 用パッケージを導入していた。
- 対応: `libpq-dev` / `postgresql-client` に置き換えた。

### 9. `config/routes.rb` に scaffold 由来と思われる重複ルートがある【対応済み】

- 該当: `config/routes.rb` の `get 'programs/index'`
- 検証結果: 一見不要に見えたが、`test/controllers/programs_controller_test.rb` が `programs_index_url` ヘルパー経由でこのルートに依存していた。
- 対応: ルートを削除し、テスト側を `resources :programs` が標準生成する `programs_url` を使うように修正した（このテストは項目14の認証追加もあわせて実施）。

### 10. 隔週（biweekly）計算に曜日がズレるバグがある【対応済み・確認済みの実バグ】

- 該当: `app/models/program.rb` の `Program#next_update_date`（biweekly 分岐）
- 検証結果: `base_date` と指定 `weekday` が異なる場合、Ruby スクリプトで実際に計算をトレースしたところ、テスト `"biweekly: 異なる曜日を持つ隔週プログラムの次更新日"` が期待する `2026-05-06` に対し、実装は `2026-05-04`（曜日が異なる日）を返しており、実バグであることを確認した。
- 対応: 「`base_date` 以降で最初に指定曜日と一致する日」を周期の起点として求め、そこから 14 日単位で `from_date` より後の日を計算する形にロジックを統一・簡潔化した。既存の全 biweekly テストケース（同一曜日・異なる曜日の両方）を手計算で再検証し、期待値と一致することを確認済み。

## 優先度: 低

### 11. ログイン成功時に `reset_session` を呼んでいない【対応済み】

- 該当: `app/controllers/sessions_controller.rb#create`
- 対応: `session[:authenticated] = true` の前に `reset_session` を呼ぶようにした。

### 12. ログイン・ログアウトのルーティングが非 RESTful【未対応】

- 該当: `config/routes.rb`（`get/post 'login'`, `delete 'logout'`）
- 対応方針: 動作上の問題がなく、`resource :session` 形式への書き換えはヘルパー名（`login_path` → `new_session_path` 等）の変更を伴い影響範囲が広い一方で得られる効果は可読性向上のみのため、今回は見送った。

### 13. `ProgramsController` でアプリ側 `sort_by` を使っている【対応不可・調査により判明】

- 該当: `app/controllers/programs_controller.rb`
- 検証結果: 前回の指摘では「DB側でソート可能な内容をロード後に Ruby でソートしている」としたが、実際にはソートキーの `next_update_date` は DB カラムではなく `Program` モデルのメソッドで動的に計算される値であり、`ORDER BY` に単純に置き換えることはできない。件数が少ない現状の運用では実害は小さいと判断し、対応は見送った。
- 対応するなら: `next_update_date` をバッチで計算して専用カラムに保存し、それに対して `order` する設計変更が必要（データの鮮度管理が別途必要になるため、今回のスコープでは実施しない）。

### 14. controller テストが認証を考慮していない【対応済み】

- 該当: `test/controllers/programs_controller_test.rb`
- 内容: 未認証セッションのまま `:success` を期待しており、`ApplicationController#require_login` によるリダイレクトと衝突する可能性が高かった。加えて、存在しない `programs_index_url` ヘルパーに依存していた（項目9参照）。
- 対応: `setup` ブロックで `post login_url` を実行してから各テストを実行するようにし、リクエスト先も `programs_url` に修正した。

### 15. `config/credentials.yml.enc.bak` がリポジトリに残っている【対応済み】

- 対応: 不要なバックアップファイルを削除した。

### 16. README がフレームワーク生成時のままである【対応済み】

- 対応: セットアップ、起動、テスト、Docker、主な環境変数の手順を追記した。

## 注記: テスト実行について

本対応中、開発環境のテスト用データベース（`db/test.sqlite3`）に `programs` テーブルが存在せず、マイグレーションが未適用の状態だったことを確認した。マイグレーション適用（`bin/rails db:migrate` 相当の操作）は本セッションの安全ポリシー上、人間の承認なしには実行できないため、このブランチではテストスイートを実行できていない。

そのため、`app/models/program.rb` の隔週計算バグ修正については、Rails を介さず日付計算ロジックのみを抜き出した Ruby スクリプトで、既存テストが期待する入出力と一致することを手動検証した（4パターン全て一致）。マージ前に、`bin/rails db:migrate` を実行した上で `bin/rails test` を一度実行し、本ドキュメント記載の対応が実際のテストでも成功することを確認することを強く推奨する。
