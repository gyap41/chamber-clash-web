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

## バージョン表示

ゲームのバージョンは `project.godot` の `application/config/version` で管理する。初期値は `0.1.0-dev`。タイトル画面はこの値を読み、`v0.1.0-dev` の形式で表示する。リリース時はこの設定を更新する。

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
- numeric_relic_stacking: 数値補正19種の価格・重複購入/配置/売却/仮取得/HUD、時間短縮の乗算、条件付き効果の固定時間、直接/派生弾、HP取得差分。
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

2026-09-12: 数値補正19種の重複解禁・低数値化・価格改定後、headless全55本PASS、終了コード0。
実行: `powershell -ExecutionPolicy Bypass -File run_tests.ps1`。
ログ: `.local/logs/run_tests-20260912-021554.log`。初回はGodotのログ・証明書アクセスがサンドボックスで拒否されたため、通常権限で再実行した。
単体効果、重複19種の取得経路、合計表示、装填/回避/近接/開封の乗算、発動時間据え置き、射撃補正、HP/弾倉を確認。今回の描画目視と人間の実プレイによる価格・対人バランス評価は未実施。

勝敗UIの修正後、`result_flow.gd`（描画あり）、`small_improvements.gd`、`smoke.gd`、`match_progression.gd` がPASS・終了コード0。途中勝敗の次準備ボタン/Enter、引き分け再戦、最終決着時のみ戻り先表示、途中の戻り先API拒否、最終Enterでキャラ選択を検証。全体一括テストは今回再実行していない。

描画再現: `.local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/result_flow.gd --quit-after 120 -- --result-screenshot`。
`.local/logs/result-round.png`、`result-draw.png`、`result-match.png` でメッセージ・スコア・操作ボタンの重なりがないことを確認した。

2026-09-12: 武器別間合い・迂回の追加後、**headless全53本PASS、終了コード0**。
実行: `powershell -ExecutionPolicy Bypass -File run_tests.ps1`。
ログ: `.local/logs/run_tests-20260912-013758.log`。Godotのログ・証明書アクセスがサンドボックスで拒否されたため、通常権限で実行した。

CPUの武器別間合い・通常戦闘の迂回は `tests/cpu_tactics.gd` で検証する。距離240pxで散弾が接近・レールが後退・標準武器が維持すること、スパナ変形・シード改造、全38武器の間合い、3武器×7配置の実際のPlayer.stepによる射線/間合い到達、移動相手への経路更新、到達不能時の再探索間隔を含む。

既存の `cpu_ai.gd` は予測射撃・回避・補給取得、`endgame_balance.gd` は回避クールダウン、`small_improvements.gd` は8地点からの縮小エリア退避と補給より退避を優先することを確認する。

共有補給・30%のレジェンド抽選・Fキー開封・星弾追尾・勝敗画面の実装と以前の検証記録は [CPU間合い・迂回前の検証記録](../archive/2026-09-12/BEFORE_CPU_TACTICS_TESTING.md) を参照する。

今回の描画・人間による実プレイは未確認。CPUの勝率、武器別間合いの適正値、移動する相手への経路追従、補給競争との優先度は未評価。自動テスト成功を対人バランスの確定とは扱わない。

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

## 対戦HUD C案の検証（2026-09-12）

実装仕様は [BATTLE_UI_C](../design/BATTLE_UI_C.md)、素材交換は [HUD素材README](../../assets/ui/hud/README.md)。

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/hud_compact.gd --quit-after 180
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/hud_compact.gd --quit-after 180 -- --hud-screenshot
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/render.gd --quit-after 300
```

専用テストはCPU/P2武器表示、最大8丁、36個一覧と末尾スクロール、仮装備/同種数/充電/待ち時間、ポーズ/ESC/射撃予約解除、背景に遮られないアイコンのマウス判定、装填、丸腰、素材fallback、カメラ表示移動と移動境界維持を検証する。
画像保存時はCPU戦・多武器・一覧・一覧末尾・ローカル・丸腰・840×600・結果画面をdocs/art/settings/concepts/battle-ui-2026-09-12/implemented-*.pngへ出力する。

一括実行のheadless 56本PASS（ログ .local/logs/run_tests-20260912-104722.log）。同実行のrenderは背景パネルの入力遮断で失敗し、修正後のrender.gd単体・hud_compact.gd描画実行はともにPASS、終了コード0。専用画像も目視確認。人間による操作感・仮アイコンの識別性・正式素材交換後の受入は未完了。
