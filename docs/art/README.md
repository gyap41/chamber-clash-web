# 素材制作の必読入口

グラフィックの使用／未使用候補は[素材の使用状況](../../assets/README.md#グラフィックの使用状況2026-10-07)と[画像付き一覧](../../assets/graphics_inventory.html)を参照。フォルダー名だけで旧素材と判定しない。

区分: 共通制作手順と資料索引。状態: 運用中。敵・ボス・ステージ・キャラクターの生成・差し替え前に読む入口。詳細規格の正本は以下のリンク先に置き、ここへ複製しない。

## 生成前の読み順

1. 最新の依頼、対象実装、既存素材と対象の制作記録を確認する。
2. [画風の共通規格](VISUAL_STYLE_GUIDE.md)を読む。リナ基準の画風は採用済みだが、暫定数値や未採用試作まで確定仕様にしない。
3. 次の表から対象の資料を順に読む。複数の種類を制作する場合は、それぞれの行を確認する。
4. 生成する場合は[生成環境](../development/ASSET_GENERATION_SETUP.md)と利用するツールの手順（[画像CLI](../../tools/README.md)、[音響CLI](../../tools/asset_generator/README.md)）を読む。内蔵画像生成でも対象別の制作規格は省略しない。
5. 対象の制作記録へ下の確認欄を埋め、必要な素材と今回の範囲を確定してからプロンプト作成・生成へ進む。
6. 生成物は[候補素材](../../assets/candidates/README.md)として置き、[機械チェック](../../tools/asset_check/README.md)と[レビュー基準（下書き）](ART_BIBLE.md)で判定してから、ユーザーがゲーム内で最終確認する。不採用・旧版は `assets/retired/` へ分ける。

|対象|必読資料と読む順番|記録先|
|---|---|---|
|通常敵|[敵制作テンプレート](ENEMY_CREATION_TEMPLATE.md) → [敵・ボス制作計画](../planning/ENEMY_BOSS_ART_PLAN.md) → 対象実装|[production](production/README.md)の敵別台帳|
|ボス|[ボス制作テンプレート](BOSS_CREATION_TEMPLATE.md) → [敵制作テンプレート](ENEMY_CREATION_TEMPLATE.md) → [敵・ボス制作計画](../planning/ENEMY_BOSS_ART_PLAN.md) → 対象実装|productionのボス別仕様票・攻撃対応表・素材/SE台帳|
|ステージ・壁・扉・家具・照明|[ステージ制作テンプレート](STAGE_CREATION_TEMPLATE.md) → [素材規格](STAGE_ASSET_GUIDE.md) → [データ・接続定義](../development/STAGE_TEMPLATES.md)|productionのステージ別仕様票と派生レシピ|
|キャラクター|下記の制作前確認 → [キャラ美術定義](../design/CHARACTER_BIBLE.md) → [Actor表示](../development/ACTOR_ANIMATION.md) → 使用方式の手順|既存の[制作・比較記録](reviews/README.md)。新規対象はproductionへ|
|SE・BGM|対象実装 → [音響基準](../AUDIO_BIBLE.md) → [音響manifest](../../assets/audio/asset_manifest.json) → [音響CLI](../../tools/asset_generator/README.md)|音響manifestと対象制作記録|

## キャラクターの制作前確認

- キャラ美術定義で種族・衣装・色・識別点を確認し、ゲーム用の低頭身素材と通常等身の設定画を区別する。
- 対象コードと登録データから、従来の4方向パーツ表示の修正か、8方向リグの制作かを決める。4方向の仕様を8方向の必要素材数や武器の重なりに流用しない。
- 8方向リグは[共通ビルダーの手順](../../tools/character_rig/README.md)と[リナの制作記録](reviews/rina-parts-2026-09-25/README.md)を読む。5向きの描き分け、反転、頭・胴・腕・揺れ物の分割、原点・接続点を確認する。リナ固有の試作や生成回数を他キャラへの承認として扱わない。
- 制作前に方向、待機・移動・回避・攻撃、武器の分離、画像寸法、通常表示寸法、接地原点、左右反転可否、既存素材の流用と不足分を記録する。
- 通常倍率と拡大、連続再生とコマ送り、左右・前後・斜め、移動と照準の組合せで確認する。生成済み・本編仮接続・動作確認・ユーザー採用を分ける。

## 制作記録へ残す生成前確認

ステージでは、[環境の動きを同時に制作する基準](STAGE_CREATION_TEMPLATE.md#環境の動きを同時に制作する基準)も必須。水・炎・光などの動きを素材制作時に設計し、必要な分離素材やマスクと実装を同じ工程で用意する。

既存の対象別READMEに次を記入する。毎回独立したメモを増やさない。

|確認項目|記録内容|
|---|---|
|読了資料|共通規格、対象別テンプレート、実装・ツール手順のパスと確認日|
|対象と方式|対象ID、使用コード・データ、採用仕様と試作の区別|
|必要素材と不足分|方向・動作・パーツ、寸法・原点・接続点、流用する原本|
|今回の範囲|生成する素材・枚数、参照画像、依頼で認められた範囲|
|確認方法|通常サイズの比較場所、動作・接続の確認、未確認事項|

これは生成前の作業手順であり、APIが読了を自動判定する仕組みではない。資料整理・設定確認だけの依頼では生成しない。

## 素材・記録の配置

2026-09-12。設定資料は必要なものとして保存し、ゲーム素材・設定・確認資料・原画を分離した。ファイルの削除や追加の有料生成は行っていない。

|分類|置き場所|扱い|
|---|---|---|
|ゲーム使用素材|[assets/first-workshop](../../assets/first-workshop/README.md)|必要。現行キャラ・武器・床・遮蔽物・VFX・行動アイコン|
|設定資料|[settings](settings/README.md)|必要。通常等身、採用設定、初稿、世界観・デザイン案|
|採用結果の確認資料|[reviews](reviews/README.md)|必要。まとめ画像、比較GIF、実装・加工の説明|
|制作指示・再加工資料|[production](production/README.md)|必要。プロンプト、参照、加工レシピ。個別のレシピはreviewsにも保存|
|生成原画・API履歴|[assets/generated](../../assets/generated/README.md)|必要。PNG原画・同名JSON・使用量・成否不明の記録|
|候補（未採用）・不採用／旧版|[assets/candidates](../../assets/candidates/README.md) / [assets/retired](../../assets/retired/README.md)|2026-10-04開始。ゲームから参照しない（tests/asset_zones.gdで確認）。候補は起動引数でゲーム内に差し替えて試せる|
|テスト用の旧素材|[tests/fixtures/art](../../tests/fixtures/art/README.md)|必要。現行描画では未使用でも自動テストで参照|
|不要候補の退避|[unused-candidates](../archive/2026-09-12/art-organization/unused-candidates/README.md)|現行ゲームには不要。連番画像、置換済み素材、原画の旧importファイル|

設定の初稿も削除候補に入れていない。初稿と採用版の違いは各READMEと[キャラクター美術定義](../design/CHARACTER_BIBLE.md)で区別する。

移動前後の全パス・サイズ・ハッシュは[移動台帳](../archive/2026-09-12/art-organization/relocations.json)。生成時のJSON・使用量台帳は履歴として変更せず、その中の古い参照先はこの移動台帳で追跡する。

配布時：現在のWebエクスポートはdocs・tests・tools・生成原画を除外する。未接続の音響サンプルと旧リナ検証スクリプトも明示除外。検証用エクスポートの内容一覧で混入がないことを確認済み。保管ファイルは開発PCの容量を使うが、この設定の配布パックには入らない。新しい配布プリセットを追加する場合も除外設定を引き継ぐ。

[総合索引](../README.md) / [資料の更新先](../DOCUMENTATION_GUIDE.md) / [全Markdown索引](../CATALOG.md)
