# 候補素材（未採用・審査中）


4種類の機械の専用素材: [制作・確認記録](../../docs/art/production/enemy-animation-v2/remaining-machines.md)。2026-10-04の適用指示を受け、4種は使用中素材へ昇格。旧候補一式はretiredへ保存済み。新規部品シートには置換先PNGがないため、`preview.json`の`machine_sheets`へ敵ID・file・rows・計測regionsを指定し、開発用Autoloadが起動引数付きのときだけ登録する。この候補登録機能自体は通常起動・書き出しでは動かない。採用済み4種は使用中の画像を既定で読み込む。

区分: 素材の置き場所と運用手順。状態: 運用中（2026-10-04開始）。定義する範囲: 生成後、ユーザーの最終確認が終わるまでの素材。関連する正本: [素材制作の必読入口](../../docs/art/README.md) / [レビュー基準](../../docs/art/ART_BIBLE.md) / [音響基準](../../docs/AUDIO_BIBLE.md)

ここに置いた素材は**ゲームから参照しない**。Godotはインポートする（ゲーム内で試せるようにするため）が、Web書き出しからは除外している。参照していないことは `tests/asset_zones.gd` が毎回確認する。

## 3つの置き場所

|区分|置き場所|Godot|書き出し|
|---|---|---|---|
|使用中|今までの場所（`assets/first-workshop/`、`assets/stages/`、`assets/audio/se/` など）|インポート|含める|
|候補（審査中）|`assets/candidates/<asset_id>/v<N>/`|インポート|除外|
|不採用・旧版|[`assets/retired/<asset_id>/v<N>/`](../retired/README.md)|`.gdignore`でインポートしない|含めない|

生成原本と同名JSONは従来どおり `assets/generated/` に残し、加工しない。候補に置くのは、ゲームで使う形に加工した派生物。

## フォルダーの中身

```
assets/candidates/<asset_id>/v<N>/
  <ゲームで使う形のファイル>      例: lizard-sheet.png、fw_lizard_spit_04.mp3
  preview.json                  ゲーム内プレビューの差し替え指定
  check/                        機械チェックの結果（report.json、並べ画像、スペクトログラム）
  review.md                     レビュー係の判定（作り直しごとに上書きせず版ごとに残す）
```

`<asset_id>` は英小文字・数字・`_`・`-`。版は `v1` から順に増やし、上書きしない。

### preview.json

```json
{
  "asset_id": "lizard",
  "version": "v2",
  "status": "candidate",
  "replaces": {
    "res://assets/first-workshop/enemies/lizard-sheet-v3.png": "lizard-sheet.png"
  }
}
```

- `replaces` のキーは**使用中の素材のパス**、値はこのフォルダーからの相対パス（または `res://` の絶対パス）。
- 画像は使用中と同じ寸法・同じ格子にする。コードが切り出し座標を持つため、寸法が違うと位置がずれる（警告を出すが止めない）。
- `status` は `candidate` / `adopted` / `rejected`。

## ゲーム内で試す

1. 候補を置いたら一度インポートする: `.local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import`
2. 起動する:

```powershell
powershell -ExecutionPolicy Bypass -File tools/preview_candidate.ps1 lizard/v2
```

追加の起動引数はそのまま後ろに付けられる（例: `tools/preview_candidate.ps1 lizard/v2 --rina-run`）。複数の候補は `-Candidate lizard/v2,lizard_spit/v1` のようにカンマで区切る。Godotエディターから試す場合は「プロジェクト設定 → 実行 → メイン実行引数」に `-- --preview-candidate=lizard/v2` を入れてF5（試したら消す）。

画面左下に黄色で「候補プレビュー中」と表示される。赤い場合は差し替えに失敗しているので、表示されたエラーを確認する。差し替えはメモリ上だけで、ファイルは変わらない。

**新規の素材**（置き換える使用中の素材がない、新しい敵など）は、この方法では試せない。組み込みのコードが必要なため、ユーザーの了承を得てから別作業として扱う。

## ユーザーの最終確認後

|結果|作業|
|---|---|
|採用|使用中の素材を `assets/retired/<asset_id>/v<旧版>/` へ移す → 候補ファイルの中身を**使用中のパスへ上書き**（既存の`.import`とUIDを保つので参照の変更が不要）→ 再インポート → `preview.json` の status を `adopted` にして、候補フォルダーを retired へ移す|
|不採用|候補フォルダーを `assets/retired/<asset_id>/v<N>/` へ移し、`preview.json` の status を `rejected`、理由を `review.md` と制作記録に書く。使用中の素材は変更しない|

どちらも、制作記録（`docs/art/production/` または音響manifest）に結果と日付を書く。音響manifestの `file_path` は移動先へ更新する。移動後に `run_tests.ps1` を実行し、`asset_zones` を含めて通ることを確認する。

## 機械SEのレビュー候補（2026-10-04）

- [破砕機の発進](ash-ram-launch/v1/review.md)：原本保持、依頼範囲の本編接続済み、試聴待ち。
- [環砲機の斉射](triple-ring-salvo/v1/review.md)：原本保持、再生ゲイン補正で本編接続済み、試聴待ち。

音色再指定後の候補：

- [神々しいオーロラ](aurora-divine/v3/review.md)
- [重厚な破砕機](ash-ram-launch/v2/review.md)
- [重厚な環砲機](triple-ring-salvo/v2/review.md)

いずれも本編接続済み、ユーザー試聴採用待ち。旧版は比較用に保持。

- `exploration-ui/hud-v2/`：2026-10-06、A案HUD専用の6部品アトラス1枚。source.pngが内蔵生成原本、prompt.txtに全指示、manifest.jsonに領域とSHA-256。本編適用依頼に従いassets/ui/exploration/workshop/hud-atlas.pngへ同一コピー済み。最終見た目の採用はユーザー確認待ち。

鉄格子の門v3・開閉SE v2は2026-10-07にユーザー採用され、通常起動へ適用済み。制作記録・旧候補は[門v3](../retired/dungeon-gate/v3/review.md)・[SE v2](../retired/dungeon-gate-audio/v2/review.md)へ保存。
