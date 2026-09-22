> 資料区分（2026-09-22監査）：過去の制作計画・素材案を含む参照資料。本文の未制作一覧・費用・承認枠を現在の作業指示として使わない。現行の残課題はdocs/planning/ROADMAP.md、探索の素材案はENEMY_BOSS_ART_PLAN.mdとEXPLORATION_REWARDS.md、実際の採用素材は各catalog・skin.json・音響manifestを確認する。

# 実行結果（最新）

**完了：短縮プロンプトによる16種の候補が揃いました。** [全16種の再生リンク・尺・費用・レビュー](../../archive/2026-09-13/se16-review/README.md)、[試聴ページ](../../archive/2026-09-13/se16-review/index.html)。残り15種各1回が成功。全件未試聴・要確認、ゲーム未接続。以下は制作途中の履歴です。

後続の診断・短縮文面1回生成の明示承認により、標準拳銃候補 [fw_pistol_short_01.mp3](../../../assets/audio/se/fw_pistol_short_01.mp3) が成功。
通常設定、要求1秒、MP3ヘッダー1.044897959秒、Godot1秒・Resource認識PASS。未試聴のため要確認。ゲーム未接続。
この候補の生成は1回、個別実消費未取得。条件付き推定40 creditsまたは$0.002。残り15種未生成。
診断を含む経緯は [HTTP400調査](../../archive/2026-09-13/SE_HTTP400_DIAGNOSIS.md)。以下は最初の失敗時点・送信前計画の記録。

ユーザーの続行承認後、標準拳銃 fw_pistol_01 を1回送信。HTTP 400（invalid parameter）で停止。再送・別条件生成なし。残り15件は未送信。
生成要求1/16回、成功0件。契約APIの使用量は送信前5、送信後5、観測増分0。請求明細の確認ではない。
新規音声がないため再生リンク、Godot Resource・実尺・試聴の確認はなし。全16件が要確認。manifestに未生成素材は追加せず、CLIのfailed_or_uncertain履歴を保持。
以下は送信前の制作表と見積りの履歴。下表の生成回数0は事前計画時点の値であり、実行結果はこの節および execution-result.json を参照。

---

# 工房SE16種：生成前レビュー

2026-09-13。16種各1候補、最大16有料送信の承認。要求尺15秒。現在は料金確認待ち。

契約情報 GET /v1/user/subscription は取得できず停止。原因詳細は未特定。再試行なし。キー存在のみローカル確認済み。生成POSTは0回、生成による消費0。契約変更・チャージなし。

公式資料には40 credits/秒とAPI $0.12/分が併存。現在契約への適用未確認。以下の両見積りは条件付き推定であり請求額ではない。

- https://elevenlabs.io/docs/overview/capabilities/sound-effects
- https://elevenlabs.io/pricing/api
- https://elevenlabs.io/docs/api-reference/user/subscription/get

現行 data/catalog.json、data/weapon_visuals.json、武器38種レビュー画像、sound.gd、player.gd、combat_session.gd、UI参照を指定資料と照合。標準拳銃は0.32/0.38秒間隔、ミニガトル0.24秒、バースト追射0.08秒。連射素材も単発とし追射を録音しない。パルスは弾消去。ゲーム接続は変更しない。

既存 test_ui_click はプラスチック音の接続試験。新規クリックは金属・木の工房操作音で条件が異なる。既存素材は未試聴で採用未判定。16件すべて名前・条件ハッシュに既存履歴との重複なし。manifestと過去試行履歴は変更していない。

全16件の既存CLI dry-run成功、通信0回。既存設定（eleven_text_to_sound_v2、MP3 44.1kHz/128kbps、prompt_influence 0.3、loop false）を維持。

|用途|要求秒|推定credits|推定USD|状態・再生リンク|生成回数|
|---|---:|---:|---:|---|---:|
|標準拳銃：ID 0/20、0.32/0.38秒間隔|1.0|40|0.002|要確認・未生成のためリンクなし|0|
|重い単発：ID 23/26、1.5ダメージ|1.0|40|0.002|要確認・未生成のためリンクなし|0|
|連射：ID 19/27/28、ゲーム側反復用|1.0|40|0.002|要確認・未生成のためリンクなし|0|
|エネルギー：ID 6を代表、3/7/36共用案|1.0|40|0.002|要確認・未生成のためリンクなし|0|
|被弾：hurtの鈍い衝撃|1.0|40|0.002|要確認・未生成のためリンクなし|0|
|軽い回避：回避開始|1.0|40|0.002|要確認・未生成のためリンクなし|0|
|機械式リロード：装填操作用、全装填時間は表現しない|1.0|40|0.002|要確認・未生成のためリンクなし|0|
|パルス：boom、敵弾消去|1.0|40|0.002|要確認・未生成のためリンクなし|0|
|選択クリック：選択変更|0.5|20.0|0.001|要確認・未生成のためリンクなし|0|
|決定：操作確定|0.5|20.0|0.001|要確認・未生成のためリンクなし|0|
|取消：操作取消|0.5|20.0|0.001|要確認・未生成のためリンクなし|0|
|装備配置：配置成功時|0.5|20.0|0.001|要確認・未生成のためリンクなし|0|
|購入成功：支払確定時|0.5|20.0|0.001|要確認・未生成のためリンクなし|0|
|操作不可：失敗通知|0.5|20.0|0.001|要確認・未生成のためリンクなし|0|
|勝利：ラウンド・試合結果共用SE|2.0|80|0.004|要確認・未生成のためリンクなし|0|
|敗北：ラウンド・試合結果共用SE|2.0|80|0.004|要確認・未生成のためリンクなし|0|
|合計|15|600|0.030|料金確認待ち|0|

