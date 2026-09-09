# Claude向け引き継ぎプロンプト

以下をClaudeへそのまま渡してください。

---

`C:\GameCreate\chamber-clash` のGodotゲーム開発を引き継いでください。最初に調査し、実装済みの内容を再実装しないでください。今回はP3の実装を進めてください。

## 最初に読むもの

1. 適用される `AGENTS.md` / `CLAUDE.md` があればそれら。
2. `docs/planning/ROGUELIKE_PVP_PLAN.md`
3. `docs/design/GAME_RULES.md`
4. `docs/development/ARCHITECTURE.md`
5. `docs/development/TESTING.md`
6. `docs/planning/ROADMAP.md`
7. `git status`、最新コミットと差分、現在の実装。

## 目的と現在地

ローグライク×対人シューティングとして、一試合の中で武器・レリックを育て、組み合わせと相手への対策を楽しめるようにする。Enter the Gungeonの装備の豊富さ、Wizard of Legendのスピード感、Slay the Spireの戦略的選択が参考。

P0〜P2のコードを実装済み。既存20武器・12レリック・8キャラクターを維持した。P3以降は未実装。Godotプロジェクトが原本で、`legacy-web/` は比較資料。Gitの古い履歴には移動前の原型が残っているので、それで現在のコードを上書きしないこと。

### 実装済みのルール

- 3本先取、一試合が一つのラン。90秒・危険地帯を維持。
- 初期はサイドアーム＋共通B/B/A候補から主力1丁、共通レリック3候補から2個。
- 成長段階1〜5で装備枠3/4/5/6/6。装備中を含む所持庫8個、同一ID重複不可。準備中に着脱・破棄可能。
- 試合が続く決着後、両者に同数のレリック報酬1回。共通基礎候補から所持品を除外して補充。候補不足にも対応。
- 主力1丁を継承し、開始時にHP・弾薬・パルス・各種タイマー・変形モードをリセット。HPレリック着脱で回復を稼げない。
- フィールドレリックはG/Hの明示操作、1人1ラウンド1個の仮装備。装備上限に算入し、永続化は通常報酬1回を消費。固定フェザー配置は撤去。
- 引き分けでは報酬・段階を増やさず、仮取得を破棄して確定ビルドで再戦。
- 旧ドラフト・ショップを無料報酬・装備整理・主力指定の準備画面へ置換。相手の前ラウンド開始時の確定ビルドを表示。
- CPUも同じ状態APIで取得・装備・確定。武器特性との簡易相性評価を使い、取得できないレリックを追わない。
- キャラと音声ON/OFFは成長状態と分離。試合終了時は永続ビルド・報酬を消去し、結果用の得点と戦場を残す。Enterで新規試合にリセット。

### 実装の入口

- `scripts/game/match_state.gd`：試合内の永続データと取得・確定ルール。
- `scripts/game/reward_generator.gd`：固定シード付き抽選。補給と報酬の乱数列は分離。
- `scripts/game/main.gd`：新規試合・準備・開始・決着の接続。
- `scripts/game/run_log.gd`：`user://run-logs/`へのJSONL。外部送信なし。
- `scripts/combat/player.gd`：ビルド適用・最大HP再計算・仮レリック。
- `scripts/ui/preparation.gd`：3列の成長画面とCPU準備。`ready_shop()`という名前だけ残るが購入処理ではない。
- `scripts/ui/hud.gd`、`scripts/world/supplies.gd`、`scripts/world/pickup.gd`、`scripts/ai/cpu_ai.gd`。
- `data/catalog.json`：既存定義。IDの並べ替え禁止。

論理画面は既存1120×800（戦場600＋下部HUD）。ウィンドウ1120×600へ比率を保って縮小する。戦場の座標を不用意に600pxの表示全体へ詰めないこと。Webの日本語には同梱`assets/fonts/ipag.ttf`を使用。

## 検証済みと未確認を区別する

- 変更前21本、変更後25本のheadlessテスト全件成功。描画テスト1本も成功。
- `match_progression.gd`、`build_inventory.gd`、`reward_generation.gd`、`run_logging.gd`を追加。
- 3対0・3対2・引き分け・二重確定・同数報酬・所持庫境界・HP着脱・S主力継承・消耗リセット等を検証。
- Windows Compatibilityで初期準備・8個所持庫・6レリックHUDを目視確認。
- ローカルWeb版を通常速度でタイトルから0対3まで実操作で完走。着脱、パルス、CPU仮取得、新規試合へのリセットを確認。ただしP1は主に静止状態で、楽しさ・対人公平性の評価ではない。
- 未確認：Webの最大6装備状態の直接操作、Windows配布版、音の聴取、操作全体の網羅的な実プレイ、20〜30試合の比較、人間同士の対策・公平性、最大構成の長時間負荷。

```powershell
& ./.local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --quit
powershell -ExecutionPolicy Bypass -File run_tests.ps1
$env:CHAMBER_SCREENSHOT = "$PWD/.local/logs/claude-render.png"
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

ツールは`.local/tools/`を確認。環境のログ保存先・証明書アクセスエラーとゲームの不具合を区別するが、エラーが出た実行を成功扱いにしない。ログ名・画像は`TESTING.md`を参照。`.local/`はGit対象外なので別環境では再検証が必要。

## 次のP3への注意

まず成長試合の評価を行う。P3は共通発動条件と6種のシナジーレリック、派生深さ・適用済み効果・再帰生成禁止・倍率の整理。P0の`root`は計測用で、被弾無敵用`volley`ともP3の派生制限機構とも別。弾消去から爆発・分裂を発生させない既存仕様を維持する。P4の先行入力、P5の武器改造や大量追加を勝手に混ぜない。

## Git・配布

ローカルの現在状態を保存する際には、先行セッションのフォルダー整理とP0〜P2実装が一緒に必要。`.local/`、`.godot/`、`web-build/`はGit対象外。Webは`export_presets.cfg`の`Web`プリセットで再生成する。

`C:\GameCreate\chamber-clash` 本体には2026-09-09時点でも `remote` が設定されていない（ローカルのみ）。送信先や公開方法を推測せず、作業開始時点の`git remote -v`とユーザー指定を確認すること。

Web版（`web-build/`、本体とは別の独立git管理）は `gyap41/chamber-clash-web` へ2026-09-09にP0〜P2実装反映済みでpush・GitHub Pages公開済み（コミット`dee57a8`、`https://gyap41.github.io/chamber-clash-web/`で実機確認済み。タイトル・キャラ選択・新準備画面・日本語表示・コンソールエラー無しを確認）。P3実装後に再公開する場合も、Godotで`--export-release "Web" web-build/index.html`書き出し→`web-build`側でcommit/pushの手順を踏襲し、ソースのpush、ビルド作成、サイト公開完了を区別して報告する。

作業開始時には、最新実装と資料を照合し、残る受入確認と次の着手候補を簡潔に報告してください。
