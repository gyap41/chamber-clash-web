# 必要：生成原画・生成履歴

- [甲虫のモーション用8パーツ](../../docs/art/production/root-runner-motion/README.md)：root-runner-parts-v1の原本と生成台帳。

- [敵の外見比較用原画3枚](../../docs/art/production/enemy-field-concepts/README.md)：enemy-field-concepts 内のPNGと同名JSONに原本・指示・ハッシュを記録。本編未接続。

このフォルダーのPNGは加工前の原画。同名JSONは実際の生成条件・usageの記録。未採用原画も再確認・監査用として保存する。

- first-workshop-usage.json：使用量・送信履歴。成否不明の過去1件を含めて保持。
- acknowledged-lock：当時の停止・再開記録。削除候補には含めない。
- .gdignore：原画をGodotのゲーム素材としてインポートしないための設定。ゲームは加工済み素材を使用。
- gallery-collapse-kit-v1.png / .json：内蔵画像生成による回廊の崩落素材。透過原画はゲーム用atlasへ同一バイトで複製し、AtlasTextureで参照する。CLI台帳には含めず、ツールから提供されない費用・モデル・usageはJSONに不明と記録。[制作記録](../../docs/art/production/authored-rooms/README.md)。
- ruin-{architecture,discovery,nature,depth}-v1.png / .json：20室用の建築・発見・自然の透過シート3枚と遠景1枚。内蔵image_genを4回使用。プロンプト・SHA-256・実寸・実行用コピー・抽出レシピを同名JSONに保存。費用・モデル・usageは不明。実行用のexploration-kitは原本と同一バイト。[20室制作記録](../../docs/art/production/authored-rooms/README.md)。

原画の旧.png.importは[不要候補](../../docs/archive/2026-09-12/art-organization/unused-candidates/README.md)へ退避した。生成JSON中の古い参照パスは書き換えず、[移動台帳](../../docs/archive/2026-09-12/art-organization/relocations.json)から追跡できる。

[分類の入口](../../docs/art/README.md)

探索室の改善原画：`ruin-refinement-v1.png` と同名JSON。閉鎖大門・読書机・長椅子・記録小物の透過2×2シート。制作記録は [authored-rooms](../../docs/art/production/authored-rooms/README.md)。

丸い苔玉コガネ: `enemy-field-concepts/moss-scarab-v1.png`（全身設定画）と`moss-scarab-parts-v1.png`（8パーツ）。各JSONに内蔵imagegenプロンプト・寸法・ハッシュ。旧甲虫の細長い外見を置換するHub試作。

`enemy-field-concepts/moss-tackle-parts-v1.png`: 苔玉コガネの小さな目と収納・前転4コマ。内蔵imagegenで1枚生成、同名JSONにプロンプト・原本パス・寸法・ハッシュ。通常胴/脚/触角は旧パーツを流用。
