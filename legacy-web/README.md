# CHAMBER CLASH — 星くずトレジャーデュエル

ブラウザで動くオリジナルの2D弾幕対戦ゲーム。`dist/index.html` を開くと遊べます。PCのキーボード・マウス用です。インターネット接続がなくてもゲーム本体とキャラクターアートは動き、Webフォントだけ代替フォントになります。

## 今回の改修

- 魔法使いの女の子「モモ」、冒険少年「ソラ」、キツネの配達屋「コハク」、ロボット「ピコ」。耐久・速度・装填・回避・ブランク回数に違いあり。
- 武器16種類、C/B/A/Sの4レアリティ。最大4丁を保持し、装填弾と予備弾を武器ごとに管理。
- リロードは予備弾を消費。武器切替時にリロードを中止し、弾数は保持。弾薬箱・重複武器で補給。
- 満杯のときだけ交換キーで装備中の武器を交換。それ以外の所持武器は失わない。
- Sレア武器：虹色パレード、ねがい星バズーカ、まよなかティーカップ。
- 6種類のレリックから最大3個を組み合わせ。重複装備不可。毎ラウンドリセット。
- 時間差補給は同じ内容を2か所に配置。開始30秒で同じSレア武器を中央の上下へ配達。
- キャラクターごとに7〜10 HPから開始、3本先取。90秒で残りHPの割合を比較。開始60秒から危険地帯が縮小。
- 弾切れ時も使える近接攻撃。CPUもお宝の回収、弾薬補給、武器切替を行う。

## 操作

|操作|1P・CPU対戦|ローカルP1|ローカルP2|
|---|---|---|---|
|移動|WASD|WASD|矢印|
|照準|マウス|自動|自動|
|射撃|左クリック|F|L|
|回避|Space|Space|Shift|
|弾消し|Q|Q|O|
|武器切替|E / ホイール / 1〜4|E / 1〜4|K|
|リロード|R|R|P|
|満杯時の交換|G|G|H|
|近接|V|V|N|
|一時停止|Esc|Esc|Esc|

武器スロットをクリックして切り替えることもできます。弾数表示は「装填 / 予備」。

## レリック

|レリック|効果|
|---|---|
|ふわふわ羽根|移動速度 +12%|
|ぜんまいリボン|リロード時間 -35%|
|プリズムレンズ|対応する弾に反射回数 +1|
|おまもりベル|敵の攻撃を1回防ぐ。12秒で再使用。危険地帯には無効|
|ハートの小瓶|最大HP +2、その場でHP +2|
|流れ星のブローチ|回避時に6方向へ小さな星弾|

## 検証

`node tests/game-state.cjs`

ブラウザ非依存の状態検証で、有限弾薬、リロード中断、所持上限、同じアイテムの二重取得防止、全レリック効果、全武器の発射、重力渦、ブランク、散弾の同時命中、一時停止、S武器配達、ラウンドリセット、時間切れ、CPU対戦を確認しています。ブラウザでの目視・実操作テストは未実施です。

## アセット

`dist/assets/party.png` は今回のために生成した透明背景のオリジナルキャラクターアトラスです。ゲーム本体と選択画面で使用します。

## 追加調整

- 移動範囲をキャラクターの表示サイズに合わせ、移動を5px以下に分割。範囲外や障害物内の座標を復帰させる。
- 近接：前方120度、半径64、敵弾最大3発を即時消去。再使用1.1秒、射撃硬直0.3秒、威力0.6。無敵や反射なし。重力渦は対象外。リロード・回避中は使用不可。
- モモ：HP8 / 速度205 / 装填1.265秒 / 回避1.65秒 / ブランク3。
- ソラ：HP8 / 速度215 / 装填0.9775秒 / 回避1.8秒 / ブランク2。
- コハク：HP7 / 速度235 / 装填1.15秒 / 回避1.4秒 / ブランク2。
- ピコ：HP10 / 速度190 / 装填1.15秒 / 回避2秒 / ブランク2。
- 種の設置、加速弾、遅延泡、十字分裂、全周星弾の5種類を追加。初期候補・フィールド補給・S配達へ組み込み。
- 対人戦のバランスは初期設定。実戦の勝率に基づく調整はまだ行っていません。

## アクションUIへの更新

- リナ・ソラ・コハク・ボルト・メイ・ルナ・ラトル・クロウの8人を選択可能。追加4人は既存のステータス範囲内で構成。
- 低頭身の簡潔なキャラクター塗りと、ディテールを残した16武器の透過アトラスを使用。戦闘中の武器・補給品・選択カード・装備スロットに同じ画像を表示。
- チャコール、オレンジ、ブルーの角張ったUI、数値付きHPゲージ、石床の中立的なアリーナ。相棒→ファイター、お宝→装備／武器補給、ブランク→パルスへ統一。
- テストは8人全員のステータス、16武器、境界復帰、近接上限と既存ラウンド進行を確認。ブラウザ実操作は未実施。

## ポーズ・戦闘演出の調整

選択画面は承認済みの個別ポーズを使用。戦闘中は既存スプライトを腰下で分けた簡易リグで交互に足を動かし、体の傾き、上下運動、回避回転、射撃反動を合成。手描きのフレームアニメーションではありません。武器は体と共通の変換で手元へ寄せて描画。発射光・火花・曳光を追加。SEはノイズ、フィルター、低音／電子音を重ね、実弾・散弾・レール・爆発・装填を区別。音は画面右上でON。自動テストは描画座標・反動の進行・音の生成経路も確認。ブラウザでの実操作・試聴は未実施。


## Supply shop update

20 weapons and 12 relics. New guns: Receipt Repeater (bounce damage), Cash-on-delivery Cannon (final-round parcel fragments), Switch Spanner (reload changes firing mode), Echo Drum (delayed paired shot). New relics trade projectile speed for damage, strengthen the first shot, transfer one reserve round on switching, add a pulse counter-volley, reward melee interception, or accelerate the first ricochet.

After the free weapon draft, each player receives 100 CR plus 15 CR per point behind (maximum +30). Both get the same six offers with independent stock. Buy at most two items: B weapon 45, A weapon 60, S weapon 90, relic 40, extra pulse 25. No currency or equipment carries into the next round. Local players shop sequentially; CPU follows the same budgets and limits. Readiness from both sides starts combat. No combat time passes in the shop.

Validation: node tests/game-state.cjs covers shop spending, independent stock, readiness, round reset, new weapon/relic behaviors, and previous combat regressions. Browser visuals and competitive balance still require human playtesting.

Weapon VFX: transparent four-frame atlas on receipt ricochets, final parcel bursts, spanner impacts, and delayed echo shots. Effects last 0.20–0.32 seconds, render beneath players/projectiles, pause with combat, and are capped at 40 instances.

Projectile animation: four-frame 12 fps transparent sprites for receipt rounds, final parcel rounds, spanner nuts, and echo rounds. Source rectangles trim transparent margins; solid-body anchors rotate with velocity. Fragment and regular parcel rounds retain existing rendering. Sprite loading failure falls back to existing bullet visuals.
