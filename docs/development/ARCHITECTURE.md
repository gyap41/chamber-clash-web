## 探索の扉移動と状態持越し（2026-09-21）

`exploration_rooms.gd`は固定2部屋と相互接続する扉（安定ID/方向/相手扉/到着位置）を定義し、`data/fields/workshop_*.tres`が形状を持つ。到着位置は到着側の扉が所有する。`exploration_door.gd`は表示だけを行い、主人公より後ろに描画する。探索側で近接/射線/進行状態を検証し、`switch_field`の通常移動を呼ぶ。到着点を持つ私有のFieldDefinitionを作り、元のテンプレートは変更しない。

|対象|部屋移動時の扱い|
|---|---|
|主人公Actor・RunInventory・装備配置・所持金|同じインスタンス/値を維持。初期条件を再適用しない|
|HP/上限・弾薬/予備/武器モード・パルス回数|維持。回復・補充なし|
|射撃・装填/対象武器・回避/無敵・近接・レリック待ち時間/充電|維持。新戦闘用resetを呼ばない。次のシミュレーション更新から残り時間を進める|
|反撃回復枠と被弾別の残り期限|維持。部屋移動で延長も消去もしない|
|位置・カメラ|相手側扉の到着位置へ変更。両部屋とも倍率1|
|旧部屋の弾・重力場・パルス演出・遅延射撃・補給物|消去。弾薬を返さない。取得物はExplorationLootと部屋状態から再構築する|
|射撃/持替え予約・投入済み入力|消去。Fは解除まで再発火せず、移動時に押していた左クリックも解除を要求|
|部屋ID・訪問済み|成功時だけ更新。再挑戦で開始部屋へ初期化。ディスク保存なし|

遷移は同期処理で、途中の入力を許可しない。死亡/停止/戦闘遭遇中の要求を拒否する。部屋別の敵・拾得物の再訪状態とインベントリ反映は後述の探索構成で管理する。増援とディスクからの復元は未実装。

## 戦闘HUDの共有部品（2026-09-21）

対戦は `hud.gd`、探索は `exploration_hud.gd` が配置と表示項目を持つ。`combat_hud_view.gd` がActorからHP/回復枠・武器/弾薬・装填時間・行動状態を読み取り、独立した値の辞書を作る。操作許可はモード側から渡す。ビューの変更はActorや所持品へ書き戻されない。

- `hp_bar.gd` / `hud_action.gd`：既存のHP・回復枠と行動表示を再利用。
- `hud_weapon_panel.gd`：武器名/画像・弾薬・装填進捗。残り装填時間と実効装填時間から進捗を表示し、初回表示が装填途中でもその位置を示す。
- `hud_weapon_slot.gd`：共通の武器ボタン。切替の要求シグナルを発行し、モード側の `equip_slot` が再度操作を検証する。
- `hud_widgets.gd`：共通のパネル・ラベル・ボタン生成。進行状態を参照しない。

探索HUDは `present(view, mode)` で表示を受け取り、停止/再挑戦/タイトル/SEをシグナルで要求する。探索コントローラーが停止理由等を管理する。フィールド切替後は `CombatContext.refresh_hud()` のモード別実装を呼ぶ。対戦の既存HP・武器のノードパスは維持し、準備/勝数/結果の表示は対戦HUDに残す。インベントリ、装備詳細の共通化、オンライン制御は今回の対象外。

## キャラクターの表示状態（2026-09-21）

戦闘の辞書・装備から`Player.visual_snapshot()`が値を取り出し、描画へ渡す。
`actor_animation_state.tscn`のBodyTree（待機・移動・回避・死亡）とWeaponTree
（通常・射撃・装填・近接・無効）を独立させ、移動装填・着地射撃を表現する。
表示は手動更新で、戦闘のHP・無敵・弾薬・タイマーを変更しない。
AIの判断や戦闘の行動可否を表示グラフへ移してはいない。
身体はSpriteパーツをキーフレームで動かし、待機/歩行を補間する。専用回避は既存描画を使用。
グラフの編集場所・敵や動作の追加は[ACTOR_ANIMATION](ACTOR_ANIMATION.md)を参照。

