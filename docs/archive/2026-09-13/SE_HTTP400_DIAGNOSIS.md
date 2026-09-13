# SE HTTP 400 調査

## 短縮文面＋通常設定で標準拳銃候補が成功（最新）

ユーザーが提示文面の1回生成を明示承認。fw_pistol_short_01を通常CLIでdry-run後1回送信、成功。
text: One dry service pistol shot, tight steel mechanism, short punchy attack and quickly damped tail.
要求1秒、v2、influence=0.3、loop=false、mp3_44100_128、Accept=audio/mpeg。元のAPI設定はそのまま。
MP3ヘッダー1.044897959秒、Godot AudioStreamMP3は1秒。元音源・manifest保存、未試聴・要確認、ゲーム未接続。既知のGodot環境警告あり。
今回の実消費量は個別取得していない。条件付き推定40 credits（40/秒の場合）または$0.002（$0.12/分の場合）。契約への単価適用は未確定。
総POST12、成功10（診断9と標準拳銃候補1）、失敗2。ゲーム用16種のうち標準拳銃候補1種のみ取得。追加生成なし。

## 拳銃プロンプト短縮（最新、後続承認1回）

diagnostic_short_pistol_01：textだけを「One short dry service pistol shot. No music or voices.」にしてdry-run後1回送信、成功。元MP3・manifest保存。Godot AudioStreamMP3で2秒、未試聴、ゲーム未接続。既知のGodot環境警告は継続。
今回1 POST・成功1。使用量は前回325→直後325、観測増分0。ただし成功音源があるため無料とは判断せず、反映遅延等の可能性を残す。実消費額は未確定。
診断累計10 POST・成功9・失敗1。最初のゲーム用失敗を含め総POST11、成功9。
短い拳銃文面は成功し、492文字の元文面は最小構成で400。拳銃という題材自体が一律に拒否される証拠はない。短縮時に長さと文面の両方が変化しており、文字数制限・特定表現のいずれかは未確定。追加生成なし。

## 全指定と元プロンプトの比較（最新、後続承認2回）

1. diagnostic_combo_all_01：公式例のtextに通常CLIの全指定（format、model、duration=1、influence、loop、Accept）を加えて成功。Godot AudioStreamMP3、1秒、未試聴。元音源・manifest保存。
2. diagnostic_combo_prompt_01：元の492文字の拳銃プロンプトをtextだけで送信、クエリ・任意本文・Acceptなし。HTTP400で停止。音源なし、failed_or_uncertain履歴保持、再送なし。

公開例＋全設定は成功、元プロンプトは最小構成でも400。プロンプトに関連する原因が有力になったが、文字数・文面・内容判定・一時的なサービス挙動を特定できていない。モデレーション違反と断定しない。
今回2 POST、成功1。直前使用量315→325、観測増分10（請求明細ではない）。診断累計9 POST、成功8、失敗1。最初のゲーム用失敗を含め総POST10、成功8。ゲーム用16種は成功0。
Godot認識は全保存済み音源PASS。既知のユーザーディレクトリ書き込み・証明書ストアの環境警告は継続。今回の承認範囲の比較は終了。

## 単独比較の第2組（後続承認、追加3回）

同じ公式text-only基準に以下を単独追加し、各dry-run後に1回ずつ送信。全件成功。組合せではない。

|素材|追加した項目|結果|Godot尺|
|---|---|---|---:|
|diagnostic_field_influence_01|本文 prompt_influence=0.3|成功|1秒|
|diagnostic_field_loop_01|本文 loop=false|成功|1秒|
|diagnostic_field_accept_01|ヘッダー Accept: audio/mpeg|成功|1秒|

元音源と条件はmanifest、送信履歴はattempts.jsonに保存。Acceptの比較条件はgeneration_parameters.request_acceptに記録するが、このキーはJSON本文へ送信しない。
全件Godot AudioStreamMP3認識PASS、未試聴。既知のサンドボックスによるログ・設定保存、証明書ストアの警告は継続。
使用量は直前記録105から315へ増加（観測増分210）。前組の反映遅延や他利用を排除できず、各素材の請求額として扱わない。
今回3 POST・成功3。診断累計7 POST・成功7。最初のゲーム用失敗を含め総POST8。ゲーム用16種は未生成。
6つの追加指定はいずれも単独では400を再現しない。未比較は元の拳銃プロンプトと複数指定の組合せ。追加送信はせず停止、再試行なし。

