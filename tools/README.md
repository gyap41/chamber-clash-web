# 画像生成（開発専用）

ファイル整理後：生成原画・JSON・使用量履歴はassets/generatedに保持。設定画・確認GIF・プロンプトはdocs/artで区分し、画像加工ツールの参照先を更新した。連番キャプチャは不要候補のraw-framesへ保存し、まとめ画像とGIFだけreviewsへ出力する。生成API・保存形式・予算は変更なし。[整理入口](../docs/art/README.md)。整理検証は `python -X utf8 tools/verify_art_organization.py`。one-timeのorganize_generated_art.pyは移動済み台帳があれば再実行を拒否する。

現行承認：ユーザー「これを基準にほかのキャラクターへの展開」に基づき他7人を各1枚、計7枚。各シートは3方向×立ち姿・回避3段階。ゲームへ統合。予約上限$46、累計最大45送信（50回制限も維持）。成否不明予約を保持し、追加候補・自動再送なし。以下は以前の制作段階。

現行承認（2026-09-12）：リナの足元・歩行修正に続くドッジ専用ポーズ制作をユーザーが承認（「修正していきましょう」「お願いします。」）。前後・右の3方向×踏み込み・空中・着地を1枚だけ生成し、ゲームに統合する。予約上限$39、累計最大38送信。成否不明1件の予約は保持。モデル・通信・保存形式は維持。以下の「現在／最新」は各段階の履歴。

現在の承認：リナのゲーム用正面・背面・右側面を揃える方向別画像1枚と、ゲーム内での試験を実施。予約上限$38、累計最大37送信（成否不明1件も予約保持）。他7人への展開・追加候補・ドッジ専用シートはこの1枚に含めない。モデル・通信・保存形式は維持。

最新承認（2026-09-12）：既存種族・識別点とリナの低頭身へ揃える他7人の修正設定画を各1枚。ソラの通信成否不明を報告後、ユーザーの再開指示を受け、前回予約を残して名前を指定した1回の再送を許可。予約上限$37、累計最大36送信。アニメーション用画像の追加生成は含めない。

成否不明の記録は成功へ変更しない。ユーザーの明示的な再開指示・日時・再送名をmanual_resolutionに保存した場合だけ後続を許可し、同条件の再送は指定した新しい名前1回に限定。元の予約は解放せず、古いlockも監査用ファイルとして保存する。自動retryではない。

画像・SE・BGM共通の環境設定と連携変更手順は [AI素材生成環境ガイド](../docs/development/ASSET_GENERATION_SETUP.md) を最初に参照してください。
音響CLIの詳細は [音響生成README](asset_generator/README.md)。本書は画像CLI固有の手順です。

Python 3.10以上。追加パッケージ不要。ゲーム実行時には読み込みません。
プロジェクト直下の `.env` の `OPENAI_API_KEY` を使用します（環境変数があれば優先）。
キーをコマンド引数へ渡さないでください。`.env` はGit除外済みです。

プロジェクト直下で実行:

```powershell
python tools/generate_image.py --check
python tools/generate_image.py
python tools/generate_image.py --name health-pickup --prompt "One pixel art health pickup, centered on a plain white background, no text" --quality medium
```

デフォルトは `gpt-image-2` / low / 1024×1024 / PNGを1枚生成。
制作予算の検証範囲は `gpt-image-2` のみ。他モデルは事前承認と単価/制限の更新が必要です。実行にはAPI利用料が発生します。
出力先は常に `assets/generated/`。同名ファイルは上書きしないため、再実行時は `--name` を変更してください。
PNGと同名のJSONにプロンプト・モデル・設定・参照ハッシュ・usage・料金表換算額を保存します。
デフォルトのテスト素材は白背景の宝箱です（透過画像ではありません）。
ゲームへの組み込み・縮小・背景除去は別途行ってください。

キーやAPIエラー本文、認証ヘッダーは表示・保存しません。
HTTP 401はキー、403はモデル権限、429は残高・利用制限を確認してください。
通信失敗時は二重課金を避けるため自動再試行しません。

仕様: [OpenAI Image API公式ガイド](https://developers.openai.com/api/docs/guides/image-generation)

## アイテム一覧の更新

`python tools/export_item_catalog.py` でカタログ・価格・占有形状から `docs/design/ITEM_CATALOG.md` の表を再出力する。バッグ範囲の説明は手動更新。外部通信・素材生成なし。

## 始まりの工房・画像制作（2026-09-12）
最新承認：8人各1枚の設定シート（通常等身前後＋2頭身対応）を計8回生成。予約上限$21→$29、累計最大28回。ゲームへの自動差し替えや追加候補は含まない。
現設定はgpt-image-2を維持。--prompt-fileと最大3個の--reference PNGを追加。
参照ありはPOST /v1/images/editsのmultipart、なしはgenerationsのJSON。
参照は各辺1536px以下・20MiB以下、入力4000bytes以下、出力1024四方・1枚に制限。
画像通信もtransport.https_openerの検証付きWindows ROOT/TLSとUser-Agentを使用する。
音響の生成処理は呼ばない。追加依存なし。
送信前にassets/generated/first-workshop-usage.jsonと排他lockへ記録する。
失敗・成否不明・usage欠損・ロック残存は停止。自動再試行なし。
$21/50回の承認に対し1回$1を予約し、累計が$21に達する送信を拒否（最大20回）。
2026-09-12、ユーザーが2頭身デザイン1枚と短い歩行シート1枚の比較制作を承認し、予約上限$19→$21。現行ゲームへの正式差し替えは今回の比較制作に含まない。
2026-09-12、低頭身リナの確認用1枚に続き、待機・移動・回避の3シート生成とゲーム差し替えをユーザーが承認。予約上限$16→$19。追加候補の無断再生成は含まない。
予約は成功後も解放しない。1024 high出力の旧高額比較値$0.211と制限した入力に余裕を持たせる保守枠。
usageのtext入力2.5/image入力4/output15 USD/百万tokenで別途換算、キャッシュ割引なし。
これは公式料金表換算の推計で請求確定額ではない。予約超過usageも次回停止。
同一条件または名前の再送は拒否。追加候補は理由・残予算を示したユーザー承認が必要。
原画と同名JSON、プロンプト、加工先・フレーム矩形・原点をmanifestへ保存する。
gpt-image-2は透明出力を指定せず、単色背景からローカルで透過化する。
無料検証: python -m unittest discover -s tools/tests -v
実行例: python tools/generate_image.py --name fw-floor --prompt-file docs/art/production/first-workshop-prompts/floor.txt --reference docs/art/settings/concepts/first-workshop-2026-09-11/02_exploration_field.png --quality high --check
公式確認: https://developers.openai.com/api/docs/pricing 、 https://developers.openai.com/api/reference/resources/images/methods/edit