# 構成と拡張境界

対戦の入口は人間1人対CPU1人。別入口として敵なし探索2部屋の試作を実装済み。探索は初期の参加者登録前に共通アリーナのP2を除外する。遭遇状態noneでは敵0人でも終了しない。探索インベントリ、ランダム階層、近接敵との遭遇は実装済み（後述）。通信は未実装。
リファクタリングの検証記録は[履歴](../archive/2026-09-12/EXTENSION_REFACTOR.md)。

## 入力から結果まで

`human_input.gd` がWASD・マウスと単発キーを操作データに変換する。
`cpu_ai.gd.sample()` は同じ操作データを返す。CPUの探索経路・判断待ちなどの記憶は
Actorの一時状態に保持するが、sample自体は射撃・装填・近接・取得を実行しない。
旧 `decide()` は回帰テスト向けの「sample＋共通実行」互換入口。

`combat_command.gd` の操作データ:

|キー|意味|
|---|---|
|dx, dy|移動意図。Playerで正規化する|
|angle|ワールド照準角（ラジアン）|
|shoot|このフレームの射撃長押し|
|fire_pressed|押下端。回避終了前100msの短押し予約用。長押しで毎フレーム再予約しない|
|switch|携行スロット。-1は指定なし|
|dodge, reload, melee, pulse, interact|単発の行動要求|
|aim_jitter|CPU照準の計測・旧テスト互換値。実操作にはangleを使用|

`main.resolve_command()` が人間・CPU・投入済み操作を選び、`command_source` Callableとして
戦闘へ渡す。将来の外部入力は参加者IDと `submit_command(id, data)` で1フレーム分を投入できる。
同じIDへの複数投入は最後の1件になり、実行後に消費する。未知IDは拒否し、外部参加者は
入力欠落時にホストのキーボードへフォールバックしない。これは通信プロトコルではない。
順序番号・送信者認証・欠落補償・値の検証・再送・予測・補間は接続層で今後設計する。

`combat_session.gd` は操作の実行、射撃・派生弾・パルス・重力場・全参加者の更新を担当。
`player.gd` は操作データから移動し、弾薬・回避・ダメージなどのActor状態を更新する。
Playerは物理キーやマウスを直接読まない。`handle_key()` は旧P1効果テスト用の互換アダプターで、
実ゲームの入力配信には使用しない。P2キー入力は廃止した。

フレーム順は時間更新→追射予約→各参加者の操作/移動/危険地帯→補給→弾→重力場→勝敗判定。
描画側の演出更新はこの外側に置く。同フレームの命中、派生、吸収の順序を変更しない。

## 参加者・チーム・勝敗

`battle_roster.gd` は一意な文字列 `id`、`team`、`controller` を登録する。
配列スロットは実行中のローカル格納位置であり、参加者IDではない。試合中の並べ替え・脱退による
配列詰め直しは未対応。弾のownerはスロットを保持し、敵味方はRosterへ問い合わせる。
`is_cpu` は操作元のみを表し、敵味方判定には使わない。

CPU・追尾は生存する最寄りの敵を選択する。近接・爆発・重力場は範囲内の全敵が対象。
弾は1回だけ移動し、移動中の各小区間で全敵へ命中を検査する。通常弾は最初の対象で消滅、
往復弾は参加者IDと往路/復路ごとに命中履歴を持つ。パルス・弾消し・すり抜け装填もチームを判定する。

`victory_rule.gd` は全滅と時間切れの結果を値として返す。時間切れはチームごとの平均残HP率を比較する。
同率は引き分け。1対1では従来のHP率比較になる。チームの1人が倒れても残員がいれば続行。
`CombatSession.outcome()` が結果を一度確定し、`main.gd` が結果表示・次準備・画面遷移へ接続する。
`match_state.gd` は5本先取・収入・引き分け再戦・試合終了時の初期化を担当する。

## 戦闘と表示

