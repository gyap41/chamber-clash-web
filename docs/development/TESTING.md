## 固定2部屋・扉移動（2026-09-21）

タイトル→ストーリーモード（試作）。工房の右側の扉に近づいてFで作業室へ移動し、作業室の左側の扉でFを押すと戻る。到着後は扉へ近づき直し、Fを離してから再操作する。両部屋とも敵なし。部屋名は上部、近くの扉の操作案内は下部に表示する。

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/exploration_rooms.gd --quit-after 180
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/exploration_rooms.gd --quit-after 240 -- --capture
```

相互接続・壁/到着位置と扉への歩行到達性、20回連続移動でHP/弾薬/モード/所持金/装備/装填/回避/無敵/反撃回復/レリック充電の保持、前部屋の弾/重力場/遅延射撃/入力予約消去、Fリピート/左押下継続、停止/死亡/戦闘中の拒否、通常更新での装填完了、再挑戦で工房へ戻ることを検証する。

追加テストと exploration_mode / shared_combat_hud / field_layout の動作検証はPASS。描画ありの最終exploration_roomsは終了コード0・エラーなし（`.local/two-rooms-capture.log` / `.local/two-rooms-capture-errors.log`）。ヘッドレスのexploration_roomsとfield_layoutには既存と同種のObjectDB/Resource終了時解放エラーが残る。全体回帰の再実行・手動プレイ・Web検証はしていない。

両部屋の画像は `.local/two-rooms-workshop-door.png` / `.local/two-rooms-annex-door.png`。扉が主人公を覆わない描画順、行き先名とF案内、同じ倍率の部屋表示を目視確認。[記録](../archive/2026-09-21/two-room-exploration/REPORT.md)。

## 敵なし探索のテストプレイ（2026-09-21）

タイトルの「ストーリーモード（試作）」は敵なしで開始する。通常CPU対戦は従来どおり。上部に敵なしの案内を表示し、敵0人でも自動クリアしない。終了は「タイトルへ」。弾薬/パルスは有限の既存設定を維持する。

`exploration_mode.gd`は参加者/Actorが主人公1人であること、100秒経過でHPを失わず継続、敵なしの移動/射撃、弾owner、再挑戦後も敵なし、通常CPU対戦に2人が残ることを検証する。戦闘を明示開始した状態の全滅/相打ちは状態単体テストで確認する。動作PASS、終了時ObjectDB警告あり（`.local/enemy-free-exploration.log`）。

共有HUDの描画あり統合テストもPASS・終了コード0・エラーなし（`.local/enemy-free-hud.log` / `.local/enemy-free-hud-errors.log`）。敵なし案内と主人公のみの画面を目視確認。`capture_exploration_mode.gd`の結果画面は主人公のHPを0にして撮影する。手動プレイの操作感・Web実機は未確認。

## P1冒頭・戦闘UI共通化（2026-09-21）

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/shared_combat_hud.gd --quit-after 180
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/shared_combat_hud.gd --quit-after 240 -- --capture
```

`shared_combat_hud`は両モードの同一部品利用、表示スナップショットの非破壊性、探索側へのフィールド切替後のHUD更新、HP/反撃回復、実クリックによる武器切替と射撃漏れ防止、装填途中からの進捗、停止時の弾薬/装填保持、複数停止理由、直接の切替要求も停止中は拒否されること、8武器の配置・丸腰・死亡結果を検証する。描画ありでは `.local/shared-hud-{duel,exploration,paused,eight-weapons,small,unarmed,result}.png` を保存する。

追加1本と関連7本（exploration_mode / hud_compact / mouse_input / rally_recovery / field_layout / result_flow / initial_preparation）の動作検証はPASS。最終の描画あり統合テストとhud_compactは終了コード0・エラーなし。一部ヘッドレス実行はObjectDB/Resourceの終了時解放エラーが残り、全体完全合格とは扱わない。今回の全スイート再実行はしていない。

通常1120×800と縮小840×600で対戦・探索、8武器・丸腰・結果の画面配置を目視確認した。人間による操作感、Web実機、インベントリ/装備詳細は未検証。[検証記録](../archive/2026-09-21/shared-combat-hud/REPORT.md)。

## ストーリーモードP0の検証（2026-09-21）

タイトルの「ストーリーモード（試作）」で起動する。直接起動・seed指定と回帰テスト：

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --path . res://scenes/game/exploration.tscn -- --seed=42
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/exploration_mode.gd --quit-after 120
```

`exploration_mode`はタイトル経由の開始、MatchState不使用、所持品の独立、初期装備/資金、取引と通常時の装備変更拒否、対戦準備ロックとの分離、複数停止理由/入力破棄、敵なしで100秒経過しても即クリア/時間切れ/縮小/補給なし、状態単体で相打ち死亡優先、一度だけの終了、再挑戦、タイトル経由でCPU対戦へ戻る際の初期状態を検証する。

描画確認は `Godot --path . --script res://tools/capture_exploration_mode.gd --quit-after 180`（Godotは上記exeへ置換）。`.local/exploration-{title,play,pause,result}.png`へ保存する。タイトル・戦闘・試作クリアの画面配置と文字の収まりを目視確認。手動プレイの操作感・音の品質・Web配布は未検証。

全85スクリプトで動作検証のPASS出力を確認、SCRIPT ERROR・Assertion失敗なし（`.local/logs/run_tests-20260921-201724.log`）。一括判定は37 PASS・48 FAIL。47件は終了時Resource解放エラー、探索テスト1件はPASS末尾のコロン欠落による検出漏れで、表記修正後の個別再実行でPASSを確認（`.local/exploration-final.log`）。探索テストに残るObjectDB警告の対象はAudioStreamWAV/AudioStreamPlaybackWAV。既存資料にもある終了時解放問題が残るため、全体の完全合格とは扱わない。CPU対戦の5-0・5-4・引分け・初期化の動作検証もPASS。

P1以降の未検証項目：空部屋/増援待ち、扉往復と旧敵の退場、資源/タイマー持越し、着脱による補充防止、控え満杯、乱数と報酬の独立、室内到達可能性、敵/報酬の再訪状態、死亡/中断保存の整合性。段階別の条件は[探索ロードマップ](../planning/EXPLORATION_ROADMAP.md)を参照。

## 待機・歩行モーションの検証（2026-09-21）

振幅強化後の通常サイズ描画は `Godot --path . --script res://tools/capture_dynamic_motion.gd --quit-after 900`。
Pillow環境で `python tools/package_dynamic_motion.py` を実行し、1120×800の戦闘画面GIFを作成する。
CPUと戦闘時計を止め、指定軌跡で待機・移動・停止を撮影する。実プレイ録画とは区別する。
標準デスクトップウィンドウは1120×800。Godotの埋め込み実行では表示領域も確認する。

`Godot --headless --path . --script res://tests/character_motion.gd --quit-after 120`
で8人の描画位置/倍率継承、呼吸ループ、4方向の支持足、停止時の姿勢連続、短い入力の反転、
回避/死亡の即時中断、照準角度維持、停止時計、30/120fpsの傾き応答を検証する。
関連回帰は actor_animation_state / player_animation / character_animation / rina_directions /
rina_dive / dodge_flow / equipment_art / workshop_visuals / visual_hub_live。

