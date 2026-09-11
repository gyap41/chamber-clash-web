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

- match_state/準備: 報酬二重取得、配置衝突、控え容量/解除先満杯、確定、丸腰出撃、引き分け/試合終了、CPU。
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

## 記録と未完了の受入

2026-09-11、全40種類の形状評価と5種類の面積変更を含む最終状態で40本（headless39本＋描画1本）PASS、終了コード0。
実行：run_tests.ps1 -IncludeRender。ログ .local/logs/run_tests-20260911-212322.log。ERROR/WARNING/FAILなし。
以前の選択式拡張39本の結果は [形状調整前の記録](../archive/2026-09-11/P9_BEFORE_FOOTPRINT_BALANCE_TESTING.md)。
以前の段階検証は [拡張選択前の記録](../archive/2026-09-11/P9_BEFORE_SELECTABLE_EXPANSION_TESTING.md) と
[細分化の検証履歴](../archive/2026-09-11/P9_FINE_GRID_VALIDATION.md) に保存した。

- footprint_balance：全40形状の連結・重複なし・範囲、全8キャラの初期武器＋小型報酬2個、CPUが9マス武器を置けない時の別武器携行、3×3の右下を掴んだ実GUIドラッグ、未開放への非破壊拒否、拡張領域への移動。
- 描画 .local/logs/p9-shapes-planet-nine-cells.png を目視し、9マスの武器・2マス化した3レリック・詳細欄の収まりを確認。戦闘性能のカタログ値は変更していない。
- bag_expansion：段階5で両者へ同じ2候補、通常報酬と独立した無料1回、未配置時の完了防止、重複/範囲外/無効形状の非破壊拒否。
- 実GUI入力で候補を選択し、下側のグリッドへクリック配置。別プレイヤーに領域が漏れないこと、CPUが同じAPIで右側へ配置することを確認。
- 拡張済みセルへの装備、戦闘開始時の各プレイヤーの仮取得領域、previousへの深いコピー、引き分け/勝敗後の保持、マッチ終了/新規試合リセット。
- fine_grid、relic_stacking、preparation_ui等の既存回帰も成功。固定L字を前提にする形状テストは、明示的にL字を配置してから検証する。
- 描画 .local/logs/p9-expansion-expansion-valid.png と expansion-blocked.png を目視確認。無料拡張の候補・詳細・緑/橙プレビューがB案パネル内に収まる。
- 既存のクリック/アイテムドラッグ、控え末尾、HUD、戦闘、縮小画面の描画も実行した。拡張自体の操作はクリック方式。

人間の操作感、20〜30試合の対戦バランス、今回の形状試作値の最終調整、拡張配布段階とCPU選択方針は未評価。
回転・拡張のドラッグ・配置後の再配置は未実装。コード実装、自動GUI入力、実画像の目視確認と、人間の実プレイ受入を区別する。
最大弾幕の長時間負荷、Web/Windows配布版の一試合完走、先行入力と音の実プレイ評価も継続課題。
音響生成は行わず、audio_assetsは保存済み素材の読み込みのみ。
