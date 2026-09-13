# 構成と拡張境界

更新: 2026-09-12。通常の入口は人間1人対CPU1人。通信・探索モードは未実装。
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
今回のテストでは乱数を使わないメモリ上の定義でこの経路を確認した。ランダム生成自体は未実装。

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
ランダム生成、階層、ショップ配置、ボス、会話、セーブ/ロードは未実装。

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
