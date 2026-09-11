> 履歴資料（2026-09-11に整理）。当時の計画・結果を保存したもので、現在の作業指示ではありません。現行情報は [資料索引](../../README.md) を参照。

# AI音響生成環境 構築結果

最新結果: 後続の明示的生成依頼で `bgm:sample_battle_02` の生成に成功。
Stable Audio 2.5、20秒、44.1kHzステレオ16bit WAV。
今回の生成POST1回、自動retry0回。manifestへ登録済み。
Godot4.7.2のインポートとResourceテストでAudioStreamWAV/20秒として認識を確認。
出力は `res://assets/audio/bgm/sample_battle_02.wav`。ゲームへの組み込みと聴感/ループ確認は未実施。
これで保存済みサンプルはBGM1件・SE1件。以下は構築・調査時点の経緯。

実施日: 2026-09-11。環境構築とSE疎通は完了。BGM疎通は通信エラーで未完了。
秘密情報は本資料・manifest・ソースへ保存していない。

追記: 後続の生成なし調査でPythonの期限切れ証明書チェーン選択を確認。
詳細は [TLS調査結果](AUDIO_TLS_DIAGNOSIS.md)。以下の構築時点の記録は保持する。

後続サンプル生成依頼: `bgm:sample_battle_01` を20秒・同じ条件でdry-run後、
ユーザーの依頼に基づき `--allow-repeat` で1回だけ送信した。
TLSエラーは発生しなかったがHTTP403で拒否され、再試行せず停止した。
HTTPステータスだけではAPI権限・モデレーション・アクセス制御等の原因を確定できない。
APIエラー本文は表示/保存していない。BGMファイルは未生成、manifestはSE1件のまま。
今回のPOST試行1回、自動retry0回。失敗履歴は `.local/asset_generator/attempts.json` に保持。

後続の403調査でurllib既定User-Agentによる拒否を確認し、実アプリ識別を設定した。
修正後に認証/残高GET成功、20 credits以上を確認。生成POSTは行っていない。
詳細は [403調査結果](AUDIO_403_DIAGNOSIS.md)。

## 既存構造の調査

`project.godot` は4.7設定、実行バージョンは4.7.2.stable.official.ed1daf0bf。
タイトル→キャラ選択→準備/戦闘/結果。タイトルからCPU対戦へ進む。
scenesとscriptsはgame/combat/world/ui/visuals等で分類。定義はdata/catalog.json。
PlayerをP1/P2で共有し、CPUはcpu_ai.gdで制御。射撃、近接、被弾、回避、パルス、
重力、補給、装備レリック、HUD、HP比率による決着と3本先取を確認した。

`scripts/audio/sound.gd` はGame/Sound配下の合成SE。AudioStreamPlayer16個、
WAV合成/キャッシュ、enabled/volume_db、動的ChamberSFXバスとコンプレッサーを持つ。
一部音はMasterへ直接送られる。AudioStreamPlayer2D/3DとAutoloadはない。
既存の外部BGM/SE素材、専用ボス戦、BGM管理処理はない。
音色定義のwin/lose等と実際のイベント接続は区別した。
開始時に多数の未コミット変更があったため、その内容を保持した。

## 作成・変更

作成した開発ファイル:

- `AGENTS.md`: 今後の音響依頼の手順と課金防止指針
- `tools/asset_generator/asset.py`: CLI/dry-run/保存/manifest/排他/重複防止
- `tools/asset_generator/config.py`: プロジェクト相対パスとキー読込
- `tools/asset_generator/transport.py`: 単発HTTP、timeout、応答サイズ上限、秘密情報を出さないエラー
- `tools/asset_generator/providers/__init__.py` / `stable_audio.py` / `elevenlabs.py`: provider登録と要求構築
- `tools/asset_generator/requirements.txt` / `README.md` / `.gdignore`
- `tools/asset_generator/tests/test_asset.py`: 課金なしの13テスト
- `docs/AUDIO_BIBLE.md`: 音響方針・用途別設計・ミックス/ループ/候補基準
- `docs/archive/2026-09-11/AUDIO_SETUP_REPORT.md`: 本資料
- `tests/audio_assets.gd` とGodot生成の `.uid`: Resource認識テスト
- `assets/audio/asset_manifest.json`、bgm/se各フォルダーの `.gitkeep`
- `assets/audio/se/test_ui_click.mp3` とGodot生成の `.import`