`combat_events.gd` はburst/ring/shake/weapon_effect/dodge_trail/sound/pulseの通知を発行する。
mainが演出ノード・音・パルス表示へ接続する。戦闘は演出の戻り値を参照しない。
Player/Projectileの演出シグナルも同じ通知先へ接続する。通知の受信先なしで統合テストを実行する。

CombatSessionはRefCountedで、WeakRefで渡された実行コンテキストのActor・Arena・配列・補給・
時刻・command_source・通知先を使う。HUD、準備UI、勝数やシーン遷移を参照しない。
現状ではmainがこのコンテキストを提供する。Godot Node/Vector2を使う戦闘であり、
描画ノードもActorシーンに同居する。エンジン非依存のサーバー実装や決定論的同期の完成を意味しない。

通常HUDは1対1用。複数参加者にはID・チーム・HP・勝数の簡易表示を用意したが、
装備詳細・レリック一覧の全参加者対応、正式なチーム戦UIは今後の課題。

## フィールド

フィールドは次の3層に分ける。固定/生成の区別は戦闘側へ渡さない。

|層|実装|責務|
|---|---|---|
|初期定義|`field_definition.gd` / `data/fields/*.tres`|ID、寸法、移動/弾境界、床色、壁矩形、出現地点、補給候補点|
|配置|`field_builder.gd`|定義の私有コピーを検証し、床・壁・マーカーを生成/置換|
|実行時フィールド|`arena.gd`|移動・衝突・射線・出現位置・危険地帯の共通API|

`duel.tres` は1120×600・3壁・2出現地点、`validation.tres` は1440×900・別配置3壁・4出現地点。
従来の2シーンは定義リソースと参加者/演出ノードを接続する器となった。床・壁・出現/補給マーカーを
シーンへ重複記述しない。参加者数・チーム・操作元はフィールド定義に含めず、Roster/対戦構成が決める。

将来の生成器は `FieldDefinition.new()` の同じプロパティを埋め、保存済みリソースと同じ配置入口へ渡す。
今回のテストでは乱数を使わないメモリ上の定義でこの経路を確認した。現在のランダム生成は後述のP2構成を参照。

定義は初期配置であり、実行時の破壊・移動を書き戻さない。配置ごとに `duplicate(true)` した
runtime_definitionを保持し、壁やマーカーは毎回独立して生成する。同じ元定義を別Arenaや再訪で使える。
元Resourceを編集しても現在の配置には自動反映されず、明示的な再配置で取り込む。

配置前に有限で正の矩形、境界の包含、必要出現地点数、出現地点同士/壁との接触、補給点の型/範囲を検証する。
補給候補点が壁と重なる配置は既存の「別候補を試し、全滅なら出さない」方針に従って許容する。
補給グループの省略も可能で、その種の補給は出現しない。フィールド検証は到達可能性やバランスを保証しない。
座標はすべてArenaローカル。現在は軸平行の矩形壁に対応し、壁の回転/拡縮は対象外。

`Arena.configure_field(definition, count, radius)` は配置だけを扱い、Actor・弾・所持金や試合状態を触らない。
プレイ中の切替は **`main.switch_field(definition, new_encounter=false)`** を使う。
同期的な境界操作なので、CombatSession.stepの途中から再入せず、戦闘更新の間に呼ぶ。
戻り値の空PackedStringArrayは成功、非空は拒否理由。不正な定義・出現地点不足では現在の配置/状態を変更しない。

切替成功時は同じActor・Roster・MatchStateを維持し、旧フィールドの弾/重力場/追射/補給品/演出/入力予約/
CPUの経路と観測位置を破棄する。新フィールドの出現地点へ移動し、カメラと危険地帯表示を更新する。
HP・弾倉/予備弾・武器モード・装備/仮装備・所持金・勝数は持ち越す。
通常切替はActorの装填/回避/効果タイマーを保持し、new_encounter=trueの場合だけbegin_encounterで
Actorの一時状態を初期化する。いずれも全快・補充やビルド再適用はしない。
試合phase・残時間・決着状態は変更せず、補給の出現タイマーは新フィールドとしてリセットする。
このAPIは階層進行や次戦開始を実装するものではない。出現地点が足りれば同じ参加者数で別フィールドへ移れる。

