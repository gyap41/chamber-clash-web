# AIエージェントの設定（Claude Code・Codex）

区分: 開発ツール・設定の説明。状態: 運用中（2026-10-04作成）。定義する範囲: Claude CodeとCodexの設定ファイルの配置、共通部品、確認済みの範囲。関連する正本: [AGENTS.md](../../AGENTS.md)（両エージェント共通の指示）/ [CLAUDE.md](../../CLAUDE.md)（Claude Code固有）/ [候補素材の運用](../../assets/candidates/README.md) / [機械チェック](../asset_check/README.md)

1人開発用。チーム向けの仕組み（devcontainer等）は置かない。**同じ内容は1か所に置き、各エージェントの設定はそれを参照するだけにする。**

## 配置

|役割|正本（共通）|Claude Code|Codex|
|---|---|---|---|
|指示|`AGENTS.md`|`CLAUDE.md`（`@AGENTS.md` を取り込み＋固有の補足）|`AGENTS.md` を直接読む|
|設定|—|`.claude/settings.json`（Git管理）、`.claude/settings.local.json`（個人用・Git除外）|`.codex/config.toml`（プロジェクトを信頼したときだけ読まれる）|
|hook|`tools/agent/*.py`|`.claude/settings.json` の `hooks`|`.codex/hooks.json`|
|スキル|`.agents/skills/<name>/SKILL.md`|`.claude/skills/<name>/SKILL.md`（正本を読む入口）|`.agents/skills/` を直接読む|
|レビュー係|`tools/agent/reviewers/*.md`|`.claude/agents/art-reviewer.md`（Opus）・`audio-reviewer.md`（Sonnet）|`.codex/agents/art_reviewer.toml`（GPT-6.1 Sol）・`audio_reviewer.toml`（GPT-6 Luna）|
|コマンドの許可|—|`.claude/settings.json` の `permissions` と `guard.py`|`.codex/rules/project.rules` とサンドボックス設定|

## 台帳と同期（`agents.toml` → `sync_agents.py`）

両ツールで同じことを2か所に書く部分は、台帳 [agents.toml](agents.toml) だけを直し、同期スクリプトで書き出す。

```bash
python tools/agent/sync_agents.py
```

|台帳の項目|書き出す先|
|---|---|
|`[[skills]]`|`.claude/skills/<name>/SKILL.md`（全体）、`.agents/skills/<name>/SKILL.md`（先頭のname/descriptionだけ。本文の手順は手書き）、`explicit_only` なら `.agents/skills/<name>/agents/openai.yaml`|
|`[[reviewers]]`|`.claude/agents/<claude_name>.md`、`.codex/agents/<codex_name>.toml`（本文は `instructions` のファイル）|
|`[[hooks]]`|`.claude/settings.json` の `"hooks"`（他のキーは手書きのまま）、`.codex/hooks.json`|
|`[safety]`|書き出さない。Claudeの `permissions.deny`、`.codex/config.toml`（ネットワーク禁止・キーの除外）、`.codex/rules/project.rules`（有料生成はprompt、force pushはforbidden）、`guard.py` に必要な規則があるかを確認するだけ|

- `python tools/agent/sync_agents.py --check` は何も書かずに、台帳とのずれと安全ルールの欠落を報告する（問題があれば終了コード1）。
- どちらのツールで作業しても、台帳・生成ファイル・安全ルールのファイルを編集した直後と、作業の終了時にhookが `--check` を実行し、ずれていれば直させる。生成ファイルを手で直すと止められる。
- 新しいスキルを台帳に足して同期すると、`.agents/skills/<name>/SKILL.md` が「本文（手順）をここに書く」という仮の本文で作られ、本文を書くまで `--check` が知らせる。
- 2026-10-04に確認した動作: 生成ファイルの手編集（Claude・Codexの両形式）、安全ルールの削除、台帳だけ直して同期を忘れた場合をそれぞれ検出し、同期で両ツールに同じ変更が入り、Codexスキルの手書き本文が保たれることを確認した。

## hook（`tools/agent/`）

|スクリプト|タイミング|内容|
|---|---|---|
|`guard.py`|ツール実行前|`.env`・`*_API_KEY`・環境変数の一覧表示を含むコマンドや、`.env` の読み書きを止める（終了コード2）。Claude Codeでは有料生成（`generate_image.py` の `--check`/`--plan` 以外、`asset.py se/bgm` の `--dry-run` 以外）に毎回確認を求める|
|`post_edit.py`|ファイル編集後（Claude: Edit/Write、Codex: apply_patch）|`.gd` は `godot --check-only`、`.md` は `docs_index.py --check`。失敗すると終了コード2でエージェントに直させる|
|`stop_check.py`|作業の終了時|gitで変更のある `.gd` を全部 `--check-only`（Bashやsedで編集した分も拾う）。同じエラーでは1回しか止めない（無限ループ防止）|
|`session_start.py`|セッション開始時|ブランチ・変更ファイル・直近のテスト結果・今月の画像予算・審査待ちの候補を表示|
|`extract_test_failures.py`|run-testsスキルから|run_tests.ps1のログからFAIL区間と最初のエラー位置だけを抜き出す|

- hookの起動コマンドは、スクリプトが見つからないときは何もせず通す（2026-10-04、スクリプトの移動中に「見つからない＝終了コード2＝全ツールが止まる」状態になったため）。
- Codexのhookはgitでリポジトリのルートを求めてから起動するので、サブフォルダーで起動しても動く。
- 秘密情報: Claude Codeは `permissions.deny` でも `.env` を禁止。Codexは `shell_environment_policy` でキーをコマンドの環境から外し、生成ツールは `.env` から自分で読む。キーが環境変数だけにある場合、Codexから有料生成はできない（ユーザーが実行する）。
- 有料生成: Claude Codeは `guard.py` が毎回確認。Codexはサンドボックスでネットワークを止めているため承認が必要になり、さらに `project.rules` で毎回確認にしている。

## モデルの選び方

- メインはユーザーの既定（Claude Code: Opus、Codex: `~/.codex/config.toml`）。
- 画像レビュー係は画像を読む力と美術の判断が要るので上位モデル（Opus / GPT-6.1 Sol、思考量high）。呼び出しは1素材あたり最大4回。
- 音のレビュー係は数値と規格の照合が中心なので中位モデル（Sonnet / GPT-6 Luna）。
- ログの解析・機械チェックはモデルを使わずスクリプトで行う。

## 確認済みの範囲（2026-10-04）

- Claude Code: hookの実動作（`.gd` の構文エラー検出、`.md` 追加時の索引チェック、`.env` を含むコマンドの停止、スクリプトが無いときの素通り）をこのセッションで確認。
- Codex: `.codex/hooks.json` のWindows用コマンドを、Codex形式の入力（`apply_patch`、引数の配列、`stop_hook_active` なし）で9項目実行して確認。**Codex本体での動作、`project.rules` の読み込み、サブエージェントの起動は未確認**（このPCに `codex` コマンドが見つからなかった）。Codexを使える環境で次を確認する:

```bash
codex execpolicy check --pretty --rules .codex/rules/project.rules -- .local/audio-venv/Scripts/python.exe tools/generate_image.py --name x
```

- 使えるモデル名・設定キーは2026-10-04時点の公式資料（Codex: hooks / subagents / config reference / skills / rules）に基づく。名前が変わったら `.codex/agents/*.toml` の `model` を直す。
