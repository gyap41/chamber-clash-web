# 固定2部屋の実装と検証

2026-09-21。敵なしの工房/作業室をFキーの扉で接続した。既存フィールド切替を利用し、部屋ID/扉ID/到着位置/訪問済み情報を追加。部屋移動で資源やタイマーを初期化しない。両部屋の床と壁は既存素材を再利用、扉は仮の図形。追加素材生成なし。

exploration_roomsの20回連続移動・資源とタイマー保持・接続/到達性・入力解除・状態ガード・再挑戦がPASS。exploration_mode / shared_combat_hud / field_layoutも動作PASS。ヘッドレスの一部は既存と同種の終了時Resource/ObjectDB解放エラーあり。描画あり最終テストはエラーなしで終了。

描画確認で扉が主人公より前に表示される問題を検出し、Playersより前の描画順へ移動。行き先ラベルと頭上名を離した。修正後、両部屋の画像を再生成し、主人公が扉の前で見えることを確認した。

ログ: `.local/exploration-rooms-test.log`、`.local/two-rooms-capture.log` / `two-rooms-capture-errors.log`、`.local/two-rooms-field_layout.log` / `two-rooms-shared_combat_hud.log`。画像: `.local/two-rooms-*.png`（ローカル検証用、Git対象外）。exploration_modeはツール実行出力で確認した。

手動操作感、Web実機、部屋別敵入替、インベントリ、拾得物の再訪、中断保存は未検証/未実装。現行手順は[TESTING](../../../development/TESTING.md)、残課題は[探索ロードマップ](../../../planning/EXPLORATION_ROADMAP.md)。
