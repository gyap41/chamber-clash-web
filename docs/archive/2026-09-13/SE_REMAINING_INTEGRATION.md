# 追加SEのゲーム接続

50種接続（先行16＋追加34）。新規有料生成0回・追加費用0。計画50種に宝箱出現を追加し、戦闘開始を保留したため接続数は50。戦闘開始と旧Sレア通知・旧危険警告の原音は保持。

残課題：実プレイでの音量・同時発音・音色の試聴。開封アニメーション追加後の同期。入場演出決定後の戦闘開始音。現行主要イベントの素材不足はなし。タイトル／キャラ選択のUI音は別途適用検討（既存UI素材の再利用可）。

Sレア通知は5秒前予告で1回。宝箱はspawn_groupの配置成功時に出現音、取得成功時に開封音と取得音。リナのダイブ終了に着地、ボルト／クロウは重い回避。装填音は既存美術のcharge/runeとmechanicalを参照。壁着弾と跳弾は各80msの連続発音抑制。時間切れ音と結果音は同時発音。戦闘開始のstart要求は無音。

検証：8本のGodot回帰テスト成功。音声品質は未試聴。

|接続素材|用途|
|---|---|
|[fw_pistol_short_01](../../../assets/audio/se/fw_pistol_short_01.mp3)|User-authorized shortened standard pistol candidate after long prompt HTTP 400|
|[fw_heavy_short_01](../../../assets/audio/se/fw_heavy_short_01.mp3)|重い単発：ガードリベット等|
|[fw_rapid_short_01](../../../assets/audio/se/fw_rapid_short_01.mp3)|連射：ミニガトル等、単発反復用|
|[fw_energy_short_01](../../../assets/audio/se/fw_energy_short_01.mp3)|エネルギー：アークレール等|
|[fw_hit_short_01](../../../assets/audio/se/fw_hit_short_01.mp3)|被弾|
|[fw_dodge_short_01](../../../assets/audio/se/fw_dodge_short_01.mp3)|軽い回避|
|[fw_reload_short_01](../../../assets/audio/se/fw_reload_short_01.mp3)|機械式リロード|
|[fw_pulse_short_01](../../../assets/audio/se/fw_pulse_short_01.mp3)|パルス：敵弾消去|
|[fw_ui_select_short_01](../../../assets/audio/se/fw_ui_select_short_01.mp3)|選択クリック|
|[fw_ui_confirm_short_01](../../../assets/audio/se/fw_ui_confirm_short_01.mp3)|決定|
|[fw_ui_cancel_short_01](../../../assets/audio/se/fw_ui_cancel_short_01.mp3)|取消|
|[fw_ui_place_short_01](../../../assets/audio/se/fw_ui_place_short_01.mp3)|装備配置|
|[fw_ui_purchase_short_01](../../../assets/audio/se/fw_ui_purchase_short_01.mp3)|購入成功|
|[fw_ui_blocked_short_01](../../../assets/audio/se/fw_ui_blocked_short_01.mp3)|操作不可|
|[fw_victory_short_01](../../../assets/audio/se/fw_victory_short_01.mp3)|勝利|
|[fw_defeat_short_01](../../../assets/audio/se/fw_defeat_short_01.mp3)|敗北|
|[fw_shotgun_01](../../../assets/audio/se/fw_shotgun_01.mp3)|散弾：4/31|
|[fw_needle_01](../../../assets/audio/se/fw_needle_01.mp3)|針・精密弾：21/24/29/30|
|[fw_metal_shot_01](../../../assets/audio/se/fw_metal_shot_01.mp3)|金属反射弾：1/22/32|
|[fw_launcher_01](../../../assets/audio/se/fw_launcher_01.mp3)|推進・大型投射：2/9/12/34|
|[fw_return_blade_01](../../../assets/audio/se/fw_return_blade_01.mp3)|帰還刃：5/33|
|[fw_seed_launch_01](../../../assets/audio/se/fw_seed_launch_01.mp3)|種・展開弾：11/14/35|
|[fw_pressure_ball_01](../../../assets/audio/se/fw_pressure_ball_01.mp3)|圧力球：13|
|[fw_sheet_launch_01](../../../assets/audio/se/fw_sheet_launch_01.mp3)|薄片・荷札弾：16/17|
|[fw_tool_switch_shot_01](../../../assets/audio/se/fw_tool_switch_shot_01.mp3)|切替工作機構：18|
|[fw_ancient_shot_01](../../../assets/audio/se/fw_ancient_shot_01.mp3)|古代動力・星弾：8/10/15/25/37|
|[fw_wall_impact_01](../../../assets/audio/se/fw_wall_impact_01.mp3)|壁着弾|
|[fw_ricochet_01](../../../assets/audio/se/fw_ricochet_01.mp3)|跳弾|
|[fw_explosion_01](../../../assets/audio/se/fw_explosion_01.mp3)|爆発|
|[fw_melee_swing_01](../../../assets/audio/se/fw_melee_swing_01.mp3)|近接の振り|
|[fw_melee_clear_01](../../../assets/audio/se/fw_melee_clear_01.mp3)|近接で弾消し|
|[fw_heavy_dodge_01](../../../assets/audio/se/fw_heavy_dodge_01.mp3)|重い回避|
|[fw_landing_01](../../../assets/audio/se/fw_landing_01.mp3)|着地|
|[fw_power_reload_01](../../../assets/audio/se/fw_power_reload_01.mp3)|動力式装填|
|[fw_weapon_switch_01](../../../assets/audio/se/fw_weapon_switch_01.mp3)|武器切替|
|[fw_defense_01](../../../assets/audio/se/fw_defense_01.mp3)|防御|
|[fw_heal_01](../../../assets/audio/se/fw_heal_01.mp3)|回復|
|[fw_gravity_01](../../../assets/audio/se/fw_gravity_01.mp3)|重力場発生|
|[fw_ui_remove_01](../../../assets/audio/se/fw_ui_remove_01.mp3)|装備解除|
|[fw_ui_sell_01](../../../assets/audio/se/fw_ui_sell_01.mp3)|売却|
|[fw_ui_expand_01](../../../assets/audio/se/fw_ui_expand_01.mp3)|バッグ拡張確定|
|[fw_chest_open_01](../../../assets/audio/se/fw_chest_open_01.mp3)|宝箱開封|
|[fw_ammo_pickup_01](../../../assets/audio/se/fw_ammo_pickup_01.mp3)|弾薬取得|
|[fw_item_pickup_01](../../../assets/audio/se/fw_item_pickup_01.mp3)|武器／レリック取得|
|[fw_rare_pickup_01](../../../assets/audio/se/fw_rare_pickup_01.mp3)|レア取得|
|[fw_time_up_01](../../../assets/audio/se/fw_time_up_01.mp3)|時間切れ|
|[fw_draw_01](../../../assets/audio/se/fw_draw_01.mp3)|引き分け|
|[fw_chest_spawn_01](../../../assets/audio/se/fw_chest_spawn_01.mp3)|宝箱出現|
|[fw_rare_drop_02](../../../assets/audio/se/fw_rare_drop_02.mp3)|Sレア投下通知・特別感|
|[fw_danger_warning_02](../../../assets/audio/se/fw_danger_warning_02.mp3)|危険地帯警告・長い警告音|
