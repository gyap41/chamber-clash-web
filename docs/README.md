# 資料索引

素材の使用状況・旧素材を調べるときは[画像付き一覧と分類結果](../assets/README.md#グラフィックの使用状況2026-10-07)を参照してください。

敵・ボス・ステージ・キャラクターの生成／差し替えは、まず[素材制作の必読入口](art/README.md)へ。共通画風 → 対象別規格 → 生成前記録の順に確認します。

作業はこのページから始めます。[資料の配置・更新ルール](DOCUMENTATION_GUIDE.md)には仕様追加時の反映先とメモの終了方法、[全ファイル索引](CATALOG.md)にはリポジトリ内のMarkdownを分類して掲載しています。

## 依頼から探す

|頼みたいこと|最初に読む|変更を反映する場所|
|---|---|---|
|世界観・冒険の目的・階層構成を考える|[世界観と5階層案](planning/WORLD_AND_DUNGEON_CONCEPT.md)|planningの提案。現行動作や制作仕様と区別する|
|ボスを設計・制作・レビューする|[ボス制作テンプレート](art/BOSS_CREATION_TEMPLATE.md) → [敵素材の共通規格](art/ENEMY_CREATION_TEMPLATE.md)|ボス別の制作記録、実装済み仕様はGAME_RULES、検証はTESTING|
|敵の素材・アニメーションを作る|[敵素材の制作テンプレート](art/ENEMY_CREATION_TEMPLATE.md) → [敵・ボス制作計画](planning/ENEMY_BOSS_ART_PLAN.md)|art/productionの素材台帳、実装後はACTOR_ANIMATION・GAME_RULES|
|次の作業を進める|[全体ロードマップ](planning/ROADMAP.md) → [探索の工程](planning/EXPLORATION_ROADMAP.md)|該当仕様と残課題|
|戦闘・装備・操作を追加／修正|[ゲームルール](design/GAME_RULES.md)、[アイテム一覧](design/ITEM_CATALOG.md)|designの対象節。検証方法はTESTING|
|敵・ボス・探索の仕様を考える|[探索体験](planning/EXPLORATION_DESIGN.md)、[敵・ボス美術](planning/ENEMY_BOSS_ART_PLAN.md)|提案と採用済み未実装はplanning、実装後はGAME_RULES|
|宝箱・報酬・演出を作る|[報酬と演出](planning/EXPLORATION_REWARDS.md)|採用案、実装済み動作、個別の制作記録|
|画風・グラフィック全体の統一感を見直す|[画風の共通規格](art/VISUAL_STYLE_GUIDE.md) → [画風3案の比較](planning/art-direction-comps/README.md)|共通規格、各テンプレートの参照、適用結果はart/production|
|ステージを作る／素材を直す|[制作テンプレート](art/STAGE_CREATION_TEMPLATE.md) → [素材規格](art/STAGE_ASSET_GUIDE.md)・[データ定義](development/STAGE_TEMPLATES.md)|共通ルールとart/productionの個別記録|
|キャラ・アニメーションを変える|[生成前確認](art/README.md#キャラクターの制作前確認) → [キャラ美術](design/CHARACTER_BIBLE.md)、[Actor表示](development/ACTOR_ANIMATION.md)|設定・実装手順・採用画像の記録|
|UIを変える|[文字説明を減らす共通方針](art/VISUAL_STYLE_GUIDE.md#uiの文字説明を減らす共通方針2026-10-05ユーザー決定) → [対戦HUD](design/BATTLE_UI_C.md)、[準備画面](design/PREPARATION_UI_B.md)、[構成](development/ARCHITECTURE.md)|対象UI仕様。探索固有の操作はGAME_RULES|
|音を作る／変更する|[音響基準](AUDIO_BIBLE.md)、対象実装・音響manifest|音響基準・manifest・試聴結果|
|生成APIやツールを設定する|[生成環境](development/ASSET_GENERATION_SETUP.md) → [画像CLI](../tools/README.md)・[音響CLI](../tools/asset_generator/README.md)|共通設定と対象CLIのREADME|
|バグ修正・リファクタリング|[構成](development/ARCHITECTURE.md)、[検証](development/TESTING.md)、対象仕様|変更した責務・動作・必要な検証方法|
|途中の調査を引き継ぐ|[共通引き継ぎ](development/HANDOFF_FOR_CLAUDE.md)、[一時メモ](notes/README.md)|反映先・未決事項・終了条件を持つメモ|

## 分類から探す

|入口|役割|
|---|---|
|[現行仕様](design/README.md)|動作・性能・UI・キャラ設定|
|[計画と提案](planning/README.md)|次の工程、未実装の採用仕様、検討案|
|[実装と検証](development/README.md)|構造、編集・拡張方法、実行手順|
|[美術と制作](art/README.md)|共通規格、設定画、加工レシピ、採用確認|
|[音響基準](AUDIO_BIBLE.md)|音の方向性、採用状態、試聴基準|
|[一時メモ](notes/README.md)|調査途中・未決質問。正本へ反映したら終了|
|[履歴](archive/README.md)|完了・置換・却下された計画と検証記録|
|[素材](../assets/README.md)・[開発ツール](../tools/README.md)|実ファイル群の使い方|
|[全ファイル索引](CATALOG.md)|各Markdownへのリンクと分類・表題|

新しい依頼のたびに全資料を読む必要はありません。依頼別の入口、対象コード、該当する正本を読み、過去の理由が必要なときに履歴へ進みます。現行資料にも古い記述が残るため、[一次監査の未完了項目](archive/2026-09-22/markdown-audit/README.md)を考慮し、分類だけを正確性の保証としないでください。
