---
# name/description は 自動生成: tools/agent/sync_agents.py（台帳: tools/agent/agents.toml）。直接編集せず、台帳を直して同期する。
name: run-tests
description: "CHAMBER CLASHの自動テスト（run_tests.ps1）を実行し、PASS/FAIL/NO-PASSを隠さず報告し、FAILはログから根本原因を特定して直す。「テストして」「テストを回して」「run_tests」「全テスト」と言われたとき、またはGDScriptの変更を終えて動作確認するときに使う。"
---

<!-- 正本: .agents/skills/run-tests/SKILL.md（Codexが直接読む）。Claude Codeは .claude/skills/run-tests/SKILL.md からここを読む。 -->

# テスト実行と失敗の修正

ローカルのPCで直接実行する（以前のリモート用の「コミットしてバイト照合」手順は不要）。

## 1. 実行

```bash
powershell -ExecutionPolicy Bypass -File run_tests.ps1
```

- 全150本前後で数分かかる（2026-10-04: 151本）。コマンドの待ち時間は10分以上にし、途中で打ち切らない。
- `render.gd`（描画あり）はユーザーが求めたときだけ `-IncludeRender` を付ける。
- 1本だけ再実行するとき（修正後の確認）:

```bash
timeout 120 .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/<name>.gd --quit-after 120
```

`--quit-after` と `timeout` を必ず付ける（スクリプトエラーでGodotが終了せず待ち続けたことがある）。

## 2. 結果を読む

ログ全体を読まない。まず抜き出しスクリプトを使う:

```bash
python tools/agent/extract_test_failures.py
```

（最新の `.local/logs/run_tests-*.log` を読む。別のログはパスを引数に渡す。）

判定の意味（run_tests.ps1の規則）:
- **FAIL**: 終了コード≠0、`SCRIPT ERROR`、`Assertion failed`、行頭`ERROR:`（終了時の「resources still in use」を除く）、`FAIL:`。
- **PASS**: エラーなし、かつ行頭`PASS`の行がある。
- **NO-PASS**: エラーもPASS行もない撮影・確認用スクリプト。失敗には数えないが、名前は必ず報告する。
- Leaks列は終了時のリソース残りで、失敗ではない。

## 3. FAILの原因を直す

1. 抜き出し結果の「first error location」でまとめる。**1つのスクリプトの構文・型エラーで、それをpreloadする多数のテストが連鎖してFAILする**のがよくある形。件数が多いグループの先頭の場所から直す。
2. 典型例: 三項式に`:=`を使い、Variantと推論されてParse Error（`var x: float = a if c else b` のように型を書く）。`Dictionary.get()`・型なし変数・配列要素からの`:=`推論も同じ。
3. 原因のファイルを直したら、そのファイルに `--check-only` をかけ（Claude Code・Codexとも編集後のhookで自動で走る）、該当テストを1本ずつ再実行し、最後に全体を再実行する。
4. 修正→再実行は**最大3回**。それでも残るFAILは止めて、原因の推定と試したことを報告する。

### してはいけないこと

- assertを弱める・消す・コメントアウトする、テストを削除・改名してPASSにする。
- run_tests.ps1の判定規則を変えてPASSにする。
- 今回の変更と無関係な既存のFAILを黙って直す、または黙って無視する。無関係と判断した根拠（`git stash`せずに、最新ログ以前の記録や変更範囲から）を書いて報告する。
- テストの期待値が古いだけに見える場合も、勝手に書き換えない。どちらが正しいか（仕様か実装か）を示してユーザーに確認する。

## 4. 報告の書式

```
テスト結果: PASS 145 / FAIL 0 / NO-PASS 4 / 合計 149（ログ: .local/logs/run_tests-YYYYMMDD-HHMMSS.log）
FAIL: なし（ある場合はテスト名と最初のエラー行・場所を全部）
NO-PASS: enemy_animation_review, ...（失敗ではない撮影用）
修正したこと: ファイルと理由（あれば）
未解決: …
```

- 数字は実行結果をそのまま書く。前回の成功やログ以外の推測でPASSと言わない。
- 自動テストのPASSは、画面の見た目・操作感・音の確認とは別。必要なら「目視・試聴は未確認」と書く。
