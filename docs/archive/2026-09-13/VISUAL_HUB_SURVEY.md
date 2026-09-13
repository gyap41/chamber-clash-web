# Chamber Clash Visual Hub 設計調査

調査日: 2026-09-13。対象: C:/GameCreate/chamber-clash。

**結論:** このゲームのVisual Hubは、素材ブラウザーと、データ・コード駆動の描画を再現するプレビューの二層が適する。実コンテンツの中心は8キャラ、38武器、35レリック、2フィールド。Sceneだけの列挙では、方向別パーツ、動的な壁配置、弾道・残光、UI、合成SEを把握できない。

調査は読み取りと本レポートの新規作成のみ。既存ファイルの編集・移動・削除、実装、素材生成、Godot起動、テスト実行、音声試聴は行っていない。既存の戦闘・準備画面PNGを目視したが、現在の実行結果とは扱わない。過去のテスト合格記録も今回の検証結果とは区別する。

集計は通常のrg列挙対象（隠しファイル含む、Git除外・.git・.godot・認証ファイルを除く）を基準とする。ファイル数と論理コンテンツ数は別であり、表の各カテゴリは重複する。Git除外されたローカル出力は別途ディレクトリ・拡張子のみ集計した。全画像の品質評価、類似画像判定、実行時全分岐の到達性証明は対象外。

## 1. 現在のプロジェクト構成

