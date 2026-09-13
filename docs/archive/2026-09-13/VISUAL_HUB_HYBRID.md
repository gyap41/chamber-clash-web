# Visual Hub v1 Hybrid — 実装・検証記録

実施日：2026-09-13。追加資料のGodot → Collector / Manifest → Preview → Webという方向を受け、既存Godot版を保持してHybridへ拡張した。
調査のみの依頼中は実装を止め、その後の「実装計画のマイルストーンを立てて、実施」の指示で再開した。

## マイルストーン結果

|段階|成果|結果|
|---|---|---|
|M1 現状固定|未コミット変更確認、Godot基盤保持、原本・通常入口維持|完了|
|M2 収集と出力|1462件の型付きRecord、参照UID/内容ハッシュ、選択描画、差分キャッシュ|完了|
|M3 Webレビュー|Overview/Library/比較/History、検索・詳細・タグ・判定・コメント|完了|
|M4 ローカル運用|起動・更新・テストCLI、Godotへの条件受渡し、README、配布分離|完了|
|M5 検証|全73回帰、Web6テスト、実描画とブラウザ操作、キャッシュ破損、export確認|完了|

原本のゲームスクリプト、Scene、定義JSON、画像に変更なし。通常main_sceneに変更なし。
既存差分を上書きせず、変更はHub追加と.gitignore/exportフィルタ、npm管理、資料に限定した。コミットは行っていない。

## 今回実行した検証

- `run_tests.ps1`：全73件合格。今回のログ `.local/logs/run_tests-20260913-150027.log`、要約 `.local/visual-hub/full-regression-current.log`。
- `tests/visual_hub.gd`：8キャラの4方向・待機/歩行/回避、38武器各6秒の実射撃・弾・着弾・リロード、重力場、2ステージの隔離、再現性に合格。
- 同テストの専用fixtureカタログで追加ID999・削除・必須項目欠落・欠落画像・未対応方式・再読込・条件保存を検証。実カタログにダミーを追加していない。ログ `.local/visual-hub/native-test-current.log`。
- `verify_render.gd`：Godot 4.7.2 / OpenGL Compatibility / RTX 3070 Tiで実描画。クリック、4対象比較、一時停止のピクセル一致、1ステップ、再開の変化、重力場の再シミュレーション一致、PNG＋条件、ステージ補助線、UIサイズ、アプリ再生成と設定復元、1120×760最小画面に合格。ログ `.local/visual-hub/native-render-current.log`。
- WebのNodeテスト6件：条件とID検証、内容/順序/時刻/seed/フレーム数によるキャッシュキー、レビュー永続化と競合拒否、画像パス制限と古い画像拒否、Origin/Host/token/原本非公開。すべて合格。
- TypeScript型検査とVite本番ビルドに合格。起動スクリプトで古いシステムNodeを避けてNode24.19.0を選択し、ビルド→素材更新→サービス起動を実行。
- `verify_pipeline.mjs`：4武器（4/10/20/37）の連射を開始1秒から24フレーム撮影。PNG640×400/対象、重力場の描画を確認。2ステージ撮影、同条件のキャッシュヒット、故意に壊したPNGの再生成と元画像ハッシュ一致、背景変更による別キー作成に合格。ログ `.local/visual-hub/pipeline-verification.log` とJSON。
- ブラウザで一覧・検索・詳細・4キャラ比較を操作。Godotから4×24枚を撮影。再生→一時停止後にframe11のまま保持し、1コマ操作で4対象すべてframe12へ進むことを確認。PNG＋条件のダウンロード処理が完了。再読込で検索・選択・比較条件、レビューコメント復元を確認。検証用コメントは確認後に除去済み。
- ネイティブ画像、Web一覧・比較画面、重力場・ステージPNGを目視確認。日本語表示、操作バー、スクロール、画像読み込みに問題なし。Webはデスクトップブラウザでの確認であり、全モバイル機種の確認ではない。
- `--export-pack Web` の検証用ZIP819エントリーでtools/tests/docs/.local/node_modules/package.json/package-lock.json非収録を確認。これはゲームデータZIPの検証であり、Webエンジン全体を含む配布起動検証ではない。

実数：キャラ8、武器38、レリック35、ステージ2、行動アイコン3。別区分の素材ファイル1376、合計1462Record。
ファイル数は依存画像を含む補助一覧の数であり、ゲームの独立した論理素材数とは異なる。

## 検出して修正した点

1. GodotのJSON小数表記で60Hzのdtが微小に丸められ、厳密一致で撮影完了を拒否した。許容誤差を小さく限定して60/120Hzへ正規化し、実撮影を再実行した。
2. npm管理JSONがGodotのall_resources exportに混入した。明示除外後にZIPを作り直して非収録を確認した。
3. 元画像の変更と完成撮影の破損を黙ってキャッシュ表示しないようにした。撮影前に再収集し、PNG内容ハッシュを照合して破損分を再生成する。
4. 異なる対象・条件の撮影を「現在の条件」と表示しないよう、差分を表示する。履歴メタデータ破損は他の一覧を止めず診断へ出す。

## 保存された確認画像

- `.local/visual-hub/ui-character.png`、`ui-compare-characters.png`、`ui-compare-weapons.png`、`ui-stages.png`、`ui-minimum-window.png`
- `.local/visual-hub/renders/` 以下の対象別PNG、capture.json、image_hashes
- `.local/visual-hub/game-export-audit.zip`（検証用、配布しない）

以前の `.local/logs/run_tests-20260913-141724.log` や既存美術レビューのテスト結果は今回の実行結果に数えていない。

## 既知の範囲・後続

- WebはGodotの撮影済み画像/12fpsフレーム列。任意の実時間操作、細かなStage補助操作はGodot版へ渡す。外部Web向けのGodot埋込みは実装していない。
- ローカル連携のため127.0.0.1限定HTTPを使用する。外部サービス用HTTP APIは実装しない。LAN共有・マルチユーザー運用は対象外。
- 新規画像はGodot側の再インポートが必要。開いたままのGodot Hubへスクリプト更新は即時反映せず再起動を案内する。
- 汎用のScene全ノード検査、完全依存グラフ、単独VFXライブラリ、UI全状態、音声試聴、自動監視、AI生成/自動QAは後続。
- レビューの未保存入力は対象切替前に保存する。履歴のBefore/Afterは各撮影の先頭対象を確認する簡易表示。
- 全コードハッシュで安全側に無効化するため、無関係な描画コード編集でも再撮影になる場合がある。

運用と拡張の現行手順は [README](../../../tools/visual_hub/README.md) に集約した。