危険地帯の判定・表示・CPU退避は `safe_rect(inset, padding)` を共有する。
ギミックのダメージは `player.hurt(amount, volley, hazard, origin)` を使う。hazardは環境ダメージ区分で、
回避/被弾無敵まで無視する意味ではない。新規ギミックの定義・生成器、エディター上の配置プレビューは未実装。
配置は実行時に生成するため、編集する原本は.tres。再訪時の壊れた壁や未取得品の保存も今回は行わない。

検証方法は[TESTING](TESTING.md)、移行の記録は[フィールド分離](../archive/2026-09-12/FIELD_DEFINITION_REFACTOR.md)。

## コンテンツ

`data/catalog.json` の武器・レリック・キャラには明示的な数値 `id` がある。
旧IDは一切変更せず、カタログはID索引で参照する。配列の並べ替えはIDを変更しない。
未登録IDは空Dictionaryを返す。追加時は未使用ID、定義、形状、画像対応、テストを揃え、
武器/レリックのSUPPORTEDへ追加する。削除済みIDを別用途に再利用しない。
武器 `gun:<id>`、レリック `relic:<id>:<serial>` の個体トークンは従来どおり。
画像のcell/art_idと種類IDも別概念である。

`relic_effects.gd` の発動点はshooting、incoming_damage、damaged、reload_completed、
switching、melee_cleared、recovered、dodge_started、pulse_used、first_bounce。
共有のscalesが直接/派生の補正を計算する。弾倉・移動速度などの常時計算と一時タイマーはPlayer、
特殊な武器弾道はProjectile、具体的な追加弾生成はCombatSessionに残す。
汎用DSLやイベント自動連鎖は導入していない。

発動順はスターター→帰還バッテリーの分配→ラストスタンプの分配→威力/速度倍率。
時間差連射は発射時の補正を保存する。既存のdepth/applied_effects/volleyによる
派生再発動制限、散弾の被弾処理、補填と装填完了の区別を維持する。

## 状態の寿命と将来の探索

|責務|保持するもの|初期化の入口|
|---|---|---|
|Playerの戦闘一時状態|回避・装填・無敵・充電・予約・CPU判断記憶|reset / begin_encounter|
|RunInventory|個体・所持庫・装備配置・改造・所持金・取得履歴・商品|RunInventory.new(seed,count)|
|EncounterResources|HP・弾薬・武器モード・パルス・装備の境界コピー|capture / restore|
|MatchState|対戦の勝数・決着・準備段階・ラウンド収入|new_match / finish_team|
|永続解放|未実装。RunInventoryや戦闘一時状態へ格納しない|将来別のProfile責務|

RunInventoryはUIなしで生成・購入・取得・配置できる。`grant_item(slot, entry, source)` は
武器/レリックの重複・控え容量・個体生成を共通化し、部屋の取得で使える。
対戦の「戦闘中のみ武器取得可能」制限はMatchStateのallows_field_acquisitionで追加する。
試合本数を使わない探索はMatchStateの終了処理を呼ばずRunInventoryを保持する。
ショップの準備ロックや品揃え段階は現行対戦由来の方針として残り、探索での運用は未実装。

`move_to_room(spawn)` は位置と入力予約のみ変更する。
`begin_encounter(spawn)` は一時状態を初期化し、HP・弾薬・装備・仮装備を持ち越す。
明示的なreplenish指定時だけ全快/弾薬補充する。通常対戦のlaunch_roundは従来どおり
reset＋確定ビルドの全快適用を選ぶ。部屋・階層移動でこの対戦用入口を使わない。
ランダム階層は後述のP2構成で実装済み。正式ショップ、ボス、会話、ディスクへのセーブ/ロードは未実装。

## その他

配置計算はbuild_grid、個体比較はitem_identity、CPU購入はcpu_preparation、
商品乱数はreward_generator、画像切り出しはatlas_regionsを共有する。
ログはrun_logでuser://run-logsへ保存し、外部送信しない。
ファイル構成の旧一覧・経緯は[変更前の構成](../archive/2026-09-12/BEFORE_EXTENSION_ARCHITECTURE.md)。
素材環境は[素材生成設定](ASSET_GENERATION_SETUP.md)。今回有料生成は行っていない。


