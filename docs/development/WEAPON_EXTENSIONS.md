# 武器・演出・特殊効果を追加する

2026-09-13。弾・VFXの共通構造を実装済み。既存性能と演出は別に管理する。

## 追加先

|変更|入口|
|性能・入手条件|data/catalog.json の guns、weapon_catalog.gd の対応ID一覧、weapon_shapes.gd の占有形状|
|本体画像・倍率・握り点・銃口|data/weapon_visuals.json の weapons → body|
|主弾・回転・軌跡|同じ武器の bullet、bullet_size、spin、trail|
|発射・命中・反射・分裂|families の共通設定、武器側で muzzle / hit / bounce / split を上書き|
|リロード|reload_style（mechanical / charge / rune）、任意の reload_start / reload_complete 演出|
|画像とコマ|effects の名前付き定義。texture / duration / size / frames / anchor|
|独自の描画・複雑な動き|effects の scene に WeaponEffectInstance 派生シーンを登録|
|新しいゲーム上の効果|性能側 guns の behaviors に WeaponBehavior 派生スクリプトのパスを登録|

名前付きの画像演出なら戦闘コードへ武器IDの分岐を追加しない。共通系統を参照し、違う項目だけ武器側で上書きする。新規IDを追加した場合はショップ抽選・価格・占有形状・説明の整合も確認する。

## 設定例

```json
{
  "family": "energy",
  "bullet": "res://assets/first-workshop/projectiles/06.png",
  "bullet_size": [22, 5],
  "trail": "rail",
  "spin": 0,
  "reload_style": "charge",
  "hit": "impact_energy"
}
```

body の grip / muzzle は切り出した画像上の0〜1座標。body.scale は戦闘中の倍率で、UIの枠サイズは変えない。従来のEQUIPMENT_POINTS/EQUIPMENT_SCALEはこの設定から作る互換参照。基準ピストルだけは同じ設定内のfixed_width/offsetで既存の表示を維持する。

## 専用演出シーン

`scripts/visuals/weapon_effect_instance.gd` を継承する。configure(event, definition)で入力を受け、advance(dt)で進めて存続中ならtrueを返す。独自の_process、Timer、ゲーム乱数を使わず、戦闘の結果を書き換えない。既定クラスはdurationに達したら終了する。

共通処理がポーズ／結果画面中の停止、ラウンド切替の削除、同時表示上限を管理する。reload_startの専用効果は開始時の実装填時間を使用し、所有者と動作トークンが一致する完了／中断で消える。開始時に渡された弱参照が有効なら所有者の位置に追従する。細かな追従点・独自動作は派生シーンで扱う。既定リロードは武器に追従するコード描画で、画像の追加生成なし。

## ゲーム上の特殊効果

`scripts/combat/weapon_behavior.gd` を継承し、`on_event(kind, context)` を実装する。登録は性能カタログの `behaviors` 配列。現在の通知は fire、launch、hit、bounce、reload_start、reload_complete、reload_cancel。fireは最初の射撃処理1回、launchは実際の各弾（遅延・派生を含む）、hitはダメージが通った接触を指す。

context.actorは所有者、実ゲーム内ではcontext.sessionから戦闘サービスを利用できる。launch/hit/bounceはprojectile、hitはtarget、reload_completeは実装填amountも渡す。インスタンスは通知ごとに生成するので、持続状態はactorまたはprojectileへ保持する。派生を生む効果はdepthや由来を確認して再帰生成を防ぐ。個別の新しい能力には専用テストが必要。

既存の追尾・反射・分裂等は従来の戦闘処理を維持している。すべてを新しい仕組みに書き換えたわけではない。新規ルールは登録されたスクリプトへ分け、移行は必要な範囲で行う。

## 制約と確認

表示用visual_weapon/visual_variantは攻撃IDと別で、紙片・星くず・葉を生成しても元の数値計算は変えない。通常弾の寿命切れ、除去、命中、反射、分裂は別の通知。弾の周囲の敵味方・危険・仮レリック識別リングは表示しない。当たり判定は維持する。

標準演出40個、独自シーン40個、汎用粒子650個、弾ごとの軌跡は最大24点（設定値は8〜18点）を上限とする。現在の最長はアークレールの100px。武器プロファイル未指定は共通系統へ、任意の画像が欠けた場合は代替画像へフォールバックするが、正式登録素材の欠損は検証で不合格にする。

`tests/weapon_visual_events.gd`：既定値・装填一回性・取消・派生元・遅延射撃・専用シーン・特殊効果登録。
`tests/weapon_visual_assets.gd`：全38武器の本体／弾／8系統VFXと派生素材の実在。
`tests/combat_visuals.gd`：発射・反射・着弾・分裂・停止・上限。

確認画像と動画は [弾・VFXの導入記録](../art/reviews/projectile-effects-2026-09-13/README.md)。

## 弾の寸法と飛行表現

`bullet_size` は表示枠で、通常は画像比率を維持する。`fit: "stretch"` の場合だけ縦横独立で枠へ合わせる。`trail_length`（世界px）、`trail_width`（世界px）、`trail_samples`（2〜24）で軌跡を設定。`thruster` は噴炎の長さ。`motion` は `flutter` / `pulse` / `bubble`、`spin` はラジアン毎秒。bubble は実際の弾速から伸縮を決め、ゲーム判定は変更しない。軌跡は世界座標で保持するため画像の回転・伸縮から独立する。

`muzzle_scale` と `impact_scale` は武器別の演出倍率。variants の `impact_scale` は小包などの倍率を追加する。破片は元武器の色を保ち、噴炎・脈動・長い軌跡は引き継がない。

接触半径は性能側 `data/catalog.json` の `projectile_radius`、最終小包は `parcel_radius`。省略時は従来の種別既定値、発射時 opts.radius は最優先。描画寸法や残光から半径を自動算出しない。変更時はかすり接触、壁、派生弾、爆風の重複命中を検証する。

## 持続場のネイティブ粒子とシェーダー

重力場は `gravity_legendary.gd` に描画を分離。CPUParticles2D は speed_scale=0 と request_particles_process(dt) で戦闘時間に同期し、シェーダーにも effect_age を渡す。独立した実時間や TIME で進行させない。ShaderMaterial は場ごとに作り、親の削除で描画一式も消す。screen texture を読む際はコピー範囲・複数効果の重なり・カメラを含めて実描画を検証する。現在は互換描画でビューポートコピーを使用するため、同時場数が増える変更では負荷測定も必要。
