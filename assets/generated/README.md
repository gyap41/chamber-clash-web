# 必要：生成原画・生成履歴

このフォルダーのPNGは加工前の原画。同名JSONは実際の生成条件・usageの記録。未採用原画も再確認・監査用として保存する。

- first-workshop-usage.json：使用量・送信履歴。成否不明の過去1件を含めて保持。
- acknowledged-lock：当時の停止・再開記録。削除候補には含めない。
- .gdignore：原画をGodotのゲーム素材としてインポートしないための設定。ゲームは加工済み素材を使用。

原画の旧.png.importは[不要候補](../../docs/archive/2026-09-12/art-organization/unused-candidates/README.md)へ退避した。生成JSON中の古い参照パスは書き換えず、[移動台帳](../../docs/archive/2026-09-12/art-organization/relocations.json)から追跡できる。

[分類の入口](../../docs/art/README.md)
