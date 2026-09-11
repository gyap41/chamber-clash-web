# AI音響素材生成（開発専用）

環境構築・API連携変更・通信障害対応では [画像・SE・BGM共通設定ガイド](../../docs/development/ASSET_GENERATION_SETUP.md) を最初に参照する。
本書は音響CLI固有の詳細を管理し、連携変更時は共通ガイドも更新する。

Windows / Python 3.10以上。ゲーム実行時にAPIは呼ばない。
生成前に [AUDIO_BIBLE](../../docs/AUDIO_BIBLE.md) と
[manifest](../../assets/audio/asset_manifest.json) と対象ゲームコードを確認する。
1コマンドは常に1素材。バッチ指定なし。候補が3つ必要なら明示的な依頼の範囲で3回実行する。
今回の環境構築テストはBGM1個・SE1個を厳守する。

## セットアップ

プロジェクトルートでPowerShellを開く。仮想環境のActivateは不要。

```powershell
python -m venv .local/audio-venv
.local/audio-venv/Scripts/python.exe -m pip install --retries 0 -r tools/asset_generator/requirements.txt
.local/audio-venv/Scripts/python.exe tools/asset_generator/asset.py check-keys
```

必要な環境変数は `STABILITY_API_KEY` / `ELEVENLABS_API_KEY`。
ユーザーの環境変数設定から設定し、必要ならターミナル/アプリを再起動する。
キーをCLI引数、プロンプト、ログ、ソースへ貼り付けない。
既存画像ツールに合わせ、プロセス環境にないキーだけルートの `.env` から読み取る。
`.env` は読み取り専用。引用符と `export NAME=` は受け付けるが変数展開・コード評価はしない。
check-keysはこの読み込み後の存在だけを表示し、APIへの接続確認はしない。
`.env` / `.env.*`、`.local/`、`.venv/`、PythonキャッシュはGit除外。
本ツール配下は `.gdignore` によりGodotインポート対象外。

## 使用例

```powershell
# 課金なし・書き込みなし。キー未設定でも実行できる。
.local/audio-venv/Scripts/python.exe tools/asset_generator/asset.py bgm --name battle_preview --prompt "Instrumental playful sci-fi arena battle, 132 BPM, punchy synth bass, tight electronic drums, sparse arpeggios, no voices, no sound effects" --duration 20 --purpose "通常戦闘の方向性確認" --dry-run
.local/audio-venv/Scripts/python.exe tools/asset_generator/asset.py se --name ui_preview --prompt "One subtle dry game UI click, soft tactile plastic tap, very short transient, quiet tail, no music, no voice" --duration 0.5 --dry-run
```

内容確認後、`--dry-run` を外すと1回だけ有料生成する。
Activate済みなら `python tools/asset_generator/asset.py bgm ...` / `se ...` でも同じ。
スクリプトの絶対パスを指定すれば、現在の作業ディレクトリに依存しない。

|オプション|意味|
|---|---|
|--name|必須。小文字英字始まり、英数字/ハイフン/アンダースコア、最大64文字。上書き不可|
|--prompt|必須。音の説明。空文字不可、ツール上限10000文字|
|--purpose|用途、対象イベント、元asset_idなど|
|--duration|秒。BGM既定20、範囲1〜190。SE既定0.5、範囲0.5〜30|
|--loop|ループ用途。SEではAPIへ送信。BGMではプロンプトにも意図を記す。Godot設定は変更しない|
|--seed|BGMのみ0〜4294967294。0/省略はランダム。同一音の完全再現は保証されない|
|--prompt-influence|SEのみ0〜1、既定0.3|
|--timeout|既定180秒、5〜600。ソケット待ち時間と読み込み期限。最後のread待ちにより最大でさらに1待ち時間延びうる|
|--allow-repeat|既に試行した同条件を明示的に再生成。必ず新しい名前を使う。課金が再発生する|

## 出力・manifest

`assets/audio/bgm/<name>.wav`、`assets/audio/se/<name>.mp3`。
それぞれ `res://assets/audio/bgm/` / `res://assets/audio/se/` で参照できる。
BGMはAPIのWAV、SEはAPIのMP3 44.1kHz/128kbpsをそのまま保存し、再エンコードしない。
WAV構造とサンプル量、MP3ヘッダーと長さを検査する。MP3検査は全サンプルのデコード試験ではない。

manifestの `assets` 配列にasset_id/type/provider/file_path/purpose/prompt/duration/
loop/generated_at/generation_parametersを記録する。durationは音声ヘッダー由来の秒数、
要求時間はgeneration_parametersに残す。fingerprintは生成条件、sha256は音声ファイルのハッシュ。
loop_verifiedは未試聴のためfalseで登録。キー・HTTPヘッダー・エラー本文は保存しない。
元のプロンプト/設定を参照して修正し、新しい名前で生成する。既存素材は自動削除しない。