実描画は `Godot --path . --script res://tools/capture_character_motion.gd --quit-after 900`。
旧式と新式を同じ素材・照準・移動意図で並べた210フレームと、装備付きの実戦画面を出力する。
Pillow環境で `python tools/package_character_motion.py` を実行すると比較GIFになる。
[レビュー素材](../art/reviews/character-motion-2026-09-21/README.md)。
8人の新モーションはAnimationTreeの時計で進むため、撮影時はmove_phase/elapsedの代入ではなく
`advance_visual(dt, moving)`を使う。停止状態の再描画では時刻を進めない。

## キャラクター状態遷移の検証（2026-09-21）

`Godot --headless --path . --script res://tests/actor_animation_state.gd --quit-after 120`
で、Actorなしの標準グラフ再生、個体/身体/武器の独立、同一状態の再生継続、連射イベントの再始動、
手動時計、移動装填・回避装填・8人の回避射撃窓、装備変更の装填中断、死亡即時通知、初期化、
スナップショットの独立と戦闘データ非変更を検証する。
ポーズ・決着・部屋移動、表示だけの更新で時間が進まないことも対象。

関連回帰は player_animation / character_animation / character_directions / rina_directions /
rina_dive / rina_dodge_poses / dodge_flow / action_buffer / weapon_visual_events / equipment_art /
workshop_visuals / extension_boundaries / visual_hub_live / synergies / added_relics /
rally_recovery / projectile_hp / combat_visuals / characters / visual_hub。
撮影・Hubでは旧`Animation.advance()`や`Animation.moving`への直接操作を使わず、
`Player.advance_visual(dt, moving)`または`visual_moving`設定後の`sync_visual()`を使う。

今回の21スクリプトは動作アサーションのPASSを確認。旧描画と新描画の48条件で実画像が一致。
詳細と制限は[検証記録](../archive/2026-09-21/ACTOR_ANIMATION_STATE.md)。
証明書ストア読込と既存の終了時ObjectDB/Resource解放エラーが出るため、
エラーを含めた一括検証の完全成功とは区別する。手動プレイ・Web配布は未確認。

`tests/projectile_sound.gd`：通常弾の画面端着弾が無音、コメット着弾が爆発音1回・汎用着弾音なしを検証してPASS。

着弾音調整：generated_soundは20回同時要求の1発への集約、100ms後の抑制、250ms後の再発音と着弾-24dB／跳弾-20dBを検証しPASS。聴感は実機確認が必要。

2026-09-14 Web音響：music / sound / generated_sound / result_flow合格。soundは既定SE ONとStream再生を検証。ローカルWebデータを再出力し、Chromiumでタイトル→選択→準備（SE ON）→戦闘を確認、Webコンソールerror/warnなし。出音の聴取は未実施。公開Web版反映後はキャッシュ更新、準備曲・戦闘曲とSEの実音を確認する。

BGM接続：`Godot --headless --path . --script res://tests/music.gd` でタイトル→選択の継続、準備→戦闘→結果→次準備、ミュート保持、ポーズ減音、元Resource不変を検証。実機では右下BGM切替、SEとの音量バランス、各曲3周の継ぎ目を確認する。Webはブラウザ操作後の音声開始も確認する。

追加SE接続検証：generated_sound / sound / supplies / projectile_personality / added_relics / extension_boundaries / preparation_ui / preparation_redesign が成功。generated_soundは全38武器、Sレア予告1回、出現・開封・レア取得、危険警告1回、時間切れ・開始音保留を検証。実試聴は別途必要。

Visual Hub Web Live：`tests/visual_hub_live.gd` は8キャラ×3動作の24枠、装備一括変更、停止、画面外解放を検証する。起動スクリプトはWebビルドとHub専用PCKを生成する。ブラウザでは装備変更に撮影を使わないこと、pause/step、スクロール、拡大、レリックの効果と形状、WebGLエラーを確認する。[今回の記録](../archive/2026-09-13/VISUAL_HUB_WEB_LIVE.md)。

比較更新の受入確認：対象削除直後に古い枠を残さず、条件変更後に自動更新すること。更新中に再変更しても旧条件を表示しないこと。キャラ＋レリックの適用対象表示、静止素材だけの再生無効も確認する。

## Visual Hubの現行検証

起動は `powershell -ExecutionPolicy Bypass -File tools/visual_hub/start.ps1`。初回は `-Install`、Godot版のみは `-Mode Native`。
Web再生の受入確認：未撮影・静止画・動作変更後の「再生」で現条件を撮影して自動再生し、一時停止で同一フレームを維持すること。
Webの条件・レビュー競合・ローカル接続制限は `start.ps1 -Mode Test`。
`tests/visual_hub.gd` は現行全キャラ・武器・レリック・ステージ、隔離試射、追加・削除・欠落・未対応と保存復元を検証する。
`tools/visual_hub/verify_render.gd` はCompatibility実描画とクリック、停止・再開、比較PNG、再シミュレーションを検証する。
`node tools/visual_hub/web/verify_pipeline.mjs` は実Godotの4武器・2ステージ撮影、同条件キャッシュと破損PNG修復を検証する（対応Nodeが必要）。
配布検証は `Godot --headless --path . --export-pack Web .local/visual-hub/game-export-audit.zip`。tools/tests/docs/.local/node_modules/package*.jsonの非収録を確認する。
今回の結果と既知の制約は[実装・検証記録](../archive/2026-09-13/VISUAL_HUB_HYBRID.md)。以下の過去の結果とは区別する。

2026-09-13 ダブルバック改修: equipment_art / weapon_readability 成功。Compatibilityで38武器の左右を撮影。docs/art/reviews/doubleback-body-2026-09-13/ を参照。

# 検証手順

オーロラの虹の帯：weapon_readability / aurora_ribbon / projectile_hp が合格。曲線の連続性・距離上限・7色補間・既存弾の停止／方向を検証。実戦48フレームを再描画。[結果](../art/reviews/aurora-ribbon-2026-09-13/README.md)。

武器視認性修正：全71件合格（`.local/logs/run_tests-20260913-122418.log`）。weapon_readability は発射色→専用Sprite→着弾、軌跡の材質分離、厚みと判定維持、材質解除を検証。ID 4 / 8 / 20 / 37 の実戦各48フレームと全38種左右表示を確認。[結果](../art/reviews/weapon-readability-fix-2026-09-13/README.md)。

武器視認性レビュー：`tools/audit_weapon_readability.gd` で38武器を倍率1・同一キャラ・左右方向から描画して寸法と半径を計測。`tools/capture_weapon_audit_battle.gd -- 4`（20 / 37も対応）で実戦背景の自動射撃48フレームを確認。今回、ゲーム実装に変更なし。[資料](../art/reviews/weapon-readability-audit-2026-09-13/README.md)。

レジェンド重力場：legendary_weapons / gravity_legendary 合格。`tools/check_gravity_legendary_render.gd` は4個同時描画、停止中のピクセル一致、再開時の変化を検証。`tools/capture_gravity_legendary.gd` は実戦96フレーム。[ログと映像](../art/reviews/gravity-legendary-2026-09-13/README.md)。

重力場の残留演出（2026-09-13、渦の強調後も96フレーム再描画）：legendary_weapons 合格（`.local/logs/gravity-residue-test.log`）。実戦描画は `tools/capture_gravity_residue.gd`、96フレーム。吸引・ダメージ・壁・敵弾吸収・持続と停止の既存テストを使用。

弾の差別化（2026-09-13）：全69件実行、66件初回合格。旧半径を検査していた equipment / legendary_weapons / pattern_weapons の3件は新仕様へ更新し再実行で合格。新規 projectile_personality はかすり接触・半径の上書き・小包の対比・泡の伸縮・軌跡上限を検証。ログ `.local/logs/run_tests-20260913-110705.log` と `.local/logs/personality-{equipment,legendary,pattern}.log`。12種類の飛行描画と実戦描画、最新Webデータパックの起動・不要素材除外も確認。[詳細と動画](../art/reviews/projectile-personality-2026-09-13/README.md)。

