# エディタでの調整

## エディタで調整する場所
|ファイル / ノード|編集内容|
|---|---|
|scenes/game/main.tscn / Game|Round Duration、Projectile Scene。進行・停止・勝敗を管理|
|scenes/world/arena.tscn / Walls / Wall1〜3|2Dで選択して移動・サイズ変更。ColorRectのPosition/Sizeを衝突判定にも使用。wall.tscnのインスタンスを複製して壁を追加可能|
|scenes/world/arena.tscn / Spawns / P1・P2|Marker2DのPositionが開始・再戦位置。プレイヤーの実行時位置はこちらから設定|
|scenes/world/arena.tscn / Players / P1・P2|HP、速度、回避、近接、装填時間、Weapon Display SizeをInspectorで変更|
|Players / P1・P2 / Sprite|Frame 0〜7で静止画を変更。位置・Scaleも編集可能。キャラ選択画面を経由した対戦ではset_character()がここへ選択キャラのcellを上書きするため、直接編集は対戦開始前のプレビュー表示にのみ影響|
|scenes/ui/character_select.tscn|Panel/Content内の見出し、Info、Cardsグリッドの配置。カードはcharacter_select.gdが8キャラ分生成し、立ち絵はcharacter_catalog.gdのart()がfighters.pngから切り出す|
|scenes/combat/pulse_effect.tscn|拡大リングの表示時間・拡大速度。消去効果自体は距離に関係なく即時適用|
|scenes/combat/player.tscn|Sprite、照準Line2D、識別Label、近接Line2D、Weapon/Spriteの共通表示。武器画像とScaleは装備時に更新|
|scenes/world/supplies.tscn / Spawns|InitialWeapons・Weapons・Ammo・LegendaryのMarker2Dで補給位置を編集。Supplies/Itemsは原点・等倍を維持|
|scenes/world/supplies.tscn / Supplies|出現間隔、Sレア時刻、取得待ち時間、寿命、取得範囲をInspectorで調整|
|scenes/world/pickup.tscn|武器画像・弾薬箱・名前・交換案内の共通表示。Label/Hintはマウス入力を遮らない|
|scenes/ui/preparation.tscn|Panel/Content内の見出し、Cardsグリッド、Notice、Readyの配置。カードはpreparation.gdで生成|
|data/catalog.json / scripts/catalog/weapon_catalog.gd|元の武器数値と、実装済みIDの許可リスト・画像対応。catalog.json自体は今回無変更|
|scenes/combat/gravity_well.tscn|寿命・吸引/ダメージ/弾吸収の範囲・強さ・周期をInspectorで調整。Line2Dの色・太さを編集可。円の頂点は実行時に範囲から生成|
|scenes/combat/projectile.tscn|寿命とVisual（Polygon2D）。弾速・威力・半径・跳弾数は発射時に武器定義/効果から設定|
|scenes/ui/hud.tscn / Root|Status・Message・LoadoutsをControlとして配置。武器枠はhud.gdが生成|

表示領域はproject.godotで1120×800に設定しています。アリーナの座標・壁・スポーン・移動境界は従来のままです。

Arenaの各コンテナは原点・等倍を維持してください。壁は軸平行の矩形のみ対応し、回転やScaleによる変更は未対応です。壁の大きさはSizeで変更します。出現位置は壁の外かつFighter Bounds内に置いてください。境界はArenaのFighter Bounds（プレイヤー中心の許容範囲）とProjectile Boundsで調整します。床表示を変える場合はFloorも編集します。プレイヤー半径とSpriteの大きさ、弾半径とVisualの大きさは別なので、両方確認してください。

arena.tscnを直接開いて編集し、動作確認にはF5を使います。各部品単体のF6では試合は開始しません。scenes/game/main.tscnから子を編集する場合はインスタンスの「編集可能な子」を有効にします。プレイヤー本体のPositionは配置プレビュー用で、開始時にSpawnsの位置へ戻ります。
