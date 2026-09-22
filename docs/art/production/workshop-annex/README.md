# 隣の作業室の更新（2026-09-22）

## 仕様票

- ID: workshop_annex。探索用の資材保管・仕上げ作業室。敵なし。
- 灰色の石床、明るい石積み、金属縁。通常サイズのリナ、正投影1120×800、フィールド1120×600、倍率1。
- 床は(128,128,864,384)、西通路(16,244,112,112)。外周7壁と厚み32px、北壁48pxを維持。描画高さ36px。
- 西扉westは(70,300)、開口112px、到着(220,300)。開始工房eastと接続。中央の横断路を空ける。
- data/fields/workshop_annex.tres / data/rooms/workshop_annex.tres。workshop_showcaseテーマを共用。旧石ブロック3個を取り除き、独立した衝突を持つ家具へ置換。

## 必要素材と配置

すべて既存素材を流用。有料生成・画像加工なし。

|素材|参照元|表示寸法・用途|
|---|---|---|
|床|assets/first-workshop/showcase/floor.png|256px反復、床色・目地緩和を共有|
|壁上面・正面・縁・端|assets/first-workshop/wall-kit-v2/{top,face,edge,end}.tres|接続壁の共通周期。上角の上面と通路終端の正面を区別|
|作業台|showcase/workbench-overhead.png|134×61、(520,421)、擦れと接地影|
|棚|showcase/cabinet.png|82×100、(520,124)、北壁際と背面影|
|資材箱|showcase/material-crate.png|72×57、(350,211)|
|金属パレット|showcase/metal-pallet.png|88×58、(840,410)|
|金床|showcase/anvil.png|68×40、(760,285)|
|壁灯|showcase/lamp.png|北壁27×44を2個、西通路正面24×39を1個|
|敷居・室外・影|既存テーマと共通描画|西向き開口。装飾柱なし|

家具のパスはassets/first-workshop/以下。原本・切出し・透過レシピは[工房素材記録](../workshop-showcase/README.md)、壁は[wall-kit-v2](../wall-kit-v2/README.md)と各manifestを参照。追加の素材不足なし。炉・煙道は隣室には不要。

## 確認

[通常サイズの確認画像](room-preview.png)。左出入口の上面連続と通路正面、北壁、棚の取り付き、天板主体の机、床と家具の縮尺を画像で確認。明示的な照明なし比較・家具の奥/手前の全配置での目視は未確認。

exploration_roomsで扉到達、20往復、HP・弾薬・タイマー保持、家具・光源の重複防止を確認。描画あり実行PASS、stderr空。stage_templatesで共通テーマ、家具衝突、旧石ブロックの撤去、出入口の余白を検証する。ユーザー採用・手動操作感・Webは未確認。自動テスト成功と美術上の採用は別扱い。