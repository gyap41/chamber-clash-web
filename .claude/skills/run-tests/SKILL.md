---
name: run-tests
description: "CHAMBER CLASHの自動テスト（run_tests.ps1）を実行し、PASS/FAIL/NO-PASSを隠さず報告し、FAILはログから根本原因を特定して直す。「テストして」「テストを回して」「run_tests」「全テスト」と言われたとき、またはGDScriptの変更を終えて動作確認するときに使う。"
---

<!-- 自動生成: tools/agent/sync_agents.py（台帳: tools/agent/agents.toml）。直接編集せず、台帳を直して同期する。 -->

手順の正本は `.agents/skills/run-tests/SKILL.md`（Codexと共通）。最初にそれを読み、そのとおりに進める。

Claude Code固有の補足:
- `run_tests.ps1` はBashツールで `timeout: 600000` を付けて実行する。10分を超えそうなら `run_in_background` で実行し、完了通知を待つ（途中経過をポーリングしない）。
