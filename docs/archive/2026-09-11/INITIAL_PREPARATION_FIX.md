# 初回準備の仮P-12表示不整合

2026-09-11。報告：初回のP-12を配置できず、レリック購入後に別武器へ変わって見える。
原因：main._ready()が仮P-12で準備画面を描いた後、character_select.start_match()がキャラ固有の武器を付与しても表示を更新していなかった。
配置要求は既に所持していないgun:0を送り拒否され、購入時のrefreshで実際の初期武器が初めて表示された。
キャラ/CPUモード確定後にpreparation.begin()を1回呼び、表示と選択を確定済みの所持データへ同期した。

initial_preparation.gdを修正前に実行し、初回の表示と所持品の一致アサーションで失敗を確認。
修正後は全8キャラ×Local/CPUで一致・GUI配置・購入前後の武器不変を検証。
全44本（headless43＋描画1）PASS、終了0。run_tests-20260911-230106.log、ERROR/WARNING/FAILなし。
人間の実プレイ受入は未実施。現在のルール・実行方法はGAME_RULES/TESTINGを参照。
