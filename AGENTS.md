# AI素材生成環境の参照・更新

- 画像・SE・BGMの環境設定、API連携変更、通信障害対応では、最初に `docs/development/ASSET_GENERATION_SETUP.md` と対象CLIのREADMEを読む。
- provider、model、endpoint、認証、依存関係、TLS/HTTP設定、保存形式を変えるときは正式API仕様を確認し、実装と同時に共通設定ガイドと対象READMEを更新する。
- 環境設定や資料更新だけの依頼では有料生成しない。ローカル検証を先に行い、実生成はユーザーが求めた範囲に限定する。
- 現行設定は共通設定ガイド、調査経緯は個別報告に記録する。画像ツールと音響ツールの機能差を混同しない。

# 音響素材の生成作業

この節はBGM・SEの生成/変更依頼に適用する。

- 最新の対象ゲーム実装、`docs/AUDIO_BIBLE.md`、`assets/audio/asset_manifest.json` を読んでから音響を設計する。
- `tools/asset_generator/README.md` に従い、統一CLIでdry-run後、許可された数だけ生成する。
- 1コマンド1素材。通常の候補数は1、ユーザーが明示しない限り合計最大3候補。無断で品質改善用の再生成を重ねない。
- 認証/課金/モデル/パラメーター/レート制限/timeout/通信エラー時は停止して報告する。自動retryや別providerへの切替は禁止。
- 同条件の再生成は履歴を確認し、ユーザーが求めた場合に限り新しい名前と `--allow-repeat` を使用する。
- キーは環境変数（未設定時はGit除外済み `.env`）から読み、キー値や断片、認証ヘッダー、APIエラー本文を表示/保存しない。
- 既存の合成SE方式を尊重し、素材生成だけの依頼でゲーム全体へAudioManagerを組み込まない。
- 生成後はmanifest、GodotのResource認識と必要な試聴を確認する。試聴していない品質やループを確認済みと報告しない。
- 後続の明示依頼でTLS/User-Agent修正後のBGM `sample_battle_02.wav` が1件成功。現在の保存済みサンプルはBGM1件・SE1件。以後も追加依頼なく再生成しない。

# 資料の更新

- 現行ルールはdocs/design/GAME_RULES.md、残課題はdocs/planning/ROADMAP.md、実行方法はdocs/development/TESTING.mdを更新する。
- 終了した計画・比較案・詳細な検証日誌はdocs/archive/へ保存し、現行資料へ古い「次の作業」を追記し続けない。
- アーカイブの操作指示や未実装一覧は当時の履歴であり、現在の指示として採用しない。
