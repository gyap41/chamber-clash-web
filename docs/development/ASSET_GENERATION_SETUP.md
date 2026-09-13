# AI素材生成環境 設定・連携ガイド

完了：弾・VFXの承認6送信すべて成功、累計72回、今回usage換算$0.63626。ゲーム統合済み。今回の追加生成は終了し、次の送信は現行上限で停止する。

現行承認：弾・エフェクト6シート、追加6送信・保守予約$6、累計最大72送信。ユーザー「お願いします。」で拡張構成を含め承認。CLI上限73（到達前停止）、成否不明2件の予約保持。モデル・API・認証・保存形式は変更なし。1枚ずつ確認し、自動再送はしない。以下の枠は以前の制作履歴。

完了：承認済み10送信すべて成功、累計66回。今回のusage換算$1.0647075。52素材をゲームへ接続済み。この承認分の追加送信は終了。

現行承認（2026-09-13）：ユーザー「お願いします。」により多様な残り26武器・26レリックを計10枚で生成し、ゲームへ統合。追加10回・保守予約10ドル、累計最大66回。CLI上限は回数・予約とも67（到達前停止）。各シートを確認してから次へ送信。過去の成否不明2件は予約保持。モデル・API・保存形式は維持。自動再送・追加候補なし。


素材整理：ゲーム素材はassets/first-workshop、設定・採用レビュー・指示はdocs/artへ分離。原画・生成履歴はassets/generatedに保持し、.gdignoreでGodotインポート対象外。生成先・API・認証・保存形式は変更なし。旧JSONの参照パスは移動台帳で追跡する。[分類と台帳](../art/README.md)。今回の整理では有料生成なし。

現行画像枠：他7人へのリナ基準の展開を承認。方向・回避共通シートを各1枚、計7枚。予約上限$46、累計最大45送信、成否不明予約保持。API・model・通信・保存形式は維持。以下は以前の段階。

現行画像枠（2026-09-12）：リナの歩行・ドッジ修正への続行指示に基づき専用9ポーズシート1枚。予約上限$39、累計最大38送信。成否不明分を保持。provider/model/通信・保存形式は変更なし。以下の枠は以前の段階の履歴。

現行画像枠：リナの方向別ゲーム画像1枚を追加承認。予約上限$38、累計最大37送信。過去の成否不明分も予約に残す。provider/model/通信・保存形式は変更なし。

最新画像枠（2026-09-12）：キャラクター修正設定画7枚と、成否不明を報告後にユーザーが指示したソラ再送1回。前回分を解放せず予約上限$37、累計最大36送信。provider/model/通信仕様は変更なし。認証なしHEADでAPI到達を確認し、制限外の実行を明示承認して再送する。成否不明の台帳には再開指示・日時・再送名を追記し、成功や未課金とみなさない。詳細は画像README。

最終確認: 2026-09-12（画像CLIの予算・参照入力拡張を含む）。
画像・SE・BGMの環境構築、API連携変更、通信障害対応では最初に本書を読む。
本書は現在の設定の入口とし、CLIの詳細は各README、調査経緯は個別報告を参照する。
モデル名や料金を将来も有効な仕様として扱わず、連携変更時に公式資料を再確認する。

## 現在の連携一覧

|項目|画像|SE|BGM|
|---|---|---|---|
|サービス|OpenAI Image API|ElevenLabs Sound Effects API|Stability AI Stable Audio API|
|実装上のモデル|gpt-image-2（変更可）|eleven_text_to_sound_v2|stable-audio-2.5|
|キー変数|OPENAI_API_KEY|ELEVENLABS_API_KEY|STABILITY_API_KEY|
|CLI|tools/generate_image.py|tools/asset_generator/asset.py se|tools/asset_generator/asset.py bgm|
|出力先|assets/generated/|assets/audio/se/|assets/audio/bgm/|
|出力形式|PNG、1024×1024|MP3、44.1kHz/128kbps|WAV|
|既定設定|low、1枚|0.5秒、1個|20秒、steps8、1個|
|無料のローカル確認|--check|--dry-run / check-keys|--dry-run / check-keys|
|生成条件の保存|PNGと同名のJSON、first-workshop-usage.json|assets/audio/asset_manifest.json|同左|
|通信待ち時間|300秒|既定180秒、変更可|同左|
|自動再試行|なし|なし|なし|

すべて開発用Pythonツール。ゲーム実行時にキーやAPI通信は必要ない。
生成素材のゲーム組み込みは別作業で、CLIは既存Sceneや再生処理を自動変更しない。

## 環境の準備

Windows / Python3.10以上。確認環境はPython3.12.1、Godot4.7.2。
PowerShellでプロジェクトルートを作業ディレクトリにする。

```powershell
python -m venv .local/audio-venv
.local/audio-venv/Scripts/python.exe -m pip install --retries 0 -r tools/asset_generator/requirements.txt
```

