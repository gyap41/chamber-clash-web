# 画像・関連ファイルの整理

2026-09-12。ユーザーの依頼に基づき、必要なゲーム素材・設定資料・採用結果・生成原画と、現行ゲームに不要な中間物・旧素材を区別して配置した。削除・有料生成なし。

699ファイルを移動（移動前の合計191,816,215 bytes）。うち画像507ファイルはSHA-256一致で内容不変を確認。設定の初稿も必要な比較資料として保存した。原画・同名JSON・使用量台帳・成否不明の記録はassets/generatedに保持し、過去の送信内容を変更していない。

不要候補は497ファイル、約64.26MiB：連番PNG300、差し替え済み素材と関連情報152、原画の旧importファイル45。ここは現行ゲームが参照しないが、古い比較ツールや保存フレームからのGIF再編集には使うため、今回削除しない。テストで必要な旧リナはtests/fixtures/artへ分離した。

設定はdocs/art/settings、確認結果はdocs/art/reviews、制作指示はdocs/art/production。ゲーム使用素材はassets/first-workshopに維持。原画には.gdignoreを置いてGodotのインポート対象から外した。生成先、API・認証・モデル・保存形式・課金枠は変更していない。

移動に合わせて124個の既存テキストファイルの参照を更新し、分類READMEを追加。撮影ツールとGIF化ツールは連番画像をraw-frames、完成結果をreviewsに分けて保存する。元パスと現在パス・ハッシュはrelocations.jsonに記録した。生成JSONに記録された当時のパスは台帳から追跡する。

検証：`python -X utf8 tools/verify_art_organization.py` 合格。全移動先存在、画像507点のハッシュ、docs/art内のリンクを検証。Godotインポート成功。全64ヘッドレステスト合格（`.local/logs/run_tests-20260912-212428.log`）。ゲームの描画や性能の変更はしていない。

[整理入口](../../../art/README.md) / [移動台帳](relocations.json) / [不要候補](unused-candidates/README.md)
