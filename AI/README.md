# AI Development Team Agents

Rails 開発で AI を「開発チーム」として使うためのエージェント定義集です。各 Markdown は、依頼を分解し、要件整理、設計、実装、検証、レビュー、PR、ドキュメント更新までを役割分担して進めるための指示書です。

## 基本方針

- いきなり実装しない。目的、要件、テスト観点、設計方針を確認してから着手する。
- 要件定義書、シナリオテスト仕様書、テーブル定義、画面遷移図、既存実装を優先して読む。
- 実装担当とレビュー担当を分け、自己完結した確認で終わらせない。
- UI の表示制御だけで安全と判断しない。controller、model、DB 制約、直接リクエストを確認する。
- 変更範囲は issue の完了定義に合わせ、別 issue に分けるべき内容を混ぜない。
- 未実装、未確認、推測を PR 本文や完了報告に書かない。

## エージェント一覧

| ファイル | 役割 |
|---|---|
| `router.md` | 依頼内容から使うエージェントと実行順を決める |
| `pm_agent.md` | issue、目的、スコープ、完了定義を整理する |
| `requirements_user_agent.md` | ユーザー体験、画面表示、操作フローの要件を確認する |
| `requirements_business_agent.md` | 業務、運用、履歴、監査、データ保持の観点で要件を確認する |
| `architecture_safe_agent.md` | 既存 Rails 構成に沿った堅実な設計を作る |
| `architecture_innovation_agent.md` | 改善案、拡張案、別 issue 候補を整理する |
| `implementation_agent.md` | 要件と設計に沿って最小範囲で実装する |
| `qa_agent.md` | 正常系、異常系、回帰、手動確認、自動テストを実施する |
| `scenario_test_agent.md` | シナリオテスト仕様書と実装の対応を確認する |
| `security_agent.md` | 権限、直アクセス、副作用のあるリクエストを確認する |
| `db_integrity_agent.md` | 関連、外部キー、削除影響、N+1、migration を確認する |
| `rails_review_agent.md` | Rails 実装品質、責務分離、不要差分をレビューする |
| `pr_agent.md` | 実装内容と確認結果に基づく PR 本文を作成する |
| `docs_agent.md` | 要件、テスト、設計判断、レビュー記録を更新する |

## 推奨フロー

```txt
router
↓
pm_agent
↓
requirements_user_agent / requirements_business_agent
↓
architecture_safe_agent / architecture_innovation_agent
↓
implementation_agent
↓
qa_agent
↓
scenario_test_agent
↓
security_agent
↓
db_integrity_agent
↓
rails_review_agent
↓
pr_agent
↓
docs_agent
```

依頼内容によって全員を必ず使う必要はありません。ただし、DB、権限、削除、更新、管理画面、決済、履歴に関わる場合は、`security_agent.md` と `db_integrity_agent.md` を省略しないでください。

## 使い方

対象プロジェクトからこのディレクトリを参照できるようにします。

```bash
ln -s /path/to/ai-agents ./agents
```

Codex などの AI 開発環境で、最初に router を指定します。

```txt
agents/router.md を参照して router として動作してください。

依頼:
現在のブランチの商品削除機能について、実装、テスト、レビューまでに必要なエージェントを選んでください。
```

各エージェントを実行するときは、次の情報を渡してください。

- issue または依頼文
- 関連ドキュメントの場所
- 対象ブランチまたは差分
- 既に確認済みのこと
- 未確認、保留、制約条件

## 完了の基準

- 要件、実装、テスト、レビュー、PR 本文の内容が一致している。
- 確認済みと未確認が明確に分かれている。
- 重要なリスクに対して、修正、保留、別 issue 化のいずれかの判断がある。
- 実行したコマンドと結果が記録されている。
- ドキュメントに古い仕様や矛盾が残っていない。
