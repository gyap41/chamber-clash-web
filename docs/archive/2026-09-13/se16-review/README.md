現行接続状況：50種をゲームへ接続済み。戦闘開始は保留、Sレア投下・危険警告の旧候補は未接続。[接続一覧](../SE_REMAINING_INTEGRATION.md)。以下の未接続表記は生成当時の記録。

# 工房SE16種・レビュー一覧

後続依頼でゲーム接続済み。[接続内容・検証](../SE_GAME_INTEGRATION.md)。未試聴の区分は維持。以下の「ゲーム接続なし」は生成完了時点の記録。

残り15種を各1回で生成成功。先行した標準拳銃1種と合わせ16候補。要求尺合計15秒。ゲーム接続なし、BGM・画像生成なし。

全件要確認（未試聴）。音の本体の短さ、複数発音・声・音楽の混入、連射時の聞きやすさ、勝敗の判別は未確認。品質を採用済みとは扱わない。

全16件のファイルSHA256とmanifestの整合性、およびGodot AudioStreamMP3認識・長さを確認。ヘッダー尺はMP3のパディング等によりGodot尺と異なる。全サンプルのデコード解析は未実施。Godotにはユーザーディレクトリのログ・設定保存と証明書ストアの環境警告が併発したが、音声Resource確認は全件PASS。

費用：各行は条件付き推定（40 credits/秒 または $0.12/分）。契約への単価適用は未確定。最終アカウント使用量525/10000、前回観測325との差200は今回15件の直前値ではなく先行生成の反映遅延等も含み得る。個別請求額・消費量として按分しない。

回数：今回15 POST・15成功。最終16候補は各1回。全経緯では27 POST・成功25・失敗2（ゲーム候補16成功＋元拳銃失敗1、診断9成功＋1失敗）。過去の試験SE/BGMはこの回数に含めない。

|用途・再生|要求秒|MP3ヘッダー秒|Godot秒|区分|候補生成回数|推定credits / USD|
|---|---:|---:|---:|---|---:|---:|
|[標準拳銃](../../../../assets/audio/se/fw_pistol_short_01.mp3)|1|1.044898|1|要確認・未試聴|1|40 / $0.002|
|[重い単発](../../../../assets/audio/se/fw_heavy_short_01.mp3)|1|1.044898|1|要確認・未試聴|1|40 / $0.002|
|[連射（単発反復用）](../../../../assets/audio/se/fw_rapid_short_01.mp3)|1|1.044898|1|要確認・未試聴|1|40 / $0.002|
|[エネルギー](../../../../assets/audio/se/fw_energy_short_01.mp3)|1|1.044898|1|要確認・未試聴|1|40 / $0.002|
|[被弾](../../../../assets/audio/se/fw_hit_short_01.mp3)|1|1.044898|1|要確認・未試聴|1|40 / $0.002|
|[軽い回避](../../../../assets/audio/se/fw_dodge_short_01.mp3)|1|1.044898|1|要確認・未試聴|1|40 / $0.002|
|[機械式リロード](../../../../assets/audio/se/fw_reload_short_01.mp3)|1|1.044898|1|要確認・未試聴|1|40 / $0.002|
|[パルス（敵弾消去）](../../../../assets/audio/se/fw_pulse_short_01.mp3)|1|1.044898|1|要確認・未試聴|1|40 / $0.002|
|[選択クリック](../../../../assets/audio/se/fw_ui_select_short_01.mp3)|0.5|0.522449|0.48|要確認・未試聴|1|20 / $0.001|
|[決定](../../../../assets/audio/se/fw_ui_confirm_short_01.mp3)|0.5|0.522449|0.48|要確認・未試聴|1|20 / $0.001|
|[取消](../../../../assets/audio/se/fw_ui_cancel_short_01.mp3)|0.5|0.522449|0.48|要確認・未試聴|1|20 / $0.001|
|[装備配置](../../../../assets/audio/se/fw_ui_place_short_01.mp3)|0.5|0.522449|0.48|要確認・未試聴|1|20 / $0.001|
|[購入成功](../../../../assets/audio/se/fw_ui_purchase_short_01.mp3)|0.5|0.522449|0.48|要確認・未試聴|1|20 / $0.001|
|[操作不可](../../../../assets/audio/se/fw_ui_blocked_short_01.mp3)|0.5|0.522449|0.48|要確認・未試聴|1|20 / $0.001|
|[勝利](../../../../assets/audio/se/fw_victory_short_01.mp3)|2|2.037551|2|要確認・未試聴|1|80 / $0.004|
|[敗北](../../../../assets/audio/se/fw_defeat_short_01.mp3)|2|2.037551|2|要確認・未試聴|1|80 / $0.004|
|合計|15|||要確認16|16|600 / $0.030|

## 生成プロンプト

### 標準拳銃
One dry service pistol shot, tight steel mechanism, short punchy attack and quickly damped tail.

### 重い単発
One heavy rivet handgun shot, dense steel mechanism, low punchy impact and a short damped tail.

### 連射（単発反復用）
One compact rotary gun shot, light dry steel attack, softened treble and a very brief tail, suitable for rapid repetition.

### エネルギー
One restrained electromagnetic rail discharge, tight electric snap, compact powered body and a quickly fading tail.

### 被弾
One blunt impact on padded leather armor, rounded dry thud and short decay. No voice.

### 軽い回避
One swift evasive swish of leather and cloth with a secured portable workshop case, light air cut and short decay.

### 機械式リロード
One precision steel breech sliding into a damped lock, a compact loading gesture with a short mechanical finish.

### パルス（敵弾消去）
One expanding defensive energy pulse, smooth outward pressure whoom with restrained electromagnetic texture and a brief tail.

### 選択クリック
One tiny dry metal selector tick on a wood-backed workshop control, soft attack and immediate decay.

### 決定
One clean workshop latch engagement with a subtle upward powered inflection, crisp and briefly damped.

### 取消
One gentle wood-and-metal control release with a subtle downward inflection and short dry decay.

### 装備配置
One equipment module seating in a leather-lined workshop socket, a small solid metal-and-wood clunk with short decay.

### 購入成功
One warm brass transaction-confirmation click with a brief luminous power shimmer, a single compact sound effect.

### 操作不可
One muted padded-steel control stop, a low resistant tok with a tiny downward inflection and immediate decay.

### 勝利
One non-musical victory effect: confident metal closure fused with a warm brightening power bloom, fading within one second.

### 敗北
One non-musical defeat effect: soft damped metal closure fused with a descending power release, fading within one second.
