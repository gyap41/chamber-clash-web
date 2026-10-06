# 鉄格子の開閉SE v1

区分：音響制作・検証記録。状態：候補プレビューへ接続、試聴未確認・ユーザー未採用。正本：[音響基準](../../../../docs/AUDIO_BIBLE.md)、[門の制作記録](../../../../docs/art/production/ashen-foundry-v2/README.md)。2026-10-06。

読了：AUDIO_BIBLE、音響manifest、ASSET_GENERATION_SETUP、asset_generator/README、asset_check/README、Sound・ExplorationDoor・探索コントローラー。ユーザー依頼の開閉各1候補、計2件をdry-run後にElevenLabsへ1件ずつ送信。成功2、再試行0、追加候補0。provider・モデル・通信設定は変更なし。

## 試聴用

ゲームと同じ個別ゲインを適用したWAV。音響バスのコンプレッサーやBGMは含まない。

- [閉鎖](gate-close-preview.wav)：鎖の短い前置き＋着地打音。全長0.763秒、最大振幅を開始後0.35秒へ配置。
- [開放](gate-open-preview.wav)：鎖・巻上げの指示で生成。全長0.680秒。

以下の尺はデコード後の値。manifestはMP3ヘッダー由来で閉鎖0.522秒・開放0.731秒となり、符号化余白を含む。

原本：fw_gate_close_01.mp3（0.480秒）・fw_gate_open_01.mp3（0.680秒）。閉鎖原本の最大振幅は0.0675秒で、指定した着地時刻より早かった。原本は変更せず、開放原本の先頭0.2825秒を-3dB・両端20msフェードで前置きし、閉鎖原本を続けた。末尾10msフェード。再生成はしていない。[mix.py](mix.py)・[recipe.json](recipe.json)で再現可能。

## 数値による確認

|音|ピーク|概算LUFS|クリップ|開始無音|判定|
|---|---:|---:|---:|---:|---|
|閉鎖原本|-1.47dBFS|-14.2|0|0ms|既存宝箱音より10.9LU大きい警告|
|開放原本|-7.01dBFS|-19.7|0|0ms|機械チェックPASS|
|閉鎖合成|-1.47dBFS|-14.0|0|5ms|機械チェックPASS、立上りの検出344.2ms|

閉鎖はvolume_db-20dB、開放は-19dB。閉鎖の大きさの警告は再生成でなく再生ゲインで対応。閉鎖の最大振幅と着地時刻は合わせたが、音色の重さ・鎖らしさ・聴感上の同期・混戦の聞き取りは試聴未確認。波形・帯域の数値だけで美術／聴感合格とはしない。

## 接続

- `dungeon-gate/v3`のプレビューに開閉2音を登録。音だけは`--preview-candidate=dungeon-gate-audio/v1`でも確認可能。通常起動には未採用。
- Doorが実際に動き始めた時にシグナル発火。固定した状態の毎フレームや開放済み再訪では鳴らさない。
- 部屋ごとに専用の1ボイスを既存Sound・SEバス内へ追加。4門同時でも1音。反転は前の音を停止し、残り移動時間に合わせて前半をスキップする。
- ポーズで停止位置を保持、ミュート・部屋再構築・リスタート・終了で停止。ゲーム全体のAudioManager変更はなし。
- 合成WAVは44.1kHzステレオ16bit PCM、Godot無圧縮・正規化なし・非ループ。原本MP3は再圧縮しない。
- `tests/door_audio.gd`で初期無音・4門同時抑制・状態継続・反転・ポーズ・ミュート・停止を確認。候補音源も既存音源と同じResource/長さ検査の対象にする修正はユーザー承認済み。

全体テスト：PASS 162 / FAIL 0 / NO-PASS 4 / 合計166。ログ：`.local/logs/run_tests-20261006-230813.log`。NO-PASSはenemy_animation_review、enemy_art_preview、enemy_death_review、quillback_art（エラーのない撮影用）。音源124件のAudioStream認識・長さ検査はPASS。実際のv3候補でも生成音源の読込、探索からの発火、部屋再構築での停止を追加確認しPASS。資料索引・リンク・設定同期も確認済み。
