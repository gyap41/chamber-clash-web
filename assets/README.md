# アセット分類

画像本体は再生成・加工せず、用途ごとに移動しています。`.import` も一緒に管理し、Godotの再インポートで移動後のキャッシュを生成します。

|配置|素材|用途・対応|
|---|---|---|
|`characters/`|`fighters.png`|4列×2行。プレイヤー表示と選択カード。キャラ定義の `cell` で対応|
|`weapons/`|`weapons.png`|4×4。武器ID 0〜15|
|`weapons/`|`weapons-extra.png`|2×2。武器ID 16〜19|
|`effects/`|`projectile-sprites.png`|追加武器の弾アニメ。切り出し矩形は `scripts/visuals/projectile_art.gd`|
|`effects/`|`weapon-effects.png`|戦闘演出。`scripts/visuals/combat_visuals.gd` から参照|
|`fonts/`|`ipag.ttf`|保存済み日本語フォント。現行シーンからの直接参照なし。適用時にライセンス表記も確認する|
|`reference/`|`portraits.png`, `party.png`|現行Godotコード・シーンから参照されない移植元素材。比較/将来検討用に保存し、`.gdignore` と配布除外で区別|

現在の音は `scripts/audio/sound.gd` の合成処理です。生成サンプルは `audio/se/` と `audio/bgm/` に保存済みですが、ゲームへ未接続です。設定は [素材生成環境](../docs/development/ASSET_GENERATION_SETUP.md)、音響台帳は `audio/asset_manifest.json` を参照してください。UI画像は `ui/`、背景は `environments/`、キャラ別の素材が増えたら `characters/<character_id>/` とします。用途が生じる前に空の分類を増やす必要はありません。

追加時は安定した英小文字のファイル名を付け、この一覧に利用先・シート構成・出所・利用条件を記録します。既存素材の入手元と権利情報は、この整理では新たに確定していません。未使用だけを理由に元データを削除せず、採用を取りやめた素材は `reference/` で区別します。
