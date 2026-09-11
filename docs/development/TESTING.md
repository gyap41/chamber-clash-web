# 検証手順

更新: 2026-09-11。実行方法と残る受入を管理する。過去の件数・失敗修正・ログは
[検証履歴](../archive/2026-09-11/BEFORE_TESTING.md) を参照する。

## 実行

プロジェクトルートのPowerShellから実行する。Godotは.local/tools/を優先して探索する。

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
powershell -ExecutionPolicy Bypass -File run_tests.ps1
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

別の実行ファイルは -GodotPath で指定する。tests直下の.gdを自動検出し、通常はrender.gdを除く。
件数は増減するため固定の「全34本」等を現在の合格条件にしない。
ログは.local/logs/。終了コード、エラー行、PASS表示を確認する。
PASS数はアサーション数ではない。Godotのユーザーデータ/キャッシュ権限エラーも無視しない。
音響素材がない場合のaudio_assets.gdはSKIPを返す。単独実行は終了コード0だが、現行の一括ランナーはPASS表示なしを失敗扱いにする。未生成を認識成功と扱わない。

## 描画と入力

```powershell
$env:CHAMBER_SCREENSHOT = "$PWD/.local/logs/render.png"
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

render.gdは画面描画可能な環境で実行する。準備・所持品・HUD・戦闘・補給・演出を確認する。
B案の座標/操作基準は [準備UI仕様](../design/PREPARATION_UI_B.md)。
スクリプトによるGUI入力や静止画確認と、人間による操作感評価を区別する。

## 重点回帰

- match_state/準備: 商品二重購入・資金収支、配置衝突、控え容量/解除先満杯、確定、丸腰出撃、引き分け/試合終了、CPU。
- fine_grid/item_instances/relic_stacking: 個体ID、同種の位置/破棄、重複可否、能力加算、取得経路。
- 戦闘: 全武器、改造、レリック、派生制限、回避/被弾、入力予約、危険地帯、補給/宝箱。
- sound: ミュート、戦闘シグナル、合成PCM、16ボイス、停止/キャッシュ/バス解放。
- 描画: 長文、所持品増加、縮小画面、選択固定、配置プレビュー、ドラッグの掴み位置。

武器が必要なテストは明示的に装備を作る。自動サイドアームや旧4枠制限を仮定しない。
tests/helpers/battle.gdを活用し、レリックの追射予約・一時フラグなど状態リークを防ぐ。

## 素材生成ツール

```powershell
.local/audio-venv/Scripts/python.exe -m unittest discover -s tools/asset_generator/tests -v
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/audio_assets.gd
```

Pythonテストは通信mockで課金なし。環境と無料確認は [素材生成設定](ASSET_GENERATION_SETUP.md)。
直近の音響検証ではPython19件とBGM/SEのGodot Resource認識が成功。全ゲームテストの再実行とは別。

## 最新の記録と未完了の受入

後続依頼の武器最低2マス化（P-12/ダブルバックを横2マス）後も、43本（headless42＋描画1）PASS、終了0。
ログ：`.local/logs/run_tests-20260911-224659.log`。ERROR/WARNING/FAILなし。
全20武器が2マス以上であること、全キャラの初期武器＋小型2品、CPU予算/配置、購入・売却・ドラッグを回帰確認。
新しい形状に合わせて混在占有テストとドラッグの空き配置先を更新し、衝突拒否の検証を維持した。
今回は描画テスト実行まで。以下の保存画像の目視は最低2マス化前の記録であり、変更後の人間の実操作は未確認。

### 購入経済導入時の記録

購入制・有料バッグ拡張・5本先取を実装した状態で、2026-09-11に **43本（headless42＋描画1）PASS、終了コード0**。
実行：`powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender`。
Godot：`.local/tools/Godot_v4.7.2-stable_win64_console.exe`。
ログ：`.local/logs/run_tests-20260911-223954.log`。ERROR/WARNING/FAILなし。
基準014f55fも40本成功を再確認（`.local/logs/run_tests-20260911-222101.log`）。

- purchase_economy（新規）：資金不足・控え満杯・二重購入の非破壊拒否、重複個体と売却、無料品0G、武器売却時の改造消去と再購入、更新・古いカード拒否・無料確保。
- economy_rounds（新規）：24マス上限、フィールド武器持ち帰り、満杯時の無料確保候補保持、引き分け・最終戦の境界、20シード×9戦×2人のCPUで資金収支・購入品配置・携行/控え上限。
- shop_ui（新規）：Godotへマウス入力を送り購入・売り切れ・二重入力・クリック配置・売却・更新・無料候補保持/確保を検証。
- bag_expansion：有料拡張の無効配置/取消無課金、実GUIクリック確定、独立した領域、previous深いコピー、CPU、リセット。
- match_progression：5-0/5-4、引き分けで資金/商品/購入数不変、両者同額収入、5勝で次準備を走らせない、タイトル→キャラ→CPU戦完走。
- 既存の個体/効果加算、全武器・改造・戦闘・ドラッグ・控え末尾・GUI境界・音響Resource認識の回帰も成功。

旧無料報酬の取得回数や段階別面積の期待値は、新しい資金・購入・独立面積の検証へ置換した。
幾何配置テストは `tests/helpers/preparation.gd` で4×4の明示的な拡張済みfixtureを作る。
経済・ラウンドテストは実際の購入APIと収入で検証する。戦闘テストの性能アサーションは維持。

### 描画確認済みの範囲

`CHAMBER_SCREENSHOT` を `.local/logs/purchase-economy.png` に指定し、render.gdの各場面を保存。
次の画像を目視確認：

- `.local/logs/purchase-economy-preparation.png`：初期8マス、12G、価格付きショップ、拡張3種、任意の準備完了。
- `.local/logs/purchase-economy-expansion-valid.png`：6マス6G、詳細の接続/課金条件、緑の配置プレビュー。
- `.local/logs/purchase-economy-planet-nine-cells.png`：9マスのプラネタリウム、詳細、控え、ショップの収まり。

既存の縮小/原寸画面、控え末尾、装備ドラッグ、HUD・戦闘・補給・演出の描画も自動実行した。
描画テストは無料報酬前提を拡張済みfixtureに更新し、既存の配置/境界アサーションを維持。

### 人間の実プレイ未確認

購入・売却・配置操作の使いやすさ、5本先取の総時間、価格/初期8/上限24/控え8のバランス、
CPUの投資判断、プラネタリウム取得直後の強さは未評価。20シードのCPU自動検証は対人試合の実測ではない。
20〜30試合の比較と、必要なら4本先取との比較を行う。自動テスト成功だけで数値を確定しない。
拡張のドラッグ・回転・配置後移動、P9隣接効果、オンライン対応は未実装。
Web/Windows配布版、一試合完走、最大負荷、先行入力・音の実プレイ確認も残る。
音響生成は行っていない。audio_assetsは保存済み素材の読み込みのみ。

旧40本の詳しい記録は [移行前の検証記録](../archive/2026-09-11/BEFORE_PURCHASE_TESTING.md)、
購入移行の経緯は [検証日誌](../archive/2026-09-11/PURCHASE_ECONOMY_VALIDATION.md) を参照。
