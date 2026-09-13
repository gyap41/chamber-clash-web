# Chamber Clash Visual Hub / Web Live

Godot Web実行版のリアルタイム描画と、Reactの一覧・比較・レビューを組み合わせたローカル開発ツールです。
通常ゲームの起動Scene、ゲームのカタログ、所持品、素材原本は変更しません。

## 主画面：追加操作なしで一覧確認

- **武器一覧**：全38武器（現在値）を行に並べ、本体・名前・ショップ価格・占有形状、装備/発射・弾丸/軌道・命中/固有効果・リロードを列に表示します。非売品はゲームのShopCatalogに従います。
- **モーション一覧**：全8キャラ×待機/歩行/回避。「全員の装備武器」、照準、移動方向、回避同期を一括変更します。武器変更時の撮影は不要です。
- **レリック一覧**：デザイン、名前、効果の説明、回転前の占有形状を一覧表示します。

画面内の枠だけを1つのGodot Webエンジンで描画します（上限24枠）。スクロールで外れた枠を解放し、戻った枠は現在のループ時刻に合わせます。初回はWebエンジンとデータパックの読込が必要ですが、その後の表示条件変更はブラウザ内で反映します。
再生/停止、1ステップ（60Hz）、速度、背景、等倍/倍率、枠に収める表示を操作できます。倍率を選ぶと実寸表示へ切り替わります。動作は6秒ループ、seedは719で固定。共通表示条件と装備武器をローカル保存します。
各枠をクリックすると拡大し、上部の共通操作をそのまま使えます。「一覧に戻る」で戻ります。
「判定・銃口」は握り/銃口/弾判定に加え、実シミュレーションの累積ダメージ・存在する弾数・重力場数を表示します。標的は死亡しない検証用です。「固有効果・引き寄せ」以外では標的位置を固定します。ゲーム本体の効果計算は変更しません。

一覧のリアルタイム表示と、従来のCompare/Historyの撮影結果を区別してください。従来CompareはPNG・条件・レビュー記録のために維持しています。ステージの細かな確認とネイティブ最終確認にはGodot版も利用できます。

## 起動

プロジェクトのルートでPowerShellを開きます。

```powershell
# 初回のみ依存をインストールし、ビルド・収集・起動
powershell -ExecutionPolicy Bypass -File tools/visual_hub/start.ps1 -Install
# 2回目以降
powershell -ExecutionPolicy Bypass -File tools/visual_hub/start.ps1
```

表示された `http://127.0.0.1:4178` をブラウザで開きます。起動したPowerShellは使用中そのまま開いておいてください。終了はそのウィンドウで `Ctrl+C` を押します。ブラウザを閉じるだけではサーバーは停止しません。再利用時は同じ起動コマンドを実行してください。すでに起動中なら追加起動せず、URLを開くだけで利用できます。
Node 20.19以上／22.12以上／24以上とnpmが必要です。`-NodePath` または `HUB_NODE` で実行ファイルを指定可能。
既定Nodeが古い場合、ローカルのCodex付属Nodeも確認します。自動ダウンロードはしません。
Godotは `.local/tools/Godot_v4.7.2-stable_win64_console.exe` を使用し、別配置は `-GodotPath` または `HUB_GODOT` で指定します。
現行検証環境はGodot 4.7.2 / Compatibility / WebGL 2、Node 24.19.0です。
Webエンジンは既存の `web-build/index.js`、`index.wasm`、2つのaudio workletを利用します。別PCではGodot 4.7.2のWebテンプレートを導入して通常のWeb出力を先に作成してください。Hub起動時には版の一致を検査します。
初回のnpm取得後は外部サービス不要。ローカル連携は127.0.0.1限定の同一Origin・操作トークン付きHTTPです。
公開API、認証サービス、外部送信はありません。ポート変更は `HUB_PORT`。

Godotだけでも全プレビューを使用できます（Node不要）。

```powershell
powershell -ExecutionPolicy Bypass -File tools/visual_hub/start.ps1 -Mode Native
# Godotエディターでは tools/visual_hub/visual_hub.tscn を開いてF6
```

## 探す → 動かす → 比べる → 修正先