## 単独パラメーター比較（後続承認、3回）

成功したtext-only例を共通基準とし、以下をそれぞれ単独で追加。順にdry-run→1回生成→結果確認。累積追加ではない。3件とも成功し元MP3・条件をmanifestと試行履歴に保持。

|素材|追加した項目|結果|Godot尺|
|---|---|---|---:|
|diagnostic_field_format_01|クエリ output_format=mp3_44100_128|成功|2秒|
|diagnostic_field_model_01|本文 model_id=eleven_text_to_sound_v2|成功|1秒|
|diagnostic_field_duration_01|本文 duration_seconds=1.0|成功|1秒|

3件ともGodot AudioStreamMP3認識PASS。未試聴。エディターのユーザー設定・ログ書き込みと証明書ストアには既知の環境制限メッセージが併発。
使用量は前回確認55から今回105へ増加、観測増分50。個別消費量は取得していない。請求明細ではなく、他の利用・反映遅延を排除できないため各素材への按分は行わない。
今回3 POST／成功3、診断累計4 POST／成功4。最初のゲーム用失敗を含む総POST5。ゲーム用16種は成功0のまま。
出力形式・モデル指定・1秒指定はそれぞれ単独では400を再現しなかった。まだ未比較なのはprompt_influence、loop、Acceptヘッダー、元の拳銃プロンプト、指定の組合せ。一度の成功で全条件の恒常的な成功は保証しない。自動retryなし、追加生成はここで停止。

## 後続の明示承認による最小構成診断：成功

公式例のtext「Spacious braam suitable for high-impact movie trailer moments」だけを本文にして、クエリなし・Content-Type application/jsonで1回送信。追加のAccept指定も省略。既存CLIの保存・排他・重複防止・試行台帳を使う診断用アダプターで実施。通常provider設定は変更なし。
dry-run後、se:diagnostic_minimal_braam_01 が成功。元MP3とmanifestを保存。ヘッダー尺1.044897959秒、Godot AudioStreamMP3は1.0秒。未試聴・ゲーム未接続。GodotはResource確認にPASSしたが、サンドボックスによるユーザーディレクトリのログ・設定保存および証明書ストア警告が併発。
契約使用量は直前の記録5から55に増加（観測増分50、他の並行利用を排除した請求明細ではない）。最初の失敗1回＋この診断1回、総POST2回・成功1件。16種の制作候補は成功0のまま。
最小構成の生成は可能と判明。複数条件が異なるためoutput_formatだけを400原因と断定できない。後続の比較生成は未実施。自動retryなし。

2026-09-13。対象 se:fw_pistol_01、送信時刻10:51:25 UTC（19:51:25 JST）。

## 確認結果

- HTTP400は取得済み。ただし「invalid parameter」はtransport.pyの固定文言であり、サービスの詳細理由ではなかった。パラメーター不正との断定を撤回し、原因不明のBad Requestと表示するよう修正。
- 公式生成リファレンスと照合：model_id=eleven_text_to_sound_v2、duration_seconds=1.0、prompt_influence=0.3、loop=false、output_format=mp3_44100_128。公開仕様上の不一致は発見していない。
- textは492文字。公開リファレンスにこの長さを拒否する条件は確認できない。プロンプト内容の個別判定、アカウント制約なども未確定。
- 成功済みtest_ui_clickと同じモデル・出力形式・prompt_influence・loop設定。今回の尺とtextは異なる。過去の成功で現在の権限や生成成功は保証できない。
- APIエラー本文は運用に従い表示・保存しておらず、過去レスポンスの詳細理由はローカルから復元できない。
- 今回の調査で生成API再送なし、設定変更なし、履歴削除なし。総生成送信1、成功0。使用量の直前・直後は5で観測増分0（請求明細ではない）。

## 次に必要な証拠

ElevenLabs管理画面で19:51頃のPOST /v1/sound-generation、HTTP400の詳細に原因コードが表示される場合、そのコードを確認する。HTTP番号のみのCSVでは原因は確定できない。認証情報やエラー本文全体を共有・記録しない。
原因が判明する前にモデル・尺・プロンプトを推測で変更して有料再送しない。

## 公式参照

https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert

尺0.5〜30秒、prompt_influence 0〜1、v2とloopを確認。MP3 192kbpsの契約制限は今回の128kbpsとは異なる。
