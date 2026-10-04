---
name: asset-gen
description: "画像・SE・BGM素材を外部AIで生成し、機械チェック→レビュー係の判定→作り直し（最大3回）→ユーザーのゲーム内最終確認まで進める。有料APIを使うためユーザーが /asset-gen で呼んだときだけ使う。"
disable-model-invocation: true
argument-hint: "<素材の種類と対象（例: 火袋トカゲの吐き出しSE、苔玉の歩行シート）>"
---

<!-- 自動生成: tools/agent/sync_agents.py（台帳: tools/agent/agents.toml）。直接編集せず、台帳を直して同期する。 -->

対象: $ARGUMENTS

手順の正本は `.agents/skills/asset-gen/SKILL.md`（Codexと共通）。最初にそれを読み、そのとおりに進める。

Claude Code固有の補足:
- レビューは Agent ツールで `art-reviewer`（画像、Opus）/ `audio-reviewer`（音、Sonnet）を呼ぶ。
- 有料生成のコマンドは `tools/agent/guard.py` が毎回確認を求める。許可された回数を超えて実行しない。