## Visual Hub（開発専用）

`tools/visual_hub/visual_hub.tscn` は通常ゲームと独立した入口。Collector → 値だけのRecord → Preview Registry/Adapter → UIの4層を分離する。
既存Player/CombatSession/FieldDefinition/Sceneと描画処理を使用し、AI・補給・音声・ログを開始しない。通常のmain_sceneは変更しない。
`export_catalog.gd` が内容ハッシュ・UID・参照規則付きManifestを出力し、`export_preview.gd` が同じAdapterから選択対象だけ描画する。
React/TypeScriptのWeb画面はManifestとフレーム列を表示する。127.0.0.1限定のNodeサービスが収集・撮影・レビュー保存・Godot起動を仲介し、外部サービスには接続しない。
原本は既存ゲーム定義、レビューだけ `tools/visual_hub/reviews.json`。再生成物・設定・PNGは `.local/visual-hub/` に分離し、exportからHubとnpm関連を除外する。
[起動・操作・拡張契約](../../tools/visual_hub/README.md)。


Visual Hubの新しい武器/キャラ一覧は `live_preview.gd` とJavaScriptBridgeを介したGodot Webリアルタイム描画を使う。Reactが表示中のDOM枠と条件を渡し、1エンジン内で最大24 SubViewportを管理する。画面外は解放する。`pack_live.gd` によるHub専用PCKだけで起動Sceneを変更し、通常project.godotと配布設定は維持する。価格はShopCatalog、占有形状はBuildGridからManifestへ出力する。既存の撮影Compare/Historyはレビュー用として併存する。

Visual Hubライブ一覧の表示は、単一Godot WebのアトラスからDOMカード内Canvasへ描画完了時に同期転送する。スクロール座標をGodot描画へ追従させず、表示対象・寸法のみを送信する。レイアウト世代と描画面寸法が一致するフレームだけ転送し、スクロール時の白い残像を防止する。
## 外周壁の素材交換

`FieldDefinition.walls` は衝突矩形、`wall_textures` は壁番号をキーとする任意のTexture2D参照。未指定なら既存の遮蔽物画像を使う。`FieldBuilder` が双方をWallへ設定し、画像寸法から衝突矩形を生成しない。探索2部屋の境界と通路壁は7矩形、室内遮蔽物は3矩形。floor_regionsで室内と通路の床描画を限定し、室外を暗くする。wall_face_texturesで壁正面を別指定し、上面と高さを描き分ける。扉枠の表示はExplorationDoorが担当し、開口部には壁を置かない。素材は `assets/first-workshop/environment/` のAtlasTextureから交換できる。
## ステージ構成データ（2026-09-21）

StageTheme / FieldDefinition / RoomTemplate / StagePlacementへ表示素材・幾何・扉・配置を分割し、固定2部屋を移行した。FieldBuilderは配置物と照明の生成/破棄も管理する。詳細は[ステージテンプレート](STAGE_TEMPLATES.md)。wall_idsを使う探索の材質指定はwall_materialsを優先し、旧式wall_texturesは互換用。

## 探索中の装備編集（P1）

ExplorationBagは表示と編集用ExplorationInventoryを扱い、対戦のMatchStateを使わない。RelicGridCellはinventory_stateを受け取れるようにし、従来準備画面のgame.match_state参照は互換として維持。RelicChip/RelicTray/ItemFootprint/HUD部品を共有する。バッグの画面構築はグリッド・控え・詳細の関数に分け、グリッド寸法と控え容量はBuildGridの共通定義を参照する。

配置・解除ごとにon_changeから探索側へ変更を渡し、成功・失敗のどちらもライブ状態から編集コピーを更新する。閉じる操作は反映・取消を行わない。画面構成と停止/反映規則はモード別に維持し、CPU戦と共通化するのは表示・操作部品までとする。

