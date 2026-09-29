# 2026-09-12 更新前資料の履歴集

区分: 履歴。状態: 参照専用。旧仕様・承認・未実装一覧は現在の指示ではありません。

更新前の全文バックアップを一冊へ統合しました。各節の旧ファイル名と本文を保持し、文書リンクのみ統合先へ更新しています。現行資料は[総合索引](../../README.md)から参照してください。

## 収録資料
- [BEFORE_CPU_STRENGTHENING_TESTING.md](#snapshot-01)
- [BEFORE_CPU_TACTICS_TESTING.md](#snapshot-02)
- [BEFORE_EXTENSION_ARCHITECTURE.md](#snapshot-03)
- [BEFORE_EXTENSION_TESTING.md](#snapshot-04)
- [BEFORE_REFACTOR_TESTING.md](#snapshot-05)
- [BEFORE_SHARED_SUPPLIES_TESTING.md](#snapshot-06)
- [BEFORE_SMALL_IMPROVEMENTS_TESTING.md](#snapshot-07)
- [BEFORE_WEAPON_DIFFERENTIATION_TESTING.md](#snapshot-08)
- [PREPARATION_UI_BEFORE_REVISION.md](#snapshot-09)

---

<a id="snapshot-01"></a>

## 旧ファイル: BEFORE_CPU_STRENGTHENING_TESTING.md

# 検証手順

更新: 2026-09-12。実行方法と残る受入を管理する。過去の件数・失敗修正・ログは
[検証履歴](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-14) を参照する。

## 実行

プロジェクトルートのPowerShellから実行する。Godotは.local/tools/を優先して探索する。

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
powershell -ExecutionPolicy Bypass -File run_tests.ps1
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

別の実行ファイルは -GodotPath で指定する。tests直下の.gdを自動検出し、通常はrender.gdを除く。
件数は増減するため固定の「全34本」等を現在の合格条件にしない。
ログは.local/logs/。終了コード、エラー行、PASS表示を確認する。
PASS数はアサーション数ではない。Godotのユーザーデータ/キャッシュ権限エラーも無視しない。
音響素材がない場合のaudio_assets.gdはSKIPを返す。単独実行は終了コード0だが、現行の一括ランナーはPASS表示なしを失敗扱いにする。未生成を認識成功と扱わない。

## 描画と入力

```powershell
$env:CHAMBER_SCREENSHOT = "$PWD/.local/logs/render.png"
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

render.gdは画面描画可能な環境で実行する。準備・所持品・HUD・戦闘・補給・演出を確認する。
B案の座標/操作基準は [準備UI仕様](../../design/PREPARATION_UI_B.md)。
スクリプトによるGUI入力や静止画確認と、人間による操作感評価を区別する。

## 重点回帰

- match_state/準備: 商品二重購入・資金収支、配置衝突、控え容量/解除先満杯、確定、丸腰出撃、引き分け/試合終了、CPU。
- fine_grid/item_instances/relic_stacking: 個体ID、同種の位置/破棄、重複可否、能力加算、取得経路。
- 戦闘: 全武器、改造、レリック、派生制限、回避/被弾、入力予約、危険地帯、補給/宝箱。
- field_weapon_reserve/eight_more_weapons: 控え収納と明示配置、引き分け/決着/満杯/重複、追加通常8武器。
- added_weapons/added_relics/added_item_acquisition: 初期専用8種の抽選除外、追加全品の購入・売却・無料持ち帰り、3連射の補正/予約取消、交差弾、15レリックの条件/上限/対象外、CPU初期装備。
- sound: ミュート、戦闘シグナル、合成PCM、16ボイス、停止/キャッシュ/バス解放。
- 描画: 長文、所持品増加、縮小画面、選択固定、配置プレビュー、ドラッグの掴み位置。

武器が必要なテストは明示的に装備を作る。自動サイドアームや旧4枠制限を仮定しない。
tests/helpers/battle.gdを活用し、レリックの追射予約・一時フラグなど状態リークを防ぐ。

## 素材生成ツール

```powershell
.local/audio-venv/Scripts/python.exe -m unittest discover -s tools/asset_generator/tests -v
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/audio_assets.gd
```

Pythonテストは通信mockで課金なし。環境と無料確認は [素材生成設定](../../development/ASSET_GENERATION_SETUP.md)。
直近の音響検証ではPython19件とBGM/SEのGodot Resource認識が成功。全ゲームテストの再実行とは別。

## 最新の記録と未完了の受入

武器14種の差別化とプラネタリウム8方向化後、**52本（headless51＋描画1）PASS、終了コード0**。
実行: `powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender`。
ログ: `.local/logs/run_tests-20260912-004007.log`。
Godot 4.7.2のheadlessエディタで再インポートも成功。サンドボックス内のユーザーデータ・キャッシュ・証明書権限エラー後、通常権限で検証した。

- `weapon_differentiation.gd`: 8発の45度間隔・消費1発、武器×キャラ×装填短縮、装填直前/直後、切替中断、途中取得による進行時間の固定、2発弾倉へのワイドマガジン、未指定武器の1.15秒・スパナ変形を検証。
- 既存の追尾方向/反射/パルス、レシートの反射加算、エコ追射、散弾角度、弾薬箱の予備補給、レリック効果と残弾の期待値を新仕様へ更新して回帰成功。
- 最初の全体実行では旧弾数・角度・補給量の期待値が残る5テストが失敗。更新後の全体再実行はすべて成功。
- 描画テストはCompatibilityで成功。今回はスクリーンショットの目視確認・人間による実プレイを含まない。

前回のリファクタリング検証は [変更前の検証記録](DOCUMENT_SNAPSHOTS.md#snapshot-08)。
武器差別化の判断と試作値は [実装前の比較案](WEAPON_DIFFERENTIATION_PROPOSAL.md)、現行値は [アイテム一覧](../../design/ITEM_CATALOG.md)。

一覧更新: `python tools/export_item_catalog.py`。全38武器・35レリック・8キャラの表を生成する。
武器・レリック件数と通常入手数は自動集計。バッグ説明は手動管理。

### 人間の実プレイ未確認

購入・売却・配置操作の使いやすさ、5本先取の総時間、価格/初期8/上限24/控え8のバランス、
CPUの投資判断、8方向化したプラネタリウムの避けやすさ・配置後の強さ、武器別装填を含む初期キャラの均衡は未評価。20シードのCPU自動検証は対人試合の実測ではない。
20〜30試合の比較と、必要なら4本先取との比較を行う。自動テスト成功だけで数値を確定しない。
拡張のドラッグ・回転・配置後移動、P9隣接効果、オンライン対応は未実装。
Web/Windows配布版、一試合完走、最大負荷、先行入力・音の実プレイ確認も残る。
音響生成は行っていない。audio_assetsは保存済み素材の読み込みのみ。

旧40本の詳しい記録は [移行前の検証記録](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-11)、
購入移行の経緯は [検証日誌](../2026-09-11/PURCHASE_ECONOMY_VALIDATION.md) を参照。


---

<a id="snapshot-02"></a>

## 旧ファイル: BEFORE_CPU_TACTICS_TESTING.md

# 検証手順

更新: 2026-09-12。実行方法と残る受入を管理する。過去の件数・失敗修正・ログは
[検証履歴](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-14) を参照する。

## 実行

プロジェクトルートのPowerShellから実行する。Godotは.local/tools/を優先して探索する。

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
powershell -ExecutionPolicy Bypass -File run_tests.ps1
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

別の実行ファイルは -GodotPath で指定する。tests直下の.gdを自動検出し、通常はrender.gdを除く。
件数は増減するため固定の「全34本」等を現在の合格条件にしない。
ログは.local/logs/。終了コード、エラー行、PASS表示を確認する。
PASS数はアサーション数ではない。Godotのユーザーデータ/キャッシュ権限エラーも無視しない。
音響素材がない場合のaudio_assets.gdはSKIPを返す。単独実行は終了コード0だが、現行の一括ランナーはPASS表示なしを失敗扱いにする。未生成を認識成功と扱わない。

## 描画と入力

```powershell
$env:CHAMBER_SCREENSHOT = "$PWD/.local/logs/render.png"
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

render.gdは画面描画可能な環境で実行する。準備・所持品・HUD・戦闘・補給・演出を確認する。
B案の座標/操作基準は [準備UI仕様](../../design/PREPARATION_UI_B.md)。
スクリプトによるGUI入力や静止画確認と、人間による操作感評価を区別する。

## 重点回帰

- match_state/準備: 商品二重購入・資金収支、配置衝突、控え容量/解除先満杯、確定、丸腰出撃、引き分け/試合終了、CPU。
- fine_grid/item_instances/relic_stacking: 個体ID、同種の位置/破棄、重複可否、能力加算、取得経路。
- 戦闘: 全武器、改造、レリック、派生制限、回避/被弾、入力予約、危険地帯、補給/宝箱。
- field_weapon_reserve/eight_more_weapons: 控え収納と明示配置、引き分け/決着/満杯/重複、追加通常8武器。
- added_weapons/added_relics/added_item_acquisition: 初期専用8種の抽選除外、追加全品の購入・売却・無料持ち帰り、3連射の補正/予約取消、交差弾、15レリックの条件/上限/対象外、CPU初期装備。
- sound: ミュート、戦闘シグナル、合成PCM、16ボイス、停止/キャッシュ/バス解放。
- 描画: 長文、所持品増加、縮小画面、選択固定、配置プレビュー、ドラッグの掴み位置。

武器が必要なテストは明示的に装備を作る。自動サイドアームや旧4枠制限を仮定しない。
tests/helpers/battle.gdを活用し、レリックの追射予約・一時フラグなど状態リークを防ぐ。

## 素材生成ツール

```powershell
.local/audio-venv/Scripts/python.exe -m unittest discover -s tools/asset_generator/tests -v
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/audio_assets.gd
```

Pythonテストは通信mockで課金なし。環境と無料確認は [素材生成設定](../../development/ASSET_GENERATION_SETUP.md)。
直近の音響検証ではPython19件とBGM/SEのGodot Resource認識が成功。全ゲームテストの再実行とは別。

## 最新の記録と未完了の受入

小改善の回帰は `tests/small_improvements.gd` で検証する。Fでの開封とGの無効化・ポーズ中のガード、星弾の旋回量と前方範囲、8か所のエリア端・壁付近から実際のPlayer.stepによる退避、ラウンド/試合終了時のボタン、キャラ選択へのモード引継ぎ・新規試合・タイトルへの遷移を含む。

レジェンド出現率は30%。変更後に `supplies.gd` / `play_feedback.gd` をheadlessで実行し、両方PASS・終了コード0。`supplies.gd` で既定値、当選時の予告と1回投下、落選時の予告なし・投下なし・再抽選なし、リセットを検証する。最大補給数のテストでは当選率を明示的に100%へ固定する。

共有補給への変更は `supplies.gd` / `relics.gd` で検証する。各イベントの1個出現、90秒の最大総数（通常武器2・S当選時1・レリック1・弾薬5）、弾薬の0/18/40/62/84秒、占有候補の代替と全候補占有時の出現抑止を確認する。

2026-09-12: headless全52本を実行し51本PASS。`play_feedback.gd` の旧上限（武器6/レリック2/弾薬14）を新上限（3/1/5）へ更新し、単独再実行でPASS・終了コード0。追加した `supplies.gd` の時刻・占有回帰も単独PASS。ログ: `.local/logs/run_tests-20260912-012724.log`。修正後の一括再実行はしていない。実プレイの弾切れ頻度と補給独占のバランスは未測定。

前回のテスト・勝敗画面の描画記録は [共有補給前の検証記録](DOCUMENT_SNAPSHOTS.md#snapshot-06) を参照。

CPU強化時の実行記録は [小改善前の検証記録](DOCUMENT_SNAPSHOTS.md#snapshot-07) を参照。
今回の人間による操作感・追尾の避けやすさ・CPU勝率は未評価。

一覧更新: `python tools/export_item_catalog.py`。全38武器・35レリック・8キャラの表を生成する。
武器・レリック件数と通常入手数は自動集計。バッグ説明は手動管理。

### 人間の実プレイ未確認

購入・売却・配置操作の使いやすさ、5本先取の総時間、価格/初期8/上限24/控え8のバランス、
CPUの投資判断、8方向化したプラネタリウムの避けやすさ・配置後の強さ、武器別装填を含む初期キャラの均衡は未評価。20シードのCPU自動検証は対人試合の実測ではない。
20〜30試合の比較と、必要なら4本先取との比較を行う。自動テスト成功だけで数値を確定しない。
拡張のドラッグ・回転・配置後移動、P9隣接効果、オンライン対応は未実装。
Web/Windows配布版、一試合完走、最大負荷、先行入力・音の実プレイ確認も残る。
音響生成は行っていない。audio_assetsは保存済み素材の読み込みのみ。

旧40本の詳しい記録は [移行前の検証記録](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-11)、
購入移行の経緯は [検証日誌](../2026-09-11/PURCHASE_ECONOMY_VALIDATION.md) を参照。


---

<a id="snapshot-03"></a>

## 旧ファイル: BEFORE_EXTENSION_ARCHITECTURE.md

# プロジェクト構成

シーンとスクリプトは同じ用途名で分類します。ファイルの移動でノード階層・シグナル・Inspector値・戦闘ルールは変更していません。

|フォルダー|責務|
|---|---|
|`scenes/game/`, `scripts/game/`|試合の開始・停止・ラウンド進行、各機能の接続|
|`scenes/combat/`, `scripts/combat/`|プレイヤー、弾、重力場、パルス|
|`scenes/world/`, `scripts/world/`|アリーナ、壁、補給の配置・取得|
|`scenes/ui/`, `scripts/ui/`|タイトル、キャラクター選択、成長準備、HUD|
|`scenes/visuals/`, `scripts/visuals/`|描画・アニメーション・画像切り出し|
|`scripts/catalog/`|定義の読み込みと種類別アクセス、装備初期値の生成|
|`scripts/ai/`|CPUの行動判断|
|`scripts/audio/`|合成効果音・ミュート制御|
|`data/`|共有定義の原本。現在は `catalog.json`|
|`assets/`|実行用素材と用途別の素材案内|
|`tests/`|独立実行できる回帰テスト。直下の `.gd` を一括実行|
|`legacy-web/`|移植元。比較用に保存し、Godotインポート・配布から除外|
|`web-build/`|再生成するWeb出力。Git管理・Godotインポート対象外|
|`.local/`|ローカルのツール、バックアップ、ログ、検証画像|

`project.godot` と `export_presets.cfg`、`run_tests.ps1` はプロジェクトの入口としてルートに置きます。エディタ用の `export_templates/`、`feature_profiles/`、`script_templates/`、`text_editor_themes/` はそのままです。

## データと共通処理

`game_catalog.gd` がJSONを一度読み込みます。武器・キャラクター・レリックのカタログはこの定義を共有し、別の種類のカタログへ依存しません。定義は読み取り専用として扱います。弾倉・予備弾・変形モードは `new_inventory_entry()` で毎回独立したDictionaryを作り、プレイヤーの在庫だけで変更します。

`atlas_regions.gd` が矩形切り出しと縦横別のグリッド切り出しを共通化します。各カタログと弾描画側は切り出したAtlasTextureをキャッシュし、毎フレーム生成しません。元画像のピクセルやシート配置は変更していません。

`item_identity.gd` が武器トークン・レリック個体と種類IDの変換、異なる型を含む個体比較を扱います。
`build_grid.gd` が開放セル・形状・占有セル・配置可否・携行武器の読み順を計算します。
どちらも試合や画面のノードを保持しません。準備の状態変更・購入条件は `match_state.gd`、
戦闘開始時の装備コピーと仮取得は `player.gd` が担当し、同じ配置計算を使用します。
MatchStateの既存の形状・識別APIは委譲メソッドとして維持しています。

## 拡張するとき

- 武器・レリック追加は、JSONへの定義追加、実装、画像対応、回帰テストを揃えてから `SUPPORTED` にIDを追加します。配列番号が既存IDなので、既存要素の並べ替えは避けます。
- 新しい戦闘効果は `combat/`、見た目だけの処理は `visuals/` へ追加します。規模が増えたら `main.gd` の射撃生成や試合状態を独立させます。
- オンライン対戦は今後の計画です。ローカル入力・CPU判断と戦闘状態を分ける設計を先に検討し、現在の辞書共有をそのまま通信仕様にしないでください。
- ファイル移動時は `.gd.uid` / `.import` を一緒に移し、`res://` 参照・テスト・現行資料を更新してGodotを再インポートします。
- 再開時はディスク上の最新ファイルとGit差分を確認します。未コミット変更を古いコピーで上書きせず、広い変更の前に `.local/backups/` へ保存します。

## 現在のラン状態

- `match_state.gd`：武器/レリック共通の所持庫・装備/配置・改造・段階・報酬・確定状態を保持。戦闘ノードは保持しない。`previous`は前ラウンド開始時の確定ビルドの独立コピー。
- `reward_generator.gd`：ローカルのRandomNumberGeneratorで候補生成。ショップの基礎商品はmatch_stateがこの乱数列を使って生成し、補給は別の乱数列を使う。同じシードと同じ選択・段階で同じ候補になる。入力・物理・CPU回避乱数の完全再現ではない。
- `main.gd`：`new_match(seed)`と`reset_round()`を分離。決着を一度だけ確定し、引き分けは準備を挟まず確定ビルドを再適用。`launch_round()`だけが消耗と戦闘一時状態を全初期化する。
- `player.gd`：戦闘用の装備コピーと仮レリック1個。`apply_build()`は最大HPを基礎値から再計算し、heal指定時のみ全快と武器再生成。35種のレリック定義に対応。個体を種類ID配列へ変換し、小型レリックは加算処理を使用。P3の発動条件・派生制限はplayer/main/projectileの各経路で管理。射撃・切替予約とすり抜け装填の状態変更はplayerが保持し、mainが入力・実行順・破棄を接続する。
- `preparation.gd`：B案のグリッド・詳細・ショップ・下部控え・購入/売却・配置・出撃確認を扱う。`ready_shop()`は準備完了を確定し、CPU準備と出撃へ接続する。
- `cpu_preparation.gd`：画面から独立したCPUの相性評価・購入・配置方針。MatchStateの共通APIだけで資金・取得・配置・確定を変更する。UIの既存呼出メソッドは委譲とログ記録を担当する。
- `hud.gd`：武器欄と現在のrelic_capacityに応じたレリックカード。`relic_card.gd`がカードの折り返し付きツールチップを生成し、カード上の入力は戦闘へ流さない。
- `run_log.gd`：`user://run-logs/`へJSONLで記録。シード、準備と戦闘時間、装備/選択/交換、射撃起点、散弾数、分裂/追射/パルス、実ダメージ、補給、フレーム間隔と最大弾数。外部送信なし。起点IDは計測用で、被弾無敵のvolleyとは別に管理する。

画面は既存の論理1120×800（戦場600＋下部HUD）を維持し、既定ウィンドウ1120×600へアスペクト比を保って縮小する。Webでも同梱の`ipag.ttf`を既定フォントとして使用する。

武器は `gun:<id>`、レリック個体は `relic:<種類ID>:<連番>` として扱う。item_identity.gdが種類との変換境界。
装備容量はグリッド面積と形状の収まりで判定し、主力IDと自動サイドアームは使用しない。
生成ツールはゲーム本体と分離し、[素材生成設定](../../development/ASSET_GENERATION_SETUP.md)を参照する。

## 戦闘フレームの順序

`main.gd`の物理更新は、残り時間・演出、パルス演出、追射、プレイヤー行動と危険地帯、
補給、弾の移動と消滅/派生、重力場と吸収、決着の順に実行します。
各処理を専用メソッドに分けていますが、同フレームの命中・派生・吸収に関わる順序は維持します。
パルス・近接・吸収による消去と、寿命終了時の爆発・分裂を混同しないでください。


---

<a id="snapshot-04"></a>

## 旧ファイル: BEFORE_EXTENSION_TESTING.md

# 検証手順

更新: 2026-09-12。実行方法と残る受入を管理する。過去の件数・失敗修正・ログは
[検証履歴](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-14) を参照する。

## 実行

プロジェクトルートのPowerShellから実行する。Godotは.local/tools/を優先して探索する。

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
powershell -ExecutionPolicy Bypass -File run_tests.ps1
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

別の実行ファイルは -GodotPath で指定する。tests直下の.gdを自動検出し、通常はrender.gdを除く。
件数は増減するため固定の「全34本」等を現在の合格条件にしない。
ログは.local/logs/。終了コード、エラー行、PASS表示を確認する。
PASS数はアサーション数ではない。Godotのユーザーデータ/キャッシュ権限エラーも無視しない。
音響素材がない場合のaudio_assets.gdはSKIPを返す。単独実行は終了コード0だが、現行の一括ランナーはPASS表示なしを失敗扱いにする。未生成を認識成功と扱わない。

## バージョン表示

ゲームのバージョンは `project.godot` の `application/config/version` で管理する。初期値は `0.1.0-dev`。タイトル画面はこの値を読み、`v0.1.0-dev` の形式で表示する。リリース時はこの設定を更新する。

## 描画と入力

```powershell
$env:CHAMBER_SCREENSHOT = "$PWD/.local/logs/render.png"
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

render.gdは画面描画可能な環境で実行する。準備・所持品・HUD・戦闘・補給・演出を確認する。
B案の座標/操作基準は [準備UI仕様](../../design/PREPARATION_UI_B.md)。
スクリプトによるGUI入力や静止画確認と、人間による操作感評価を区別する。

## 重点回帰

- match_state/準備: 商品二重購入・資金収支、配置衝突、控え容量/解除先満杯、確定、丸腰出撃、引き分け/試合終了、CPU。
- fine_grid/item_instances/relic_stacking: 個体ID、同種の位置/破棄、重複可否、能力加算、取得経路。
- numeric_relic_stacking: 数値補正19種の価格・重複購入/配置/売却/仮取得/HUD、時間短縮の乗算、条件付き効果の固定時間、直接/派生弾、HP取得差分。
- 戦闘: 全武器、改造、レリック、派生制限、回避/被弾、入力予約、危険地帯、補給/宝箱。
- field_weapon_reserve/eight_more_weapons: 控え収納と明示配置、引き分け/決着/満杯/重複、追加通常8武器。
- added_weapons/added_relics/added_item_acquisition: 初期専用8種の抽選除外、追加全品の購入・売却・無料持ち帰り、3連射の補正/予約取消、交差弾、15レリックの条件/上限/対象外、CPU初期装備。
- sound: ミュート、戦闘シグナル、合成PCM、16ボイス、停止/キャッシュ/バス解放。
- 描画: 長文、所持品増加、縮小画面、選択固定、配置プレビュー、ドラッグの掴み位置。

武器が必要なテストは明示的に装備を作る。自動サイドアームや旧4枠制限を仮定しない。
tests/helpers/battle.gdを活用し、レリックの追射予約・一時フラグなど状態リークを防ぐ。

## 素材生成ツール

```powershell
.local/audio-venv/Scripts/python.exe -m unittest discover -s tools/asset_generator/tests -v
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/audio_assets.gd
```

Pythonテストは通信mockで課金なし。環境と無料確認は [素材生成設定](../../development/ASSET_GENERATION_SETUP.md)。
直近の音響検証ではPython19件とBGM/SEのGodot Resource認識が成功。全ゲームテストの再実行とは別。

## 最新の記録と未完了の受入

2026-09-12: 数値補正19種の重複解禁・低数値化・価格改定後、headless全55本PASS、終了コード0。
実行: `powershell -ExecutionPolicy Bypass -File run_tests.ps1`。
ログ: `.local/logs/run_tests-20260912-021554.log`。初回はGodotのログ・証明書アクセスがサンドボックスで拒否されたため、通常権限で再実行した。
単体効果、重複19種の取得経路、合計表示、装填/回避/近接/開封の乗算、発動時間据え置き、射撃補正、HP/弾倉を確認。今回の描画目視と人間の実プレイによる価格・対人バランス評価は未実施。

勝敗UIの修正後、`result_flow.gd`（描画あり）、`small_improvements.gd`、`smoke.gd`、`match_progression.gd` がPASS・終了コード0。途中勝敗の次準備ボタン/Enter、引き分け再戦、最終決着時のみ戻り先表示、途中の戻り先API拒否、最終Enterでキャラ選択を検証。全体一括テストは今回再実行していない。

描画再現: `.local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/result_flow.gd --quit-after 120 -- --result-screenshot`。
`.local/logs/result-round.png`、`result-draw.png`、`result-match.png` でメッセージ・スコア・操作ボタンの重なりがないことを確認した。

2026-09-12: 武器別間合い・迂回の追加後、**headless全53本PASS、終了コード0**。
実行: `powershell -ExecutionPolicy Bypass -File run_tests.ps1`。
ログ: `.local/logs/run_tests-20260912-013758.log`。Godotのログ・証明書アクセスがサンドボックスで拒否されたため、通常権限で実行した。

CPUの武器別間合い・通常戦闘の迂回は `tests/cpu_tactics.gd` で検証する。距離240pxで散弾が接近・レールが後退・標準武器が維持すること、スパナ変形・シード改造、全38武器の間合い、3武器×7配置の実際のPlayer.stepによる射線/間合い到達、移動相手への経路更新、到達不能時の再探索間隔を含む。

既存の `cpu_ai.gd` は予測射撃・回避・補給取得、`endgame_balance.gd` は回避クールダウン、`small_improvements.gd` は8地点からの縮小エリア退避と補給より退避を優先することを確認する。

共有補給・30%のレジェンド抽選・Fキー開封・星弾追尾・勝敗画面の実装と以前の検証記録は [CPU間合い・迂回前の検証記録](DOCUMENT_SNAPSHOTS.md#snapshot-02) を参照する。

今回の描画・人間による実プレイは未確認。CPUの勝率、武器別間合いの適正値、移動する相手への経路追従、補給競争との優先度は未評価。自動テスト成功を対人バランスの確定とは扱わない。

一覧更新: `python tools/export_item_catalog.py`。全38武器・35レリック・8キャラの表を生成する。
武器・レリック件数と通常入手数は自動集計。バッグ説明は手動管理。

### 人間の実プレイ未確認

購入・売却・配置操作の使いやすさ、5本先取の総時間、価格/初期8/上限24/控え8のバランス、
CPUの投資判断、8方向化したプラネタリウムの避けやすさ・配置後の強さ、武器別装填を含む初期キャラの均衡は未評価。20シードのCPU自動検証は対人試合の実測ではない。
20〜30試合の比較と、必要なら4本先取との比較を行う。自動テスト成功だけで数値を確定しない。
拡張のドラッグ・回転・配置後移動、P9隣接効果、オンライン対応は未実装。
Web/Windows配布版、一試合完走、最大負荷、先行入力・音の実プレイ確認も残る。
音響生成は行っていない。audio_assetsは保存済み素材の読み込みのみ。

旧40本の詳しい記録は [移行前の検証記録](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-11)、
購入移行の経緯は [検証日誌](../2026-09-11/PURCHASE_ECONOMY_VALIDATION.md) を参照。

## 対戦HUD C案の検証（2026-09-12）

実装仕様は [BATTLE_UI_C](../../design/BATTLE_UI_C.md)、素材交換は [HUD素材README](../../../assets/ui/hud/README.md)。

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/hud_compact.gd --quit-after 180
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/hud_compact.gd --quit-after 180 -- --hud-screenshot
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/render.gd --quit-after 300
```

専用テストはCPU/P2武器表示、最大8丁、36個一覧と末尾スクロール、仮装備/同種数/充電/待ち時間、ポーズ/ESC/射撃予約解除、背景に遮られないアイコンのマウス判定、装填、丸腰、素材fallback、カメラ表示移動と移動境界維持を検証する。
画像保存時はCPU戦・多武器・一覧・一覧末尾・ローカル・丸腰・840×600・結果画面をdocs/art/settings/concepts/battle-ui-2026-09-12/implemented-*.pngへ出力する。

一括実行のheadless 56本PASS（ログ .local/logs/run_tests-20260912-104722.log）。同実行のrenderは背景パネルの入力遮断で失敗し、修正後のrender.gd単体・hud_compact.gd描画実行はともにPASS、終了コード0。専用画像も目視確認。人間による操作感・仮アイコンの識別性・正式素材交換後の受入は未完了。


---

<a id="snapshot-05"></a>

## 旧ファイル: BEFORE_REFACTOR_TESTING.md

# 検証手順

更新: 2026-09-11。実行方法と残る受入を管理する。過去の件数・失敗修正・ログは
[検証履歴](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-14) を参照する。

## 実行

プロジェクトルートのPowerShellから実行する。Godotは.local/tools/を優先して探索する。

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
powershell -ExecutionPolicy Bypass -File run_tests.ps1
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

別の実行ファイルは -GodotPath で指定する。tests直下の.gdを自動検出し、通常はrender.gdを除く。
件数は増減するため固定の「全34本」等を現在の合格条件にしない。
ログは.local/logs/。終了コード、エラー行、PASS表示を確認する。
PASS数はアサーション数ではない。Godotのユーザーデータ/キャッシュ権限エラーも無視しない。
音響素材がない場合のaudio_assets.gdはSKIPを返す。単独実行は終了コード0だが、現行の一括ランナーはPASS表示なしを失敗扱いにする。未生成を認識成功と扱わない。

## 描画と入力

```powershell
$env:CHAMBER_SCREENSHOT = "$PWD/.local/logs/render.png"
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

render.gdは画面描画可能な環境で実行する。準備・所持品・HUD・戦闘・補給・演出を確認する。
B案の座標/操作基準は [準備UI仕様](../../design/PREPARATION_UI_B.md)。
スクリプトによるGUI入力や静止画確認と、人間による操作感評価を区別する。

## 重点回帰

- match_state/準備: 商品二重購入・資金収支、配置衝突、控え容量/解除先満杯、確定、丸腰出撃、引き分け/試合終了、CPU。
- fine_grid/item_instances/relic_stacking: 個体ID、同種の位置/破棄、重複可否、能力加算、取得経路。
- 戦闘: 全武器、改造、レリック、派生制限、回避/被弾、入力予約、危険地帯、補給/宝箱。
- field_weapon_reserve/eight_more_weapons: 控え収納と明示配置、引き分け/決着/満杯/重複、追加通常8武器。
- added_weapons/added_relics/added_item_acquisition: 初期専用8種の抽選除外、追加全品の購入・売却・無料持ち帰り、3連射の補正/予約取消、交差弾、15レリックの条件/上限/対象外、CPU初期装備。
- sound: ミュート、戦闘シグナル、合成PCM、16ボイス、停止/キャッシュ/バス解放。
- 描画: 長文、所持品増加、縮小画面、選択固定、配置プレビュー、ドラッグの掴み位置。

武器が必要なテストは明示的に装備を作る。自動サイドアームや旧4枠制限を仮定しない。
tests/helpers/battle.gdを活用し、レリックの追射予約・一時フラグなど状態リークを防ぐ。

## 素材生成ツール

```powershell
.local/audio-venv/Scripts/python.exe -m unittest discover -s tools/asset_generator/tests -v
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/audio_assets.gd
```

Pythonテストは通信mockで課金なし。環境と無料確認は [素材生成設定](../../development/ASSET_GENERATION_SETUP.md)。
直近の音響検証ではPython19件とBGM/SEのGodot Resource認識が成功。全ゲームテストの再実行とは別。

## 最新の記録と未完了の受入

通常武器8種をさらに追加（全38武器・35レリック）、フィールド武器を控え収納へ変更後、
**50本（headless49＋描画1）PASS、終了コード0**。ERROR/WARNING/FAILなし。
実行: `powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender`。
ログ: `.local/logs/run_tests-20260911-235627.log`。

- eight_more_weapons: 追加8種の購入・価格・配置・射撃、3反射、2枚往復、加速、設置弾の個別数値、遅延レール、扇状追尾と抽選プール。
- field_weapon_reserve: 取得で携行一覧/残弾/リロード/変形/配置/資金を変えず控えへ収納。控え8個満杯・重複拒否、両者対称、引き分け保持、次準備で明示配置して満タンで出撃、最終勝利/新規試合リセット、CPUの満杯ガード。
- supplies/chest_pickups: 宝箱開封待ち・中断・横取り不可、取得品の控え収納、同武器補給の廃止、弾薬箱は従来通り、スケジュール・消滅・キー入力。
- 既存の初期8武器・追加15レリック・改造・経済・CPU・入力・形状・音響Resource読込・描画の回帰も成功。

描画: `.local/logs/field-reserve-field-reserve-hint.png` と
`.local/logs/field-reserve-field-reserve-next-preparation.png` を目視確認。
宝箱の「控えへ（次の準備で配置）」表示と、拾ったオーロラファンが次準備の控えへ入り、
元の初期武器だけが配置された状態を確認した。画像撮影の古いホバー表示を消しHUDを更新した後、render.gd単独も終了0・PASS。

一覧更新: `python tools/export_item_catalog.py`。全38武器・35レリック・8キャラの表を生成する。
武器・レリック件数と通常入手数は自動集計。バッグ説明は手動管理。
前回の48本成功と追加10武器・15レリックの詳細は [前回記録](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-03)。
旧取得方式は [変更前の仕様](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-02) に保存した。

### 人間の実プレイ未確認

購入・売却・配置操作の使いやすさ、5本先取の総時間、価格/初期8/上限24/控え8のバランス、
CPUの投資判断、プラネタリウム取得直後の強さは未評価。20シードのCPU自動検証は対人試合の実測ではない。
20〜30試合の比較と、必要なら4本先取との比較を行う。自動テスト成功だけで数値を確定しない。
拡張のドラッグ・回転・配置後移動、P9隣接効果、オンライン対応は未実装。
Web/Windows配布版、一試合完走、最大負荷、先行入力・音の実プレイ確認も残る。
音響生成は行っていない。audio_assetsは保存済み素材の読み込みのみ。

旧40本の詳しい記録は [移行前の検証記録](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-11)、
購入移行の経緯は [検証日誌](../2026-09-11/PURCHASE_ECONOMY_VALIDATION.md) を参照。


---

<a id="snapshot-06"></a>

## 旧ファイル: BEFORE_SHARED_SUPPLIES_TESTING.md

# 検証手順

更新: 2026-09-12。実行方法と残る受入を管理する。過去の件数・失敗修正・ログは
[検証履歴](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-14) を参照する。

## 実行

プロジェクトルートのPowerShellから実行する。Godotは.local/tools/を優先して探索する。

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
powershell -ExecutionPolicy Bypass -File run_tests.ps1
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

別の実行ファイルは -GodotPath で指定する。tests直下の.gdを自動検出し、通常はrender.gdを除く。
件数は増減するため固定の「全34本」等を現在の合格条件にしない。
ログは.local/logs/。終了コード、エラー行、PASS表示を確認する。
PASS数はアサーション数ではない。Godotのユーザーデータ/キャッシュ権限エラーも無視しない。
音響素材がない場合のaudio_assets.gdはSKIPを返す。単独実行は終了コード0だが、現行の一括ランナーはPASS表示なしを失敗扱いにする。未生成を認識成功と扱わない。

## 描画と入力

```powershell
$env:CHAMBER_SCREENSHOT = "$PWD/.local/logs/render.png"
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

render.gdは画面描画可能な環境で実行する。準備・所持品・HUD・戦闘・補給・演出を確認する。
B案の座標/操作基準は [準備UI仕様](../../design/PREPARATION_UI_B.md)。
スクリプトによるGUI入力や静止画確認と、人間による操作感評価を区別する。

## 重点回帰

- match_state/準備: 商品二重購入・資金収支、配置衝突、控え容量/解除先満杯、確定、丸腰出撃、引き分け/試合終了、CPU。
- fine_grid/item_instances/relic_stacking: 個体ID、同種の位置/破棄、重複可否、能力加算、取得経路。
- 戦闘: 全武器、改造、レリック、派生制限、回避/被弾、入力予約、危険地帯、補給/宝箱。
- field_weapon_reserve/eight_more_weapons: 控え収納と明示配置、引き分け/決着/満杯/重複、追加通常8武器。
- added_weapons/added_relics/added_item_acquisition: 初期専用8種の抽選除外、追加全品の購入・売却・無料持ち帰り、3連射の補正/予約取消、交差弾、15レリックの条件/上限/対象外、CPU初期装備。
- sound: ミュート、戦闘シグナル、合成PCM、16ボイス、停止/キャッシュ/バス解放。
- 描画: 長文、所持品増加、縮小画面、選択固定、配置プレビュー、ドラッグの掴み位置。

武器が必要なテストは明示的に装備を作る。自動サイドアームや旧4枠制限を仮定しない。
tests/helpers/battle.gdを活用し、レリックの追射予約・一時フラグなど状態リークを防ぐ。

## 素材生成ツール

```powershell
.local/audio-venv/Scripts/python.exe -m unittest discover -s tools/asset_generator/tests -v
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/audio_assets.gd
```

Pythonテストは通信mockで課金なし。環境と無料確認は [素材生成設定](../../development/ASSET_GENERATION_SETUP.md)。
直近の音響検証ではPython19件とBGM/SEのGodot Resource認識が成功。全ゲームテストの再実行とは別。

## 最新の記録と未完了の受入

小改善の回帰は `tests/small_improvements.gd` で検証する。Fでの開封とGの無効化・ポーズ中のガード、星弾の旋回量と前方範囲、8か所のエリア端・壁付近から実際のPlayer.stepによる退避、ラウンド/試合終了時のボタン、キャラ選択へのモード引継ぎ・新規試合・タイトルへの遷移を含む。

2026-09-12: 全52本のheadlessテストを実行し51本PASS。旧Gキー前提の `supplies.gd` だけ失敗したため、Fキーへ更新して単独再実行しPASS（終了コード0）。全52本の成功を確認したが、修正後の一括再実行はしていない。一括ログ: `.local/logs/run_tests-20260912-012146.log`。

`small_improvements.gd` を描画ありでも実行してPASS。`.local/logs/result-actions.png` で勝敗メッセージと戻る2ボタンが重ならず表示されることを確認。再現コマンド:

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/small_improvements.gd --quit-after 120 -- --result-screenshot
```

CPU強化時の実行記録は [小改善前の検証記録](DOCUMENT_SNAPSHOTS.md#snapshot-07) を参照。
今回の人間による操作感・追尾の避けやすさ・CPU勝率は未評価。

一覧更新: `python tools/export_item_catalog.py`。全38武器・35レリック・8キャラの表を生成する。
武器・レリック件数と通常入手数は自動集計。バッグ説明は手動管理。

### 人間の実プレイ未確認

購入・売却・配置操作の使いやすさ、5本先取の総時間、価格/初期8/上限24/控え8のバランス、
CPUの投資判断、8方向化したプラネタリウムの避けやすさ・配置後の強さ、武器別装填を含む初期キャラの均衡は未評価。20シードのCPU自動検証は対人試合の実測ではない。
20〜30試合の比較と、必要なら4本先取との比較を行う。自動テスト成功だけで数値を確定しない。
拡張のドラッグ・回転・配置後移動、P9隣接効果、オンライン対応は未実装。
Web/Windows配布版、一試合完走、最大負荷、先行入力・音の実プレイ確認も残る。
音響生成は行っていない。audio_assetsは保存済み素材の読み込みのみ。

旧40本の詳しい記録は [移行前の検証記録](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-11)、
購入移行の経緯は [検証日誌](../2026-09-11/PURCHASE_ECONOMY_VALIDATION.md) を参照。


---

<a id="snapshot-07"></a>

## 旧ファイル: BEFORE_SMALL_IMPROVEMENTS_TESTING.md

# 検証手順

更新: 2026-09-12。実行方法と残る受入を管理する。過去の件数・失敗修正・ログは
[検証履歴](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-14) を参照する。

## 実行

プロジェクトルートのPowerShellから実行する。Godotは.local/tools/を優先して探索する。

```powershell
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import
powershell -ExecutionPolicy Bypass -File run_tests.ps1
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

別の実行ファイルは -GodotPath で指定する。tests直下の.gdを自動検出し、通常はrender.gdを除く。
件数は増減するため固定の「全34本」等を現在の合格条件にしない。
ログは.local/logs/。終了コード、エラー行、PASS表示を確認する。
PASS数はアサーション数ではない。Godotのユーザーデータ/キャッシュ権限エラーも無視しない。
音響素材がない場合のaudio_assets.gdはSKIPを返す。単独実行は終了コード0だが、現行の一括ランナーはPASS表示なしを失敗扱いにする。未生成を認識成功と扱わない。

## 描画と入力

```powershell
$env:CHAMBER_SCREENSHOT = "$PWD/.local/logs/render.png"
powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender
```

render.gdは画面描画可能な環境で実行する。準備・所持品・HUD・戦闘・補給・演出を確認する。
B案の座標/操作基準は [準備UI仕様](../../design/PREPARATION_UI_B.md)。
スクリプトによるGUI入力や静止画確認と、人間による操作感評価を区別する。

## 重点回帰

- match_state/準備: 商品二重購入・資金収支、配置衝突、控え容量/解除先満杯、確定、丸腰出撃、引き分け/試合終了、CPU。
- fine_grid/item_instances/relic_stacking: 個体ID、同種の位置/破棄、重複可否、能力加算、取得経路。
- 戦闘: 全武器、改造、レリック、派生制限、回避/被弾、入力予約、危険地帯、補給/宝箱。
- field_weapon_reserve/eight_more_weapons: 控え収納と明示配置、引き分け/決着/満杯/重複、追加通常8武器。
- added_weapons/added_relics/added_item_acquisition: 初期専用8種の抽選除外、追加全品の購入・売却・無料持ち帰り、3連射の補正/予約取消、交差弾、15レリックの条件/上限/対象外、CPU初期装備。
- sound: ミュート、戦闘シグナル、合成PCM、16ボイス、停止/キャッシュ/バス解放。
- 描画: 長文、所持品増加、縮小画面、選択固定、配置プレビュー、ドラッグの掴み位置。

武器が必要なテストは明示的に装備を作る。自動サイドアームや旧4枠制限を仮定しない。
tests/helpers/battle.gdを活用し、レリックの追射予約・一時フラグなど状態リークを防ぐ。

## 素材生成ツール

```powershell
.local/audio-venv/Scripts/python.exe -m unittest discover -s tools/asset_generator/tests -v
& .local/tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/audio_assets.gd
```

Pythonテストは通信mockで課金なし。環境と無料確認は [素材生成設定](../../development/ASSET_GENERATION_SETUP.md)。
直近の音響検証ではPython19件とBGM/SEのGodot Resource認識が成功。全ゲームテストの再実行とは別。

## 最新の記録と未完了の受入

CPU強化後、**headless全51本PASS、終了コード0**。
実行: `powershell -ExecutionPolicy Bypass -File run_tests.ps1`。
ログ: `.local/logs/run_tests-20260912-004948.log`。Godotのユーザーログ・証明書アクセスがサンドボックスで拒否されたため、通常権限で実行した。

CPU強化の回帰では、移動相手への予測照準・静止相手への照準維持・90pxより遠い接近弾への回避・遠ざかる弾の無視・回避方向の反映・丸腰時の接近を `cpu_ai.gd` で検証する。`endgame_balance.gd` は実際の回避クールダウン中に再発動・追加弾生成が起きないことを検証する。

初回の全体実行は50本PASS、1本FAIL。`endgame_balance.gd` が旧仕様の負の判断タイマーと50px先の静止弾を仮定していたため、判断タイマー0・接触に近い静止弾20pxへ更新した。実際の回避クールダウンを守るアサーションは維持している。

前回の武器差別化・描画を含む検証結果は [CPU強化前の検証記録](DOCUMENT_SNAPSHOTS.md#snapshot-01)。今回の変更は描画・人間による実プレイ評価を含まない。予測射撃の命中率・回避の強さ・CPU勝率は未測定。

一覧更新: `python tools/export_item_catalog.py`。全38武器・35レリック・8キャラの表を生成する。
武器・レリック件数と通常入手数は自動集計。バッグ説明は手動管理。

### 人間の実プレイ未確認

購入・売却・配置操作の使いやすさ、5本先取の総時間、価格/初期8/上限24/控え8のバランス、
CPUの投資判断、8方向化したプラネタリウムの避けやすさ・配置後の強さ、武器別装填を含む初期キャラの均衡は未評価。20シードのCPU自動検証は対人試合の実測ではない。
20〜30試合の比較と、必要なら4本先取との比較を行う。自動テスト成功だけで数値を確定しない。
拡張のドラッグ・回転・配置後移動、P9隣接効果、オンライン対応は未実装。
Web/Windows配布版、一試合完走、最大負荷、先行入力・音の実プレイ確認も残る。
音響生成は行っていない。audio_assetsは保存済み素材の読み込みのみ。

旧40本の詳しい記録は [移行前の検証記録](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-11)、
購入移行の経緯は [検証日誌](../2026-09-11/PURCHASE_ECONOMY_VALIDATION.md) を参照。


---

<a id="snapshot-08"></a>

## 旧ファイル: BEFORE_WEAPON_DIFFERENTIATION_TESTING.md

# 武器差別化前の検証記録

現行ルールを維持したリファクタリング後、**51本（headless50＋描画1）PASS、終了コード0**。
ERROR/WARNING/FAILなし。既存49本のheadlessテストに、画面なしのCPU準備と
準備/戦闘の配置境界を確認する `preparation_boundaries.gd` を追加した。

実行: `powershell -ExecutionPolicy Bypass -File run_tests.ps1 -IncludeRender`。
ログ: `.local/logs/run_tests-20260912-001104.log`。
Godot 4.7.2のheadlessエディタで再インポートも成功。

- 38武器・35レリック、購入/売却/拡張、個体ID、初期準備、フィールド控え収納、入力、CPU、音響Resource読込の既存回帰が成功。
- 新規テスト: 20シードの各9ラウンドで、画面なしのCPU準備、資金/容量/重複配置の制約、5対4での試合終了リセットを検証。
- 準備と戦闘で携行武器の読み順、同種レリック個体の占有セル、仮取得の形状判定が一致し、元ビルドを書き換えないことを検証。
- 保存した変更前CPU実装との一時比較では、360回の準備について所持品・配置・資金・商品・個体/カード連番・乱数状態が一致。
- 描画テストはCompatibilityで成功。今回の実行はスクリーンショットの保存・目視確認や人間の実プレイ評価を含まない。

変更前49本の成功ログは `.local/logs/run_tests-20260912-000452.log`。
サンドボックス内ではユーザーログと証明書ストアの権限エラーが出たため、
通常権限の実行で検証した。これらのエラーを除外して合格にする変更は行っていない。
詳細は[リファクタリング記録](REFACTOR_VALIDATION.md)、
前回の取得武器・描画検証は[変更前の検証資料](DOCUMENT_SNAPSHOTS.md#snapshot-05)を参照。



---

<a id="snapshot-09"></a>

## 旧ファイル: PREPARATION_UI_BEFORE_REVISION.md

# B案：準備画面

更新: 2026-09-11。B案の配置パネル・詳細・ショップ・控え・下端ボタンを維持し、P9前の個体管理と6×6へ対応。

## 現行レイアウト

1120×800の論理座標。6×6を58pxセル＋4px間隔（368px角）で表示する。
未開放セルを暗色と×で区別し、配置不可理由にも「未開放」を表示する。
成長でセル寸法や左上座標を変えず、使用可能セルを追加する。

|領域|x|y|幅|高さ|
|---|---:|---:|---:|---:|
|配置パネル|24|132|704|440|
|最大グリッド|48|192|368|368|
|詳細欄|448|188|264|376|
|ショップパネル|744|132|352|544|
|控えパネル|24|588|704|88|
|控えスクロール|40|622|520|50|
|固定の装備解除枠|576|622|136|48|
|出撃情報の帯|24|692|1072|84|
|準備完了ボタン|800|706|280|56|

1120×600ウィンドウでは75%に縮小され、セルは43.5px相当。任意の極小サイズは保証しない。
装備した同一個体のマス間をつなぐ。同種でも別個体の境界は残す。
1マス品の名前は短縮表示し、詳細とtooltipで全文を確認する。

## ショップと有料拡張（試作）

右のショップ欄に残金・商品更新2G・常設拡張・通常商品を表示する。通常は武器2/レリック3/対象があれば改造1枠。
価格付き購入ボタン、購入不可理由、売り切れを表示する。商品カードIDで二重入力を拒否する。
商品更新は毎準備1回。拡張・無料持ち帰り候補を保持し、古い通常カードIDは無効になる。
無料レリック候補は「無料確保」で明示取得。未確保で出撃すると失うことを下端の情報帯に表示する。

正方形4マス4G、L字/長方形6マス6Gから毎準備1個まで選択。初期8マス、開放上限24マス。
ボタンは「選択」と表示し、形状を選んだ後にグリッドの基準マスをクリックする。
選択中は「バッグの配置先をクリック・配置確定で支払い」を案内する。緑/橙プレビューで接続・重複・範囲・資金・上限を案内。
配置成功時だけ支払い、失敗・Esc取消は無課金。回転なし・配置後固定。拡張購入は準備完了の条件ではない。
拡張欄は購入後や面積上限でも残し、各形状を購入できない理由（資金不足・今準備購入済み・上限の残り面積・配置場所なし）を表示して無効化する。
開放20マスなら4マスだけ選択可能。22マスでは最小4マスも収まらないため、それ以上は購入できない。
拡張のドラッグ、回転、配置後移動は今回の試作に含まない。装備品のドラッグは維持する。

## 初回画面の確定

キャラ選択から遷移するときは、両者の初期武器とCPUモードを適用した後に準備画面を再構築する。
仮のP-12を表示した古いボタンや配置選択を残さず、初回から表示品と所持品を一致させる。
購入による再描画まで初期武器の表示更新を遅らせない。

## 操作

- 品をクリックして選択を固定し、配置先をクリック。Escで解除。他品へのホバーで選択を変えない。
- ドラッグは掴んだマスのオフセットを保持する。配置成功で選択を解除する。
- 無効配置は状態を変えず、重複・未開放・グリッド外の理由を表示する。
- 固定解除枠へのクリックまたはドロップで控えへ戻す。控えが満杯なら解除を拒否し、先に配置か破棄する案内を出す。
- 処分は詳細の「売却 nG」または「破棄（無料品）」。実支払額の半額を返金し、無料品は換金不可。解除と名称・場所・色を分ける。
- 商品は効果確認と購入を分離。新規取得は個体を控えへ追加し、配置用に選択する。同じカードは1回だけ購入可能。
- 詳細には同種の装備数・効果合計。控えは装備と別に8個の試作上限で横スクロールする。
- 買わずに準備完了できる。丸腰でも完了可能。
- プレイヤー交代で選択とスクロールを初期化する。

戦闘HUDは下端の固定領域内で縦スクロールし、仮取得した1個のみ仮表示する。
形状・開放セル・容量の試作理由は [細分化計画](../2026-09-22/planning-cleanup/FINE_GRID_ROADMAP.md)、現行ルールは [GAME_RULES](../../design/GAME_RULES.md) を参照。

## 検証

6列のGUI合成入力によるクリック配置、ドラッグ開始しきい値、複数マスの掴み位置付き移動、
配置失敗の非破壊性、控え末尾、パネル境界、HUD末尾到達を自動検証する。
描画PNGと最終ログは [TESTING](../../development/TESTING.md) に記録する。
人間による操作感、長時間の対戦バランス、全形状の最終調整は未確認。

[改修前のB案資料・画像寸法・検証履歴](../2026-09-11/DOCUMENT_SNAPSHOTS.md#snapshot-17) は当時の記録。
旧 capture_preparation_b.gd / draw_preparation_b_review.ps1 は改修前資料用であり、現行の描画確認は tests/render.gd を使う。
