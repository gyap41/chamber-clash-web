@AGENTS.md

# Claude Code固有の補足

共通の規則（Godotの実行、GDScriptの書き方、素材の置き場所、秘密情報）は上のAGENTS.mdの「Godot・GDScriptの共通規則」。Codexも同じAGENTS.mdを読むので、両方に効く規則はAGENTS.mdへ書き、ここにはClaude Code固有のことだけを書く。

- 作業の入口は `docs/README.md` の依頼別索引。`docs/archive/`（旧MIGRATION_PLAN.mdを含む）は履歴で、今の指示ではない。`.local/backups/` は古いコードの複製なので読まない（settings.jsonで禁止）。
- スキル: `run-tests`（テスト）、`/asset-gen`（素材生成。有料なのでユーザーが呼んだときだけ）。手順の正本は `.agents/skills/` にあり、`.claude/skills/` はそれを読む入口。`.claude/skills/`・`.claude/agents/`・settings.jsonの `hooks` は `tools/agent/agents.toml` からの自動生成なので、直接編集しない（AGENTS.mdの同期手順に従う）。
- レビュー係: `art-reviewer`（画像、Opus）、`audio-reviewer`（音、Sonnet）。指示の正本は `tools/agent/reviewers/`。
- hook（`.claude/settings.json` → `tools/agent/`）: `.gd` 編集後の構文チェック、`.md` 編集後の資料索引チェック、終了時の変更 `.gd` 全体のチェック、`.env`・APIキーの読み取り禁止と有料生成の確認、開始時の状況表示。hookに止められたら、内容を読んで直す（回避しない）。
- ゲームの実行・実行時エラーの確認には、接続されている Godot MCP サーバー（`mcp__godot__*`）も使える。
- 報告では、自動テストのPASS・画面の目視・操作感・試聴・ユーザー採用を別の事実として書く。コミットは英語の命令形の件名で、ユーザーに頼まれたときだけ。
