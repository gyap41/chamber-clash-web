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

武器14種の差別化とプラネタリウム8方向化後、**52本（headless51＋描画1）PASS、終了コード0**。
実行: `powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender`。
ログ: `.local/logs/run_tests-20260912-004007.log`。
Godot 4.7.2のheadlessエディタで再インポートも成功。サンドボックス内のユーザーデータ・キャッシュ・証明書権限エラー後、通常権限で検証した。

- `weapon_differentiation.gd`: 8発の45度間隔・消費1発、武器×キャラ×装填短縮、装填直前/直後、切替中断、途中取得による進行時間の固定、2発弾倉へのワイドマガジン、未指定武器の1.15秒・スパナ変形を検証。
- 既存の追尾方向/反射/パルス、レシートの反射加算、エコ追射、散弾角度、弾薬箱の予備補給、レリック効果と残弾の期待値を新仕様へ更新して回帰成功。
- 最初の全体実行では旧弾数・角度・補給量の期待値が残る5テストが失敗。更新後の全体再実行はすべて成功。
- 描画テストはCompatibilityで成功。今回はスクリーンショットの目視確認・人間による実プレイを含まない。

前回のリファクタリング検証は [変更前の検証記録](../archive/2026-09-12/BEFORE_WEAPON_DIFFERENTIATION_TESTING.md)。
武器差別化の判断と試作値は [実装前の比較案](../archive/2026-09-12/WEAPON_DIFFERENTIATION_PROPOSAL.md)、現行値は [アイテム一覧](../design/ITEM_CATALOG.md)。

一覧更新: `python tools/export_item_catalog.py`。全38武器・35レリック・8キャラの表を生成する。
武器・レリック件数と通常入手数は自動集計。バッグ説明は手動管理。

### 人間の実プレイ未確認

購入・売却・配置操作の使いやすさ、5本先取の総時間、価格/初期8/上限24/控え8のバランス、
CPUの投資判断、8方向化したプラネタリウムの避けやすさ・配置後の強さ、武器別装填を含む初期キャラの均衡は未評価。20シードのCPU自動検証は対人試合の実測ではない。
20〜30試合の比較と、必要なら4本先取との比較を行う。自動テスト成功だけで数値を確定しない。
拡張のドラッグ・回転・配置後移動、P9隣接効果、オンライン対応は未実装。
Web/Windows配布版、一試合完走、最大負荷、先行入力・音の実プレイ確認も残る。
音響生成は行っていない。audio_assetsは保存済み素材の読み込みのみ。

旧40本の詳しい記録は [移行前の検証記録](../archive/2026-09-11/BEFORE_PURCHASE_TESTING.md)、
購入移行の経緯は [検証日誌](../archive/2026-09-11/PURCHASE_ECONOMY_VALIDATION.md) を参照。
