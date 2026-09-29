# 画像生成（開発専用）

探索20室の専用素材: `Godot --headless --path . --script res://tools/build_exploration_kit.gd --quit-after 600`。インポート済みの `assets/stages/ashen-foundry-v2/exploration-kit/` の5枚の透過原画と遠景から19個のAtlasTextureを作り、実寸・抽出範囲をregions.jsonへ保存。ピクセル加工・追加生成は行わない。[生成条件と部屋への組み込み](../docs/art/production/authored-rooms/README.md)。

回廊の崩落アトラス: `Godot --headless --path . --script res://tools/build_gallery_collapse_atlas.gd` で、インポート済みの `assets/stages/ashen-foundry-v2/gallery-collapse/atlas.png` から4つのAtlasTexture `.tres`を再構築する。画像生成・画像ピクセル加工は行わない。原本・内蔵画像生成の条件・表示寸法は[回廊制作記録](../docs/art/production/authored-rooms/README.md)を参照。

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


## 月間予算（2026-09-27〜）

以前の「送信回数の上限（1回1ドルの予約で計算）」を廃止し、**月ごとの金額予算**に切り替えました。ユーザー決定で月20ドル。

- 設定は [image_budget.json](image_budget.json)（`monthly_budget_usd`、`request_reserve_usd`）。金額は環境変数 `IMAGE_MONTHLY_BUDGET_USD` で一時的に上書きできます。キーではないので `.env` には置きません。
- 使用額は、使用量台帳 `assets/generated/first-workshop-usage.json` の使用量からの換算額（請求額ではない）を、送信日時のUTC年月ごとに合計します。費用が分からない送信（送信中・失敗・成否不明）は1回0.25ドルとして数えます。
- 送信前に「今月の残り ≥ 0.25ドル」を確認し、足りなければ送信しません。1回の実費が0.25ドルを超えた場合は、見積もりが甘いので台帳を `budget_review_required` にして止めます。
- 作業の前に、何枚まで作れるかを確認できます（キー・通信不要）:

```powershell
python tools/generate_image.py --plan 4
```

終了コード0なら予算内、3なら予算超過。`--check` と生成の完了時にも、今月の使用額と残りを表示します。

**OpenAIの実際の残高は確認できません。** 通常のAPIキーでは残りクレジットを読めないためです（2026-09-27時点の理解。公式資料の該当ページは取得できず、未確認）。残高がなくなると、生成はHTTP 429等のエラーで失敗し、自動再試行せずに停止します。失敗した送信は台帳に残り、ユーザーと照合するまで次の送信を止めます。

## 参照入力と停止条件

--prompt-fileと最大3個の--reference PNGに対応。画像・プロンプトの制限はCLIと共通設定ガイドを参照。参照ありはedits、なしはgenerationsを使用する。送信前にfirst-workshop-usage.jsonと排他lockへ記録し、失敗・成否不明・usage欠損・ロック残存時は停止する。自動再試行しない。上記--checkはローカル検証のみ。実生成は依頼範囲を確認してから、用途に応じた引数で実行する。

## 資料索引の保守

`python tools/docs_index.py` でMarkdownの分類索引を再生成します。`python tools/docs_index.py --check` は索引の更新漏れとローカルのインラインリンク先の存在を点検し、問題があれば終了コード1を返します。外部URL、見出しアンカー、参照形式リンク、本文中の裸のパスは検証対象外です。API通信や素材生成は行いません。分類と資料更新のルールは[資料運用](../docs/DOCUMENTATION_GUIDE.md)を参照してください。

## キャラクターの8方向リグ

生成した部品画像と設定ファイルから、8方向の待機・走行・回避・近接の素材を書き出す。手順は [キャラリグの作り方](character_rig/README.md)。

作り込み部屋の分岐マップ撮影：`Godot --path . --script res://tools/capture_authored_map.gd --quit-after 1500`。seed27の全訪問地図、分岐・北門口・保管区画の入口と発見地点を制作記録のviewsへ保存。

展望室v2の欄干：`Godot --headless --path . --script res://tools/build_overlook_assets.gd --quit-after 100`。生成PNGの透過余白をAtlasTextureの参照範囲として除き、原本は変更しない。地底背景と生成条件は[展望室の制作記録](../docs/art/production/authored-rooms/README.md)を参照。

苔玉8方向: `Godot --headless --path . --script res://tools/build_moss_directions.gd`で既存透過原本の抽出矩形・共通縮尺・甲羅原点を再計測する。`Godot --path . --script res://tools/capture_moss_directions.gd --quit-after 1800`で8方向の歩行と横倒しを72フレーム撮影する。生成指示と原本は[制作記録](../docs/art/production/root-runner-motion/README.md)を参照。
