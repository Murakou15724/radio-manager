# Radio Manager

ラジオ番組の更新周期(毎週・隔週・月1回)を登録し、「未聴取」「聴取済み」を管理する小規模な Web アプリケーションです。

詳しい仕様は [`docs/application-overview.md`](docs/application-overview.md) を参照してください。

## 必要な環境

- Ruby 3.2.0（`.ruby-version` 参照）
- Bundler
- SQLite3（development / test）
- PostgreSQL（production。`docker-compose.yml` を使う場合は不要）

## セットアップ

```bash
bundle install
bin/rails db:prepare
```

## 起動

```bash
bin/rails server
```

`http://localhost:3000` にアクセスすると、ログイン画面が表示されます（現状パスワードは不要で、ログインボタンを押すだけでログインできます）。

## テスト

```bash
bin/rails test
```

## Docker で起動する場合

```bash
docker compose up
```

`docker-compose.yml` は PostgreSQL コンテナと Web コンテナを起動します。production 用の credentials 復号鍵（`RAILS_MASTER_KEY` など）は別途環境変数等で注入する必要があります。

## 主な環境変数

| 変数 | 用途 |
|---|---|
| `DATABASE_URL` | production の DB 接続先 |
| `RAILS_MASTER_KEY` | production で credentials を復号するための鍵 |
| `REDIS_URL` | Action Cable（production）用。現状 Redis gem は未導入で未使用 |

その他の環境変数や運用上の注意点は [`docs/application-overview.md`](docs/application-overview.md) の「環境変数、起動、デプロイ」を参照してください。

## スリープ防止の定期アクセス

GitHub Actions の `Keep alive` が、毎日 **日本時間8:00〜23:55の5分間隔**（1日192回）で、認証不要の `https://stylish-radio-manager.onrender.com/up` にアクセスします。

1. `.github/workflows/keep-alive.yml` をデフォルトブランチに反映します。
2. **Actions → Keep alive → Run workflow** で手動実行し、成功することを確認します。

アクセス先を変更する場合は、ワークフローの `APP_URL` を本番アプリのベースURLに変更してください。`/up` は自動で付加されます。

通信エラーやHTTPエラーはジョブの失敗として記録され、一時的な通信障害などは最大3回再試行します。[GitHub Actionsの仕様](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)により、混雑時は実行が遅延・欠落する場合があり、厳密な5分間隔は保証されません。また、公開リポジトリでは60日間リポジトリへの活動がないと定期実行が自動停止するため、停止時はActions画面から再度有効化してください。