弾の識別リング撤去：projectile_hpテスト合格。全38武器の再描画で輪が消えていることを確認。当たり判定・速度・威力は変更なし。ログ .local/logs/projectile-no-rings-test.log。

弾・VFX統合（2026-09-13）：全68テスト合格、ログ `.local/logs/run_tests-20260913-054400.log`。`weapon_visual_assets` は全38武器・派生画像・8系統VFXの実在を検証、`weapon_visual_events` は装填開始／完了／中断、派生元、遅延射撃、専用シーンの停止、ゲーム効果の登録を検証。後続の戦闘サービス参照の追加も同テストで合格。実描画は `tools/capture_projectile_effects.gd` と `tools/capture_projectile_battle.gd`。[動画と結果](../art/reviews/projectile-effects-2026-09-13/README.md)。

WebデータZIP `.local/projectile-effects-export.zip` に新素材60 PNGと `data/weapon_visuals.json` を収録。旧弾／VFXシート・旧共通muzzle/impact・docs・生成原画等の非収録と起動を確認。データZIPは約16.2MB（Web実行エンジンを含まない）。画像予算テスト7件合格、今回6送信すべて成功、累計72回。

2026-09-13：全38武器・35レリックを接続。全66テストに合格（`.local/logs/run_tests-20260913-050332.log`）。初回実行で戦闘前の `apply_build` による未設定の照準角度参照を検出し、初期角度0で処理するよう修正した後、全件を再実行した。

`equipment_art` は37新装備武器の縦横比・四方向の握り点・銃口・回避中非表示と全35レリック参照を検証。`catalog` は既存ピストルを含む全38画像の共有参照を検証。`tools/capture_all_equipment.gd` で左右の武器描画と35アイコンを撮影し、`capture_preparation_revision.gd` で実UIを確認。[確認資料](../art/reviews/equipment-diversity-2026-09-13/README.md)。

`python -m unittest discover -s tools/tests -v` の画像予算7件に合格。`python -X utf8 tools/verify_art_organization.py` は699移動先・507画像の同一性・資料リンクを検証し、エラー0。累計66送信、今回10送信すべて成功。

`Godot --headless --path . --export-pack Web .local/diverse-equipment-export.zip` とZIPの起動に成功。採用装備72 PNGのインポート参照を確認。docs・tests・tools・生成原画・旧武器シート・旧レリックSVGは非収録。Webエンジンを含まないゲームデータZIPの確認である。

準備UI改修：`tests/preparation_redesign.gd` は通常5商品の表示、閲覧の非破壊性、購入後の明示配置、HP0〜3個加算、同時警告、Esc取消を検証。`preparation_ui.gd` は控えの所持品・空き枠・枠間への実ドロップも検証する。実画面撮影は `CHAMBER_SCREENSHOT` に既存の保存先ディレクトリを指定し、`Godot --path . --script res://tools/capture_preparation_revision.gd --quit-after 150`。[画面・実行記録](../art/reviews/preparation-ui-2026-09-12/README.md)。

配布内容の確認：`Godot --headless --path . --export-pack Web .local/art-export-audit.zip` でローカル検証用ZIPを作成し、内容一覧にdocs/・tests/・tools/・assets/generated/、未接続のsample_battle_02/test_ui_click、旧twohead_rinaがないことを確認する。これはゲームデータ部分の検証で、Web実行エンジン込みの配布容量とは異なる。将来音響サンプルを正式採用するときは、そのファイルのexclude_filterを解除する。

素材整理後の検証：`python -X utf8 tools/verify_art_organization.py` で移動先の存在、画像のハッシュ一致、docs/art内のリンクを確認する。旧リナ画像はtests/fixtures/artへ移動。連番撮影は不要候補のraw-frames、完成GIF・まとめ画像はdocs/art/reviewsへ保存する。

整理後の全64ヘッドレステスト合格（`.local/logs/run_tests-20260912-212428.log`）。[整理・検証記録](../archive/2026-09-12/art-organization/REPORT.md)。

全8人の方向別展開：`tests/character_directions.gd` で他7人の靴の支持中心・底辺、4方向選択、専用9ポーズと回避時間・無敵を検証。`tools/capture_direction_rollout.gd` で128フレームを撮影し、Pillow環境で `tools/package_direction_rollout.py` を実行して比較GIFを作る。全ヘッドレステスト合格（`.local/logs/run_tests-20260912-210616.log`）。[検証記録](../archive/2026-09-12/character-directions/REPORT.md)。

リナ現行：`rina_directions` は靴の支持中心・底辺、足の交代と胴体の支点を検証。`rina_dodge_poses` は専用9素材・段階の時刻・空中の上下動を検証する。回避性能は `rina_dive`。撮影は `tools/capture_rina_directions.gd`、GIF化はPillow環境で `tools/package_rina_motion.py`。[今回の8テストと描画確認](../archive/2026-09-12/rina-gait-dodge/REPORT.md)。

リナ4方向：`tests/rina_directions.gd` で方向選択、斜めの安定、正面の反転防止、後ろ歩き、回避方向優先、靴の交代と接地制約を検証。`tools/capture_rina_directions.gd` で実描画を撮影。[結果](../art/reviews/rina-directions-2026-09-12/README.md)。

8方向キャラクターリグ（リナ、走行・待機・回避・近接）：`tests/character_rig8.gd` で、登録キャラだけが対象であること、近接の4コマ・ナイフ・踏み込み・当たり判定（64px・70°）と、既定無効、有効時は8方向の向き選択と左向き3方向の反転、待機・回避のコマ送りと回避の浮き、回避は移動方向で向きを選び銃を隠して両腕を前へ出すこと、境界付近で前の向きを保つこと、各向きで grip が手の位置に来ること、従来パーツと Weapon/Sprite を隠すこと、8コマの巡回と後退の逆順、ポニーテール・スカーフの別画像と走行中のばねの角度変化、他キャラは従来表示、Vキーの切替（同じ入力を複数Actorが受けても1回だけ）を検証。キャラの大きさ案D（C キー）で探索カメラ1.45倍・リナ1.1倍（足元中心）になり既定は無効であることも同テストで検証。

8キャラの差し替え・固定パーツ歩行・前後切替・キャラ別回避は `tests/character_animation.gd`。描画比較は `Godot --path . --script res://tools/capture_character_rigs.gd --quit-after 900`、対戦撮影は `tools/capture_character_battle.gd`。既存回避性能はrina_dive、武器重なり等はworkshop_visualsも確認。[検証記録](../archive/2026-09-12/character-integration/REPORT.md)。

リナ飛び込みは `tests/rina_dive.gd` で距離の刻み幅非依存、0.31秒の無敵と着地中の被弾、他キャラの回避時間維持を検証。`tools/capture_rina_dive.gd` で連続画面を保存する。[実行結果](../archive/2026-09-12/rina-dive/REPORT.md)。

2頭身リナ：全59件合格（`.local/logs/run_tests-20260912-163851.log`）、最終描画調整後の `tests/workshop_visuals.gd` も合格。実移動撮影は `Godot --path . --script res://tools/capture_twohead_motion.gd --quit-after 900`。上下左右ポーズ撮影は `Godot --path . --script res://tools/capture_chibi.gd --quit-after 900 -- --twohead`。Godotはローカル実行ファイルへ置換。[結果と制限](../archive/2026-09-12/rina-twohead/REPORT.md)。