## 英語生成プロンプト

### se:fw_pistol_01
One service pistol shot from a compact precision steel sidearm with a worn ivory housing. Dry mechanical snap and restrained ballistic punch, body 0.12 seconds, damped tail under 0.22 seconds. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_heavy_01
One heavy rivet handgun shot. Dense low-mid steel mechanism impact and firm compact discharge, weighty without excessive sub bass, body 0.22 seconds, damped tail under 0.4 seconds. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_rapid_01
Exactly one shot from a compact rotary-barrel firearm, a light tightly damped steel attack with a small dry ballistic punch. Body 0.05 seconds, tail under 0.08 seconds, softened high frequencies for comfortable rapid layering. No burst, no automatic firing sequence, no motor spin-up. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_energy_01
One precision electromagnetic rail discharge from a long metal emitter. Tight restrained electrical snap with a brief low-mid powered body, subtle smooth high-frequency edge, body 0.16 seconds, tail under 0.3 seconds. No charge-up, no cartoon laser pew. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_hit_01
One blunt impact against padded leather over a solid protective plate. Rounded dry low-mid thud, softer attack than a gunshot, body 0.12 seconds, tail under 0.22 seconds. No flesh squelch, no pain vocalization. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_dodge_01
One swift light evasive movement by an explorer carrying a compact workshop case. A single cohesive soft leather-and-cloth swish with a tightly secured case shifting and a short air cut, body 0.18 seconds, tail under 0.3 seconds. No footsteps or landing, no loose rattling. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_reload_01
One short precision loading mechanism actuation: a steel spring-loaded breech sliding directly into a firm damped lock, one cohesive mechanical gesture, body 0.25 seconds, tail under 0.4 seconds. No magazine removal sequence, no repeated clicks, no firing. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_pulse_01
One expanding defensive energy pulse from a portable advanced workshop power cell. Smooth broad outward pressure whoom with restrained electromagnetic texture, rounded onset, body 0.35 seconds, tail under 0.6 seconds. No explosive bang, debris, fire, rumbling ambience or repeated pulses. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_ui_select_01
One tiny tactile precision metal selector click on a wood-backed portable workshop control. Soft dry tick, body 0.04 seconds, tail under 0.09 seconds, unobtrusive. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_ui_confirm_01
One positive precision control engagement, a clean small metal latch with a subtle upward powered inflection fused into the same attack. Body 0.1 seconds, tail under 0.18 seconds. No melodic notes. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_ui_cancel_01
One gentle control disengagement, a soft wooden-and-metal release with a subtle downward inflection fused into one gesture. Body 0.09 seconds, tail under 0.16 seconds. No warning alarm. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_ui_place_01
One compact equipment module seating into a leather-lined workshop grid socket, a small solid metal-and-wood clunk with a damped locking contact fused into one impact. Body 0.12 seconds, tail under 0.2 seconds. No dragging or rattling. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_ui_purchase_01
One satisfying workshop transaction confirmation: a warm small brass mechanism contact with a brief restrained luminous power shimmer, one unified onset. Body 0.14 seconds, tail under 0.23 seconds. No coins spilling, cash register or melody. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_ui_blocked_01
One muted mechanical stop against a padded steel control, a low dry resistant tok with a tiny downward powered inflection. Body 0.09 seconds, tail under 0.16 seconds. Clearly restrained negative feedback, no harsh buzzer or alarm. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_victory_01
One non-musical success sound from an ancient precision fabrication device completing its work: a confident warm metal closure fused with one smoothly brightening amber power bloom. Single onset, body 0.55 seconds, restrained decay fully quiet by 0.95 seconds. No tune, melody, arpeggio, chord progression, fanfare or jingle. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

### se:fw_defeat_01
One non-musical subdued shutdown sound from an explorer workshop device: a soft weighty damped metal closure fused with a smoothly descending power release. Single onset, body 0.45 seconds, restrained decay fully quiet by 0.85 seconds. Calm and dignified, no tune, melody, arpeggio, chord progression, buzzer or jingle. Isolated single game sound effect for an explorer-artisan world of ancient stone facilities and advanced manufacturing. Start promptly; remaining clip is quiet. No music, voices, singing, background ambience, long reverberation, echoes, multiple separate events or repetition. No toy or comic sound.

## 再開条件
現在のAPIキーに対応する契約のSE単価・課金方式が必要。料金が確認できるまで有料送信しない。再開時は履歴を再照合し、1コマンド1素材、失敗時停止、retryなし。生成後のみmanifest登録、Godot Resource認識、実尺・デコード検証、可能な試聴を行う。現時点は未生成につきこれらは未実施。
