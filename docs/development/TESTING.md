# 検証手順

更新: 2026-09-12。現在の実行方法と受入条件を管理する。
詳細な過去記録は[変更前の検証資料](../archive/2026-09-12/BEFORE_EXTENSION_TESTING.md)、
今回の記録は[拡張リファクタリング](../archive/2026-09-12/EXTENSION_REFACTOR.md)。

## 全体回帰

プロジェクトルートのPowerShellで実行する。

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import --quit
powershell -ExecutionPolicy Bypass -File run_tests.ps1
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

別のGodotは-GodotPathで指定。tests直下の.gdを自動検出し、通常はrender.gdを除外する。
ログは.local/logs。終了コード、SCRIPT ERROR/ERROR/Assertion、PASS表示をすべて確認する。
Godotのユーザーデータ・キャッシュ・証明書ストアへの権限拒否も成功扱いしない。

通常mainはCPU対戦。武器/経済を隔離する既存テストではhelpers/battle.gdの
passive_opponentsを明示使用し、CPUの自動射撃が期待弾数を変えないようにする。
CPU統合テストは実際にis_cpuを有効にし、共通操作経路を通す。
P2キーの旧テストは削除された入力を無視することと、共通操作APIによる同じ効果を検証する。

## 拡張境界

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/extension_boundaries.gd --quit-after 120
```

1対3 CPUを別寸法・別壁配置のフィールドで10秒相当実行。さらに独立ケースで
味方通過/敵命中、全敵への近接・爆発・重力、味方を消さないパルス、4番目の参加者による取得、
共通操作/参加者ID入力の一致、全滅勝敗・一度だけの確定、フィールド境界と危険地帯、
部屋/戦闘のHP・弾薬・装備持ち越し、UIなしのRunInventory、種類IDの並べ替え耐性を確認する。
演出通知の受信を外した状態でも戦闘を実行する。通信自体の検証ではない。

人間1人対CPU3人の手動検証用起動（自動テストとは別）:

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/extension_boundaries.gd -- --extension-preview
```

検証装備を自動配置して開始する。マウス照準・左射撃・右近接・WASD・Space・R・E/数字/ホイール・Q・F。
HUDは簡易参加者情報のみ拡張している。正式モードではない。

## フィールド定義・配置・切替

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/field_layout.gd --quit-after 120
```

旧2シーンから転記した独立の期待値で、寸法・境界・床・全壁・全出現地点・全補給候補点を比較する。
同じ定義の複数Arenaへの再利用、実行時の壁変更/削除・マーカー/私有コピー変更による元定義への非干渉、
反復再配置でノードが重複しないことを検証する。

シーンファイルを持たないメモリ上の定義も配置して同じ衝突・弾処理を実行する。原点が0でない定義も含む。
不正矩形・NaN・境界外・出現地点不足/壁重複・不正補給型の拒否で、既存の壁/弾/入力/リソースが保たれることを確認する。
フィールド往復でActor/MatchState/Rosterを維持し、HP・弾薬・モード・仮装備・所持金・装備配置・勝数を比較する。
通常切替は一時タイマーを持ち越し、新encounter指定では一時状態だけリセットする。カメラ倍率の復帰も検証する。

全体回帰はfield_layoutを自動検出する。1対3の実戦更新は既存のextension_boundariesで引き続き確認する。
詳細と実行ログは[フィールド分離の記録](../archive/2026-09-12/FIELD_DEFINITION_REFACTOR.md)を参照。

## 描画と重点回帰

描画可能な環境でrender.gd、hud_compact.gd、result_flow.gdを実行する。
静止画/自動GUI入力と人間の操作感評価を区別する。

- 入力: action_buffer、mouse_input、character_select、initial_preparation。
- 戦闘: 全武器テスト、relics/synergies/added_relics/numeric_relic_stacking、projectile_hp、danger_zone、pulse。
- 経済: purchase_economy、economy_rounds、match_progression、item_instances、relic_stacking、field_weapon_reserve。
- CPU: cpu_ai、cpu_tactics、small_improvements。経路探索と間合い・弾予測・取得・危険地帯退避。
- 表示/進行: preparation_ui、hud_compact、result_flow、render。

武器はテスト側で明示的に用意する。自動サイドアームやローカルP2入力を仮定しない。
素材APIの有料生成は行わず、audio_assetsは保存済み素材のGodot Resource認識のみ。
素材ツールの無料mock検証は[素材生成設定](ASSET_GENERATION_SETUP.md)に従う。

## 未確認の受入

人間による操作感・購入経済/チーム戦バランス、配布版の一試合完走、最大負荷、
オンライン通信・同期・再接続は未確認。探索モード/階層/ボス/セーブは未実装。
現在の検証結果とログは[今回の記録](../archive/2026-09-12/EXTENSION_REFACTOR.md)を参照。