更新: 2026-09-12。現在の実行方法と受入条件を管理する。
詳細な過去記録は[変更前の検証資料](../archive/2026-09-12/BEFORE_EXTENSION_TESTING.md)、
今回の記録は[拡張リファクタリング](../archive/2026-09-12/EXTENSION_REFACTOR.md)。

## 回避から反撃への接続（2026-09-15）

`Godot --headless --path . --script res://tests/dodge_flow.gd --quit-after 120` で、8キャラの射撃開始時刻、リナの着地中の武器表示、他7人の回避後無敵、予約切替と短押し射撃、ホイール往復での発射待ち・弾数維持、Eからホイール逆回転での予約取消を確認する。

関連回帰は action_buffer / mouse_input / rina_dive / equipment_art / synergies / added_relics。action_bufferは回避前半の切替予約、切替直後の短押し射撃、停止・フォーカス離脱・決着・再初期化での予約破棄を含む。全体ランナーはdodge_flowを自動検出する。

手動受入：リナと他キャラで回避しながら左ボタン長押し／終盤短押し、E／数字／ホイール／HUDでの予約切替を試す。リナが着地中に照準方向へ撃てるか、武器表示が自然か、連射や無敵射撃が過剰でないかを確認する。動作アサーションと実プレイの気持ちよさは別に評価する。

実行結果：全81スクリプトを実行（`.local/logs/run_tests-20260915-202110.log`）。80件は動作検証のPASSを出力。workshop_visualsの「回避中は常に武器非表示」という旧期待値を新仕様に更新し、個別再実行でPASSを確認した。一括判定は33件PASS・48件FAILで、上記修正後もObjectDB/Resourceの終了時解放エラーが残るため全件合格とは扱わない。実プレイの操作感・バランスと着地射撃の見え方は未確認。

## 反撃回復（2026-09-15）

`Godot --headless --path . --script res://tests/rally_recovery.gd --quit-after 120` で、50%回収枠、3秒の被弾別期限、部分回収、実ダメージ・過剰ダメージ・無敵/軽減・危険地帯・死亡/初期化、弾/近接/重力/爆発の攻撃者帰属、HUD表示を確認する。関連回帰はprojectile_hp / legendary_weapons / added_relics / synergies / hud_compact / extension_boundaries / endgame_balance。

描画確認は `Godot --path . --script res://tests/rally_recovery.gd --quit-after 120 -- --capture`。`.local/rally-recovery.png` に実HUDを保存する。黄色の回収可能分と現在HPが区別でき、左右の説明が収まることを確認した。手動プレイの戦闘フィーリング、武器間バランス、リングの見やすさは未検証。

全82スクリプトで動作検証のPASS出力を確認（`.local/logs/run_tests-20260915-211235.log`、SCRIPT ERROR・Assertion失敗なし）。一括判定は28件PASS・54件FAILで、終了時のObjectDB/Resource解放エラーが残る。軽減と既存回復の併用を追加した最終版のrally_recoveryも個別実行で動作PASS。描画ありの回復テストは終了コード0・エラーなし。ヘッドレスの解放エラーが未解決のため、全体回帰の完全合格とは扱わない。

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
オンライン通信・同期・再接続は未確認。探索の階層/ボス/セーブは未実装。固定2部屋の移動は冒頭を参照。P0の試作と検証範囲は冒頭を参照。
現在の検証結果とログは[今回の記録](../archive/2026-09-12/EXTENSION_REFACTOR.md)を参照。
# 低頭身リナの描画確認（2026-09-12）

`python -m unittest discover -s tools/tests -v` で予算等5テストが合格。
`powershell -ExecutionPolicy Bypass -File run_tests.ps1` で全59件が合格（ログ `.local/logs/run_tests-20260912-150858.log`）。
`Godot --headless --path . --script res://tests/workshop_visuals.gd` は前後切替、後退位相、武器位置、回避性能維持を検証する。
`Godot --path . --script res://tools/capture_chibi.gd --quit-after 900` で上下左右のゲーム内ポーズを撮影する（Godotはローカルの実行ファイルへ置換）。
Pillow入りPythonで `tools/review_chibi_capture.py` を実行すると比較GIFを作成する。
[結果・制限](../archive/2026-09-12/rina-chibi/REPORT.md)。移動シートは不採用で、脚を交互に動かす描画を使用。手動プレイの自然さの最終評価は未実施。

Visual Hubのライブ表示変更時は、武器一覧を再生中・停止中に上下スクロールし、白い帯やカード外への描画漏れがないことを確認する。拡大と一覧への復帰、モーション一覧も確認する。表示はカード内Canvasで、画面内の対象のみGodotで動作する。
# 生成SE接続の確認

`Godot --headless --path . --script res://tests/generated_sound.gd --quit-after 180` で16素材・11武器ID振分け・合成フォールバック・初期ゲイン・準備操作成否・プレビュー無音・勝敗1回通知・再生解放を確認する。
関連回帰：sound、preparation_ui、preparation_redesign、extension_boundaries。実試聴では準備画面の音をONにし、連射・パルス・UI・勝敗の音量差と声／音楽の混入を確認する。試聴品質は未確認。

## CPUの取得判断・ランダム補給（2026-09-14）

`Godot --headless --path . --script res://tests/cpu_loot_pressure.gd --quit-after 120` は通常弾の壁遮蔽、壁を通過する月刃への回避、取得要求の抑制、2.5秒の被弾記憶、600フレーム以内の補給への壁迂回を検証する。
`Godot --headless --path . --script res://tests/random_supplies.gd --quit-after 120` は24シード・通常/縮小時の4補給、位置の多様性、同シード再現、到達領域、壁・補給間隔を検証する。suppliesの固定マーカー検証はrandomize_positions=falseを明示。workshop_visualsはランダムな初期補給を除去して専用の補給表示を検証する。

全79スクリプトを実行。追加2件・cpu_tactics・field_layout・small_improvementsはPASS。workshop_visualsにランダム補給との重なりが見つかり、テスト配置を分離した後の個別再実行でPASSを確認。ほかのスクリプトは動作検証のPASSを出力したが、多数で終了時のObjectDB/Resource解放エラーがあり、一括実行は失敗扱い（全件合格ではない）。最終CPU迂回テストも個別再実行でPASS。実プレイでの勝率・取得頻度・操作感は未検証。
ベルフラワー対応：`Godot --headless --path . --script res://tests/cpu_seed_avoidance.gd --quit-after 120` で待機中の警戒・取得抑制・離脱・回避クールダウン・実際の突進開始・壁遮蔽・味方/消滅弾の除外を検証する。cpu_ai / cpu_tactics / cpu_loot_pressure / cpu_seed_avoidance の動作アサーションはPASS。サンドボックス実行では証明書ストア読取エラー、一部テストでは終了時Resource/ObjectDB解放エラーが残る。実プレイ品質は未検証。
## 外周壁の確認（2026-09-21）

継ぎ目修正後は左右2部屋の角柱・通路接続・細壁の両側の縁・暗い室外基礎を描画確認。ログは `.local/stage-joints.log` と `.local/stage-joints-errors.log`。描画テストで20往復・衝突の回帰もPASS。変更前の比較画像は `.local/stage-before-joints.png`。

