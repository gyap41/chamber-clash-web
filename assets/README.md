# アセット分類

素材の新規生成・差し替えは[素材制作の必読入口](../docs/art/README.md)から始める。

## グラフィックの使用状況（2026-09-29）

[画像付きの分類・検索一覧](graphics_inventory.html) / [全画像と参照元の台帳](graphics_inventory.json)

今回は画像を移動・削除せず、現行のコード・データと開発資料から使用状況を分類した。以前のフォルダー名や「必要」という見出しだけでは現在の使用を判断しない。

|分類|件数|扱い|
|---|---:|---|
|ゲーム側に画像参照あり|196|コード・シーン・データと、それらが参照するJSON／tresから画像参照を検出。未実行の分岐も含む|
|ゲーム側の動的読込候補|265|パス連結・書式付きパスの対象フォルダー。実際に使う画像より広く含む|
|ツール・テスト・試作から参照|201|制作・比較・検証用。動的なフォルダー参照も含む|
|生成原画|125|加工元と生成履歴を保管。ゲーム用コピーとの重複でも保持|
|旧素材・履歴|635|archive・reference内の画像。旧比較や再加工に必要なものも含む|
|設定・比較・制作資料|501|設定画、スクリーンショット、比較GIF等|
|旧Web版|7|legacy-web内の画像|
|ゲーム側参照未検出・要確認|42|未使用候補。削除可能と確定した意味ではない|

合計1,972件。同一バイト列の重複はSHA-256で74組。PNG/JPEG/WebP/SVG/GIF/BMPを対象とし、`.local`、`.godot`、依存パッケージ、Webビルド等は除外。音声・動画・フォント・シェーダーと画像のimportファイルはこの画像件数に含めない。

### 今回確認した主な区別

- `assets/first-workshop/root-runner-prototype/`：名前はprototypeだが、苔玉コガネの現行描画は `moss-parts-v1.png`、`tackle-parts-v1.png`、`directions-v1.png` を参照する。フォルダー全体を旧素材として移さない。
- `assets/first-workshop/rina-run-8dir/`：登録JSONから動的読込。Vキー／`--rina-run`で使う仮接続であり、全キャラの既定素材とは区別する。
- `assets/stages/ashen-foundry-v2/props/` と `exploration-kit/`：書式付きパスとAtlasTexture経由の読込がある。画像名の単純検索だけで未使用と判定しない。
- `assets/ui/hud/relic_00.svg`〜`relic_34.svg`（35件）と `dodge.svg`・`melee.svg`・`pulse.svg`（3件）：旧仮素材。現行skinはPNGを参照する。`fallback.svg`は現在もskinから参照されるので保持する。
- `assets/weapons/`の旧シート2件と `assets/effects/`の旧シート2件：ゲーム側参照未検出。Web配布除外設定とも一致する。
- `assets/first-workshop/muzzle.png`・`impact.png`：Web配布除外済み。制作ツールのフォルダー参照候補として残るため、本編使用と扱わない。
- `assets/generated/`：原画と実行用atlasが同一内容の場合がある。原画・同名JSON・使用量台帳は制作履歴として一緒に保持する。

### 判定の限界と次の整理方法

この台帳は静的な文字列参照の調査であり、タイトルからの到達性・実行中の読込・目視採用は検証していない。コメントや未使用コードの参照も含む。任意の文字列組立て、外部ツール、裸のファイル名などを完全には追跡しない。配布除外は現在のWebプリセットのパターンとの照合であり、実際のPCK内容を検査した結果ではない。

移動・削除の対象を選ぶときは、画像一覧で比較し、生成原本・再加工レシピ・テストの必要性を確認する。移動するなら画像とimportの対応、コード・資料の参照、旧パスとハッシュの台帳を更新する。今回の分類には一括削除機能を設けていない。

再調査: `python tools/graphics_inventory.py`。更新漏れの検査: `python tools/graphics_inventory.py --check`。件数を変える素材追加・削除後はこの概要も更新する。

## 素材フォルダーの案内

|配置|素材|用途・対応|
|---|---|---|
|`characters/`|`fighters.png`|4列×2行。プレイヤー表示と選択カード。キャラ定義の `cell` で対応|
|`weapons/`|`weapons.png`|旧4×4シート。現行の専用武器画像はfirst-workshop/equipmentとweapon_catalog.gdを参照|
|`weapons/`|`weapons-extra.png`|旧2×2シート。採用画像の対応はweapon_catalog.gdを参照|
|`effects/`|`projectile-sprites.png`|旧弾シート。今回の調査ではゲーム側参照未検出・Web配布除外|
|`effects/`|`weapon-effects.png`|旧演出シート。今回の調査ではゲーム側参照未検出・Web配布除外|
|`fonts/`|`ipag.ttf`|保存済み日本語フォント。project.godotの既定フォントから参照。ライセンス表記を保持する|
|`reference/`|`portraits.png`, `party.png`|現行Godotコード・シーンから参照されない移植元素材。比較/将来検討用に保存し、`.gdignore` と配布除外で区別|

現在のSEは `scripts/audio/sound.gd` の生成音源と合成処理、BGMは `scripts/audio/music.gd` の採用3曲です。設定は [素材生成環境](../docs/development/ASSET_GENERATION_SETUP.md)、音響台帳は `audio/asset_manifest.json` を参照してください。UI画像は `ui/`、背景は `environments/`、キャラ別の素材が増えたら `characters/<character_id>/` とします。用途が生じる前に空の分類を増やす必要はありません。

2026-10-04以降の生成物は、ユーザーの最終確認まで `candidates/`（未採用・ゲームから参照しない・書き出し除外）に置き、不採用と旧版は `retired/`（インポートしない）へ移す。手順は[候補素材の運用](candidates/README.md)。

追加時は安定した英小文字のファイル名を付け、この一覧に利用先・シート構成・出所・利用条件を記録します。既存素材の入手元と権利情報は、この整理では新たに確定していません。未使用だけを理由に元データを削除せず、採用を取りやめた素材は `reference/` で区別します。
