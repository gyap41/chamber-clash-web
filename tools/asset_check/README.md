# 素材の機械チェック（開発専用）

区分: 開発ツール。状態: 運用中（2026-10-04作成、しきい値は暫定）。定義する範囲: 生成した画像・SE・BGMを、好みに関係なく測れる項目で確認する。関連する正本: [レビュー基準](../../docs/art/ART_BIBLE.md) / [画風の共通規格](../../docs/art/VISUAL_STYLE_GUIDE.md) / [音響基準](../../docs/AUDIO_BIBLE.md) / [候補素材の運用](../../assets/candidates/README.md)

API通信・課金・素材の変更はしない。結果は `--out` のフォルダーにだけ書く。候補素材では `assets/candidates/<id>/<版>/check/` を使う。

## 準備

```powershell
.local/audio-venv/Scripts/python.exe -m pip install --retries 0 -r tools/asset_check/requirements.txt
```

MP3はsoundfile（libsndfile 1.2.2）で読む。ffmpegは不要。

## 画像: check_image.py

```powershell
.local/audio-venv/Scripts/python.exe tools/asset_check/check_image.py assets/first-workshop/enemies/lizard-sheet-v3.png `
  --grid 4x8 --directions columns --direction-names front,back,right,left `
  --groups walk:0-3:loop,windup:4,spit:5,idle:6,death:7 --ground 230 --display-scale 0.24 `
  --out .local/asset-check/lizard-v3
```

|引数|意味|
|---|---|
|`--grid COLSxROWS`|等分の格子。割り切れない画像は、組立スクリプト（`tools/build_*.gd`）で等分のアトラスにしてから測る|
|`--directions rows/columns`|方向が並んでいる軸。トカゲv3は列が方向（前・後・右・左）、行が動作|
|`--groups`|動作ごとのコマ範囲。`:loop` を付けると末尾→先頭の継ぎ目も測る|
|`--ground`|セル内の接地線のy座標（原画の画素）|
|`--display-scale`|ゲーム内の表示倍率（カメラ前）。`--camera-zoom`（既定1.2、画風規格の計測と同じ）を掛ける。代わりに `--display-height`（画面上の最大の高さpx）でも指定できる|
|`--baseline`|採用済みの基準素材を同じ引数で測った `report.json`。明るさ・輪郭がその80%未満なら警告|
|`--floor`|合成する床。既定は現行の探索床 `assets/stages/ashen-foundry-v2/floor.png`|

出力:
- `contact_display.png`: 全コマを**ゲームの表示倍率で床の上に**並べた画像（行＝方向、列＝コマ順）。ループの列には先頭コマを `=0` として繰り返す。赤線は接地線。
- `contact_zoom3.png`: 同じものを3倍（最近傍）にした調査用。合否は表示倍率の方で判断する。
- `report.json`: コマごとの外接矩形・接地位置・明度・ばらつき・彩度・細部量・輪郭の対背景差、動作ごとの接地のずれ・大きさのぶれ・隣接コマの差分・シルエットの重なり・ループ継ぎ目。

|判定|条件（暫定）|
|---|---|
|不合格（レビューに回さず作り直し）|透過なし、空のコマ、体がセルの端に接する（はみ出し・隣接コマの混入）、マゼンタ背景の残りが0.2%超、接地線から2表示px超のずれ（撃破を除く）|
|警告（レビュー係が判断）|ループ内で体の高さが12%超変わる、隣接コマがほぼ同じ（差分1.0未満）、ループ継ぎ目の差分が平均の3倍超、基準素材より明るさ・輪郭が20%超弱い|

明度などの値は、床に合成しただけの画像で測る（照明・影なし）。[画風の共通規格3.5](../../docs/art/VISUAL_STYLE_GUIDE.md#35-色の役割と明暗の帯)の目標値は、照明と影を含むゲーム画面で測った値なので、直接比べない（トカゲv3の正面待機: ゲーム画面の計測では輪郭差16.2、このツールでは6.5）。同じツールで測った基準素材と比べる。

基準素材の参考値（2026-10-04、上の例の引数）: 火袋トカゲv3 全コマの中央値 明度40.5・ばらつき11.7・彩度54.8・細部量5.0・輪郭差6.6、画面上の最大の高さ46px。トカゲv3はユーザー採用前なので、基準として使うかは制作記録で決める。

## 音: check_audio.py

```powershell
.local/audio-venv/Scripts/python.exe tools/asset_check/check_audio.py assets/audio/se/fw_lizard_spit_03.mp3 `
  --category attack --reference assets/audio/se/fw_lizard_spit_02.mp3 --reference assets/audio/se/fw_sentry_swing_01.mp3 `
  --out .local/asset-check/spit03
.local/audio-venv/Scripts/python.exe tools/asset_check/check_audio.py assets/audio/bgm/fw_title_02.wav --category bgm --loop-end 60 --out .local/asset-check/title02
```

|引数|意味|
|---|---|
|`--category`|`shot` `heavy` `attack` `hit` `ui` `skill` `system` `defeat` `bgm`。AUDIO_BIBLEの長さの目安と比べる|
|`--reference`|同じ役割の採用済み音（複数可）。音量・長さ・明るさ・立ち上がりの差を出す|
|`--loop` / `--loop-end 秒`|ループ素材。music.gdのようにファイル末尾より前でループする場合は秒数を指定|

計測するもの: ファイル長と**聞こえている長さ**（ピークから40dB下がるまで。ElevenLabsは最短0.5秒なので区別する）、鳴り始めまでの無音（デコード後。映像より遅れる原因）、立ち上がり、ピーク、音割れサンプル数、RMS、おおよその統合ラウドネス（BS.1770のK特性とゲート。1kHz・-20dBFSの正弦波で-23.0 LUFSを確認済み）、DCオフセット、打音の回数、スペクトル重心・85%ロールオフ・平坦度・帯域ごとのエネルギー比、調和性と音程、ステレオ相関、ループ継ぎ目。

出力: `report.json` と `waveform_spectrogram.png`（候補と参照音を同じ時間軸で縦に並べる。上が音量の推移、下が対数周波数のスペクトログラム）。

|判定|条件（暫定）|
|---|---|
|不合格|50サンプルを超える音割れ、無音のファイル|
|警告|ピーク-0.3dBFS超・少数の音割れ（生成MP3では一般的。2026-10-04時点の既存SE100本中25本に数サンプルの音割れ）、用途の長さの範囲外、鳴り始めまで25ms超の無音、末尾が途切れる、DCオフセット、ループ継ぎ目の段差、参照音と6LU超の音量差|

**測れないもの**: 音色の良し悪し、絵との合い方、実プレイの混戦での聞き取りやすさ、ループの音楽的なつながり。これらは「試聴未確認」としてユーザーの試聴に残す。
