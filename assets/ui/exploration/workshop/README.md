# 携帯工房の探索バッグ素材

区分：採用素材の出所・実装記録。2026-10-05、ユーザーの本編適用依頼で昇格。現行操作はdocs/design/GAME_RULES.md。

- `shell.png`：候補exploration-ui/v9/shell.pngの同一コピー（1254×1254）。
- `drive.png`：同drive-transparent.pngの同一コピー（1536×1024）。
- `power.png`：同power-transparent.pngの同一コピー（1536×1024）。
- `regions.json`：同v9の16領域・原点を維持し、参照画像名を正式名へ変更。

生成原本・指示・加工指示は[候補台帳](../../../candidates/exploration-ui/v9/manifest.json)、経緯は[制作記録](../../../../docs/planning/EXPLORATION_UI_COMP.md)。今回は新規生成なし。ゲームはこの正式領域だけを参照し、候補フォルダーを読まない。候補のHTML/動画試作群は `.gdignore` でGodotのインポートから除外する。

描画はscripts/ui/workshop_skin.gd。枠の角を66px固定で9分割し、左右の蓋は反転流用、開閉の歯車と通電・流動・粒子は実行時描画。採用配置は1120×800基準。実Godotの開いた画面と開閉250/450msの途中を目視確認済み。連続操作感とSE試聴は別評価。

## ショップ用追加素材（2026-10-05）

`shop-accessories.png` は候補shop-v13/accessories-source.pngの同一コピー（1536×1024 RGBA）。`shop-regions.json` は6部品の領域。原本・内蔵画像生成プロンプト・SHA-256は[候補台帳](../../../candidates/exploration-ui/shop-v13/manifest.json)。ユーザーの本編適用依頼で昇格。描画はscripts/ui/shop_skin.gd、操作はexploration_shop.gd。カバーと回転歯車は別レイヤー、扉は幅を縮めず移動して収納口で切る。画像の再生成なし。機械・発光の見た目と操作の自動確認は制作記録参照。

## 探索HUDへの再利用（2026-10-05）

ユーザー採用のA案でshell.pngのbody_frame領域を小さな9分割枠として流用。exploration_hud_skin.gdがHP/装備/操作アイコン/停止メニューの枠を描く。新規画像生成なし。HUDでは歯車や通電粒子を常時動かさず、被弾・装備切替・所持金増加時の短い反応に限定する。

## 探索HUD専用素材（2026-10-06）

`hud-atlas.png`：内蔵image_genで生成した1536×1024 RGBAアトラスの同一コピー。HP・装備・小枠・行動リング・ボスHP筐体・歯車貨の6領域。今回の制作・適用依頼に従い本編へ接続、ユーザーの最終見た目確認は未実施。原本・全プロンプト・領域・SHA-256は[制作台帳](../../../candidates/exploration-ui/hud-v2/manifest.json)。画素編集なし、領域切出しと拡縮はGodot側で実施。

exploration_hud_skin.gdのREGIONSとdraw_frameが角の表示寸法を固定して9分割描画。行動リング・貨幣は比率維持、小さな武器枠はStyleBoxTextureで表示する。停止メニューは従来shellの枠を維持。生成原本は候補に保持し、ゲームは正式コピーのみを参照する。
