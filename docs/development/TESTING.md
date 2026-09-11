# 検証手順

更新: 2026-09-12。実行方法と残る受入を管理する。過去の件数・失敗修正・ログは
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
- field_weapon_reserve/eight_more_weapons: 控え収納と明示配置、引き分け/決着/満杯/重複、追加通常8武器。
- added_weapons/added_relics/added_item_acquisition: 初期専用8種の抽選除外、追加全品の購入・売却・無料持ち帰り、3連射の補正/予約取消、交差弾、15レリックの条件/上限/対象外、CPU初期装備。
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

現行ルールを維持したリファクタリング後、**51本（headless50＋描画1）PASS、終了コード0**。
ERROR/WARNING/FAILなし。既存49本のheadlessテストに、画面なしのCPU準備と
準備/戦闘の配置境界を確認する `preparation_boundaries.gd` を追加した。

実行: `powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender`。
ログ: `.local/logs/run_tests-20260912-001104.log`。
Godot 4.7.2のheadlessエディタで再インポートも成功。

- 38武器・35レリック、購入/売却/拡張、個体ID、初期準備、フィールド控え収納、入力、CPU、音響Resource読込の既存回帰が成功。
- 新規テスト: 20シードの各9ラウンドで、画面なしのCPU準備、資金/容量/重複配置の制約、5対4での試合終了リセットを検証。
- 準備と戦闘で携行武器の読み順、同種レリック個体の占有セル、仮取得の形状判定が一致し、元ビルドを書き換えないことを検証。
- 保存した変更前CPU実装との一時比較では、360回の準備について所持品・配置・資金・商品・個体/カード連番・乱数状態が一致。
- 描画テストはCompatibilityで成功。今回の実行はスクリーンショットの保存・目視確認や人間の実プレイ評価を含まない。

変更前49本の成功ログは `.local/logs/run_tests-20260912-000452.log`。
サンドボックス内ではユーザーログと証明書ストアの権限エラーが出たため、
通常権限の実行で検証した。これらのエラーを除外して合格にする変更は行っていない。
詳細は[リファクタリング記録](../archive/2026-09-12/REFACTOR_VALIDATION.md)、
前回の取得武器・描画検証は[変更前の検証資料](../archive/2026-09-12/BEFORE_REFACTOR_TESTING.md)を参照。

一覧更新: `python tools/export_item_catalog.py`。全38武器・35レリック・8キャラの表を生成する。
武器・レリック件数と通常入手数は自動集計。バッグ説明は手動管理。

### 人間の実プレイ未確認

購入・売却・配置操作の使いやすさ、5本先取の総時間、価格/初期8/上限24/控え8のバランス、
CPUの投資判断、プラネタリウム取得直後の強さは未評価。20シードのCPU自動検証は対人試合の実測ではない。
20〜30試合の比較と、必要なら4本先取との比較を行う。自動テスト成功だけで数値を確定しない。
拡張のドラッグ・回転・配置後移動、P9隣接効果、オンライン対応は未実装。
Web/Windows配布版、一試合完走、最大負荷、先行入力・音の実プレイ確認も残る。
音響生成は行っていない。audio_assetsは保存済み素材の読み込みのみ。

旧40本の詳しい記録は [移行前の検証記録](../archive/2026-09-11/BEFORE_PURCHASE_TESTING.md)、
購入移行の経緯は [検証日誌](../archive/2026-09-11/PURCHASE_ECONOMY_VALIDATION.md) を参照。
