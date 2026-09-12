# 検証手順

準備UI改修：`tests/preparation_redesign.gd` は通常5商品の表示、閲覧の非破壊性、購入後の明示配置、HP0〜3個加算、同時警告、Esc取消を検証。`preparation_ui.gd` は控えの所持品・空き枠・枠間への実ドロップも検証する。実画面撮影は `CHAMBER_SCREENSHOT` に既存の保存先ディレクトリを指定し、`Godot --path . --script res://tools/capture_preparation_revision.gd --quit-after 150`。[画面・実行記録](../art/reviews/preparation-ui-2026-09-12/README.md)。

配布内容の確認：`Godot --headless --path . --export-pack Web .local/art-export-audit.zip` でローカル検証用ZIPを作成し、内容一覧にdocs/・tests/・tools/・assets/generated/、未接続のsample_battle_02/test_ui_click、旧twohead_rinaがないことを確認する。これはゲームデータ部分の検証で、Web実行エンジン込みの配布容量とは異なる。将来音響サンプルを正式採用するときは、そのファイルのexclude_filterを解除する。

素材整理後の検証：`python -X utf8 tools/verify_art_organization.py` で移動先の存在、画像のハッシュ一致、docs/art内のリンクを確認する。旧リナ画像はtests/fixtures/artへ移動。連番撮影は不要候補のraw-frames、完成GIF・まとめ画像はdocs/art/reviewsへ保存する。

整理後の全64ヘッドレステスト合格（`.local/logs/run_tests-20260912-212428.log`）。[整理・検証記録](../archive/2026-09-12/art-organization/REPORT.md)。

全8人の方向別展開：`tests/character_directions.gd` で他7人の靴の支持中心・底辺、4方向選択、専用9ポーズと回避時間・無敵を検証。`tools/capture_direction_rollout.gd` で128フレームを撮影し、Pillow環境で `tools/package_direction_rollout.py` を実行して比較GIFを作る。全ヘッドレステスト合格（`.local/logs/run_tests-20260912-210616.log`）。[検証記録](../archive/2026-09-12/character-directions/REPORT.md)。

リナ現行：`rina_directions` は靴の支持中心・底辺、足の交代と胴体の支点を検証。`rina_dodge_poses` は専用9素材・段階の時刻・空中の上下動を検証する。回避性能は `rina_dive`。撮影は `tools/capture_rina_directions.gd`、GIF化はPillow環境で `tools/package_rina_motion.py`。[今回の8テストと描画確認](../archive/2026-09-12/rina-gait-dodge/REPORT.md)。

リナ4方向：`tests/rina_directions.gd` で方向選択、斜めの安定、正面の反転防止、後ろ歩き、回避方向優先、靴の交代と接地制約を検証。`tools/capture_rina_directions.gd` で実描画を撮影。[結果](../art/reviews/rina-directions-2026-09-12/README.md)。

8キャラの差し替え・固定パーツ歩行・前後切替・キャラ別回避は `tests/character_animation.gd`。描画比較は `Godot --path . --script res://tools/capture_character_rigs.gd --quit-after 900`、対戦撮影は `tools/capture_character_battle.gd`。既存回避性能はrina_dive、武器重なり等はworkshop_visualsも確認。[検証記録](../archive/2026-09-12/character-integration/REPORT.md)。

リナ飛び込みは `tests/rina_dive.gd` で距離の刻み幅非依存、0.31秒の無敵と着地中の被弾、他キャラの回避時間維持を検証。`tools/capture_rina_dive.gd` で連続画面を保存する。[実行結果](../archive/2026-09-12/rina-dive/REPORT.md)。

2頭身リナ：全59件合格（`.local/logs/run_tests-20260912-163851.log`）、最終描画調整後の `tests/workshop_visuals.gd` も合格。実移動撮影は `Godot --path . --script res://tools/capture_twohead_motion.gd --quit-after 900`。上下左右ポーズ撮影は `Godot --path . --script res://tools/capture_chibi.gd --quit-after 900 -- --twohead`。Godotはローカル実行ファイルへ置換。[結果と制限](../archive/2026-09-12/rina-twohead/REPORT.md)。

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

## 始まりの工房・最小画像構成

`tests/workshop_visuals.gd` は一括ランナーが自動検出する。リナ＋サービスピストルの移動、射撃、装填、補給、6コマの回避選択、照準と異なる回避方向、回避と無敵の0.05秒差を検証する。
原画・加工・API使用履歴は `assets/first-workshop/README.md` を参照。

```powershell
python -m unittest discover -s tools/tests -v
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/workshop_visuals.gd --quit-after 120
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/capture_workshop.gd -- --motion
```

最後のコマンドは描画可能な環境で1120×800の画面・各アニメキー・射撃/装填/補給を `docs/archive/2026-09-12/first-workshop/` に保存する。
撮影は決定的な状態を作る自動検証。手動プレイの操作感評価とは区別する。スクリプトは有料APIを呼ばない。

## 未確認の受入

人間による操作感・購入経済/チーム戦バランス、配布版の一試合完走、最大負荷、
オンライン通信・同期・再接続は未確認。探索モード/階層/ボス/セーブは未実装。
現在の検証結果とログは[今回の記録](../archive/2026-09-12/EXTENSION_REFACTOR.md)を参照。
# 低頭身リナの描画確認（2026-09-12）

`python -m unittest discover -s tools/tests -v` で予算等5テストが合格。
`powershell -ExecutionPolicy Bypass -File run_tests.ps1` で全59件が合格（ログ `.local/logs/run_tests-20260912-150858.log`）。
`Godot --headless --path . --script res://tests/workshop_visuals.gd` は前後切替、後退位相、武器位置、回避性能維持を検証する。
`Godot --path . --script res://tools/capture_chibi.gd --quit-after 900` で上下左右のゲーム内ポーズを撮影する（Godotはローカルの実行ファイルへ置換）。
Pillow入りPythonで `tools/review_chibi_capture.py` を実行すると比較GIFを作成する。
[結果・制限](../archive/2026-09-12/rina-chibi/REPORT.md)。移動シートは不採用で、脚を交互に動かす描画を使用。手動プレイの自然さの最終評価は未実施。
