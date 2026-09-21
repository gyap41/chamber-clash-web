# 工房の外周壁素材

2026-09-21、ユーザーの明示承認を受け、既存CLIからOpenAI Image APIで1枚生成。gpt-image-2 / high / 1024×1024 / PNG。参照画像は `assets/first-workshop/cover.png`。追加候補・再送なし。

- [生成プロンプト](prompt.txt)
- [生成原本](../../../../assets/generated/fw-workshop-walls-v1.png)
- [API使用量・生成条件](../../../../assets/generated/fw-workshop-walls-v1.json)
- ゲーム用コピー：`assets/first-workshop/environment/workshop-walls-v1.png`
- usage換算推定：$0.107649。実際の請求額ではない。

画像を目視確認。既存の象牙色の石・青緑の金属・真鍮に合わせた4区画を、画像加工せずAtlasTextureとして参照する。

| Resource | 領域 (x, y, width, height) | 用途 |
| --- | --- | --- |
| `wall-face.tres` | 0, 0, 512, 512 | 壁の正面 |
| `wall-top.tres` | 512, 0, 512, 512 | 壁上面 |
| `corner-cap.tres` | 0, 512, 512, 512 | 角柱上面 |
| `door-jamb.tres` | 512, 512, 512, 512 | 扉枠用の面材 |

各Resourceは `assets/first-workshop/environment/` に保存。扉枠パネルは閉じた金属面に見えるため、開口部全体を覆う扉画像として使わず、枠の面材として使う。1120×800の両部屋の描画で連続配置と縮小表示を確認した。

固定2部屋へ外周壁と開口部を接続済み。FieldDefinition.wallsが衝突矩形、wall_texturesが上面、wall_face_texturesが正面のTexture2D参照を持つ。参考画像を受け、暗い室外・壁の垂直面・短い通路へ構成を改善した。素材交換で衝突矩形は変わらない。縦壁は素材を90度回転して48px単位で反復表示する。扉枠面材は開口部の両端に表示。