`tests/exploration_rooms.gd` に外周壁と開口部のsolid判定、上下壁への移動阻止、Texture2Dを外した場合の衝突不変性を追加。2部屋の到達性と20往復も継続検証する。参考画像への対応後、通路の上下壁、不正な床描画領域・壁正面参照の拒否も追加した。描画確認は下記と同じ `--capture` オプションを使う。`field_layout.gd` で既存マップも検証。両テストはPASS、描画実行は終了コード0・stderr空。ヘッドレス終了時の既存と同種のResource解放警告は残る。Web・手動プレイは未確認。
## ステージテンプレート（2026-09-21）

`tests/stage_templates.gd` は未知の部屋ID、素材セット交換、壁IDを保持した並べ替え、家具の独立衝突、照明生成、室外solid、不正データの組み立て前拒否、5回の部屋再構築を検証する。

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/stage_templates.gd --quit-after 180
```

併せてexploration_rooms（描画あり）とfield_layoutを実行。新規テストと2部屋描画はPASS。既存field_layoutのヘッドレス終了時Resource解放警告は残る。Webと照明の美術品質は未検証。
## 工房見本（2026-09-21）

exploration_roomsの20往復で、現在の部屋定義と配置物数が一致し、光源あり配置にはPointLight2Dが1個だけ存在することを追加検証。描画ログは `.local/showcase.log` / `.local/showcase-errors.log`、プレビューはdocs/art/production/workshop-showcase/room-preview.png。stage_templatesは家具あり部屋を基準に変更し、追加配置の衝突・光・後片付けを検証する。画像CLIの予算境界7テストもPASS。
## ステージの奥行き

stage_depthに北壁と側壁の上面高さ一致、右通路の上下接続数、側壁の衝突矩形不変性を追加。描画付きexploration_roomsで両部屋の継ぎ目と20往復を確認（`.local/joins.log`）。

`tests/stage_depth.gd` は壁の高さ変更後も衝突矩形が同じこと、家具の足元補正、Yソート用レイヤー、作業台の奥/手前の有効な立ち位置、隣室でソート設定が戻ることを検証。`-- --capture`で`.local/depth-behind-bench.png`と`depth-front-bench.png`を出力し、人物と武器の隠れ方を目視確認した。stage_templates / exploration_rooms / player_animationもPASS。終了時のObjectDB/Resource解放警告は一部に残る。追加のAPI生成なし。
## 家具の縮尺

stage_depthのcaptureに作業台の横へキャラを配置した比較画像 `.local/depth-beside-bench.png` を追加。その立ち位置に衝突がないことと、前後関係も検証。机・棚の衝突縮小後はexploration_roomsで到達性と20往復を再確認する。
## 見下ろし作業台（2026-09-22）

stage_depthの描画実行で奥・手前・横の立ち位置、前後関係、衝突と壁接続の維持を確認。ログは `.local/table-overhead.log` / `.local/table-overhead-errors.log`。ゲーム内比較はdocs/art/production/workshop-showcase/workbench-overhead-preview.png。画像CLIの予算検証7件もPASS。Webと手動プレイは未確認。

## 工房の馴染み調整（2026-09-22）

stage_templatesは3つの新遮蔽物の中心がsolidで、旧石ブロックの空いた角は通れることを検証する。壁数は各部屋定義から取得し、並べ替え後も壁IDの材質が維持されることを確認。stage_templates / stage_depth / field_layoutのアサーションPASS。stage_depthは終了時ObjectDB解放警告あり。描画付きexploration_roomsで20往復と入口案内を再確認し、プレビューをdocs/art/production/workshop-showcase/workshop-polish-preview.pngへ保存。手動プレイとWebは未確認。

## 出入口の石材接続（2026-09-22）

描画付きexploration_roomsで両部屋の到達性・20往復・状態保持をPASS、stderr空。stage_depthの接続数・衝突・前後関係もPASS（終了時の既存ObjectDB警告あり）。旧金属扉枠、棒状の敷居、下側の角材の連続を解消した画面を目視確認。ログ.local/door-stone.log、プレビューdocs/art/production/workshop-showcase/door-stone-preview.png。

炉の排煙管・出口壁灯修正：描画付きexploration_roomsで20往復と資源保持、配置・光源数を検証してPASS、stderr空（.local/fixture-review.log）。壁灯が通路上側の壁正面に収まり、炉の口が壁接続管で覆われることを目視確認。

## 四方向の扉（2026-09-22）

通常の探索は工房2部屋。四方向5部屋を手動操作する場合：

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --path . res://scenes/game/exploration.tscn -- --stage-four-way
```

自動検証（描画画像が不要なら--headlessを追加し、-- --captureを省く）：

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/four_way_rooms.gd --quit-after 600 -- --capture
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/wall_junctions.gd --quit-after 180
```

four_way_roomsは上下144px・左右112pxの開口、方向/幅の不正値拒否、接続先不整合、通路の横方向の衝突、到達性、20往復（40回遷移）の資源保持、F押下解除、再挑戦を検証。wall_junctionsはL字/T字・縦壁下端の正面接続、24px厚、配列順に依存しない接続、衝突不変性を検証する。

両テストと既存exploration_rooms/stage_templates/stage_depth/field_layoutのアサーションはPASS。four_way_roomsの描画実行はstderr空。ヘッドレスでは一部終了時ObjectDB/Resource解放警告が残る。描画ログ.local/four-way.log、画像.local/two-rooms-four-way-{north,south,east,west}.png。四方向の通常サイズ表示を目視確認。Webと人間による操作感は未確認。

## 接続用壁材v2

`tests/connected_wall_surface.gd`はL字/T字/十字と分割矩形で外周バンドが内部を横切らないこと、配列順に依存しないこと、必須素材欠落の拒否、部屋切替時の描画ノード削除/再作成と衝突不変性を検証する。実行は他のSceneTreeテストと同じGodot --headless --path . --script res://tests/connected_wall_surface.gd --quit-after 180。

新規テストとstage_templates/stage_depth/wall_junctions/field_layoutのアサーションはPASS。一部のヘッドレス終了時に既存と同種のObjectDB/Resource警告あり。exploration_roomsとfour_way_roomsは描画実行でPASS、stderr空（.local/wall-kit.log、.local/wall-kit-four.log）。工房の通路接合と四方向開口を通常サイズで目視確認。生成予算7テストもPASS。Web性能と手動操作感は未確認。

壁正面の接続修正：connected_wall_surfaceに右通路の側壁厚みが正面となり、正面と上面の面積重複がないことを追加。four_way_roomsには左右両方の接合を追加。両テストPASS（前者のヘッドレス終了時に既存ObjectDB警告あり）。exploration_rooms/four_way_roomsの描画付き20往復もPASS。exploration_roomsはstderr空、four_way_roomsは終了時ObjectDB警告あり。工房と四方向検証室を目視確認。ログ.local/wall-return*.log。

上側の角の再修正：connected_wall_surfaceで左右北角が上面、通路終端が正面であることを同時に検証してPASS。正面と上面の重複なしも維持。ヘッドレス終了時ObjectDB警告あり。exploration_roomsの描画・20回遷移はPASS、stderr空（.local/wall-upper-corner.log）。上側の連続と下側の石積み維持を目視確認。

## P1 探索バッグ（2026-09-22）

通常入口の工房でTabまたは「バッグ」。Fで固定の武器/レリックを取得し、控えからドラッグまたは選択→マスクリックで配置。配置・解除は即時反映。「閉じる」/Esc/Tabで変更を維持して戻る。使用/使用可能マス数、控えと詳細の占有マス数、グリッドの色付き形状を確認する。工房と隣室を往復して取得物が復活しないことを確認する。

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/exploration_bag.gd --quit-after 600 -- --capture
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/exploration_bag_ui.gd --quit-after 600 -- --capture
```

