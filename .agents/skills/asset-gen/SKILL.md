---
# name/description は 自動生成: tools/agent/sync_agents.py（台帳: tools/agent/agents.toml）。直接編集せず、台帳を直して同期する。
name: asset-gen
description: "画像・SE・BGM素材を外部AIで生成し、機械チェック→レビュー係の判定→作り直し（最大3回）→ユーザーのゲーム内最終確認まで進める。有料APIを使うため、ユーザーが明示的に呼んだときだけ使う（Codex: $asset-gen、Claude Code: /asset-gen）。"
---

<!-- 正本: .agents/skills/asset-gen/SKILL.md（Codexが直接読む）。Claude Codeは .claude/skills/asset-gen/SKILL.md からここを読む。 -->

# 素材生成の流れ

対象: 呼び出したときにユーザーが指定した素材（種類と対象）。指定がなければ最初に確認する。

生成 → 機械チェック → レビュー → 作り直しは最大3回（**最初の生成＋作り直し3回＝合計最大4回**）→ ユーザーの最終確認。生成物はユーザーが採用するまで `assets/candidates/` に置き、ゲームの使用中素材とは分ける。

## 0. 生成の前（省略しない）

1. AGENTS.mdの規則どおり [素材制作の必読入口](../../../docs/art/README.md) から対象別の資料を読む。音は `docs/AUDIO_BIBLE.md`・`assets/audio/asset_manifest.json`・`tools/asset_generator/README.md`。
2. 対象の制作記録（`docs/art/production/<対象>/README.md`、なければ作る）に「読んだ資料・方式・必要素材と不足分・寸法/原点/接続点・今回の生成範囲・比較する基準素材」を書く。
3. 置き換えか新規かを決める。**置き換え**なら使用中の素材のパス・寸法・格子を記録し、候補も同じ寸法にする（ゲーム内プレビューで差し替えるため）。**新規**はプレビューで試せないので、組み込みは別作業になることをユーザーに伝える。
4. 候補IDと版を決める: `assets/candidates/<asset_id>/v1/`。既存の版があれば次の番号。
5. 費用を確認し、**ユーザーの許可を取る**:
   - 画像: `.local/audio-venv/Scripts/python.exe tools/generate_image.py --plan 4`（最大4回分が予算内か）。
   - 音: `asset.py se|bgm ... --candidate <asset_id>/v1 --dry-run` で内容を見せる。
   - 「最大4回生成（1回目＋作り直し3回）・見込み額・品質設定」を示し、明確な許可を得てから進む。許可された回数を超えない。

## 1. 生成（1回ごと）

- 画像: 共通ブロック＋素材固有の指示をプロンプトファイルに書き、`--reference` は画風基準（8方向版リナ）を主にする。`tools/generate_image.py --name <asset_id>-v<N> --prompt-file ... --reference ...`。原本は `assets/generated/` に保存される。ゲームで使う形への加工（背景の透過、格子への切り出し）は既存の `tools/build_*.gd` の方式で行い、結果を `assets/candidates/<asset_id>/v<N>/` に置く。原本は加工しない。
- 音: `tools/asset_generator/asset.py se|bgm --name <新しい名前> --candidate <asset_id>/v<N> ...`。1コマンド1素材。
- Codexではサンドボックスがネットワークを止めているため、有料生成のコマンドは承認を求める（`.codex/rules/project.rules` でも毎回確認）。APIキーはCodexのコマンド環境から除外しているので、ツールは `.env` から読む。`.env` が無くキーが環境変数だけにある場合は、ユーザーに生成コマンドを実行してもらう。
- 認証・課金・レート制限・タイムアウト・通信エラーは**その場で止めて報告**。自動で再送しない、別のproviderに切り替えない。
- `preview.json` を書く（`replaces` に使用中のパス→候補ファイル。書式は `assets/candidates/README.md`）。
- 候補を置いたらインポート: `.local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import --quit-after 600`（timeout付き）。

## 2. 機械チェック

- 画像: `.local/audio-venv/Scripts/python.exe tools/asset_check/check_image.py <候補> --grid ... --directions ... --groups ... --ground ... --display-scale ... --baseline <基準素材のreport.json> --out assets/candidates/<id>/v<N>/check`
  （基準素材のreport.jsonが無ければ、先に同じ引数で基準素材を測って `.local/asset-check/` に作る。）
- 音: `.local/audio-venv/Scripts/python.exe tools/asset_check/check_audio.py <候補> --category ... --reference <採用済みの同役割の音> --out assets/candidates/<id>/v<N>/check`
- **FAIL（不合格）ならレビューに回さず**、原因をプロンプトか加工手順に反映して次の版へ（1回に数える）。WARNはレビュー係に渡す。

## 3. レビュー

- 画像は画像レビュー係、音は音響レビュー係のサブエージェントに渡す（Claude Code: `art-reviewer` / `audio-reviewer`、Codex: `art_reviewer` / `audio_reviewer`。指示の正本は `tools/agent/reviewers/`）。渡すもの: 制作記録のパス、候補フォルダー、check/の結果、基準素材、（作り直しなら）前回の `review.md`。生成プロンプトの狙いの説明は渡さない（画像・数値だけで判定させる）。
- 返ってきた判定を `assets/candidates/<id>/v<N>/review.md` に保存する。

## 4. 作り直し（最大3回）

- 総合が「要修正」「不合格」なら、レビューの指示を優先順にプロンプト・参照画像・加工手順へ反映し、**新しい版番号**で1へ戻る。同じ条件の再送はしない（音は `--allow-repeat` を使わない）。
- 作り直しが3回に達したら止める。合格がなくても、一番良い版と残った問題を並べてユーザーに渡す。
- 作り直しごとに、変えたことと理由を制作記録に1行ずつ残す。

## 5. ユーザーの最終確認

次をまとめて提示し、判断を待つ（自分で採用しない）:

- 版ごとの結果の表（機械チェック・レビュー総合・主な指摘・費用）。
- 推す版の `check/contact_display.png`（画像）または `check/waveform_spectrogram.png`（音）。
- ゲーム内で試すコマンド（PowerShellのRunボタン用に1コマンドずつ）:
  `powershell -ExecutionPolicy Bypass -File tools/preview_candidate.ps1 <asset_id>/v<N>`
- 確認してほしい点（レビュー係の「未確認」、音なら「ユーザーに試聴してほしい点」）。

## 6. 結果の処理（ユーザーの判断を受けてから）

`assets/candidates/README.md` の「ユーザーの最終確認後」に従う。

- **採用**: 使用中の素材を `assets/retired/<asset_id>/v<旧>/` へ移す → 候補の中身を使用中のパスへ上書き（`.import`・UIDは既存のまま）→ 再インポート → 候補フォルダーを retired へ移し status を `adopted`。
- **不採用**: 候補フォルダーを `assets/retired/<asset_id>/v<N>/` へ移し、status を `rejected`、理由を `review.md` と制作記録へ。使用中の素材は変更しない。
- 音の場合は `asset_manifest.json` の `file_path` を移動先へ更新する。ユーザーの試聴評価は `docs/AUDIO_BIBLE.md` の「試聴評価と計測値の対応」に1行足す。
- 最後に run-tests スキル（`.agents/skills/run-tests/SKILL.md`）でテストを実行（`asset_zones` を含む）し、`python tools/graphics_inventory.py --check`（画像を増減したとき。約20秒）と `python tools/docs_index.py --check` を通す。
- 報告では「生成済み・機械チェック・レビュー判定・ゲーム内確認・ユーザー採用」を分けて書く。
