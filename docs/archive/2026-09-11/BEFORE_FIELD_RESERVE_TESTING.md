> 過去の検証・仕様の記録。現在のルールや次の作業として採用しない。

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

武器10種（専用初期8＋通常2）・レリック15種追加、P-12発射間隔0.38秒への変更後、
**48本（headless47＋描画1）PASS、終了コード0**。ERROR/WARNING/FAILなし。
実行: `powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender`。
ログ: `.local/logs/run_tests-20260911-233716.log`。

- added_weapons: 全10種の射撃、1反射上限、弱追尾の角度制限、交互散布、3連射の弾薬/初射補正保持/持替/パルス/停止/決着、交差弾の曲がる時刻。
- added_relics: 全15種の効果、派生弾対象外、拡張弾倉と補填経路、装填短縮の再使用待ち、防御順・全軽減、回復2回上限/予約重複/死亡、発射元への回収補填、宝箱開封時間とUI、ラウンドリセット。
- added_item_acquisition: 100シード×9準備で35レリックの抽選到達、非売品の購入拒否、追加全品の購入/配置/詳細/売却/無料持ち帰り、全キャラ初期配布とCPU配置。
- initial_preparation: 全8キャラ×Local/CPUで初回表示と所持品が一致し、2マスへの実GUIクリック配置が成功。
- 既存の戦闘・改造・音響Resource読込・ショップ・経済・CPU・入力・描画テストも成功。連射間隔・件数・無効IDを旧値で固定していたテストを現行値に更新した。

描画の保存先は `.local/logs/item-expansion-*.png`。
`item-expansion-new-starter.png` と `item-expansion-new-relic.png` を目視確認し、ルーンペンの初期控え、
ワイドマガジンとの縦2マス配置、詳細説明、残金と価格、ショップの収まりを確認した。
専用画像は既存素材の仮利用。実プレイでの対戦バランスや操作感を確認済みとはしない。

アイテム一覧の更新は `python tools/export_item_catalog.py`。全30武器・35レリック・8キャラの表をカタログ・価格・形状から出力する。
バッグ範囲の説明は手動管理。提案と追加前の検証は [提案履歴](../archive/2026-09-11/ITEM_EXPANSION_PROPOSAL.md)、
[前回検証記録](../archive/2026-09-11/BEFORE_ITEM_EXPANSION_TESTING.md) を参照。

### 人間の実プレイ未確認

購入・売却・配置操作の使いやすさ、5本先取の総時間、価格/初期8/上限24/控え8のバランス、
CPUの投資判断、プラネタリウム取得直後の強さは未評価。20シードのCPU自動検証は対人試合の実測ではない。
20〜30試合の比較と、必要なら4本先取との比較を行う。自動テスト成功だけで数値を確定しない。
拡張のドラッグ・回転・配置後移動、P9隣接効果、オンライン対応は未実装。
Web/Windows配布版、一試合完走、最大負荷、先行入力・音の実プレイ確認も残る。
音響生成は行っていない。audio_assetsは保存済み素材の読み込みのみ。

旧40本の詳しい記録は [移行前の検証記録](../archive/2026-09-11/BEFORE_PURCHASE_TESTING.md)、
購入移行の経緯は [検証日誌](../archive/2026-09-11/PURCHASE_ECONOMY_VALIDATION.md) を参照。