状態テストは停止/即時反映/閉じる、不正配置の原状維持、丸腰からの再装備、弾薬/モード/射撃待ち/装填/回避/充電保持、HP上限着脱、拾得後の利用、再訪、満杯時の拾得と解除拒否、他停止理由、死亡時拒否、再挑戦を検証。UIテストは実クリックで開閉・選択・即時配置・占有数表示し射撃漏れがないことを確認。両方の最終描画実行PASS・stderr空。非表示ウィンドウの初期フォーカス通知後にテストの停止を解除する。

回帰exploration_rooms/four_way_rooms/preparation_ui/preparation_boundaries/build_inventory/exploration_mode/shared_combat_hud/extension_boundariesはPASS。一部ヘッドレス終了時にObjectDB/Resource警告が残る。バッグ画面を通常サイズで目視確認。実ドラッグ操作の手動受入・Web・敵ありの体験は未確認。ログ.local/exploration-bag*.log、記録画像docs/art/reviews/exploration-bag-2026-09-22/preview.png。

フォーカス復帰：`Godot --headless --path . --script res://tests/exploration_focus.gd --quit-after 120`。アプリのフォーカス喪失/復帰通知を3往復させ、停止中の位置保持、復帰後の移動、射撃押下と予約入力の消去、手動ポーズ/バッグ停止の維持を検証する。Godotエディタの再生ボタンからの手動確認は別途、探索中に別ウィンドウへ移り、ゲームへ戻って移動・Tabを操作する。

隣室更新：stage_templatesで共通接続壁テーマ、家具5点の衝突、旧石ブロック位置と西扉・到着点の空きを検証。exploration_roomsの描画あり実行で20往復・重複生成防止を確認。画像はdocs/art/production/workshop-annex/room-preview.png。

商取引・拾得物の分離後の回帰確認：`purchase_economy.gd`（支払い・売却・二重購入拒否）、`bag_expansion.gd`（拡張配置と課金）、`reward_generation.gd`（seedと共有商品）、`preparation_boundaries.gd`（CPU20試合）、`exploration_bag.gd`（拾得・満杯・状態保持）、`exploration_rooms.gd`（20往復）。いずれも `Godot --headless --path . --script res://tests/<ファイル名> --quit-after 600` で実行。`exploration_bag_ui.gd` は描画ありで実クリックを確認する。終了時のObjectDB/Resource警告はテストのPASSと分けて扱う。

P2配置ID：Godot --headless --path . --script res://tests/room_instances.gd --quit-after 600。同じテンプレートの取得/戦闘状態の独立、配置IDを変更した2部屋の実遷移、再訪と再挑戦を検証する。exploration_mode / exploration_bagも回帰確認。通常入口のランダム化や敵の復元はこのテストの対象外。

P2ランダム階層：タイトルの「ストーリーモード（ランダム階層・試作）」、F移動、Mマップ、Tabバッグ。直接起動は `Godot --path . res://scenes/game/exploration.tscn -- --random-floor --seed=22`。

- `Godot --headless --path . --script res://tests/exploration_floor.gd --quit-after 3000`：100seed、8〜12室、再現性、4役割、扉相互参照、重複なし、274形状/家具/開口組合せの到達性、通路封鎖/重複配置の拒否。
- `Godot --headless --path . --script res://tests/random_floor_play.gd --quit-after 1200`：タイトル起動、全室往復、資源と取得済み状態、マップ表示範囲/停止理由/M入力、同seed再挑戦と異seed変更。
- 描画確認は後者から--headlessを外し末尾に `-- --capture`。画像は.local/two-rooms-random-{title,start,map}.png。採用確認用コピーはdocs/art/production/random-workshop-floor/。描画テストPASS、終了時ObjectDB/Resource警告あり。Webと手動操作感は未確認。
- 回帰：four_way_rooms、room_instances、exploration_mode、shared_combat_hudがPASS。この回帰は敵生成を無効化した形状/移動の検証。敵はP3専用テスト、特殊部屋機能は未実装。

探索カメラ：Godot --headless --path . --script res://tests/exploration_camera.gd --quit-after 600。小部屋/同寸法/大部屋/縦長、端制限、表示倍率、HUDを除いた中央への座標変換、停止、部屋切替を検証。exploration_roomsとshared_combat_hudも回帰PASS。大部屋はテスト用の空フィールドで、正式な大型ステージの美術と手動の追従操作感は未確認。

部屋バリエーションは同じexploration_floorテストで全6形状の出現保証、ボス寸法、壁/床の同seed再現も検証。random_floor_play -- --captureで.local/two-rooms-variant-{standard,compact,wide,tall,elbow,hall}.pngを保存する。生成版2、seed22の通常表示画像はdocs/art/production/workshop-room-variants/。既存四方向扉とカメラテストもPASS。

### P3最初の近接敵

タイトルのランダム階層から通常の作業室へFで入ると2体が出現する。固定の工房テストは敵なし。

- `Godot --headless --path . --script res://tests/exploration_encounter.gd --quit-after 1200`：通常6室、安全室4室、構え中の照準固定/停止時の表示スナップショット保持と被弾/空振り/壁越し拒否、家具迂回、停止、射撃/近接による被弾、出口利用拒否/解放、owner付き弾/重力場/追射破棄、再訪、資源持越し、戦闘中再初期化、相打ち死亡優先、再挑戦。
- `Godot --headless --path . --script res://tests/exploration_enemy_spawns.gd --quit-after 1800`：10seed/108入口で広さ別3〜6体の出現位置、入口と敵同士の距離、衝突なし、主人公までの経路。
- 描画ありは最初のコマンドから--headlessを外して `-- --capture` を付ける。1120×800の構え・打撃・硬直を.local/two-rooms-enemy-{windup,strike,recover}.pngへ保存。通常サイズの比較はdocs/art/production/exploration-first-enemy/README.md。
- exploration_mode、random_floor_play、exploration_bag、extension_boundaries、shared_combat_hudもPASS。headlessの一部は既存の終了時ObjectDB/Resource警告あり。描画ありの遭遇テストも実行終了時にObjectDB警告が出る場合がある。手動操作感・Web負荷・正式美術の採用は別確認。

## 資料整理の検証（2026-09-22）

探索企画3資料、索引、ロードマップ、引き継ぎと退避先について、Markdown内のローカルファイルリンク210件の存在を確認（欠落0件）。古いグリッド計画へのリンクは退避先へ変更し、重複したリナ導入案内を削除。git diff --checkが成功。今回は資料のみの変更で、ゲーム動作テストや素材生成・音の試聴は追加実行していない。企画の数値・ボス候補・報酬演出は未実装/未採用案として区別する。

## 資料の追加・移動時の確認

```powershell
python tools/docs_index.py
python tools/docs_index.py --check
```

全件索引の更新漏れとローカルのインラインリンク先を確認する。外部URL・見出しアンカー・参照形式リンク・本文中の裸のパスは対象外。仕様内容の正しさは対象コードと個別に照合する。運用は[資料の配置と更新](../DOCUMENTATION_GUIDE.md)。

## 火袋トカゲと混成戦

`Godot --headless --path . --script res://tests/fire_pouch_lizard.gd --quit-after 1200`。初戦/混成、射撃前の待機、狙い固定の2発、硬直、停止、横回避、被弾、無敵、敵同士非被弾、壁/口の壁貫通防止、パルス、画面外での開始禁止と中止、死亡・再挑戦を確認。描画ありでは--headlessを外し末尾に `-- --capture` を付け、.local/two-rooms-lizard-{windup,shot}.pngを保存する。

