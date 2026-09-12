# 準備UI改修の実画面

2026-09-12。Godot 4.7.2 Compatibilityでゲーム実装から撮影。事前イメージや画像生成APIの出力ではない。

|画像|確認内容|
|---|---|
|[初期画面](01_initial.png)|通常5商品・控え8枠・丸腰での出撃案内|
|[装備とショップ詳細](02_equipment_and_shop.png)|装備済み武器・商品説明・購入ボタン・装填倍率比較|
|[拡張メニュー](03_expansion.png)|3形状の選択、配置で支払い、Esc取消|
|[控え8枠と警告](04_eight_reserve_and_warnings.png)|全枠表示、控え満杯の購入不可理由、武器未配置と無料品未確保の同時警告|
|[縮小表示](05_small_window.png)|1120×600ウィンドウ相当の840×600描画領域|

再撮影：環境変数 `CHAMBER_SCREENSHOT` にこのディレクトリの絶対パスを指定し、`Godot --path . --script res://tools/capture_preparation_revision.gd --quit-after 150` を実行する。

## 検証結果

- 全体テスト65件の一括実行では64件合格。追加テスト1件は古いMatchStateを参照したテスト側の不備で失敗したため修正（`.local/logs/run_tests-20260912-220646.log`）。
- 最終調整後、`preparation_ui`、`preparation_redesign`、`bag_expansion`、`expansion_availability`、`shop_ui`、`initial_preparation`、`fine_grid` の7件を再実行し全件合格。追加テストの失敗も解消。
- `tests/render.gd` の全体描画が合格。最終状態の専用撮影5状態も合格。
- 実クリック／ドラッグ、控えの所持品・空き枠・枠間への解除、8キャラの初期配置、二重購入、拡張の取消と確定時支払い、通常5商品の画面内収容、重複HP表示を確認。
- 画像で通常・拡張・縮小時の配置を確認。人間による操作感と小さい文字の読みやすさの受入評価は未実施。

素材生成APIは使っておらず、画像生成クレジットの消費はない。

[現行UI仕様](../../../design/PREPARATION_UI_B.md)
