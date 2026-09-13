# 弾・発射・飛翔・着弾の専用化

状態：承認6シートの生成とゲーム統合が完了。[結果・動画](../../reviews/projectile-effects-2026-09-13/README.md)、[実装済みの追加手順](../../../development/WEAPON_EXTENSIONS.md)。以下の調査・計画は制作時点の記録。

## 現在の確認結果

- `scripts/visuals/projectile_art.gd`：ID20のサービスピストルは正式PNG。ID16伝票、ID17の最終小包、ID18、ID19は旧4コマシート。その他の主弾、ID17の通常荷札、派生破片は共通Polygon2Dを着色する。
- `scripts/visuals/player_animation.gd`：全武器が概ね共通のオレンジ色の発射光を使用。電撃、泡、魔法、種にも同じ画像が出る。
- `scripts/visuals/combat_visuals.gd`：旧シートの4系統とID20用着弾画像があり、それ以外は汎用の線状粒子とリングが中心。
- `scripts/combat/combat_session.gd`：分裂破片はゲーム上の武器ID0として生成され、元武器を表す表示情報がない。遅延射撃も共通の旧エフェクトを出す。
- 弾に追従する専用の飛翔軌跡は未実装。重力場は既存の円形表示を使用する。

## 制作内容（6枚）

1. 弾シート3枚：37武器の主弾を新規制作。ID20は採用済み画像を継続。別途、小包、紙片、火花、星くず、葉、レリック派生弾、重力の中心画像を含む。
2. 発射光1枚：実弾、金属、電撃、爆発、魔法、植物、紙、水の8系統。
3. 着弾2枚：8系統×4段階。初光→拡大→分散→消散。各武器で色・大きさ・時間を調整する。

煙や軌跡はコードで短く補間し、各弾の速度と方向へ追従する。回転する刃、種の待機と突進、泡の待機と加速もゲーム状態から動かす。生成画像だけで全アニメーションを固定しない。

## 組み込み方針

- 全武器の表示プロファイルを分離し、ID・弾種から主弾／小包／破片を選ぶ。
- 派生弾へ元武器の「表示用ID」を渡す。ダメージ計算や派生効果判定のIDは変えない。
- 小型の実弾は短い明色の芯、SFは細い発光軌跡、刃は短い残像、植物は少量の葉や花粉。色だけで識別を済ませず、形も分ける。
- 発射は武器の銃口位置へ接続。遅延弾は実際の発射時にその武器用の光を出す。
- 壁反射、壁命中、敵命中、分裂・爆発を区別。通常弾の寿命切れや近接・パルスによる除去で偽の着弾や爆発を出さない。戻り刃の接触は重複再生を抑える。
- 重力場は新しい中心画像と既存の吸引／ダメージ範囲表示を併用する。
- 当たり判定、速度、威力、弾数、反射数は維持。敵味方の識別リングと危険表示を残し、発光で覆わない。
- 粒子数・軌跡長に上限を設定。ポーズ・ラウンド切替で停止／消去する。見た目の乱数は戦闘乱数と分離する。

## 確認

素材は1枚ごとに確認し、背景を除去して小型表示を検査する。全38種・小包・派生破片の参照、発射／命中／反射／消滅イベント、停止／消去と粒子上限をテストする。実描画で通常・高密度の弾幕、左右の銃口、準備画面からの開始を確認し、既存全テストとエクスポートで回帰確認する。

## 予算

前回の承認10枚は完了、現在66送信。今回は追加6送信・保守予約$6を提案する。最大72送信、到達前停止のCLI上限は承認後に73へ変更する。過去の成否不明2件の予約を保持。直近のusage換算では6枚で約$0.64が目安だが、請求額ではない。追加候補・自動再送を含まない。音響SEの生成は対象外。

生成指示は全6枚とも4000バイト以内、出力名の未使用をローカルで確認済み。承認後にCLI上限を73へ更新し、累計72回で今回の生成を完了。

## 全武器の割り当て

|ID|武器|弾本体の指定|効果系統|軌跡|
|---|---|---|---|---|
|0|P-12 サイドアーム|Short silver pointed bullet, copper base; no cartridge case|ballistic|short|
|1|跳弾キャンディ|Red and white striped round candy, dark rim|metal|dots|
|2|ファイアワークス|Small red paper firework rocket, golden nose|explosion|embers|
|3|ハニービー|Yellow black bee micro missile, two short fins|energy|short|
|4|ダブルバック|Compact copper round pellet with white highlight|ballistic|none|
|5|ムーンリーパー|Silver crescent moon blade, navy inner edge|arcane|arc|
|6|アークレール|Long narrow cyan white rail dart|energy|rail|
|7|ヘリックス|Purple glass plasma pearl, white nucleus|energy|helix|
|8|プリズムバースト|White faceted diamond light shard, subtle rainbow edges|arcane|prism|
|9|コメットランチャー|Olive rocket shell with luminous gold star nose|explosion|smoke|
|10|ブラックホール・ティー|Black gravity orb with violet accretion ring|arcane|orbit|
|11|シードマイン|Brown seed pod with green split husk|organic|leaves|
|12|ロケットペンシル|Yellow miniature pencil rocket, graphite tip, red tail|explosion|embers|
|13|バブルクロック|Cyan transparent bubble with clear white rim|water|bubble|
|14|クローバースプリッター|Green four leaf clover, small golden core|organic|leaves|
|15|プラネタリウム|Gold five pointed star, navy inner face|arcane|stars|
|16|レシートリピーター|Folded ivory receipt strip with simple dark marks, no readable text|paper|paper|
|17|着払いキャノン|Small cream shipping tag with red stamp, no readable text|paper|paper|
|18|スイッチスパナ|Short silver hex bolt with red collar|metal|short|
|19|エコードラム|Copper bullet with two engraved dark rings|ballistic|echo|
|20|サービスピストル|Keep existing service pistol bullet|ballistic|short|
|21|スカウトニードル|Thin steel needle with blue tip|metal|needle|
|22|トリックコイン|Gold coin viewed at slight tilt, bold star engraving|metal|dots|
|23|ガードリベット|Thick brass rivet, broad flat head|metal|short|
|24|ツインタッカー|Small copper tack, short pointed shaft|metal|short|
|25|ルーンペン|Violet diamond rune on compact pale blue ink droplet|arcane|rune|
|26|シックスノート|Large copper revolver bullet with cream highlight|ballistic|short|
|27|ミニガトル|Stubby steel bullet with brass base|ballistic|short|
|28|ホチキスバースト|Silver U shaped staple with sharp ends pointing right|metal|short|
|29|クロスステッチ|Silver sewing needle with short pink thread attached|metal|thread|
|30|チョークライフル|Long gray pointed rifle bullet, chalk white tip|ballistic|needle|
|31|ペッパーボックス|Dark bronze round pellet with bright copper highlight|ballistic|none|
|32|ピンボールパドル|Reflective chrome pinball with cyan highlight|metal|dots|
|33|ツインクレセント|Small silver crescent blade with red inner accent|arcane|arc|
|34|スパークフォーク|Sharp yellow white forked electric dart|energy|electric|
|35|ベルフラワー|Small blue bellflower bulb with green calyx|organic|leaves|
|36|カーボンコピー|Flat white blue energy dart with two parallel dark rails|energy|rail|
|37|オーロラファン|Pale blue violet aurora shard shaped like a narrow feather|arcane|aurora|

[機械可読計画とシート割り当て](plan.json)
