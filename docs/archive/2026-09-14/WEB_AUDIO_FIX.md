# Web音響の修正

公開版でタイトル→キャラ選択→準備へ操作し、準備画面の「音 OFF」を確認。コードもsound.enabled=falseで、SEが初期状態では鳴らないことは確定。BGMの参照と画面切替コードは存在し、ヘッドレステストでは切替が成功。公開版コンソールに音声エラーは出ていない。BGM無音の根本原因を聴取・WebAudio計測で確定したわけではない。

対応：SEを既定ON、UIをSE ON/OFFへ明確化。BGMとSEのAudioStreamPlayerはPLAYBACK_TYPE_STREAMを明示し、WebのSample経路からGodotのミキサー経路へ変更。Sampleには合成音／AudioEffectなどの制約があり、現在の実行時ループ設定と合成SE・コンプレッサーの利用に合わせた対策。Streamは端末によって遅延・音割れが増える可能性があるため、実機確認を残す。

公式資料：https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
https://docs.godotengine.org/en/stable/classes/class_audioserver.html

検証：music、sound、generated_sound、result_flowがPASS。OS証明書ストアと一部テスト終了時のResource/ObjectDB警告は残る。Godot 4.7.2でWebデータPCKを再出力し、既存の同バージョンWebエンジンでローカル起動。ブラウザでタイトル→キャラ選択→準備のSE ON表示→戦闘を確認、コンソールerror/warnなし。音声を実聴していないため「Webの出音を確認済み」とは扱わない。

API生成・音源編集・課金なし。公開版の反映にはコミット・プッシュ後のPages再ビルドが必要。
