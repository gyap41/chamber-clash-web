# CHAMBER CLASH Godot移行

Godot 4.5.1 Standard / GDScript / Compatibilityを対象とする、M1ローカル2人対戦の検証版です。HTML版の完全移植ではありません。今回の実行検証は入手済みのGodot 4.7.2で実施し、4.5.1での再確認は残っています。

## 起動・操作
project.godotをインポートし、F5で開始します。
- P1: WASD移動、F射撃、Space回避、V近接、Rリロード、E銃切替
- P2: 矢印移動、J射撃、K回避、L近接、Pリロード、O銃切替
- Esc: 一時停止。決着後Enter: 再戦。
- 自動照準。通常弾・跳弾は8発/予備40発を共有する仮実装です。

## エディタで調整する場所
|ファイル / ノード|編集内容|
|---|---|
|main.tscn / Game|Round Duration、Projectile Scene。進行・停止・勝敗を管理|
|scenes/arena.tscn / Walls / Wall1〜3|2Dで選択して移動・サイズ変更。ColorRectのPosition/Sizeを衝突判定にも使用。wall.tscnのインスタンスを複製して壁を追加可能|
|scenes/arena.tscn / Spawns / P1・P2|Marker2DのPositionが開始・再戦位置。プレイヤーの実行時位置はこちらから設定|
|scenes/arena.tscn / Players / P1・P2|HP、速度、回避、近接、弾数、装填時間、連射間隔をInspectorで変更|
|Players / P1・P2 / Sprite|Frame 0〜7で静止画を変更。位置・Scaleも編集可能。見た目の変更だけでキャラ固有能力は適用しない|
|scenes/player.tscn|Sprite、照準Line2D、識別Label、近接Line2Dの共通表示|
|scenes/projectile.tscn|弾速、寿命、半径、威力、跳弾回数。Visualは編集可能なPolygon2D|
|scenes/hud.tscn / Root|StatusとMessageをControlとして配置・フォント調整。文面は実行時に更新|

Arenaの各コンテナは原点・等倍を維持してください。壁は軸平行の矩形のみ対応し、回転やScaleによる変更は未対応です。壁の大きさはSizeで変更します。出現位置は壁の外かつFighter Bounds内に置いてください。境界はArenaのFighter Bounds（プレイヤー中心の許容範囲）とProjectile Boundsで調整します。床表示を変える場合はFloorも編集します。プレイヤー半径とSpriteの大きさ、弾半径とVisualの大きさは別なので、両方確認してください。

arena.tscnを直接開いて編集し、動作確認にはF5を使います。各部品単体のF6では試合は開始しません。main.tscnから子を編集する場合はインスタンスの「編集可能な子」を有効にします。プレイヤー本体のPositionは配置プレビュー用で、開始時にSpawnsの位置へ戻ります。

## 素材と移植範囲
fighters.pngの4列×2行（各384×512）をSprite2Dで表示し、P1=0、P2=1を使用。68px高の静止画です。歩行・射撃・回避の連続コマはこの画像にありません。元Web版の簡易脚動作も今回は未移植です。
portraits/party/weapons/weapons-extraは保存済み。projectile-sprites/weapon-effectsは追加武器用の素材で、今回の通常弾・跳弾に流用していません。音声・全装備・固有能力・CPU・オンライン対戦などは未実装です。素材は再生成していません。

## 検証
`Godot実行ファイル --headless --path . --editor --quit`

`Godot実行ファイル --headless --path . --script res://tests/smoke.gd --quit-after 120`

コンソールの両方のPASSとSCRIPT ERRORがないことを確認してください。assert失敗時のハングを避けるため上限を設定しています。元の境界・障害物・有限リロード・勝利・時間切れに加え、四隅、射撃CT、跳弾、回避、近接弾消し、停止、再戦、シーン編集の反映を検証します。

非headlessの `--script res://tests/render.gd` はCompatibility描画を行います。環境変数CHAMBER_SCREENSHOTに絶対PNGパスを設定すると描画結果を保存します。

Godot 4.7.2で回帰テストPASS、非headlessの描画画像を目視確認済み。対人キーボード操作、4.5.1、Web/Windows書き出しは未検証です。

計画と残作業はdocs/MIGRATION_PLAN.md。legacy-webは参照用のまま保持しています。変更前のGit保存点は506f073です。
