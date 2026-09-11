# 現行ルールを維持したリファクタリング

実施日: 2026-09-12。現行指示はAGENTS.md、ルールはdocs/design/GAME_RULES.md。
この記録は完了作業の履歴であり、追加機能や素材生成の指示ではない。

## 変更範囲

- build_grid.gdを追加。開放/占有セル・形状・配置判定・携行武器の読み順を集約し、match_stateとplayerで共有。
- item_identity.gdへ武器トークンの変換と型を考慮した個体比較を集約。MatchStateの既存APIは委譲として保持。
- cpu_preparation.gdへ相性/価格評価・配置・購入方針を移動。準備画面は呼出とログ記録を担当。状態変更は従来のMatchState API経由。
- main.gdの物理更新をパルス演出・追射・プレイヤー・弾・重力場・決着に分割。処理順と逆順走査を保持。
- すり抜け装填の状態変更をplayerへ移動。回避/発動済み/敵弾距離の条件、装填効果を発動しない制約を保持。
- 初期資金は既存Shop.INITIAL_GOLDを参照。バッグ上限・携行上限の参照を共通化。
- ARCHITECTUREの旧「ショップ処理なし」「20レリック」等を現行実装に更新。GAME_RULES/ROADMAP/TESTINGを同期。

武器・レリックの定義、価格、形状、ゲームルール、シーン階層、素材、生成ツール設定は変更していない。
既存の未コミット作業を維持。変更直前のscripts/docsとcatalog.jsonは
`.local/backups/refactor-20260912/`へ保存した。コミットや配布は行っていない。

## 検証

1. 変更前: headless49本PASS、終了0。`.local/logs/run_tests-20260912-000452.log`。
2. Godot 4.7.2 headless editor import: 終了0、構文・参照エラーなし。
3. 追加テストpreparation_boundaries: UIなしの20シード×9ラウンド、資金・装備面積・控え・決着、準備/戦闘間の読み順・占有・仮取得・元データ保持。
4. 変更後: headless50＋描画1の51本PASS、終了0、ERROR/WARNING/FAILなし。
   `.local/logs/run_tests-20260912-001104.log`。
5. `.local/compare_refactor.gd`で保存した変更前CPU・MatchStateと比較。20シード×9準備×2人の360回で、builds/gold/products/next_card_id/temporary/ready/expansion_bought/purchase_countsと乱数状態が一致。
6. Git差分の空白検証に問題なし。catalog.jsonは変更直前と同一。

初回のサンドボックス実行はuser://ログ保存・Windows証明書ストアの権限エラーで失敗。
通常環境で再実行して全件成功を確認。エラーの握りつぶしやTLS設定変更は行っていない。

CPU比較用の一時スクリプトはローカルバックアップが必要。一括ランナーで再現可能な回帰はtests/preparation_boundaries.gdに保存。
描画テストは実行したが、今回のスクリーンショット目視・人間の操作感・対人バランス・配布版の受入は未実施。
有料生成は行っていない。音響テストは保存済みResourceの読み込みのみ。
