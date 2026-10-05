# 不採用・旧版の素材

携帯工房の開くSE：[採用までの制作記録](../../docs/planning/EXPLORATION_UI_COMP.md)。workshop-open/v1・v2は2026-10-05に採用された結合音の原本と再現レシピ、legacy-synthは置換前の合成実装。採用音はassets/audio/se/fw_workshop_open_energy_01.wav。

区分: 素材の置き場所。状態: 運用中（2026-10-04開始）。定義する範囲: ユーザーの最終確認で不採用になった候補と、新しい素材の採用で使われなくなった旧版。関連する正本: [候補素材の運用](../candidates/README.md)

`.gdignore` を置いているため、Godotはこのフォルダーをインポートしない。Web書き出しからも除外している。ゲームから参照していないことは `tests/asset_zones.gd` が確認する。

```
assets/retired/<asset_id>/v<N>/
  <素材ファイル>
  preview.json   status: rejected（不採用）または replaced（旧版）
  review.md      レビュー係の判定と、ユーザーの判断・理由
```

削除はしない。プロンプト・判定・不採用の理由は、次の生成で同じ失敗を避けるための資料として残す。2026-10-04より前の旧版（例: `assets/audio/se/` の `fw_lizard_spit_01/02`）は、まだ移していない。移すかどうかは1件ずつユーザーが判断する。
