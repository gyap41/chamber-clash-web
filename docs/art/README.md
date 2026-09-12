# 画像・素材の整理入口

2026-09-12。設定資料は必要なものとして保存し、ゲーム素材・設定・確認資料・原画を分離した。ファイルの削除や追加の有料生成は行っていない。

|分類|置き場所|扱い|
|---|---|---|
|ゲーム使用素材|[assets/first-workshop](../../assets/first-workshop/README.md)|必要。現行キャラ・武器・床・遮蔽物・VFX・行動アイコン|
|設定資料|[settings](settings/README.md)|必要。通常等身、採用設定、初稿、世界観・デザイン案|
|採用結果の確認資料|[reviews](reviews/README.md)|必要。まとめ画像、比較GIF、実装・加工の説明|
|制作指示・再加工資料|[production](production/README.md)|必要。プロンプト、参照、加工レシピ。個別のレシピはreviewsにも保存|
|生成原画・API履歴|[assets/generated](../../assets/generated/README.md)|必要。PNG原画・同名JSON・使用量・成否不明の記録|
|テスト用の旧素材|[tests/fixtures/art](../../tests/fixtures/art/README.md)|必要。現行描画では未使用でも自動テストで参照|
|不要候補の退避|[unused-candidates](../archive/2026-09-12/art-organization/unused-candidates/README.md)|現行ゲームには不要。連番画像、置換済み素材、原画の旧importファイル|

設定の初稿も削除候補に入れていない。初稿と採用版の違いは各READMEと[キャラクター美術定義](../design/CHARACTER_BIBLE.md)で区別する。

移動前後の全パス・サイズ・ハッシュは[移動台帳](../archive/2026-09-12/art-organization/relocations.json)。生成時のJSON・使用量台帳は履歴として変更せず、その中の古い参照先はこの移動台帳で追跡する。

配布時：現在のWebエクスポートはdocs・tests・tools・生成原画を除外する。未接続の音響サンプルと旧リナ検証スクリプトも明示除外。検証用エクスポートの内容一覧で混入がないことを確認済み。保管ファイルは開発PCの容量を使うが、この設定の配布パックには入らない。新しい配布プリセットを追加する場合も除外設定を引き継ぐ。