- **Library**：カテゴリ、使用状態、レビュー状態、名前・型付きID・タイプ・タグで絞り込み。24件の静止サムネイル単位。右側で定義・画像・Scene・描画コード・使用元・UIDを確認し、パスをコピー。
- **Compare**：カードから最大4対象を追加。背景、方向、動作、倍率、開始時刻、seedを揃えて静止画または2秒分を撮影。「再生」は現在の対象・動作・条件のフレーム列がなければGodotで準備し、完了後に自動再生します。静止画表示中も再生できます。Godotが実描画した12fpsのフレーム列を一括再生・停止・コマ送り。PNG＋条件、条件JSONの保存・読込に対応。
- **Godotで動かす**：選択IDと条件をGodot版へ渡す。連続試射、任意の時間送り、Stage補助表示、ファイル・フォルダを開く操作はこちら。
- **Review**：制作中・要レビュー・承認済み等、タグ、コメントを「レビューを保存」で確定。承認は対象の内容ハッシュ付き。別画面から変更された場合は競合として保存を拒否。未保存入力は対象切替前に保存してください。
- **Overview**：主要分類の実数、要レビュー、診断、最近の更新。
- **History**：旧撮影を保持。Before/Afterは各撮影の先頭対象を表示。条件差や原本変更は警告。旧画像を現在の描画として扱いません。

ブラウザの画面・検索・選択・比較条件はlocalStorageに保存します。Godot版の設定は `.local/visual-hub/settings.json`。
従来Compareの撮影は独立Godotプロセスで行うため、数秒の待ち時間と撮影ウィンドウが発生します。新しい一覧では撮影を行いません。
時刻は固定刻みへ丸めます。12fpsのフレーム送りと、Godot版の60/120Hzシミュレーション送りを区別してください。

## 現行対応

現数は収集結果から表示し、画面コードに固定しません。2026-09-13検証時点：

|対象|件数|確認内容|
|---|---:|---|
|キャラ|8|実Player描画、4方向、待機・歩行・回避、独立した照準と移動、武器変更|
|武器|38|装備、左右、単発・連射・弾・着弾・リロード、壁と標的、重力場、握り・銃口・判定|
|レリック|35|実HUDサイズと拡大、武器のUI画像も対応|
|ステージ|2|FieldDefinitionとScene、床・壁・Spawn・補給、俯瞰と実戦カメラ、境界別表示|
|行動アイコン|3|実寸と拡大|

リナの回避時間・描画方式を維持。回避の実時間同期／進捗同期、実寸／枠に収める比較を分けています。
静的参照・動的規則・コード生成を区別し、「定義」「素材」「ゲーム対応」「プレビュー対応」は別判定。
1376素材ファイルも補助一覧に収録しました。原画・履歴・テストを分類し、.local/.godot/配布物を現行素材として重複集計しません。
静的未参照は未使用確定ではありません。未知方式は診断と基本情報、可能な静止画像を表示します。削除操作はありません。

## 追加と更新

既存形式の武器は通常どおりゲームの `data/catalog.json` / `data/weapon_visuals.json` と対応素材へ追加し、ゲーム側の対応を検証してから「素材を更新」。Hub画面への手登録は不要です。
JSONへ登録しただけではゲーム対応済みにしません。独自のtype/effect/render方式にはゲーム側の登録が必要です。

- JSON変更・追加・削除：更新で再収集。同じIDの選択・比較は維持。削除IDは比較から除外。
- 画像変更：Godotエディターで再インポート後に更新。Webサムネイルは元画像のハッシュを検査し、古いManifestなら表示失敗を知らせます。
- スクリプト変更：ライブ一覧は「実描画を更新」で再ビルド・再起動します。従来Compareの次回撮影は新規Godotプロセス。Godot版を開いたままの場合はHubを再起動してください。
- 撮影前にも再収集し、内容ハッシュと条件が同じ完成済み撮影だけ再利用。画像、関連素材、描画コード変更で新しい撮影キーになります。

CLIで収集だけ行う場合は `start.ps1 -Mode Update`。自動ファイル監視はありません。

## 保存先と配布分離

|保存先|用途|
|---|---|
|`.local/visual-hub/catalog.json`|再生成できるManifest|
|`.local/visual-hub/thumbs/`|内容ハッシュ付きWebPサムネイル|
|`.local/visual-hub/renders/<hash>/`|対象別PNG、撮影条件、内容版、時刻|
|`.local/visual-hub/web-dist/`|Webビルド|
|`.local/visual-hub/*.log`|収集・撮影・検証ログ|
|`tools/visual_hub/reviews.json`|人が記入するレビュー（Git管理可）|
|ブラウザのダウンロード先|Webから書き出した比較PNG・JSON|

