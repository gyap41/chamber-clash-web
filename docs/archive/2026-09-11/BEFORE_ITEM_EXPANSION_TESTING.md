# アイテム追加前の検証記録

以下は当時の検証履歴。最新結果は [TESTING](../../development/TESTING.md)。

## 最新の記録と未完了の受入

拡張の選択→配置の操作案内・購入不可理由表示を改善後、45本（headless44＋描画1）PASS、終了0。
ログ：`.local/logs/run_tests-20260911-230826.log`。ERROR/WARNING/FAILなし。
新規expansion_availabilityで第3準備の20→24マス購入、各準備1回の解除、資金不足、上限、取消無課金を検証。
配置場所なしのfixtureは正規の購入/ラウンド遷移で到達できる形に整え、同テストの単独再実行も成功した。
描画 `.local/logs/expansion-guidance-expansion-valid.png` と `expansion-guidance-planet-nine-cells.png` を目視し、
選択ボタン・配置プレビュー・購入済み理由の収まりを確認。人間の改善後の操作感は未確認。
ユーザーから配置先クリックで購入できたとの回答があり、今回の報告は操作案内の問題として扱う。価格・容量・購入回数制限は変更していない。

### 初回準備表示修正の記録

初回準備の仮P-12表示不整合を修正後、44本（headless43＋描画1）PASS、終了0。
ログ：`.local/logs/run_tests-20260911-230106.log`。ERROR/WARNING/FAILなし。
新規 `initial_preparation.gd` は全8キャラ×Local/CPUの16通りで、キャラ選択から初回準備へ実際に遷移し、
手動refresh前の表示品と所持品の一致、実GUIクリックでの2マス配置、未配置の初期武器がレリック購入前後で不変であることを確認する。
修正前は表示品一致のアサーションで失敗することを確認済み。CPU確定後の準備完了ボタン表示も検証する。
描画テストは実行済み。今回の修正後の人間による実プレイ確認は未実施。

### 武器最低2マス化の記録

後続依頼の武器最低2マス化（P-12/ダブルバックを横2マス）後も、43本（headless42＋描画1）PASS、終了0。
ログ：`.local/logs/run_tests-20260911-224659.log`。ERROR/WARNING/FAILなし。
全20武器が2マス以上であること、全キャラの初期武器＋小型2品、CPU予算/配置、購入・売却・ドラッグを回帰確認。
新しい形状に合わせて混在占有テストとドラッグの空き配置先を更新し、衝突拒否の検証を維持した。
今回は描画テスト実行まで。以下の保存画像の目視は最低2マス化前の記録であり、変更後の人間の実操作は未確認。

### 購入経済導入時の記録

購入制・有料バッグ拡張・5本先取を実装した状態で、2026-09-11に **43本（headless42＋描画1）PASS、終了コード0**。
実行：`powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender`。
Godot：`.local/tools/Godot_v4.7.2-stable_win64_console.exe`。
ログ：`.local/logs/run_tests-20260911-223954.log`。ERROR/WARNING/FAILなし。
基準014f55fも40本成功を再確認（`.local/logs/run_tests-20260911-222101.log`）。

- purchase_economy（新規）：資金不足・控え満杯・二重購入の非破壊拒否、重複個体と売却、無料品0G、武器売却時の改造消去と再購入、更新・古いカード拒否・無料確保。
- economy_rounds（新規）：24マス上限、フィールド武器持ち帰り、満杯時の無料確保候補保持、引き分け・最終戦の境界、20シード×9戦×2人のCPUで資金収支・購入品配置・携行/控え上限。
- shop_ui（新規）：Godotへマウス入力を送り購入・売り切れ・二重入力・クリック配置・売却・更新・無料候補保持/確保を検証。
- bag_expansion：有料拡張の無効配置/取消無課金、実GUIクリック確定、独立した領域、previous深いコピー、CPU、リセット。
- match_progression：5-0/5-4、引き分けで資金/商品/購入数不変、両者同額収入、5勝で次準備を走らせない、タイトル→キャラ→CPU戦完走。
- 既存の個体/効果加算、全武器・改造・戦闘・ドラッグ・控え末尾・GUI境界・音響Resource認識の回帰も成功。

旧無料報酬の取得回数や段階別面積の期待値は、新しい資金・購入・独立面積の検証へ置換した。
幾何配置テストは `tests/helpers/preparation.gd` で4×4の明示的な拡張済みfixtureを作る。
経済・ラウンドテストは実際の購入APIと収入で検証する。戦闘テストの性能アサーションは維持。

### 描画確認済みの範囲

`CHAMBER_SCREENSHOT` を `.local/logs/purchase-economy.png` に指定し、render.gdの各場面を保存。
次の画像を目視確認：

- `.local/logs/purchase-economy-preparation.png`：初期8マス、12G、価格付きショップ、拡張3種、任意の準備完了。
- `.local/logs/purchase-economy-expansion-valid.png`：6マス6G、詳細の接続/課金条件、緑の配置プレビュー。
- `.local/logs/purchase-economy-planet-nine-cells.png`：9マスのプラネタリウム、詳細、控え、ショップの収まり。

既存の縮小/原寸画面、控え末尾、装備ドラッグ、HUD・戦闘・補給・演出の描画も自動実行した。
描画テストは無料報酬前提を拡張済みfixtureに更新し、既存の配置/境界アサーションを維持。

