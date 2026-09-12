# 資料索引

現行仕様・開発手順は以下を更新します。作業の経緯や過去の実行ログは現行資料へ追記せず、必要な結論と残課題を反映してください。

2026-09-11に完了計画・比較案・音響調査記録を [アーカイブ](archive/2026-09-11/README.md) へ整理しました。現行ルールと過去の記録を区別して参照してください。

|目的|資料|
|---|---|
|画像ファイルの必要／不要候補、設定資料・原画・確認GIFの区分|[素材整理の入口](art/README.md)|
|全8人の現行4方向・歩行・キャラ別専用回避|[キャラクター方向別素材](art/reviews/character-directions-2026-09-12/README.md)|
|リナの現行4方向・歩行・専用ドッジ素材と映像|[リナの現行ゲーム素材](art/reviews/rina-dodge-2026-09-12/README.md)|
|8人の外見・職人設定・通常等身とゲーム用2頭身の対応|[キャラクター美術定義](design/CHARACTER_BIBLE.md)|
|元の種族・識別点を戻した7人の修正設定画、通常等身・低頭身比較|[修正キャラクター設定画](art/settings/character-revision-2026-09-12/README.md)|
|8人の通常等身前後・2頭身設定画の初稿（旧比較案）|[初稿キャラクター設定画](art/settings/character-settings-2026-09-12/README.md)|
|開発再開・エージェント共通|[引き継ぎ資料](development/HANDOFF_FOR_CLAUDE.md)|
|起動と操作|[プロジェクトREADME](../README.md)|
|武器・レリック・キャラクター・戦闘ルール|[ゲーム仕様](design/GAME_RULES.md)|
|現行アイテムの性能・価格・占有形状・バッグ範囲・初期武器|[アイテム一覧](design/ITEM_CATALOG.md)|
|採用した武器10種・レリック15種の提案履歴|[追加提案の履歴](archive/2026-09-11/ITEM_EXPANSION_PROPOSAL.md)|
|フォルダーの責務・共通化・拡張方針|[構成ガイド](development/ARCHITECTURE.md)|
|シーンやInspectorの調整|[エディタガイド](development/EDITOR_GUIDE.md)|
|自動テストと描画確認|[検証手順](development/TESTING.md)|
|現在地と今後の開発|[ロードマップ](planning/ROADMAP.md)|
|グリッド細分化・小型重複レリック・バッグ拡張|[細分化計画](planning/FINE_GRID_ROADMAP.md)|
|画像の分類・追加ルール|[アセット一覧](../assets/README.md)|
|世界観・古代地下工房・探索職人・携帯工房の美術基準|[始まりの工房：コンセプト初稿](art/settings/concepts/first-workshop-2026-09-11/README.md)|
|正式素材の洗い出し・キャラアニメ・武器/レリック美術・API予算|[素材制作計画](planning/ASSET_PRODUCTION_PLAN.md)|
|画像・SE・BGMの環境設定とAPI連携変更|[AI素材生成環境ガイド](development/ASSET_GENERATION_SETUP.md)|
|音響素材の生成・音量・ループ設計|[AUDIO_BIBLE](AUDIO_BIBLE.md)|
|移植の経緯・古い引き継ぎ・復旧記録|[過去資料](archive/README.md)|

新しい企画は `planning/` に目的・対象範囲・受入条件を書き、採用して実装したルールを `design/` へ反映します。実装手順は `development/`、終了した検討の記録は `archive/` に置きます。

現行資料に矛盾がある場合は最新のコード・カタログを確認し、仕様と残課題を修正します。アーカイブの未実装一覧・件数・環境固有の手順を現在の指示として使用しません。