関連回帰はexploration_encounter、exploration_enemy_spawns、random_floor_play、projectile_personality。手動の混成戦・難度・連続アニメーションの読みやすさは別途評価する。[制作仕様と確認記録](../art/production/fire-pouch-lizard/README.md)。
## 探索敵SEの検証

`Godot --headless --path . --script res://tests/enemy_audio.gd --quit-after 600` で、構え・空振り・2連射の発火回数、死亡後と画面外キャンセルの無音、同時発音の抑制、SEオフを確認する。`tests/audio_assets.gd` はmanifest全件のResource認識、`tests/sound.gd` は既存音響の回帰確認。いずれも聴感を保証しない。音響の仮接続と試聴残項目は[AUDIO_BIBLE](../AUDIO_BIBLE.md)を参照。


## 敵の移動アニメーション

`Godot --headless --path . --script res://tests/enemy_motion.gd --quit-after 600` は移動距離で位相が進むこと、停止・壁押し時の足運び停止、prepareでのリセット、専用4コマ・左向き・撃破コマの選択と撃破表示の寿命・停止・離室消去を確認する。描画ありのfire_pouch_lizardで通常サイズの構えを確認。連続歩行の聴覚・視覚受入や負荷測定は自動テスト成功に含めない。


## 初戦報酬の宝箱

`Godot --path . --script res://tests/exploration_reward.gd --quit-after 900 -- --capture` で出現・開封・押し直し・停止・控え満杯・空き復元・再構築・再挑戦・死亡優先を確認。画像は.local/two-rooms-reward-closed.pngとreward-open.png。描画ありでPASS。全seedの報酬配置と手動の楽しさ・SE聴感は未確認。

`Godot --path . --script res://tests/enemy_animation_review.gd --quit-after 600` はv2の全方向・連続コマ比較を.local/enemy-animation-v2-review.pngへ保存する。静止連続コマの比較であり連続プレイの受入とは別。

撃破粒子の比較は `Godot --path . --script res://tests/enemy_death_review.gd --quit-after 600` 。enemy_motionは火花／有機粒子の区別と1.1秒の終了も検証する。

## 宝箱部屋と最低補給

- `Godot --path . --script res://tests/exploration_treasure_supplies.gd --quit-after 900 -- --capture`：宝箱先行でも初戦保証、内容固定、開封/回収/再訪/再挑戦、弾薬満タン拒否・補給・装備反映後保持、回復満タン拒否・上限・反撃回復の整合、停止/死亡/二重取得拒否。描画ありPASS、終了時警告なし。
- `Godot --headless --path . --script res://tests/exploration_reward_placement.gd --quit-after 1800`：5seed、計35通常/宝箱部屋の到達性・衝突・配置間隔を確認。PASS。全seed保証ではない。
- 既存exploration_reward、exploration_encounter、random_floor_playも回帰PASS。headless終了時のObjectDB/Resource警告は残る。

通常サイズ画像は[制作記録](../art/production/exploration-chest/README.md)。補給量の難度適合・SEの聴感・一周の期待感は手動確認が必要。

## 探索の難度調整

`Godot --headless --path . --script res://tests/exploration_balance.gd --quit-after 600`：予備弾0から20回装填、探索限定の威力、対戦用設定での有限弾、装備再反映、無限弾武器への補給拒否、6戦の補給頻度、拡大した身体の外縁への弾命中を検証する。exploration_treasure_suppliesも新頻度で回帰確認する。

exploration_encounter、fire_pouch_lizard、exploration_enemy_spawns（10seed/108入口）、synergies、shared_combat_hudを回帰確認。難度や狙いやすさの採用判断は手動テストで行う。headless終了時のObjectDB/Resource警告は既知の残課題。

増員時の検証：exploration_enemy_spawnsで初戦3体、面積別の3/4/5/6体とトカゲ比率、配置の再現性、入口260px・敵間160px、半径20pxの壁衝突と帰路を確認。exploration_encounter、fire_pouch_lizard、exploration_balance、enemy_audioも回帰PASS。全方向からの連続戦闘の難度と実機負荷は未確認。

## 棘背ヤマアラシ

`Godot --path . --script res://tests/quillback.gd --quit-after 600 -- --capture`：本編混成、構え中の狙い固定・停止、5方向同時発射、実被弾、硬直、画面外/壁越し/死亡時の中止、生物用撃破表示を確認。`quillback_art.gd`は4方向×8動作の通常倍率比較を.local/quillback-review.pngへ保存する。通常ステージと比較画像は[制作記録](../art/production/quillback/README.md)。

fire_pouch_lizard、exploration_enemy_spawns（10seed/108入口）、audio_assetsを回帰確認。静止比較と自動テストは連続歩行の自然さ・SE試聴・負荷・ユーザー受入の代わりにはしない。

2026-09-23の通常敵ダメージ調整：exploration_encounterで番機1.2、fire_pouch_lizardで火種0.9の実被弾と味方非被弾、quillbackで棘の被弾・キャンセルを確認。既知の終了時ObjectDB警告は残る。

## 生成版3：ボス前室

exploration_floorは100seed・生成引数8〜12（実総数9〜13）の再現性、5役割各1室、前室2接続・ボス南入口のみ、座標重複なし、267形状/開口組合せの到達性を確認。random_floor_playは11室往復と再挑戦を確認。

`Godot --path . --script res://tests/boss_approach.gd --quit-after 600 -- --capture`で前室の安全性・バッグ操作・南到着・往復で無料回復なしを確認。ボス戦は未実装で、このテストはボス戦の受入ではない。

## 炉守りの管理機

`Godot --path . --script res://tests/furnace_warden.gd --quit-after 900 -- --capture`：本編出現、半径44の配置、起動中の攻撃拒否/停止、出口封鎖、大槌の実被弾/側方回避、7発扇射とパルス、排熱の近距離被弾/距離回避、画面外中止、HP半分の移行、踏破時の参照整理、初戦箱なし、撃破表示の寿命、再挑戦と相打ち死亡優先を確認。boss_approachは敵なしの地形往復テスト、通常戦のexploration_encounterはボス分岐を除いて確認する。

描画ありPASS。通常戦・前室・random_floor_playも回帰PASS。既知の終了時ObjectDB/Resource警告は残る。実プレイの戦闘時間・難度・吸引挙動・正式美術・音色と負荷は未確認。

`Godot --path . --script res://tests/boss_pressure.gd --quit-after 180 -- --capture`：遠距離からの突進、大きいdtでの壁貫通防止、24発連射と画面外中止、衝撃波の被弾/ロール回避/同じ輪の重複被弾防止、再使用時間を上回る間隔、3連波、停止と撃破時整理を確認。保存画像は `.local/two-rooms-boss-pressure-waves.png`。手動の難度・音響品質は別途確認する。

`boss_pressure.gd` はストーリー反撃回復の無効化、暴走時の3連続突進→大槌と終了後の隙、42連射と弾速も確認する。`tests/rally_recovery.gd` で対戦の反撃回復を回帰検証する。

独楽の鋳造機の接続確認: furnace_warden.gdの--captureで通常/撃破、boss_pressure.gdの--captureで暴走状態を保存。後者はboss BGM切替/終了、描画時間のポーズ停止、展開完了、粒子上限も検証。静止画成功を全方向連続アニメーションや試聴済みとは扱わない。

