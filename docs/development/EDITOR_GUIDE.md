# エディタでの調整

更新: 2026-09-22。ステージ変更前には[制作テンプレート](../art/STAGE_CREATION_TEMPLATE.md)と[データ定義](STAGE_TEMPLATES.md)を読む。

|調整対象|編集元と注意点|
|---|---|
|部屋の床・壁・開始位置・境界|`data/fields/`のFieldDefinition。`arena.gd`のdefinitionをFieldBuilderが読み、壁・スポーン等を生成する。生成後のWalls/Spawnsノードを編集元にしない|
|探索の接続・扉・家具・照明・テーマ|RoomTemplate、StagePlacement、StageTheme。固定部屋とランダム生成の経路は[ステージ定義](STAGE_TEMPLATES.md)を参照|
|対戦進行|`scenes/game/main.tscn`と`scripts/game/main.gd`。探索の進行はexploration側で管理|
|キャラ・武器・レリック性能|`data/catalog.json`と対応catalog。PlayerのInspector値はキャラ設定や装備適用で上書きされるため、実行時の正本を確認する|
|キャラと武器の表示|[Actor表示](ACTOR_ANIMATION.md)。Spriteの静止プレビューだけで実行時表示を変更したと判断しない|
|対戦HUD・準備|`scenes/ui/hud.tscn`、`preparation.tscn`と各スクリプト。動的生成部品はスクリプト側を調整|
|探索HUD|`exploration_hud.gd`。共有部品と画面固有配置は[構成](ARCHITECTURE.md)を参照|
|補給|`supplies.tscn`と`supplies.gd`。ランダム位置選択とフィールド定義の経路を確認し、Markerの変更だけで出現位置が固定されると考えない|
|弾・重力場|対応するcombatシーンとスクリプト。武器定義から渡す性能と見た目を分けて調整|

論理画面は1120×800。探索の部屋サイズは画面サイズに限定せず、カメラ追従を使う。Arenaのコンテナは原点・等倍を維持する。壁の衝突は軸平行矩形で、画像寸法や見た目の高さと分ける。プレイヤーの半径を含め、開始点・扉到着点と通行幅を確認する。

F5はタイトルからの起動。F6は選択シーンの単体実行で、任意の部品だけではゲーム進行は始まらない。データ変更後は[検証手順](TESTING.md)から対象テストと通常倍率の画面確認を行う。
