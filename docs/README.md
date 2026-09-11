# 資料索引

現行仕様・開発手順は以下を更新します。作業の経緯や過去の実行ログは現行資料へ追記せず、必要な結論と残課題を反映してください。

2026-09-11に完了計画・比較案・音響調査記録を [アーカイブ](archive/2026-09-11/README.md) へ整理しました。現行ルールと過去の記録を区別して参照してください。

|目的|資料|
|---|---|
|開発再開・エージェント共通|[引き継ぎ資料](development/HANDOFF_FOR_CLAUDE.md)|
|起動と操作|[プロジェクトREADME](../README.md)|
|武器・レリック・キャラクター・戦闘ルール|[ゲーム仕様](design/GAME_RULES.md)|
|フォルダーの責務・共通化・拡張方針|[構成ガイド](development/ARCHITECTURE.md)|
|シーンやInspectorの調整|[エディタガイド](development/EDITOR_GUIDE.md)|
|自動テストと描画確認|[検証手順](development/TESTING.md)|
|現在地と今後の開発|[ロードマップ](planning/ROADMAP.md)|
|グリッド細分化・小型重複レリック・バッグ拡張|[細分化計画](planning/FINE_GRID_ROADMAP.md)|
|画像の分類・追加ルール|[アセット一覧](../assets/README.md)|
|画像・SE・BGMの環境設定とAPI連携変更|[AI素材生成環境ガイド](development/ASSET_GENERATION_SETUP.md)|
|音響素材の生成・音量・ループ設計|[AUDIO_BIBLE](AUDIO_BIBLE.md)|
|移植の経緯・古い引き継ぎ・復旧記録|[過去資料](archive/README.md)|

新しい企画は `planning/` に目的・対象範囲・受入条件を書き、採用して実装したルールを `design/` へ反映します。実装手順は `development/`、終了した検討の記録は `archive/` に置きます。

現行資料に矛盾がある場合は最新のコード・カタログを確認し、仕様と残課題を修正します。アーカイブの未実装一覧・件数・環境固有の手順を現在の指示として使用しません。