ExplorationLoadout.validateは配置以外の所持情報が元と同じこと、形状・重複・携行数・控え容量を確認する。検証前にライブの所持品/キャラを変更しない。applyは現在の武器状態をExplorationState.weapon_bankへ退避し、apply_build(heal=false)で能力を反映後、保持した武器と待ち時間を復元する。新規武器の弾薬は初回だけ作る。通常入力と遅延された武器切替も探索側で保持処理を通す。共通戦闘の対戦用装備適用は変更しない。

探索の停止理由inventoryはmenu/focusと独立。bagが存在する間は戦闘入力を通さず、closeで入力をクリアし左ボタンの解除を要求する。固定拾得物は安定IDをcollected_lootへ記録する。正式な生成・宝箱・報酬・保存の実装ではない。

## 準備UIと装填状態の境界

PreparationGridは対戦準備のグリッド描画を担当する。選択・購入・配置の判断はPreparationに残し、描画側からコールバックを呼ぶ。ItemGridAppearanceは同じ装備の占有マス間をつなぐ描画のみを共有し、探索のマス区切りと対戦の連続表示を維持する。セル寸法はPreparationGridに集約する。

Player.weapon_timing_snapshot / restore_weapon_timingが射撃待ち・装填残り時間・空弾倉開始フラグを扱う。ExplorationLoadoutは武器ごとの保存先と復帰方針を管理し、Playerの装填演出変数を直接変更しない。present_reloadで通常装填と復帰時の演出開始を共通化する。復帰では弾薬補充や装填完了効果、通常開始時の武器固有効果を発動しない。対戦の持ち替えによる装填中断は維持する。

## 所持品・商取引・探索拾得の境界

RunInventoryは所持品、個体ID、配置、控え、取得履歴と実行中の状態を保持する。InventoryCommerceは商品抽選、カード、購入/売却、再抽選、改造、支払いを伴うバッグ拡張の処理を担当する。既存のRunInventoryメソッドは互換窓口として委譲するため、UI・CPU・MatchStateの呼び出しは維持する。データを複製せず、サービスは所有者を保持しない。can_trade/can_edit/shop_stageとgenerate_rewardsのモード別上書きを維持し、探索でショップを無効にする。探索用ショップの追加時には価格・回数制限等の方針を別途設計する。

ExplorationLootは固定拾得物の定義、距離/射線による候補選択、所持品への取得、取得済みIDの記録と表示ノードの再構築を担当する。Explorationは停止・死亡・フェーズによる操作制限と案内更新を担当する。取得済み状態はExplorationState.collected_loot、表示ノード一覧は探索側が所有し、部屋再構築時に破棄する。乱数報酬・部屋インスタンスID・永続セーブはこの分離では追加しない。

## P2 部屋インスタンスの状態

room_catalogのキーが配置ID、RoomTemplate.field.field_idがテンプレートID。同一素材/形状を共有しても配置IDを一意にする。ExplorationState.enter_roomは配置IDを現在地へ設定し、room_states[配置ID]のtemplate_idとencounter、およびvisited_roomsを更新する。encounter_statusは現在地の状態への互換アクセサー。collected_lootは配置ID:ローカル拾得IDをキーとし、ExplorationLoot.entriesへ両IDを渡す。固定部屋では配置IDとテンプレートIDが同じため従来キーを維持する。これらは実行中の状態であり、ディスク保存・生成結果の版管理ではない。

## ランダム階層の組立

ExplorationFloorは専用RandomNumberGeneratorから配置セル・接続先・役割・家具テンプレートを生成し、version/seed/start/catalog/roomsを返す。WorkshopRoomShellは検証室と共通の矩形外周・四方向開口を組む。RoomReachabilityは半径14px、32px探索格子、4px間隔の線分検査で開始点から全扉/到着点への到達を確認。探索側は構造と到達性の検証後にカタログを置換する。floor_dataは現在の生成結果として保持するが、ディスク保存形式ではない。

