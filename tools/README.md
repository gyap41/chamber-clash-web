# 画像生成（開発専用）

過去の生成枠・予算変更は[制作履歴](../docs/archive/2026-09-22/markdown-audit/IMAGE_CLI_BEFORE.md)に分離しました。新規生成の許可や残予算として使わず、今回の依頼と使用量台帳・CLIの制限を確認してください。

画像・SE・BGM共通の環境設定と連携変更手順は [AI素材生成環境ガイド](../docs/development/ASSET_GENERATION_SETUP.md) を最初に参照してください。
音響CLIの詳細は [音響生成README](asset_generator/README.md)。本書は画像CLI固有の手順です。

Python 3.10以上。追加パッケージ不要。ゲーム実行時には読み込みません。
プロジェクト直下の `.env` の `OPENAI_API_KEY` を使用します（環境変数があれば優先）。
キーをコマンド引数へ渡さないでください。`.env` はGit除外済みです。

プロジェクト直下で実行:

```powershell
python tools/generate_image.py --check --name config_check_only
```

デフォルトは `gpt-image-2` / low / 1024×1024 / PNGを1枚生成。
制作予算の検証範囲は `gpt-image-2` のみ。他モデルは事前承認と単価/制限の更新が必要です。実行にはAPI利用料が発生します。
出力先は常に `assets/generated/`。同名ファイルは上書きしないため、再実行時は `--name` を変更してください。
PNGと同名のJSONにプロンプト・モデル・設定・参照ハッシュ・usage・料金表換算額を保存します。
デフォルトのテスト素材は白背景の宝箱です（透過画像ではありません）。
ゲームへの組み込み・縮小・背景除去は別途行ってください。

キーやAPIエラー本文、認証ヘッダーは表示・保存しません。
HTTPエラーは共通設定ガイドに従い切り分けます。ステータスコードだけで原因を断定しません。
通信失敗時は二重課金を避けるため自動再試行しません。

仕様: [OpenAI Image API公式ガイド](https://developers.openai.com/api/docs/guides/image-generation)

## アイテム一覧の更新

`python tools/export_item_catalog.py` でカタログ・価格・占有形状から `docs/design/ITEM_CATALOG.md` の表を再出力する。バッグ範囲の説明は手動更新。外部通信・素材生成なし。


## 参照入力と停止条件

--prompt-fileと最大3個の--reference PNGに対応。画像・プロンプトの制限はCLIと共通設定ガイドを参照。参照ありはedits、なしはgenerationsを使用する。送信前にfirst-workshop-usage.jsonと排他lockへ記録し、失敗・成否不明・usage欠損・ロック残存時は停止する。自動再試行しない。上記--checkはローカル検証のみ。実生成は依頼範囲を確認してから、用途に応じた引数で実行する。

## 資料索引の保守

`python tools/docs_index.py` でMarkdownの分類索引を再生成します。`python tools/docs_index.py --check` は索引の更新漏れとローカルのインラインリンク先の存在を点検し、問題があれば終了コード1を返します。外部URL、見出しアンカー、参照形式リンク、本文中の裸のパスは検証対象外です。API通信や素材生成は行いません。分類と資料更新のルールは[資料運用](../docs/DOCUMENTATION_GUIDE.md)を参照してください。