Godot版の「出力先を開く」から専用出力先へ移動できます。既存の `docs/art/reviews` へ撮影を上書きしません。
`.local`、tools、tests、docs、node_modules、package*.jsonはゲームexportから除外。Webソースとnode_modulesは.gdignoreでも分離します。

## 拡張境界

1. `asset_index.gd`：既存データを収集し、`enumerate()` / `detail(id)`。ゲーム定義を手作業で複製しない。
2. `asset_record.gd`：型付きID、参照、状態、対応可否の値だけを保持。`export_catalog.gd` がschema_version=1のJSONへ変換。
3. `preview_registry.gd`：method名とfactoryを登録。adapterの `initialize(record,conditions)` / `advance(dt)` / `finish()` を実装し、bounds・failureを提供。条件変更は初期化から再シミュレーション。単体・比較・Exporterで同じ基盤を使用。
4. `visual_hub.gd` と `web/src/`：UI。Webはゲーム性能やアニメーション計算を持たず、Godot出力を表示。

新しい素材種別はCollectorでRecordを作成し、静止画像ならimage方式を使えます。新描画方式だけRegistryへ追加します。
Manifestにはsource_hash（定義＋依存＋描画コード）、image_hash、参照UID、使用元、診断を出力。レビューは型付きIDとsource_hashへ紐付けます。
全コードハッシュによる無効化は安全側で、描画に無関係なコード修正でも再撮影になる場合があります。

## 検証と制約

```powershell
powershell -ExecutionPolicy Bypass -File tools/visual_hub/start.ps1 -Mode Test
# Nativeの機能検証
.local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/visual_hub.gd
# GPU実描画検証
.local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --rendering-method gl_compatibility --script res://tools/visual_hub/verify_render.gd
```

[今回の実測結果](../../docs/archive/2026-09-13/VISUAL_HUB_HYBRID.md)を参照してください。
汎用のScene全ノード検査、完全依存グラフ、音声試聴、UI全状態、単独VFXライブラリ、自動監視、AI生成・QAなどは後続です。Web内のリアルタイム描画は新しい一覧で実装済みです。
従来Compareの撮影画像は640×400/対象です。新しいライブ一覧は表示枠に応じた描画解像度で、クリックして拡大できます。
AI・補給・ログ・音声を伴う対戦本体は開始せず、実描画に必要なPlayer/CombatSession/Stageだけを隔離して使います。


### 従来Compareの比較対象・条件変更

追加・除外・条件変更は比較枠へ即時反映し、古い撮影画像は表示から外します。600msの操作待ちの後に最新条件を自動撮影します。Godotの起動・描画には数秒かかり、その間は素材サムネイルと更新表示になります。連続変更時は進行中の旧結果を表示せず、その処理が終わってから最新条件を撮影します。再生中なら更新後に再開、停止中なら停止を維持します。
異分類も配色・形状の比較用に追加できます。動作が適用される対象名を表示し、レリック・ステージは静止表示と明記します。静止素材だけの場合は再生・動作・方向・装備武器を無効にします。実寸比較と枠に収める比較の寸法は同義ではありません。


## ライブ描画の更新・構成

原本JSON・画像・スクリプト変更後は「素材を更新」だけでなく、一覧の「実描画を更新」を実行してください。最新の原本からHub専用PCKを再生成してページを再起動します。変更前のパックが残る場合は警告します。初回・起動スクリプトでも再生成します。
`node tools/visual_hub/web/build-live.mjs` で単独ビルド可能です。

`live_preview.gd` がJavaScriptBridgeでWebの表示枠・条件を受け取り、既存Registry/Adapterを配置します。1つの非表示iframeで描画したアトラスを、描画完了直後に各カード内のCanvasへ転送します。映像はカードと一緒にスクロールするため、WebとGodotの座標更新の時間差で白い背景が露出しません。レイアウト世代が古いフレームは転送しません。各枠にWebエンジンを個別起動しません。
`pack_live.gd` は通常ゲームの検証用エクスポートを基に、Hubのスクリプト・収集に必要な原本を追加した専用PCKを作成します。Hubの起動Sceneと透明描画設定は専用パック内部だけに適用し、project.godotを変更しません。
`.local/visual-hub/live/` が専用出力先です。ゲーム配布のWebプリセットは引き続きHubを除外します。Webの描画差はネイティブ版でも確認してください。

[Web Live実装・検証記録](../../docs/archive/2026-09-13/VISUAL_HUB_WEB_LIVE.md)。