ExplorationMapは渡された配置・現在地・訪問/攻略状態のスナップショットを描画し、停止理由mapは探索側が管理する。未訪問は訪問済み部屋に隣接するものだけ位置を表示し、役割は訪問後に開示。入力は他のモーダル画面同様に消費し、閉じるクリックで射撃しない。固定2部屋の入口と任意のカタログ注入は維持する。

## 探索の追従カメラ

ExplorationCameraがfield_rectとプレイヤー座標からCamera2Dの左上位置を計算する。探索のみfit_field_cameraを上書きし、通常更新は戦闘更新後、部屋切替はswitch_fieldの既存呼び出しで即時更新。ズームは1、部屋より広い表示領域は中央寄せ、他は端でクランプする。HUDの論理表示領域は1120×600、上余白90px。CanvasLayerのHUDと共通対戦カメラは維持する。カメラ揺れはoffsetへ別に適用する。

### 探索の遭遇と所有者寿命

`exploration_encounter.gd` は入室後（CombatSession.step外）に到着点から通行可能な位置を探索し、通常室だけ広さに応じて3〜6体を登録する。探索主人公は常にslot 0。敵は部屋インスタンスID/個体番号の参加者IDとenemy controllerを使う。`bind_combat_actor` は新規役者に一度だけ適用し、主人公のsignalを再登録しない。`exploration_enemy_catalog.gd` が性能、`exploration_enemy.gd` が予告/接近/攻撃/硬直と仮描画を担当する。現段階ではPlayerシーンの共通被弾・移動アダプターを継承し、購入/装備・対戦CPU判断は使用しない。将来の別Actor化では共通CombatSessionのactor契約を維持する。

全滅判定はstepの後に行い、探索状態の部屋をclearedへ変更する。`Encounter.retire` は弾・遅延射撃・重力場・入力キューを先に消し、敵ノードとfighters/participantsを退役させる。生存中のowner slotを途中で詰めず、死亡役者も部屋全滅まで保持する。移動/再挑戦前に旧owner参照が残らない。通常の攻略はrunを終了せず、死亡が優先する。進行はメモリ上のみで、戦闘中の離脱と途中敵HP復元は対象外。

## 探索の射撃敵と編成

exploration_encounter.gdは初回の通常室で番機3体、その後は部屋の外接矩形面積に応じた3〜6体（トカゲ1〜2体）の混成を選び、ExplorationStateの部屋ごとのenemy_idsに記録する。地形生成版は2のまま。編成は入場順による導入で、seedのみから編成を固定する方式ではない。保存形式を実装する際はenemy_idsも保存対象とする。

fire_pouch_lizard.gdは探索Actorの被弾・移動を共有し、構え／2発射撃／硬直の判断を持つ。Playerの武器ビルドは使わない。FIRE_SEED_ID=-1は武器カタログ外で、独自のresolved_definitionを使い、共通CombatSession.spawn_shotへ渡す。味方判定、壁、パルス、owner退役は既存経路。仮の火種はprojectile_art.gdのenemy_fire_seed表示で、画像や描画サイズから判定を作らない。音響の新規接続は行わない。

## 探索の報酬と補給

`exploration_reward.gd`はfirst_clear/treasureの独立した保証と用途別乱数を管理し、到達可能な配置探索を提供する。`exploration_supplies.gd`は攻略数に応じた補給生成と取得判定を管理する。部屋状態にrewardとsuppliesを記録し、探索画面が入力・表示ノード・SEを接続する。箱と補給の表示は非衝突。補給弾はExplorationLoadout.captureでweapon_bankへ同期する。対戦の補給生成や経済には接続しない。

探索画面だけがPlayer.exploration_starterを有効化する。infinite_reserve(id)を通常装填・レリック装填・補給とHUDで共用し、サービスピストルの性能補正はresolved_definitionの複製に適用する。共有カタログは書き換えない。

quillback.gdはfire_pouch_lizard.gdの接近・構え・画面内制限を継承し、spitを5方向の単発扇へ置換する。shots/windup_soundは敵定義で指定。負数の専用QUILL_ID=-2はプレイヤー武器と分離。画像と撃破スナップショットはenemy_idで専用シートを選び、organicフラグは粒子材質を決める。