boss_pressureは障害物を半径44pxで迂回して接近、空中で輪を出さず着地で発生、最終着地後の復帰、暴走移行途中と完了も検証。--captureでspinner-jump/spinner-openingを保存。

`Godot --headless --path . --script res://tests/boss_activity.gd --quit-after 180`：南壁際2配置で修正前に12秒の無攻撃停止を再現。大型身体が近接距離へ入れない場合、継続被弾中でも2.88秒以内に攻撃へ切り替わることを検証する。

boss_activityは画面端で本体が見える間の斉射継続、完全画面外時の硬直なし追跡復帰、届かなかった突進後の追跡復帰も検証する。boss_pressureの画面外テストは本体全体が隠れる配置を使う。


`Godot --path . --script res://tests/boss_presentation.gd -- --capture`：4方向の弾/閃光原点、反動、暴走/排圧SE、エンジンの停止・ミュート、Actor退役後の爆発SE、ポーズ、報酬出現まで結果パネル/勝利音を出さないこと、再挑戦時の破棄を確認。画像は.local/two-rooms-boss-opening-{角度}.pngとtwo-rooms-boss-destruction.png。headlessでも動作検証可（captureなし）。今回の回帰テストは通過したが、終了時ObjectDB/Resource警告は残る。音の聴感・全方向連続動作・Web負荷は別途受入。

boss_activityは突進残距離0.00001/0.0001/0.1/0.49pxで即時終了し、プレイヤーが近づかなくても次の攻撃を開始することを確認。修正前は0.00001pxのケースで12秒後もdashが継続することを再現。boss_pressureは全周斉射の通常24発/暴走48発、弾速280/330、ダメージ1も確認する。


boss_pressureは通常2連突進と追撃方向の固定、通常時に最終波が出ないこと、暴走3連の最後が跳躍→着地衝撃波1回になることも検証。全周斉射の通常12方向×2回/暴走16方向×3回を確認。boss_activityの微小残距離停止、furnace_wardenの踏破、boss_presentationの演出同期も回帰通過。実プレイ難度と最大弾幕時の端末負荷は未確認。

## 旧鋳造区の環境表現

`Godot --path . --script res://tests/ashen_foundry.gd -- --capture`：共有フィールドの非変更、重複適用、デカールの衝突なしと床専用描画、入口/侵食/鋳造/宝箱の通常サイズを確認。画像は.local/two-rooms-ashen-*.png。exploration_floor（100シード）、exploration_rooms（20往復）、connected_wall_surface、stage_templatesを併用。実プレイの弾幕視認性とWeb負荷は手動確認。

ashen_foundryは追加素材8種の配置と固定部屋の描画（two-rooms-fixed-additions.png）も確認。exploration_floorの到達性キーには配置ID/位置/衝突を含め、同じ部屋形状でも家具配置が違えば検証を省略しない。

ashen_foundryは半透明の余白を除いた家具参照領域、根の端、接地影の不正矩形、ボス設備跡の床内配置も検証する。

## ボス全周砲撃・主砲

`Godot --headless --path . --script res://tests/boss_cannon.gd --quit-after 600`：主砲の追従→最後0.25秒固定、暴走2連と再照準、直撃/爆風1回、回避後の再被弾なし、明示消去時の爆発なし、寿命爆発、演出ポーズ/破棄、斉射の角度ずらしを検証。描画版はheadlessを外し `-- --capture` を付ける。`.local/two-rooms-boss-cannon-{fire,impact,salvo}.png` に保存。boss_pressure/boss_activity/boss_presentation/furnace_warden/exploration_encounter/audio_assetsを回帰確認する。通常倍率の静止画と自動検証は、音量・難度・全方向の連続動作の手動受入とは区別する。

`Godot --headless --path . --script res://tests/boss_attack_selection.gd --quit-after 600`：通常/暴走で全5種類の攻撃枠へ到達、直前の技を連続選択しない、近接の射程間隙・壁際で射撃へ進む、射程外でカーソルを消費しない、機銃40/70発・追従・爆風なし、ポーズ・画面外中止・再挑戦初期化を検証。boss_activity/boss_pressure/boss_cannon/furnace_wardenを併用する。

boss_cannonは主砲速度900・判定半径14、直接接触と壁衝突、二重被弾防止も確認。描画版の追加画像は `.local/two-rooms-boss-cannon-flight.png`。boss_presentationは主砲反動1.8を確認する。

## ボス開始・撃破報酬

`Godot --headless --path . --script res://tests/boss_rewards.gd --quit-after 600`：初回2.4秒/再挑戦0.8秒・スキップ・BGM開始・入力遮断、ポーズで起動/報酬時計停止、撃破後4.6秒の箱・出現と着地音1回、出口の保留、単品飛び出し中の取得禁止、控え満杯・非アクティブ中の受取不可、二重取得なし、ライフアンプ装備時のみ最大HP+1（回復なし）、開封後は未取得でも出口解除、出口で踏破、再挑戦初期化、相打ち死亡優先を確認。

描画版はheadlessを外し `-- --capture`。`.local/two-rooms-boss-startup.png` と `two-rooms-boss-reward-{chest,opening,open,options}.png` を保存。通常倍率の複数状態を確認したが、実プレイの演出テンポ・音量・Web負荷は手動受入。boss_presentation/furnace_warden/boss_pressure/exploration_treasure_supplies/exploration_encounterの回帰も行う。

## 崩落した作業室の試作

`scenes/game/collapsed_workshop_preview.tscn` を開きF6で敵なし試遊。CLIは `Godot --path . res://scenes/game/collapsed_workshop_preview.tscn`。通常探索シーンへ `-- --stage-collapse` を渡しても起動できる。

`Godot --headless --path . --script tests/collapsed_workshop.gd --quit-after 600`：部屋・相互扉・到達性・柱/崩落の衝突・射線・往復後の配置数。実画面はheadlessを外して `-- --capture` を付け、`.local/two-rooms-collapsed-workshop.png` と同 `-behind-pillar.png` を保存する。美術の確認と残課題は[制作記録](../art/production/collapsed-workshop/README.md)。

## 瓦礫なしの部屋バリエーション（生成版4）

`Godot --headless --path . --script tests/exploration_floor.gd` で100seedの抽選/接続/再現性を検査。
`Godot --headless --path . --script tests/workshop_variants.gd` で14形状×15開口、巡回室、敵の配置余白と遷移を検査。
描画確認は `Godot --path . --script tests/workshop_variants.gd -- --capture`。`.local/two-rooms-variant-<shape>.png` が通常倍率、`two-rooms-overview-<shape>.png` は確認用縮小画像。後者の倍率は本編へ適用されない。
手動確認は `scenes/game/workshop_variants_preview.tscn` をF6再生し、左右の扉でFを押して巡回する。敵なし。実戦は通常のランダム探索で確認する。

### 探索ズームと敵弾表示

`tests/exploration_camera.gd` は1.2倍での部屋端・小さい軸の中央固定・追従・停止/復帰・部屋移動、画面と照準の座標往復を確認する。`tests/projectile_personality.gd` は敵弾1.3倍と大型主砲除外、更新後の倍率維持、速度/威力/衝突半径の不変を確認。画面外攻撃の回帰は `tests/fire_pouch_lizard.gd`、主砲と全周斉射は `tests/boss_cannon.gd`。通常のheadless実行でPASS。既知の証明書ストア、終了時ObjectDB/使用中Resource警告は残る。静止画の視認性と長時間の弾幕回避評価は区別する。
