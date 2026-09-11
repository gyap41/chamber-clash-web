# 購入経済試作の実装・検証日誌

2026-09-11、基準014f55f。開始時の変更は未追跡docs/design/concepts/のみで、同ディレクトリは読み書き・追加対象にしていない。

1. AGENTS.md・指定7資料・全40品の性能/形状・戦闘処理を確認し、採用仕様へ価格/抽選率を先に記録。
2. 基準の一括実行はサンドボックスのuser://ログと証明書ストアの権限エラーで失敗（222034）。
   通常権限環境で再実行し40本成功（run_tests-20260911-222101.log）。テスト判定を緩めていない。
3. 取得元/実支払額/カードID、不可分な購入・売却、無料確保を実装。purchase_economy単独成功。
4. ショップUI・CPU・有料拡張・5本先取を接続。旧無料報酬/自動成長前提のテストを新仕様へ置換。
   中間一括222846では旧前提の失敗を検出。223137では41本中character_selectの固定2武器購入前提のみ失敗。
   キャラ選択テストは価格不定の武器2個を強制購入するfixtureを、予算内の小型2品購入へ変更した。
5. economy_roundsで20シード×9戦×2人のCPU予算・配置、無料持ち帰り・最終戦境界を検証。
   shop_uiで実GUIマウス入力による購入/売却/商品更新/無料確保を検証。どちらも単独成功。
6. 提示済み改造は着脱で無料再抽選しないよう保持。旧報酬回数状態は除去し、purchase_countsへ整理。
7. 最終一括run_tests-20260911-223954.log：43本（headless42＋描画1）PASS、終了0、ERROR/WARNING/FAILなし。
   CHAMBER_SCREENSHOT=.local/logs/purchase-economy.png。preparation/expansion-valid/planet-nine-cellsを目視した。

戦闘性能・形状・フィールド抽選率は変更していない。人間の実プレイ、5本先取の長さ、価格バランスは未確認。
現行の手順・結果はdocs/development/TESTING.md、残課題はdocs/planning/ROADMAP.mdに管理する。

## 後続：武器の最低2マス化

継続使用できる武器は最低2マスという依頼により、C武器のP-12/ダブルバックを横2へ変更。現在は使い捨て武器なし。
価格・射撃性能は変更しない。全20武器の最低面積をfootprint_balanceへ追加し、既存の混在配置/ドラッグfixtureを更新。
run_tests-20260911-224659.log：43本（headless42＋描画1）PASS、終了0、ERROR/WARNING/FAILなし。
人間の実プレイ未確認。concepts資料には触れていない。