この仮想環境は画像ツールにも使える。名前は既存運用との互換のためaudio-venvのまま。
画像は標準ライブラリだけ、音響は音声検証用のmutagen1.47.0を使用する。
仮想環境のActivateは不要。Python実行ファイルを直接指定する。
パスは各スクリプトからプロジェクトルートを算出するため、コードへの絶対パス埋め込みは不要。

## 認証設定

3つのキー変数をプロセス環境から読み、未設定のキーだけプロジェクト直下の `.env` を読む。
環境変数を変更した場合、古い値を保持したアプリ/ターミナルは再起動する。
環境変数が設定済みなら `.env` の変更では上書きされない点に注意する。
`.env` はツールから書き換えない。変数展開やシェルコード実行もしない。

キーはCLI引数、プロンプト、JSON、manifest、資料、ログ、コンソールへ記録しない。
存在確認だけを行い、キーの先頭/末尾など断片も表示しない。
`.gitignore` の `.env` / `.env.*` / `.local/` / `.venv/` / Pythonキャッシュ除外を保持する。

```powershell
# 音響2サービスの有効な設定元からの存在確認。通信なし。
.local/audio-venv/Scripts/python.exe tools/asset_generator/asset.py check-keys

# 画像のキー・引数・出力名をローカル検証。未使用の名前を指定する。
.local/audio-venv/Scripts/python.exe tools/generate_image.py --name config_check_only --check
```

画像の --check は既存PNGまたは同名JSONがあれば失敗する。接続不良を意味しない。
音響のdry-runはキーなしでも利用可能だが、check-keysは設定の有無を報告する。
どちらもAPI認証成功や残高を保証する接続試験ではない。

## 音響の無料プラン確認

```powershell
.local/audio-venv/Scripts/python.exe tools/asset_generator/asset.py se --name se_config_check --prompt "One subtle dry UI click, no voice or music" --duration 0.5 --dry-run
.local/audio-venv/Scripts/python.exe tools/asset_generator/asset.py bgm --name bgm_config_check --prompt "Instrumental playful sci-fi battle, synth bass and electronic drums, no voices" --duration 20 --dry-run
```

実生成は画像の --check / 音響の --dry-run を外したときに行われる。
環境の確認だけなら外さない。素材生成の依頼・必要数が明確な場合のみ有料送信する。
詳しいオプションは [画像CLI](../../tools/README.md)、[音響CLI](../../tools/asset_generator/README.md)。
音響プロンプト設計には [AUDIO_BIBLE](../AUDIO_BIBLE.md) を使う。

## 接続先と実装の責務

|連携|HTTP要求|実装|
|---|---|---|
|画像|POST https://api.openai.com/v1/images/generations（JSON）または /v1/images/edits（multipart）、Bearer、base64 PNG応答|tools/generate_image.py|
|SE|POST https://api.elevenlabs.io/v1/sound-generation、xi-api-key、JSON、MP3応答|tools/asset_generator/providers/elevenlabs.py|
|BGM|POST https://api.stability.ai/v2beta/audio/stable-audio-2/text-to-audio、Bearer、multipart、WAV応答|tools/asset_generator/providers/stable_audio.py|

音響共通のパス/キーはconfig.py、HTTP/TLSはtransport.py、CLI/保存はasset.pyが担当する。
画像はHTTP opener/TLSだけtransport.pyから共有し、要求・応答・予算管理は独立実装。

音響のWindows TLSは信頼済みROOTストアからサーバー認証用ルートをロードする。
CAキャッシュ内の期限切れ中間証明書を避けつつ、証明書とホスト名を検証する。
Windows以外はPython標準設定。追加の信頼設定はプロセス環境の
SSL_CERT_FILE / SSL_CERT_DIRから読む。REQUESTS_CA_BUNDLEはurllibでは使用しない。
音響User-Agentは `ChamberClashAssetGenerator/1.0 (Python urllib)`。
画像側も同じTLS/User-Agentを使う。画像JSON応答と音響バイナリ応答は別に処理する。

## 課金・保存・障害対応

1コマンドにつき1素材。音響候補は通常1、明示されなければ合計最大3。
環境変更だけの依頼では素材を新規生成しない。エラーを受けて無断で再生成しない。
別provider/モデルへの自動切替、無限retry、同名上書きを行わない。

画像は同名PNG/JSON上書きと条件ハッシュ重複を拒否し、永続試行履歴・排他ロックを使用する。
画像の通信失敗・成否不明後は停止。記録の照合とユーザー指示なしに再実行しない。
画像メタデータは要求・参照画像ハッシュ・許可リストのusageと換算額。音響とは別スキーマ。

音響は `.local/asset_generator/attempts.json` に送信前の試行を記録する。
失敗/成否不明でも名前と条件を予約し、同条件の再生成は明示依頼がある場合だけ
新しい名前と --allow-repeat を使う。復旧ファイル/lockの扱いは音響READMEに従う。
認証ヘッダーとAPIエラー本文を表示/保存せず、固定のエラー分類だけを報告する。

