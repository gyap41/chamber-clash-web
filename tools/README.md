# 画像生成（開発専用）

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
`--model` で利用可能な画像モデルを指定できます。実行にはAPI利用料が発生します。
出力先は常に `assets/generated/`。同名ファイルは上書きしないため、再実行時は `--name` を変更してください。
PNGと同名のJSONにプロンプト・モデル・生成設定だけを保存します。
デフォルトのテスト素材は白背景の宝箱です（透過画像ではありません）。
ゲームへの組み込み・縮小・背景除去は別途行ってください。

キーやAPIエラー本文、認証ヘッダーは表示・保存しません。
HTTP 401はキー、403はモデル権限、429は残高・利用制限を確認してください。
通信失敗時は二重課金を避けるため自動再試行しません。

仕様: [OpenAI Image API公式ガイド](https://developers.openai.com/api/docs/guides/image-generation)