変更した既存ファイルは `.gitignore` のみ。既存 `.env` 除外を保持し、
`.env.*`、`.venv/`、`__pycache__/`、`*.py[cod]` を追加。
Scene、ゲームGDScript、project.godot、AudioManager相当の既存コードは変更していない。
インポートにより `.godot/` のローカルキャッシュや既存未インポート素材のメタデータも更新される。

ローカル専用: `.local/audio-venv/`（Python3.12.1、mutagen1.47.0）、
`.local/asset_generator/attempts.json`（秘密を含まない試行履歴）。

採用出力先は `assets/audio/bgm/` と `assets/audio/se/`。
Godotの `res://assets/audio/...` から直接参照する。再エンコードなし。

## APIと疎通結果

正式仕様は [Stability API](https://platform.stability.ai/docs/api-reference) と
[ElevenLabs Sound Effects API](https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert) を参照した。
パラメーター・timeout方針・レート制限の確認記録はツールREADMEにまとめた。

|項目|BGM|SE|
|---|---|---|
|サービス|Stability AI|ElevenLabs|
|モデル|stable-audio-2.5|eleven_text_to_sound_v2|
|POST endpoint|https://api.stability.ai/v2beta/audio/stable-audio-2/text-to-audio|https://api.elevenlabs.io/v1/sound-generation|
|認証|環境からBearer|環境からxi-api-key|
|キー存在確認|configured|configured|
|要求|20秒、WAV、steps8|0.5秒、mp3_44100_128、influence0.3|
|POST試行数|1|1|
|自動再試行|0|0|
|結果|Network/TLS/proxy failure。HTTPステータス取得なし|成功|
|保存素材|なし|res://assets/audio/se/test_ui_click.mp3|

キー確認はプロセス環境優先・未設定時の既存.env読み込み後の存在判定。
BGMはエラー時停止の指示に従って追加生成をしていない。
例外詳細を表示していないためDNS/TLS/プロキシ等の内訳は今回確定していない。
サーバー到達・生成・課金の成否は不明。管理画面や通信環境の調査後、再生成する場合は別途指示が必要。
両サービスとも追加の認証/残高確認APIは呼んでいない。最大1候補ずつの制限を遵守。

## 素材・manifest・検証

SEは控えめな単発UIクリックを目的に生成。
manifestはschema_version=1、成功素材1件（`se:test_ui_click`）。
prompt、用途、provider、resパス、要求パラメーター、生成日時、音声ハッシュ、条件ハッシュ、
実測ヘッダー長0.522449秒を記録。loop=false、loop_verified=false。
BGMの失敗は素材manifestに登録せず、ローカル履歴にfailed_or_uncertainとして保存。

- Pythonの安全性/保存/エラー処理テスト: 13件成功、API通信なし。
- BGM/SEのdry-run: 成功、API0回。
- Pythonコンパイル: 成功。
- Godot4.7.2 headless import: 制限環境のユーザーフォルダーエラー後、承認済み実行で成功。
- `tests/audio_assets.gd`: 成功。生成SEをAudioStreamMP3として認識。
- Godot再生長: 約0.480秒。MP3のパディング等の扱いによりヘッダー長とは異なる。
- `tests/sound.gd`: 成功。既存ミュート/UI/入力ガード/戦闘シグナル、20武器のPCM合成、キャッシュ/同時音数/停止/バス解放。
- 人による聴感評価・実ゲーム組み込み・ループ品質確認は未実施。

## 残課題と将来案

BGM側のネットワーク/TLS/プロキシ原因を調査する。APIが返す素材品質、WAV実応答、
GodotでのBGMインポートはまだ実証していない。既存SEとの音量合わせも本採用時に行う。

将来のBGM管理は既存Soundの呼出し窓口を尊重し、Master→BGM/SEバスを用意する。
BGM用AudioStreamPlayer2個で再生/停止/切替/ループ/クロスフェード、
既存16ボイスSEへ素材選択とバリエーションを追加する案が小規模。
音量設定はMaster/BGM/SE別に保持し、ノイズ音だけでなく全SEをSEバスへ統一する。
この設計は提案のみで、今回は実装していない。

次の依頼例:

- 「BGM側の通信エラーを調査して。生成はまだしないで」
- 「AUDIO_BIBLEに沿って剣攻撃SEを3種類作って。ゲーム組み込みは不要」
- 「test_ui_clickを試聴して、既存UIへの組み込み案を出して」
- 「このパルス用SEを1個作って」