## 課金防止・エラー・復旧

生成POSTは1回、自動retryは0。HTTPリダイレクトに認証情報を渡さない。
User-Agentは `ChamberClashAssetGenerator/1.0 (Python urllib)` として実アプリを識別する。
この環境ではurllib既定識別のアカウント/残高GETが403、実アプリ識別では200となった。
並行CLIは `.local/asset_generator/generator.lock` で拒否する。
POST前に `attempts.json` へ条件・時刻・pendingを保存する。
既存ファイル/使用済みasset_id/同一条件の履歴があればAPIを呼ばず停止。
dry-runはプラン表示用で、既存名の可否など実生成の全事前条件を保証するものではない。

401は認証、402は支払/残高、403は権限/モデレーション、404はAPI/モデル、
400/422はパラメーター、429は利用/同時実行制限、5xxはサービス側を確認する。
API本文は秘密情報漏洩防止のため表示しない。詳細は各サービスの管理画面で確認する。
ネットワーク/TLS/プロキシエラーやtimeoutは生成・課金の成否が不明な場合がある。
WindowsのTLSは信頼済みROOTストアを使い、期限切れ中間証明書が混入するCAキャッシュを
読み込まない。証明書・ホスト名検証は常に有効。Windows以外はPython標準の信頼設定を使う。
追加CAが必要な環境では `SSL_CERT_FILE` / `SSL_CERT_DIR` を明示できる（.envではなくプロセス環境）。
`REQUESTS_CA_BUNDLE` はurllibでは使用しない。信頼設定の読み込み失敗時は送信前に停止する。
原因解決前に再送しない。別プロバイダーを自動的に代替利用しない。

途中終了・保存失敗のとき:

1. 実行中のプロセスがないことを確認。生きているlockは削除しない。
2. attempts.jsonとプロバイダー管理画面、出力音声/manifestを照合する。
3. 成功レスポンスの音声は保存完了まで `.local/asset_generator/<type>_<name>.<ext>` に保持する。
   音声が残っていれば再API呼び出しせず検証/コピー/manifest修復を行う。
4. プロセス停止が確認できた場合のみ残存lockを削除する。履歴は削除しない。
5. ユーザーが再生成を求めたときだけ新しい名前と `--allow-repeat` を使用する。

ローカル履歴を消すと重複防止の一部を失う。サービス側のexactly-once保証ではない。
別チェックアウトや別マシン同士はロックを共有しない。自動化でCLIを無条件に再実行しない。

## Godot確認

エディタでプロジェクトを開いてインポートするか、手元のGodotコンソール版で:

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/audio_assets.gd
```

ResourceLoaderによるAudioStream認識と長さを確認する。出力なしの場合はSKIP。
生成音はゲームへ自動接続しない。再生音量、MP3開始遅延、ループ継ぎ目は本採用前に試聴する。

## API仕様の確認記録（2026-09-11）

一次資料: [Stability API](https://platform.stability.ai/docs/api-reference)、
[ElevenLabs Sound Effects](https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert)、
[ElevenLabs errors](https://elevenlabs.io/docs/eleven-api/resources/errors)、
[Godot音声インポート](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_audio_samples.html)。

Stability: `POST https://api.stability.ai/v2beta/audio/stable-audio-2/text-to-audio`、
Bearer認証、multipart/form-data。model=`stable-audio-2.5`、steps=8、prompt/duration/
output_format/任意seed。Accept audio/*で200の音声バイナリ。同期型を採用。
2.5は公開仕様上1成功20 creditsで、短くしても固定課金。
同公式ページにStable Audio 3の別エンドポイントと非同期方式も掲載されているが今回は採用しない。
Stabilityの429は150リクエスト/10秒超過の説明。これを目標送信量として使わない。

ElevenLabs: `POST https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128`、
xi-api-key認証、JSON、model_id=`eleven_text_to_sound_v2`。
text/duration_seconds/prompt_influence/loopを指定し、MP3バイナリを受信。
429はレート/同時実行上限。契約による上限は管理画面を確認し、固定値を仮定しない。
両生成リファレンスに共通の必須クライアントtimeout値は確認できなかったため、
本ツールの方針として180秒を設定。仕様変更時は公式資料を確認してproviderを更新する。

## 構成とテスト

`asset.py`: CLI、検証、排他、履歴、manifest。
`config.py`: パス/キー読込。`transport.py`: 1回だけのHTTP送信。
`providers/`: 音響API固有のパラメーターと要求構築。
provider追加は同じinterfaceを実装し、PROVIDERSへ登録する。

```powershell
.local/audio-venv/Scripts/python.exe -m unittest discover -s tools/asset_generator/tests -v
```

テストは通信をmockし、実生成も課金もしない。