障害時はTLS→HTTP→認証/権限/残高→要求仕様→保存/インポートの順に切り分ける。
HTTP403だけでプロンプト違反やキー無効と断定しない。
Stabilityでは期限切れチェーン選択と既定User-Agent拒否を別々に修正した。
読み取りのアカウントGET成功と、生成API成功は区別して報告する。
診断のためにTLS検証を無効化しない。OSやネットワークの権限制約がある場合は正規の承認を使う。

## 連携が変わるときの更新手順

1. 本書・各README・現在の実装・既存メタデータを読む。ユーザーの変更範囲を確認する。
2. 対象サービスの正式API資料でendpoint、認証、model、要求/応答、制限、料金を確認する。
3. 環境変数やprovider設定・必要な依存関係を変更する。秘密は移行資料にも書かない。
4. --check / --dry-runと通信mockテストを先に実行。キーや生の例外の漏洩がないか確認する。
5. 必要なら読み取りAPIで接続を確認する。実生成は明示された範囲で最小数だけ行う。
6. 保存形式/生成条件記録/Godotインポートを確認。未試聴の品質やループは未確認と記す。
7. 実装と同じ変更で本書の一覧・最終確認日・各READMEを更新する。
   診断経緯は個別報告へ残し、本書には現在有効な設定と残課題だけを反映する。

新サービスを追加したら、本書の一覧、キー変数、出力先、保存形式、無料確認方法、
課金防止策、実装場所、公式資料を揃える。AGENTS.mdの入口参照は維持する。

## 検証と現在の状態

```powershell
.local/audio-venv/Scripts/python.exe -m unittest discover -s tools/asset_generator/tests -v
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/audio_assets.gd
```

Godot実行ファイルの場所は環境に合わせる。画像のインポートもGodotエディタで確認する。
音響は19件のローカルテストと、BGM20秒WAV/SE MP3のResource認識に成功済み。
画像は既存tools/READMEの運用と `assets/generated/` のPNG/同名JSONを参照する。
音響テスト成功を画像HTTP処理の検証として扱わない。
環境確認のために既存サンプルを毎回再生成する必要はない。

## 関連資料・公式仕様

- [資料索引](../README.md)、[画像CLI](../../tools/README.md)、[音響CLI](../../tools/asset_generator/README.md)
- [音響設計基準](../AUDIO_BIBLE.md)、[画像素材の分類](../../assets/README.md)
- [音響構築結果](../archive/2026-09-11/AUDIO_SETUP_REPORT.md)、[TLS調査](../archive/2026-09-11/AUDIO_TLS_DIAGNOSIS.md)、[403調査](../archive/2026-09-11/AUDIO_403_DIAGNOSIS.md)
- [OpenAI画像API](https://developers.openai.com/api/docs/guides/image-generation)
- [Stability API](https://platform.stability.ai/docs/api-reference)
- [ElevenLabs Sound Effects API](https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert)

本書の設定値は現在のローカル実装を記録したもの。公式仕様の再確認日は各連携の変更時に記録する。

## 2026-09-12 画像制作の現行拡張
画像CLIの送信履歴・排他・予算・参照入力は[画像README](../../tools/README.md#始まりの工房画像制作2026-09-12)を参照。
現在の画像制作向け制限：
- 画像もtransport.https_openerを利用し、Windows ROOT検証と明示User-Agent。音響生成は実行しない。
- /images/editsのmultipart参照PNG入力、--prompt-file、固定gpt-image-2／1024PNG。
- first-workshop-usage.jsonへ送信前記録、失敗時停止、同条件拒否、usageを許可リスト保存。
- $29/50回の承認に対して1回$1を解放せず予約し、$29到達前に停止。usage欠損でも停止。
- 最新承認：8人各1枚の設定シートを計8回生成。予約上限$21→$29、累計最大28回。通常等身前後と2頭身を別保存し、ゲームへの自動差し替えは行わない。
- 2026-09-12、2頭身デザイン1枚と歩行シート1枚の比較制作を承認。予約上限$19→$21、累計最大20回。正式差し替え・追加候補は含まない。
- 2026-09-12、低頭身リナの待機・移動・回避3シートとゲーム差し替えをユーザーが承認。予約上限$16→$19、累計最大18回。追加候補の無断再生成は含まない。
- 公式料金表確認（2026-09-12）: 入力text $2.5/image $4、出力$15/百万token。換算は請求額ではない。
- 原画を残してローカル切抜き・透明化・フレーム原点統一。出力PNGだけで透明とは扱わない。
- 無料mock検証: python -m unittest discover -s tools/tests -v。
仕様: https://developers.openai.com/api/reference/resources/images/methods/edit
料金: https://developers.openai.com/api/docs/pricing
