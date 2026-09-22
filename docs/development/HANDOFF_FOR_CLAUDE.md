# 開発引き継ぎ（エージェント共通）

更新: 2026-09-22。参照互換のためファイル名を維持。数値・完了日誌を複製せず、正本へ案内する。

[資料の更新先・寿命](../DOCUMENTATION_GUIDE.md) / [分野別索引](README.md) / [一時メモ](../notes/README.md)

## 再開時に読む資料

1. ルートAGENTS.md、最新Git差分と対象コード。
2. [資料索引](../README.md)、[現在地](../planning/ROADMAP.md)、[現行ルール](../design/GAME_RULES.md)。
3. 探索は[工程](../planning/EXPLORATION_ROADMAP.md)と[検討案](../planning/EXPLORATION_DESIGN.md)。提案を実装済みと扱わない。
4. [構成](ARCHITECTURE.md)、[テスト](TESTING.md)。素材制作時は[ステージテンプレート](../art/STAGE_CREATION_TEMPLATE.md)、API変更は[環境ガイド](ASSET_GENERATION_SETUP.md)。

## 維持する境界

- 対戦main/MatchStateと探索進行は独立。共通のCombatSession・所持品・表示部品を利用する。
- 弾の起点IDは計測、volleyは被弾、depthは派生制限。近接/パルス消去から爆発・分裂を発火させない。
- 役者退役より先に弾・遅延射撃等のowner参照を破棄し、live slotを途中で詰めない。
- 初期サイドアームを仮定しない。テストで必要な武器は明示的に配置/付与する。
- UI入力を戦闘へ流さず、停止理由を独立管理。対人通信へ探索の停止を流用しない。
- 論理1120×800、通常の戦場表示1120×600。探索は倍率1の追従、対戦は全体表示。
- 音響と画像の既存成果を確認し、古い生成上限/接続試験を現在の追加生成指示と解釈しない。

## 検証と履歴

自動テスト成功・通常画面の目視・手動操作/試聴・ユーザー採用は別々に記録する。過去の成功を最新差分全体の確認済み扱いにしない。終了時ObjectDB/Resource警告と動作アサーションを区別する。

コミット/公開状態はGitとワークフローを確認する。履歴の未pushや未実装一覧を現在の事実として扱わない。[整理前の引き継ぎ](../archive/2026-09-22/planning-cleanup/HANDOFF_FOR_CLAUDE.md)。