|場所|役割|
|---|---|
|project.godot|4.7 / GL Compatibility指定。入口title.tscn。論理1120×800、ウィンドウ上書き1120×600、canvas_items伸縮。日本語フォント指定あり|
|scenes/|ゲーム16 Scene。game、combat、world、visuals、ui|
|scripts/|戦闘、AI、カタログ、フィールド配置、描画、UI、音声。多くの表示はGDScriptが生成|
|data/|catalog.json、weapon_visuals.json、fields/*.tres|
|assets/first-workshop/|現行キャラ、装備、弾、VFX、床、小物、行動アイコン|
|assets/characters・weapons・effects/|旧シート。fightersは現在も参照されるが、武器・VFXシートは通常表示から置換済み|
|assets/ui/hud/|skin.json、旧SVG、fallback SVG|
|assets/audio・fonts/|未接続音声サンプル2件、日本語フォント1件|
|assets/generated/|生成原画72 PNGと記録。.gdignore対象|
|docs/art/settings・production・reviews/|設定・制作指示・加工比較・ゲーム撮影。docs全体が.gdignore対象|
|docs/archive/|旧素材、過去計画・検証記録。本レポートも調査時点の記録として配置|
|tests・tools/|テスト専用Scene/画像、キャプチャ、加工・検証CLI|
|legacy-web/|移植元Web実装と画像7件。.gdignore対象|
|.local・web-build/|ローカル検証・フレーム・配布物。現行原本から分離して扱う|

## 2–3. 存在するカテゴリと素材数

|カテゴリ|確認数・意味|
|---|---|
|Scene|ゲーム16 + テストfixture 1 = 17 .tscn|
|Resource|.tres 2、どちらもFieldDefinition。独立したAnimation/Material/TileSet .tresは0|
|Character|8論理キャラ、共通Player Scene 1|
|Enemy / NPC|専用定義・専用Scene 0。敵役は同じ8キャラをCPU操作。ボス・会話NPCなし|
|Weapon|38種、武器本体38 PNG（guns/37 + pistol.png 1）|
|Equipment / Relics|35種、35 PNG。独立した防具カテゴリなし|
|Items / Props|武器・レリック取得、弾薬、宝箱。バッグ拡張3形状、改造は4武器×2分岐=8定義|
|Skill / Action|独立Skillカタログ0。回避・近接・パルスの3共通行動を表示対象にできる|
|Stage|duel・validationの2定義と2 Scene|
|Background / Environment|現行床1画像、遮蔽物1画像。独立した背景Scene・背景レイヤー定義なし|
|TileMap / TileSet|現行Scene・スクリプト・Resourceで0|
|Character画像|168 PNG = リナ21 + 他7人×21。立ち姿24、固定体・靴72、回避72|
|Projectile|38武器プロファイル。基本弾画像38（番号画像37 + bullet.png）、派生画像6|
|Projectileフォルダ|60 PNG = 基本弾37 + 派生6 + muzzle8 + impact8 + gravity_core1|
|VFXレジストリ|8系統、16画像効果定義。その他コードVFXあり|
|Shader|.gdshader 2。Materialは実行時生成|
|Particle|重力場にCPUParticles2Dを2エミッター生成。汎用burstは配列と_drawによる粒子|
|UI|独立画面/層4 Scene + 動的UI部品群。専用結果Sceneなし|
|Icon|現行レリック35 + 行動3 + fallback1。武器38画像もUIで共用。旧SVG39（レリック35、行動3、fallback1）|
|Font|ipag.ttf 1|
|Audioファイル|BGM WAV 1、SE MP3 1、Ambient 0。現在のSEはコード合成|
|ゲームデータ|data/にJSON2。HUD skin JSON1。他に加工manifest等。列挙対象全体のJSON133、CSV/TSV0|
|画像全体|PNG1310、SVG39、GIF27。assets配下PNG388。設定・履歴・重複も含む|
|資料画像|docs/art: PNG282+GIF20、docs/archive: PNG625+GIF7。すべてがゲームスクリーンショットではない|
|Script|列挙対象全体169 .gd（ゲーム・テスト・撮影ツールを含む）|

Git除外領域は上記から分離する。assets/referenceにparty.png・portraits.pngの2画像と.gdignoreを確認。.localにはPNG1529、.tscn108、.gd373等があり、検証コピーやフレームが大量に混在するため現行素材数へ足さない。web-buildにはPNG3とpck/wasm等、Claude outputsにはHTML3。feature_profiles、script_templates、text_editor_themesはファイルなし。

## 4. Character / Enemy一覧

全員がscenes/combat/player.tscnを使用する。Enemy種族や敵専用アニメが別途あるわけではなく、Rosterのチームとcontrollerで敵味方・CPUを決める。通常選択ではP1以外の7人からCPUキャラを選ぶ。

|ID|名前|役割|初期武器ID・名前|
|---|---|---|---|

|0|リナ|ガンナー|20 サービスピストル|

|1|ソラ|スカウト|21 スカウトニードル|

|2|コハク|トリックスター|22 トリックコイン|

|3|ボルト|ガードロボット|23 ガードリベット|

|4|メイ|メカニック|24 ツインタッカー|

|5|ルナ|アルカニスト|25 ルーンペン|

|6|ラトル|ガンスリンガー|26 シックスノート|

|7|クロウ|ヘビーガンナー|27 ミニガトル|

キャラID0はrina-directions/とrina-dodge/、ID1–7はdirectional-characters/<番号-名前>/。全員のfront/back/side、body、foot-0/1、回避3段階の期待パスを展開して存在確認し、欠落0。左はside反転。選択画像はfront画像のRect2(8,8,240,240)。キャラごとの通常等身・設定画はdocs/art/settingsに別保存。

## 5. Weapon / Item一覧

以下の画像・VFX系統はweapon_visuals.jsonを基準とする。通常は本体equipment/guns/ID.png、弾projectiles/ID.png（2桁）。ID20のみ本体pistol.png・弾bullet.png。ID20–27は初期専用、通常抽選対象は残り30。SEは武器画像の設定からではなくsound.gdが武器性能フラグから合成する。

|ID|武器|VFX系統|残光|
|---|---|---|---|

|0|P-12 サイドアーム|ballistic|short|

|1|跳弾キャンディ|metal|dots|

|2|ファイアワークス|explosion|embers|

|3|ハニービー|energy|short|

|4|ダブルバック|ballistic|short|

|5|ムーンリーパー|arcane|arc|

|6|アークレール|energy|rail|

|7|ヘリックス|energy|helix|

|8|プリズムバースト|arcane|prism|

|9|コメットランチャー|explosion|smoke|

|10|ブラックホール・ティー|arcane|orbit|

|11|シードマイン|organic|leaves|

|12|ロケットペンシル|explosion|embers|

|13|バブルクロック|water|bubble|

|14|クローバースプリッター|organic|leaves|

|15|プラネタリウム|arcane|stars|

|16|レシートリピーター|paper|paper|

|17|着払いキャノン|paper|paper|

|18|スイッチスパナ|metal|short|

|19|エコードラム|ballistic|echo|

|20|サービスピストル|ballistic|short|

|21|スカウトニードル|metal|needle|

|22|トリックコイン|metal|dots|

|23|ガードリベット|metal|short|

|24|ツインタッカー|metal|short|

|25|ルーンペン|arcane|rune|

|26|シックスノート|ballistic|short|

|27|ミニガトル|ballistic|short|

|28|ホチキスバースト|metal|short|

|29|クロスステッチ|metal|thread|

|30|チョークライフル|ballistic|needle|

|31|ペッパーボックス|ballistic|short|

|32|ピンボールパドル|metal|dots|

|33|ツインクレセント|arcane|arc|

|34|スパークフォーク|energy|electric|

|35|ベルフラワー|organic|leaves|

|36|カーボンコピー|energy|rail|

|37|オーロラファン|arcane|aurora|

レリックは全35種にskin.jsonのrelic_00〜relic_34があり、equipment/relics/00.png〜34.pngへ接続。武器とレリックのアイコン欠落は、今回確認した現行定義・パスの範囲では0。

|ID|レリック|安定キー|
|---|---|---|

|0|フェザー|feather|

|1|クイックギア|ribbon|

|2|プリズムレンズ|lens|

|3|ガードベル|bell|

|4|ライフアンプ|heart|

|5|ドッジノヴァ|comet|

|6|ヘビーコア|heavy|

|7|スターターセル|starter|

|8|予備マガジン|holster|

|9|パルスリレー|relay|

|10|パリィダイナモ|dynamo|

|11|リバウンドテープ|rebound|

|12|反響の種|echo_seed|

|13|空薬莢の祝福|empty_casing|

|14|帰還バッテリー|return_battery|

|15|余熱コンデンサ|residual_heat|

|16|残響ホルスター|echo_holster|

|17|すり抜け装填|phase_load|

|18|ミニフェザー|mini_feather|

|19|パワーチップ|power_chip|

|20|ロングバレル|long_barrel|

|21|ワイドマガジン|wide_magazine|

|22|ラストスタンプ|last_stamp|

|23|クールグリップ|cool_grip|

|24|ステップスプリング|step_spring|

|25|セーフティソール|safety_sole|

|26|クイックシース|quick_sheath|

|27|パリィシェル|parry_shell|

|28|応急パッチ|aid_patch|

|29|パルスブーツ|pulse_boots|

|30|チェンジサイト|change_sight|

|31|ラバーチップ|rubber_chip|

|32|整流コイル|rectifier_coil|

|33|帰還リール|return_reel|

|34|サプライキー|supply_key|

その他: ammo.pngを使う弾薬補給、武器/レリック宝箱（Polygon2D/Line2D・実アイコンの合成）、取得待機・開封ProgressBar。バッグ拡張は正方形4セル、L字6セル、長方形6セルの3形状で、専用画像ではなくグリッド描画。武器改造は跳弾キャンディ、ムーンリーパー、シードマイン、バブルクロックに各2分岐。別武器画像の欠落と数えず「基礎画像を共有する派生定義」とする。回復薬・素材資源・防具・NPC商品などの独立カタログは確認していない。

## 6. Stage一覧と詳細

|項目|duel|validation|
|---|---|---|
|Scene|scenes/world/arena.tscn|scenes/world/arena_validation.tscn|
|定義|data/fields/duel.tres|data/fields/validation.tres|
|名前|field_id=duel。専用display_nameなし。画面の「アリーナ・デュエル」はタイトル文言|field_id=validation。検証用。正式ステージ名なし|
|大きさ|1120×600|1440×900|
|背景・床|floor.pngを全域に伸縮し(.83,.86,.86)で着色|floor_colorのPolygon2D。WorkshopArtなし|
|TileMap/TileSet|なし|なし|
|地形|軸平行矩形壁3個|軸平行矩形壁3個|
|壁Rect2(x,y,w,h)|(240,160,80,85)、(800,355,80,85)、(515,250,90,90)|(350,160,120,220)、(970,355,120,305)、(680,440,80,90)|
|壁外観|wall.tscn → wall.gd → cover.png|同左|
|移動境界|(60,82,1000,458)|(60,82,1320,758)|
|弾境界|(32,37,1056,533)|(32,37,1376,833)|
|Spawn|(170,300)、(950,300)|(170,300)、(1270,300)、(1270,600)、(1270,780)|
|Scene内Actor|P1・P2|P1〜P4|
|敵の指定|FieldDefinitionには含まれない。Roster・対戦設定が担当|同左。4 Spawnと4 Actorは4種のEnemyを意味しない|
|Props|遮蔽物、動的補給/宝箱/弾薬|同左|
|ギミック|危険地帯縮小、補給出現・開封。重力場は武器が生成|同じArena API。Scene単体では試合時間・イベント文脈が不足|
|VFX|DangerZone、CombatVisuals、Effects/Wells/Projectilesの実行時内容|同左|
|Shader|ステージ専用なし。重力レンズ・武器可読性は戦闘オブジェクト側|同左|
|Lighting|Light2D/WorldEnvironmentなし。絵に描かれた陰影とコードの影・加算表現|同左|
|Camera|CombatCamera。mainでfit。zoom=1、基準position=(0,-90)|mainのfit適用時zoom=2/3、position=(-120,-135)|
|BGM / Ambient|接続なし / なし|接続なし / なし|

補給候補は両定義で同じ5グループ×2点。InitialWeapons=(560,125),(560,475)、Weapons/Legendary=(560,205),(560,395)、Ammo=(450,300),(670,300)、Relics=(460,220),(660,380)。種類ごとに表示を切り替え、同位置にある異種マーカーを重なりとして扱う。

FieldBuilderがResourceをduplicate(true)し、床・壁・Marker2Dを生成する。Sceneテキストに壁や出現座標がないことは欠落ではない。floor.pngの石板や溝をTileSet・個別Propと誤認しない。WorkshopArtはfield_id==duelでのみ描画するため、別FieldDefinitionをarena.tscnへ渡す場合にも外観が条件依存。

Hubでは俯瞰、実戦カメラ、移動/弾境界、壁判定、Spawn、補給種別、危険地帯の時間スライダーを提供すると有効。フィールドの形状とActor編成は別軸で選択する。

## 7. Animation一覧と仕組み

現行コード・Scene・ResourceにはSpriteFrames、AnimatedSprite2D、AnimationPlayer、AnimationTree、Animation.newの利用を確認できない。player.tscnの「Animation」はNode2D + player_animation.gdであり、AnimationPlayerではない。

|キャラ|Idle|Walk/Move|Run|Attack|Skill|Damage|Death|その他|
|---|---|---|---|---|---|---|---|---|
|リナ|固定パーツ呼吸|体重移動+交互の靴|独立なし|共通反動・武器動作|専用回避3段階、近接/パルス共通|無敵点滅等の共通表現|専用なし|0.38秒の飛び込み|
|ソラ|同上|同上|同上|同上|回避3段階・低い飛び込み|同上|同上|回避0.26秒|
|コハク|同上|同上|同上|同上|尾を伴う跳び込み|同上|同上|回避0.26秒|
|ボルト|同上|同上|同上|同上|脚を畳む滑走|同上|同上|回避0.26秒|
|メイ|同上|同上|同上|同上|手を伸ばす滑り込み|同上|同上|回避0.26秒|
|ルナ|同上|同上|同上|同上|浮遊ステップ|同上|同上|回避0.26秒|
|ラトル|同上|同上|同上|同上|低く身を投げ出す回避|同上|同上|回避0.26秒|
|クロウ|同上|同上|同上|同上|肩・嘴から飛び込む回避|同上|同上|回避0.26秒|

キャラ別の回避姿勢説明は既存レビュー資料による。専用Skill発動ポーズ、射撃用の全身コマ、独立した被弾・死亡クリップは8人ともない。これは表現追加の候補であり、現在の仕様に対する参照エラーではない。CPUも同じ表を使用。

- player_animationの状態名はidle/move/roll。idle4・move6・roll6のanimation_frameは論理値で、同数の画像があることを意味しない。
- 実描画はcharacter_rig → rina_directions / character_directions → _draw。front/back/sideの3原画方向、左右反転で4方向。照準と移動を別に持ち、後退時は位相反転。方向選択にはヒステリシス。
- 回避画像は3方向×3段階×8人=72。リナは0.04/0.22/0.12秒、他7人は進捗15%・72%で切替。回避時に武器を非表示。
- 射撃は反動とmuzzle、近接はSlash線、パルスは別Scene。リロードはmechanical/charge/runeの3様式、開始・完了・中断に同期する。
- 被弾はburst・shake・SE、無敵は点滅。HPゼロ用クリップ/死体Spriteはない。
- VFX着弾は4コマ横シートを時間で切り出す。ProjectileはSprite2Dの回転・伸縮・軌跡をコード更新。
- docsの既存motion.gifは比較用の遅い再生を含む。ゲーム速度とラベルを分ける。

## 8. VFX一覧

|表現|実装・依存|
|---|---|
|発射8種|muzzle_{ballistic,metal,energy,explosion,arcane,organic,paper,water}。各1コマ、0.075秒|
|着弾8種|impact_同8系統。各4コマ、通常0.22秒、explosion0.32秒|
|跳弾・分裂・装填完了|同系統impactを共用。bounce/reload_completeは基本倍率0.55、splitは2。武器別倍率も合成|
|派生弾|parcel、paper_shard、firework_shard、comet_shard、clover_shard、derived|
|軌跡|short/dots/embers/arc/rail/helix/prism/smoke/orbit/leaves/bubble/stars/paper/echo/needle/rune/thread/electric/aurora。画像のコマではなく描画方式|
|汎用burst|乱数の速度・寿命・色を持つ配列を線で描画。上限650|
|ring|拡大する円弧、寿命0.45秒|
|回避|trail.pngの残像と汎用burst|
|近接|player/Slash Line2D|
|パルス|pulse_effect.tscn、拡大Line2D、0.45秒|
|危険地帯|矩形帯、破線境界、Label|
|重力場|gravity_well.tscn、範囲リング、5本の渦・32粒のコード描画、core画像、脈動|
|重力の追加表現|gravity_legendary.gd: Infall96+Mist28のCPUParticles2D、GradientTexture2D、加算Material、BackBufferCopy、gravity_lens Shader|
|ガード・レリック|ガードベル円弧、装備レリック色の周回星、発動による派生弾・リング|
|カメラ揺れ|CombatVisualsのshake_offsetをCombatCameraへ適用|

weapon_effect_instance.gdはカスタムSceneのconfigure/advance契約。現在のeffects16件は画像登録であり、カスタムSceneの実登録はない。tests/fixtures/weapon_effect_probe.tscnはテスト専用。

## 9. UI素材一覧

タイトル、キャラ選択、準備、HUDの4 Scene。結果・一時停止・レリック一覧はHUD内の状態、ショップは準備画面内。Sceneで見えるノードだけでなく実行時生成のカード・トレイ・グリッドを収集する。

scripts/uiの表示部品: hp_bar、hud_action、hud_relic_icon、relic_card、relic_chip、relic_grid_cell、relic_tray、item_footprint。主画面制御はtitle、character_select、preparation、hud。hud_assetsはskin読み込み。独立Theme .tresなし、色・サイズ・StyleBox等は各スクリプト/Sceneに分散。

確認すべき状態: 空装備/満杯、商品売切/資金不足/更新済み、拡張の有効/無効配置、ドラッグ中、武器切替、リロード、弾切れ、パルス0、レリック重複/スクロール、CPU、簡易多人数表示、停止、勝敗/引分、試合終了。character_select.tscnにはローカル2人ボタンが残るが、現行コードはModeRowを隠してCPUモード固定。静的ノード一覧をそのまま現行画面としない。

ipag.ttfはproject.godotのtheme/custom_fontで現在使用される。assets/READMEの「適用時に確認」「現行シーンから直接参照なし」という記述だけから未使用と判断すると誤る。glyph文字の実際の表示・フォールバックも実行時確認対象。

## 10. Audio一覧

|対象|形式・長さ|接続状態|
|---|---|---|
|sample_battle_02.wav|BGM、manifest上20秒|サンプル、ゲーム未接続、配布除外|
|test_ui_click.mp3|SE、manifest上約0.522秒|接続テスト用、ゲーム未接続、配布除外|
|Ambient|0|未実装|
|sound.gd|44.1kHz/16bit/monoのAudioStreamWAVをメモリ合成|Game/Soundから実行時再生|

合成音の呼出カテゴリはshot、boom、gravity、hit、bell、reload、dodge、slash、equip、pickup、legendary、toggleを確認。start/win/loseは音色定義があるがゲームイベント接続を確認できない。音色プロファイル数と武器数は一致しない。同じプロファイルはキャッシュされ、shotはrail/gravity/prism、comet/SHOTGUN等で音色が分かれる。

16個のAudioStreamPlayerを巡回。ノイズ入りは動的ChamberSFX_<instance_id>バスとCompressor、その他はMaster。enabled初期値false。AudioStreamPlayer2D/3DやBGMプレイヤーはない。両音声のloop/loop_verifiedはfalse。今回は試聴していないので音質・ループ品質は未評価。

## 11. Scene・素材間の主な依存関係

```text
project.godot → title.tscn → character_select.tscn → game/main.tscn
main.tscn → arena.tscn + hud.tscn + preparation.tscn + sound.gd
arena(.validation).tscn → FieldDefinition .tres → field_builder.gd
  → Floor / wall.tscn×3 / Spawn・Supply Marker
  → player.tscn×2（validationは×4）/ supplies / danger_zone / combat_visuals / Camera
supplies.gd → pickup.tscn → 武器本体 / レリックskin / ammo画像
player → player_animation → character_rig → リナ専用loader / 他7人loader
player・UI・pickup → WeaponCatalog.art → WeaponVisualCatalog → body.texture
main / CombatSession → projectile / pulse_effect / gravity_well
combat_events → main._present_event → CombatVisuals・Sound・Pulse
projectile → ProjectileArt → weapon_visuals / variants / Trail / readability Shader
GravityWell → GravityLegendary → CPUParticles / Gradient / lens Shader
HUD・Preparation → hud_assets → skin.json → レリック・行動PNG
```

具体例:

- リナ(ID0) → Player → リナ固定パーツ/回避 → 初期武器20 → pistol.png + bullet.png → ballistic muzzle/impact → shot合成音。
- ブラックホール・ティー(ID10) → guns/10.png + projectiles/10.png → arcane muzzle/impact、orbit残光 → gravity_well → gravity_core・粒子・gravity_lens → gravity合成音。
- オーロラファン(ID37) → guns/37.png + projectiles/37.png → arcane効果、7色palette、aurora残光、equipment_readabilityの虹色 → shot合成音。
- パルス → pulse_effect.tscn + boom音。パルスリレー装備時は派生弾を追加。
- ドッジノヴァ → 回避開始イベント → 6方向弾。画像の対応はCombatSessionの派生指定とVisualCatalogのvariantを追う。レリック名と画像名だけでは関連を解決できない。

## 12. 未使用・重複・不足素材

**参照切れ:** scripts/scenes/data/project.godot/skin.jsonのリテラルres://パスを静的検査し、存在しないパスは0。動的キャラパスも期待値展開で欠落0。ただしファイル実在とGodot ResourceLoaderの読み込み成功は別。全動的実行分岐・UID・インポートキャッシュの整合性は未検証。

**通常ゲームで未使用と思われるもの:** assets/weaponsの2旧シート、assets/effectsの2旧シート、first-workshop/muzzle.png・impact.png。通常ソースから参照がなく、export_presets.cfgも除外する。旧レリックSVG35と旧行動SVG3は現行skinがPNGへ向く。fallback placeholder.svgは現在も必要であり旧素材と一括扱いしない。

**意図的な別用途:** assets/generated原画、assets/referenceの2画像、docsの比較/旧案、legacy-webの画像、tests/fixtures/art/legacy-rina-twohead/rina.pngとtwohead_rina.gd。後者はtests/workshop_visuals.gdが使う。「ゲームで使わない」と「どこからも使わない」は異なる。

**残存参照:** fighters.pngはplayer.tscnとCharacterCatalogがpreloadする。現在のPlayerはsource Spriteを隠してパーツ描画するが、_drawのsource.texture条件にも関係するため未使用断定不可。

**完全一致重複:** 列挙対象のPNG/SVG/GIFをSHA-256比較して52グループ114ファイル（グループ内の余分なコピー数62）。これは類似画像検査ではない。移植元5シートとassetsの一致、設定画/確認画像の一致、旧アニメでの同一コマ等を含む。保存意図があるため削除候補数ではない。Git除外のreference・.local等はこの集計に含めない。

**不足・仮表現:** 全8人の独立Death/被弾/Skill全身クリップ、専用Run、NPC/Enemy独立定義、ステージ表示名・背景/BGM/Ambientメタデータがない。宝箱は幾何描画とアイコン合成、バッグ拡張も形状描画。どれも即不具合ではなく「未定義」「コード描画」「意図した共有」を区別する。武器38・レリック35の本体/アイコン参照は存在する。

## 13. 命名・フォルダ管理上の問題

- first-workshop直下に床・武器・弾・アイコンが混在。他のassets/カテゴリは旧シート中心で、ディレクトリ名だけのカテゴリ推定が不正確。
- リナだけ2ディレクトリ、他7人は1ディレクトリ。回避命名もside-0とside-dodge-0で異なる。ID20の武器・弾だけ別パス。
- 数字だけのguns/04.png、relics/04.png、projectiles/04.pngは意味が異なる。型付きIDが必要。
- catalogのart_id/cellは種類IDとは別。現行本体画像はweapon_visuals.jsonが原本で、旧art_idを画像解決に用いると誤る。
- JSON manifestは音声、生成記録、方向別パーツ、切り出し、初期制作履歴で構造が異なる。汎用「manifest=全素材一覧」を仮定しない。
- assets/READMEに旧武器20種・旧VFXシート等の記述が残る。ROADMAPにも方向別展開前の課題が残る箇所がある。現行実装と新しいレビューで裏付ける。
- Game Screensはdocs/design、settings/concepts、reviews、archive、.localへ分散。生成コンセプトと実ゲーム撮影が同じ拡張子で混在。
- capture系ツールにはres://docs/...への固定保存先があり、再実行すると既存レビュー画像を上書きしうる。今回は実行していない。
- .localの複製プロジェクト・配布物を再帰収集するとScene数や素材数が大幅に水増しされる。

## 14. Visual Hubに表示すべき情報

共通カード: 型付きID、表示名、状態（使用中/補助参照/未接続/テスト/原画/履歴/未確認）、実パス、プレビュー方式、使用元/使用先、参照の根拠（Scene・JSON・動的規則）、画像寸法/透明領域/ハッシュ、生成元・加工履歴、確認日時。

Character: 4方向、通常と回避の足元原点、等倍/拡大、持ち武器、照準・移動方向、速度、動作時間、クリップの有無とコード表現の区別。
Weapon: UIアイコンと装備表示の両方、握り/銃口/倍率/左右反転、弾本体/判定半径、VFX系統/残光/派生、リロード様式、SEプロファイル、改造、初期専用フラグ。
Stage: 定義とScene、寸法、幾何マップ、壁/Spawn/補給、Camera、視覚背景、編成、危険地帯時刻、BGM未接続等を明示。
VFX: 寿命、フレーム、anchor、倍率、背景依存、乱数seed、更新時間、描画上限、必要イベントとActor参照。
UI: 表示状態、解像度、フォント、skinとfallback、スクロール・切詰め・ホバー。
Audio: ファイルか合成か、イベント接続、長さ、loop意図/検証、音量/バス、武器条件。無操作で鳴らさない。
Game Screens: 実撮影/生成案/加工比較、撮影対象ID・状態・seed・コード/素材ハッシュ・速度。古い画像に「最新」を付けない。

## 15. 推奨カテゴリ

|推奨|配置・理由|
|---|---|
|Dashboard|数、未確認、参照問題、直近差分|
|Scenes / Dependencies（追加）|静的Sceneと実行時生成の関係を検索|
|Characters / Enemies / NPC|共有Actorを重複カウントせず役割フィルター。独立Enemy/NPCは現在0表示|
|Weapons / Equipment / Relics|Relicsを明示。Equipmentは横断フィルターでもよい|
|Items / Pickups / Inventory Shapes（追加）|弾薬・宝箱・バッグ拡張・占有形状・改造|
|Skills / Actions|現状は共通行動とレリック発動。独立Skillなしを明示|
|Projectiles|武器プロファイル、派生、判定と外観|
|Stages / Environment / Props / TileSets|現状TileSets0。背景はEnvironmentの子分類|
|Animations / Procedural Motion（拡張）|標準Animation資源がなくても動きを収集|
|VFX / Shaders / Materials|動的粒子・GradientTextureも含む|
|UI / Icons / Fonts（追加）|フォント・文字glyph・UI状態を含む|
|BGM / SE / Ambient Audio|SE内にProcedural Audioを設ける|
|Game Screens|既存撮影資料を版・条件付きで一覧化|
|Source Art / Concepts / Production（追加）|原画・設定・加工履歴を現行素材とリンク|
|Compare|同キャラ/同方向/同背景/同時刻の比較|
|Unused / Missing|参照なし・未接続・fallback・定義不足・テスト利用を別状態に|

## 16. 自動プレビュー生成が可能そうなもの

Godotなし: PNG/SVG/GIF表示、ハッシュ・寸法・透明域、設定画/スクリーンショット一覧、JSONカード、占有セル図、FieldDefinitionの矩形マップ、WAV/MP3の波形と明示操作での再生。4コマimpactや3段階回避の簡易再生も可能だが、Godotと同一描画の保証はしない。

Godotの専用プレビュー環境を用意すれば自動化しやすい: キャラ×方向×歩行/回避、38武器の左右・銃口、16画像VFX、弾道、重力場、UI各状態、ステージ俯瞰、合成SE。既存capture_all_equipment、capture_direction_rollout、capture_projectile_effects、capture_gravity_legendary等の設定方法を参考にできる。既存ツールの固定出力先をそのまま利用しない。

## 17. Godot実行で確認すべきもの

実際の_draw合成、Sprite2D/AtlasTexture/filter/拡縮、武器の重なりと銃口、移動と照準の方向境界、回避の足元、停止/再開、派生弾とレリック効果、UIの文字・ドラッグ・レイアウト、Resource import、CameraとHUD座標、合成音ミックス。

特にgravity_lensは画面背景を読むため単体PNGでは完成形を確認できない。CPUParticlesの時間進行や加算、虹色Shaderも実レンダラーで確認する。エディターを人手で開くことが必須という意味ではなく、描画可能なGodotプロセスと適切なシーン文脈が必要。通常のheadless検証だけで見た目の確認済みとはしない。

## 18. 技術的な注意点

1. ファイル・論理コンテンツ・派生プロファイル・表示状態を別エンティティにする。weapon:20とrelic:20は別ID、配列添字・art_idも区別。
2. res://参照、preload/load、JSON、動的パステンプレート、コード生成を別種の依存エッジにする。静的未参照だけで未使用確定しない。
3. .gdignore/Git除外/配布excludeを別々に保持。docs等はOS経由では読めてもGodot Resourceとして同じように読めない。原画や履歴は通常一覧からフィルターで分離。
4. FieldDefinitionを読み、寸法と壁・Spawnを取得する。Sceneのノードだけでは配置を再現できない。Resource共有・キャッシュはプレビュー間で状態汚染させない。
5. Playerはstate、武器、Scene子ノードに依存する。単に画像やNodeを作るだけでは再現できない。プレビュー用の初期化・状態セットを設ける。
6. CombatVisuals.step、Animation.advance/refresh、Pulse.step、Gravity.advance等の時間を一元制御。停止中に独立TimerやShader TIMEが進む方式へ置き換えない。撮影のseed/時刻/ステップ/解像度を記録する。
7. CPU粒子は固定seedとrequest_particles_processを使用。通常の演出乱数はrandomizeするため再現撮影時の統制が必要。
8. 重力レンズには背景・BackBufferCopyと順序が必要。Shader/Material・Gradientは保存ファイルがなくても検出対象。
9. 主戦闘とプレビューを分離し、AI・補給乱数・run_log・AudioServerバスの副作用を制御する。sound終了時のバス解放も必要。
10. fallbackが欠落を隠す。解決要求パス・実際の採用パス・fallback理由を記録する。ファイル有無、import成功、描画成功は別の検査結果。
11. サムネイルのキャッシュキーに依存ファイル/データ/renderer/条件のハッシュを含める。大量原画/.local全件の一括読み込みは避ける。
12. 今回の4.7設定・既存API呼出を前提に、実装時は実行Godot版とCompatibility/Web双方を検証する。本調査では外部API仕様の変更・検証はしていない。
13. 参照元資料を基に原画→加工→現行→撮影の系譜を保持。著作者・利用条件が不明なら不明のまま表示し、生成記録の認証情報等は取り込まない。
14. 現在の画像だけでなく背景込み/等倍のCompareを用意する。視覚サイズと当たり判定半径、レビューGIF速度と実ゲーム速度は明確に分ける。

## Chamber Clash Visual Hub v1で最初に実装すべき機能

|優先度|機能|完了条件|
|---|---|---|
|P0|読取専用インデックス・検索・状態分類|8キャラ/38武器/35レリック/2フィールドを正確に表示し、原画・履歴・fixtureを分離|
|P0|Character/Weapon/Relic/Stageのカードと依存先|IDから画像・Scene・データへ到達し、動的参照とfallbackを表示|
|P0|キャラの4方向・待機/歩行/回避プレビュー|全8人、実時間と停止/コマ送り、専用回避の違いを比較|
|P0|38武器の装備表示・射撃/弾/着弾比較|同キャラ・同背景・左右、銃口/握り/判定のオーバーレイ|
|P0|Stage俯瞰|2定義の壁・Spawn・補給・境界を正しく重ね、検証Sceneと通常Sceneを区別|
|P0|Unused / Missingと根拠|存在検査、完全一致重複、未接続/テスト使用/fallbackを区別。削除操作なし|
|P1|VFX/Shader/Material実行プレビュー|8系統、残光、派生、パルス、危険地帯、背景付き重力場、時刻・seed制御|
|P1|UI状態ギャラリー|準備・HUD・結果・停止・空/満杯等を固定条件で比較|
|P1|Game Screens・Compare|既存撮影の分類と版情報、同条件比較、キャッシュ更新判定|
|P1|Audioブラウザー|保存2音声と合成SEを分け、明示操作で試聴、イベント接続を表示|
|P1|制作系譜・Fonts|原画/加工/現行のリンク、フォント・glyphプレビュー|
|P2|全組合せ・画像差分/品質支援|武器×キャラ×背景のバッチ、形状/色/透明余白差分、レビュー注記|
|P2|複数Actor・高負荷・Web比較|編成/大量弾/重力同時発生、renderer差・性能の可視化|
|P2|将来カテゴリ拡張|NPC/専用Enemy/TileSet/Ambient追加時のアダプター。現時点で空カテゴリの実装を先行しない|

v1の中心は「現行素材を正しく解決する」「実ゲーム相当の大きさと時間で並べる」「関連と不足の根拠を示す」の3点。編集機能・素材移動・再生成・ゲームのリファクタリングは別の依頼範囲とする。

## 調査根拠・入口

- [project.godot](C:/GameCreate/chamber-clash/project.godot)

- [data/catalog.json](C:/GameCreate/chamber-clash/data/catalog.json)

- [data/weapon_visuals.json](C:/GameCreate/chamber-clash/data/weapon_visuals.json)

- [data/fields/duel.tres](C:/GameCreate/chamber-clash/data/fields/duel.tres)

- [data/fields/validation.tres](C:/GameCreate/chamber-clash/data/fields/validation.tres)

- [scripts/visuals/player_animation.gd](C:/GameCreate/chamber-clash/scripts/visuals/player_animation.gd)

- [scripts/visuals/character_rig.gd](C:/GameCreate/chamber-clash/scripts/visuals/character_rig.gd)

- [scripts/visuals/combat_visuals.gd](C:/GameCreate/chamber-clash/scripts/visuals/combat_visuals.gd)

- [scripts/visuals/gravity_legendary.gd](C:/GameCreate/chamber-clash/scripts/visuals/gravity_legendary.gd)

- [scripts/catalog/weapon_catalog.gd](C:/GameCreate/chamber-clash/scripts/catalog/weapon_catalog.gd)

- [scripts/world/field_builder.gd](C:/GameCreate/chamber-clash/scripts/world/field_builder.gd)

- [scripts/audio/sound.gd](C:/GameCreate/chamber-clash/scripts/audio/sound.gd)

- [assets/audio/asset_manifest.json](C:/GameCreate/chamber-clash/assets/audio/asset_manifest.json)

- [assets/ui/hud/skin.json](C:/GameCreate/chamber-clash/assets/ui/hud/skin.json)

- [export_presets.cfg](C:/GameCreate/chamber-clash/export_presets.cfg)

- [docs/development/ARCHITECTURE.md](C:/GameCreate/chamber-clash/docs/development/ARCHITECTURE.md)

- [docs/design/GAME_RULES.md](C:/GameCreate/chamber-clash/docs/design/GAME_RULES.md)

- [docs/planning/ROADMAP.md](C:/GameCreate/chamber-clash/docs/planning/ROADMAP.md)

- [docs/development/TESTING.md](C:/GameCreate/chamber-clash/docs/development/TESTING.md)

- [docs/art/reviews/character-directions-2026-09-12/README.md](C:/GameCreate/chamber-clash/docs/art/reviews/character-directions-2026-09-12/README.md)

- [docs/art/reviews/aurora-ribbon-2026-09-13/battle-37.png](C:/GameCreate/chamber-clash/docs/art/reviews/aurora-ribbon-2026-09-13/battle-37.png)

- [docs/art/reviews/equipment-diversity-2026-09-13/preparation.png](C:/GameCreate/chamber-clash/docs/art/reviews/equipment-diversity-2026-09-13/preparation.png)

## 付録A: 全Sceneと直接外部依存

以下はScene内ext_resource。スクリプト経由の依存は本文11を参照。

### scenes/combat/gravity_well.tscn

- Script: res://scripts/combat/gravity_well.gd

### scenes/combat/player.tscn

- Script: res://scripts/combat/player.gd

- Texture2D: res://assets/characters/fighters.png

- Script: res://scripts/visuals/player_animation.gd

### scenes/combat/projectile.tscn

- Script: res://scripts/combat/projectile.gd

- Script: res://scripts/visuals/projectile_art.gd

### scenes/combat/pulse_effect.tscn

- Script: res://scripts/combat/pulse_effect.gd

### scenes/game/main.tscn

- Script: res://scripts/game/main.gd

- PackedScene: res://scenes/world/arena.tscn

- PackedScene: res://scenes/ui/hud.tscn

- PackedScene: res://scenes/ui/preparation.tscn

- Script: res://scripts/audio/sound.gd

### scenes/ui/character_select.tscn

- Script: res://scripts/ui/character_select.gd

### scenes/ui/hud.tscn

- Script: res://scripts/ui/hud.gd

- Script: res://scripts/ui/hp_bar.gd

### scenes/ui/preparation.tscn

- Script: res://scripts/ui/preparation.gd

### scenes/ui/title.tscn

- Script: res://scripts/ui/title.gd

### scenes/visuals/combat_visuals.tscn

- Script: res://scripts/visuals/combat_visuals.gd

### scenes/visuals/danger_zone_visual.tscn

- Script: res://scripts/visuals/danger_zone_visual.gd

### scenes/world/arena.tscn

- Script: res://scripts/world/arena.gd

- Resource: res://data/fields/duel.tres

- PackedScene: res://scenes/combat/player.tscn

- PackedScene: res://scenes/world/supplies.tscn

- PackedScene: res://scenes/visuals/danger_zone_visual.tscn

- PackedScene: res://scenes/visuals/combat_visuals.tscn

- Script: res://scripts/visuals/workshop_floor.gd

### scenes/world/arena_validation.tscn

- Script: res://scripts/world/arena.gd

- Resource: res://data/fields/validation.tres

- PackedScene: res://scenes/combat/player.tscn

- PackedScene: res://scenes/world/supplies.tscn

- PackedScene: res://scenes/visuals/danger_zone_visual.tscn

- PackedScene: res://scenes/visuals/combat_visuals.tscn

### scenes/world/pickup.tscn

- Script: res://scripts/world/pickup.gd

### scenes/world/supplies.tscn

- Script: res://scripts/world/supplies.gd

### scenes/world/wall.tscn

- Script: res://scripts/world/wall.gd

### tests/fixtures/weapon_effect_probe.tscn

- Script: res://tests/fixtures/weapon_effect_probe.gd

## 付録B: 完全一致画像グループ

SHA-256によるバイト一致。削除推奨ではない。通常rg対象、.local・reference等は含めない。

### 1 — 0f91dbbfbb6d

- legacy-web/dist/assets/projectile-sprites.png
- assets/effects/projectile-sprites.png

### 2 — 68c207890e94

- legacy-web/dist/assets/fighters.png
- assets/characters/fighters.png

### 3 — 56d8782e2e30

- legacy-web/dist/assets/weapons-extra.png
- assets/weapons/weapons-extra.png

### 4 — 903880d3d7a4

- legacy-web/dist/assets/weapon-effects.png
- assets/effects/weapon-effects.png

### 5 — 5a2fbbd8cc4c

- legacy-web/dist/assets/weapons.png
- assets/weapons/weapons.png

### 6 — 5e2d382de5dd

- docs/art/settings/concepts/rina-two-head-2026-09-12/design.png
- tests/fixtures/art/legacy-rina-twohead/rina.png

### 7 — e9a360b1eda0

- docs/art/settings/concepts/rina-chibi-2026-09-12/01-rina-design.png
- assets/generated/fw-rina-chibi-concept.png

### 8 — 80010d82f03e

- docs/archive/2026-09-12/rina-twohead/idle-up.png
- docs/archive/2026-09-12/rina-twohead/idle-left.png

### 9 — d8a60bfab494

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-23.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-23.png

### 10 — 1b6b424fb720

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-22.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-22.png

### 11 — 764bead45828

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-21.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-21.png

### 12 — 63b72e95827a

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-20.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-20.png

### 13 — 567fb12a6b01

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-19.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-19.png

### 14 — 1823c5c682e7

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-18.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-18.png

### 15 — d410cee36b34

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-17.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-17.png

### 16 — 65f649a32f2a

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-16.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-16.png

### 17 — 730ec05a1642

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-15.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-15.png

### 18 — 328faf165a1c

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-14.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-14.png

### 19 — f3358ad52b4f

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-13.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-13.png

### 20 — 12e58efb7ed4

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-12.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-12.png

### 21 — cfed09d14b2b

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-11.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-11.png

### 22 — 7606ea400552

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-10.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-10.png

### 23 — d68d256db9ab

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-09.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-09.png

### 24 — 988117586a6c

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-08.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-08.png

### 25 — 41918dad24c3

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-07.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-07.png

### 26 — 49d34b8fff7b

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-06.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-06.png

### 27 — cb47fcac9af1

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-05.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-05.png

### 28 — 28518c3506fa

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-04.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-04.png

### 29 — ee674294e761

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-03.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-03.png

### 30 — acf2b12167e6

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-02.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-02.png

### 31 — 37fa6fce4cf9

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-01.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-01.png

### 32 — 4c720a419365

- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/motion-00.png
- docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-directions-2026-09-12/motion-00.png

### 33 — b3c147531264

- docs/archive/2026-09-12/rina-dive/47.png
- docs/archive/2026-09-12/rina-dive/46.png
- docs/archive/2026-09-12/rina-dive/45.png
- docs/archive/2026-09-12/rina-dive/44.png
- docs/archive/2026-09-12/rina-dive/43.png
- docs/archive/2026-09-12/rina-dive/42.png

### 34 — e6ab2ff2e01a

- docs/archive/2026-09-12/rina-chibi/move-down-05.png
- docs/archive/2026-09-12/rina-chibi/move-down-04.png

### 35 — 37f9f38f385a

- docs/archive/2026-09-12/rina-chibi/move-down-03.png
- docs/archive/2026-09-12/rina-chibi/move-down-00.png

### 36 — 87e9d4aa7a91

- docs/archive/2026-09-12/rina-chibi/move-down-02.png
- docs/archive/2026-09-12/rina-chibi/move-down-01.png

### 37 — 9be6798dcecd

- docs/archive/2026-09-12/rina-chibi/idle-up.png
- docs/archive/2026-09-12/rina-chibi/idle-left.png

### 38 — f958a606c26f

- docs/archive/2026-09-12/rina-chibi/move-up-05.png
- docs/archive/2026-09-12/rina-chibi/move-up-04.png
- docs/archive/2026-09-12/rina-chibi/move-left-05.png
- docs/archive/2026-09-12/rina-chibi/move-left-04.png

### 39 — 9760fd563992

- docs/archive/2026-09-12/rina-chibi/move-up-03.png
- docs/archive/2026-09-12/rina-chibi/move-up-00.png
- docs/archive/2026-09-12/rina-chibi/move-left-03.png
- docs/archive/2026-09-12/rina-chibi/move-left-00.png

### 40 — b0d82fd9fd39

- docs/archive/2026-09-12/rina-chibi/move-up-02.png
- docs/archive/2026-09-12/rina-chibi/move-up-01.png
- docs/archive/2026-09-12/rina-chibi/move-left-02.png
- docs/archive/2026-09-12/rina-chibi/move-left-01.png

### 41 — 695d1c1637f8

- docs/archive/2026-09-12/rina-chibi/move-right-05.png
- docs/archive/2026-09-12/rina-chibi/move-right-04.png

### 42 — 1b5350d20da0

- docs/archive/2026-09-12/rina-chibi/move-right-03.png
- docs/archive/2026-09-12/rina-chibi/move-right-00.png

### 43 — 08765c6e54ec

- docs/archive/2026-09-12/rina-chibi/move-right-02.png
- docs/archive/2026-09-12/rina-chibi/move-right-01.png

### 44 — 9f463af58cf2

- docs/archive/2026-09-12/first-workshop/idle-00.png
- docs/archive/2026-09-12/first-workshop/01-environment.png

### 45 — d5327584b313

- docs/art/reviews/rina-dodge-2026-09-12/battle.png
- docs/art/reviews/rina-directions-2026-09-12/battle.png

### 46 — ba45a2088054

- docs/art/settings/character-revision-2026-09-12/07-crow/chibi.png
- docs/art/reviews/character-directions-2026-09-12/07-crow/identity.png

### 47 — b3ed3247abe2

- docs/art/reviews/character-directions-2026-09-12/03-bolt/identity.png
- docs/art/settings/character-revision-2026-09-12/03-bolt/chibi.png

### 48 — 024849e95360

- docs/art/reviews/character-directions-2026-09-12/06-rattle/identity.png
- docs/art/settings/character-revision-2026-09-12/06-rattle/chibi.png

### 49 — 475be1a2b9d2

- docs/art/reviews/character-directions-2026-09-12/02-kohaku/identity.png
- docs/art/settings/character-revision-2026-09-12/02-kohaku/chibi.png

### 50 — f6a22696a7e1

- docs/art/reviews/character-directions-2026-09-12/05-luna/identity.png
- docs/art/settings/character-revision-2026-09-12/05-luna/chibi.png

### 51 — 5e284c5fc4f7

- docs/art/reviews/character-directions-2026-09-12/01-sora/identity.png
- docs/art/settings/character-revision-2026-09-12/01-sora/chibi.png

### 52 — 0a2dfb3b3f64

- docs/art/reviews/character-directions-2026-09-12/04-mei/identity.png
- docs/art/settings/character-revision-2026-09-12/04-mei/chibi.png
