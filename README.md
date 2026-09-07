# CHAMBER CLASH Godot移行 第1版

Godot 4.5.1 Standardでproject.godotをインポートし、F5で開始。
GDScript / Compatibility。現行Web版の完全移植ではなくM1のローカル対戦検証版です。

- P1: WASD移動、F射撃、Space回避、V近接、Rリロード、E銃切替
- P2: 矢印移動、J射撃、K回避、L近接、Pリロード、O銃切替
- Esc: 一時停止。決着後Enter: 再戦。
- 両者自動照準。弾切れ時は手動リロード。通常弾と跳弾の残弾は検証版では共通。

計画・受入条件・未実装項目はdocs/MIGRATION_PLAN.md。
全採用PNGはassets、移植元の全数値はdata/catalog.json。
legacy-webには移植元v9のソース・テスト・素材を保持しています。
ブラウザ/Windowsの実機確認、公開切替は未実施です。
