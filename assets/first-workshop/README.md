# 必要：ゲーム使用素材

このフォルダーには現行ゲームが使う加工済み素材を保存する。設定画・生成原画・旧素材は別保管。

|場所|用途|
|---|---|
|rina-directions|リナの方向別立ち姿・固定パーツ|
|rina-dodge|リナの専用回避ポーズ|
|directional-characters|他7人の方向別立ち姿・固定パーツ・専用回避|
|pistol.png|サービスピストル|
|floor.png、cover.png|床・遮蔽物|
|bullet.png、muzzle.png、impact.png、trail.png|弾・共通VFX|
|ammo.png|弾薬箱|
|dodge.png、melee.png、pulse.png|行動アイコン|

キャラクターごとのmanifestに原画ハッシュ・倍率・切り出し・原点を保存する。直下manifest.jsonは初期制作の加工履歴で、現行キャラ全体の一覧ではない。

[設定資料・確認GIF・原画の入口](../../docs/art/README.md) / [全8人の現行素材説明](../../docs/art/reviews/character-directions-2026-09-12/README.md)

旧characters・chibiと直下の旧アニメは[不要候補](../../docs/archive/2026-09-12/art-organization/unused-candidates/README.md)へ退避。旧twoheadは[テスト用素材](../../tests/fixtures/art/README.md)として保持。制作指示は[production](../../docs/art/production/README.md)、原画と生成記録は[generated](../generated/README.md)にある。

今回の整理でゲームの見た目・性能は変更していない。移動前後は[移動台帳](../../docs/archive/2026-09-12/art-organization/relocations.json)から追跡できる。
