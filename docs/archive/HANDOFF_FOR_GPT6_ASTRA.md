> 過去の記録です。旧パス・当時の未実装情報を含みます。現在の仕様・課題は [資料索引](../README.md) を参照してください。

# CHAMBER CLASH：GPT6 ASTRAへの引き継ぎプロンプト

作成日: 2026-09-08。作成者: Claude（Cowork、C:\GameCreate\chamber-clashへのremote-devicesブリッジ経由でのみPCへ到達可能な環境で作業）。

このドキュメントは、GPT6 ASTRA製の「CHAMBER CLASH」（2人ローカル対戦アクション）をWeb版JavaScriptからGodot 4.7.2/GDScriptへ移植する作業を、そのままGPT6 ASTRAへ引き継ぐためのプロンプト兼リファレンスです。冒頭を作業指示として読み、以降を必要に応じて参照してください。

---

## あなたへの指示（プロンプトとして）

あなたはCHAMBER CLASHの開発者で、これまでWeb版（`legacy-web/dist/`）として実装してきたこのゲームを、Godot 4.7.2/GDScriptへ移植する作業を別のAIアシスタント（Claude）から引き継ぎます。移植は「元の数値・素材・仕様をそのまま再現する」ことを最優先方針としてこれまで進められており、ゲーム性の大幅変更は移植完了後に検討する計画です。以下のマイルストーン表・完了済み範囲・残作業・厳守事項を踏まえ、続きを実装してください。

**最重要の作業ルール（これまで一貫して守られてきたもの）**
1. **移植元（`legacy-web/dist/*.js`・`assets/*`・`data/catalog.json`）は変更しない。** 参照専用。
2. **数値・条件式は元Webの該当関数を直接読んで一致させる。** 推測や「だいたい同じ」で済ませない。
3. **実装しただけでは完了とみなさない。** ユーザー環境で`run_tests.ps1`を実際に実行してもらい、全ファイルPASS・SCRIPT ERRORなしを確認するまでは「未検証」として扱う。テストが通ってもコード上のレビューだけでは「実行確認済み」と書かない。
4. **README.mdとdocs/MIGRATION_PLAN.mdに、日付入りの変更履歴として何を・なぜ・どう直したかを追記する。** 既存のエントリを削除・書き換えず、末尾に追記していくスタイル。検証済みか未検証かを必ず明記する。
5. リモート環境からPCへファイルを書き込む手段を使う場合、書き込みが実際に反映されたかどうかは信用せず、書き込み直後に読み直してバイト数/内容を照合する（このプロジェクトでは何度も「成功」と報告されつつ実際には反映されていない事例があった）。
6. テストや実機確認の結果は正直に報告する。1件でもFAILがあれば「成功」と言わない。

---

## 移植元（Web版）のファイル構成

`legacy-web/dist/`にあり、**変更禁止・参照専用**。

| ファイル | 内容 |
|---|---|
| `data.js` | キャラクター8種・武器20種・レリック12種のデータ定義（`characters`/`guns`/`relics`配列） |
| `game.js` | メインループ、物理・入力、弾丸・武器発射・当たり判定、危険地帯、CPU AI（`aiInput()`）、ラウンド進行（`updatePlayer()`/`endRound()`等） |
| `shop.js` | 武器ドラフト・ショップのロジック（`openShop()`/`buyShop()`/`readyShop()`）、CPU自動購入分岐 |
| `render.js` | 描画・視覚演出。パーティクル（`burst()`）、画面シェイク（`shake`）、武器エフェクトのスプライト演出（`weaponEffect()`）、危険地帯オーバーレイ（`drawArena()`）、レリック軌道アイコン（`star()`）、HUD描画、音声（`tone()`/`combatSound()`） |
| `index.html` / `style.css` | 画面構成・CSS。優先度は低い |

画像素材は`assets/`にあり、Godotプロジェクトへも既にコピー・インポート済み（`fighters.png`・`weapons.png`・`weapons-extra.png`・`weapon-effects.png`・`projectile-sprites.png`・`party.png`・`portraits.png`）。**素材が足りないという理由で未実装の項目は現時点で無い。**

## 移植先（Godotプロジェクト）のファイル構成

プロジェクトルート: `C:\GameCreate\chamber-clash`（Godot 4.7.2 / GDScript / Compatibility描画。project.godotのfeaturesに4.5互換記載あり、4.7.2起動を妨げるものではない）。

| ファイル | 内容 |
|---|---|
| `main.gd` / `main.tscn` | ラウンド進行の調停役。入力ディスパッチ、弾・重力場・パルスの管理 |
| `scripts/player.gd` | プレイヤーの状態・物理・入力・近接・ドッジ・被弾処理 |
| `scripts/projectile.gd` | 弾丸の弾道・当たり判定（20種の武器効果） |
| `scripts/arena.gd` / `scripts/wall.gd` | アリーナ境界・障害物 |
| `scripts/supplies.gd` / `scripts/pickup.gd` | フィールド補給品 |
| `scripts/preparation.gd` | 武器ドラフト・ショップ |
| `scripts/character_select.gd` / `scripts/character_catalog.gd` | キャラ選択・能力値 |
| `scripts/weapon_catalog.gd` / `scripts/relic_catalog.gd` | 武器・レリックのカタログ定義（`data/catalog.json`参照） |
| `scripts/cpu_ai.gd` | CPU AI（`decide()`、legacy `aiInput()`の移植） |
| `scripts/gravity_well.gd` | 重力場（ブラックホール武器） |
| `scripts/hud.gd` | HUD表示（現状はテキスト・ボタン中心） |
| `scripts/pulse_effect.gd` | パルスの拡大リング表示 |
| `data/catalog.json` | `data.js`のGodot版データ |
| `scenes/*.tscn` | 各スクリプトに対応するシーン |
| `tests/*.gd` | `run_tests.ps1`で自動実行される単体テスト（headless SceneTree） |
| `README.md` | ユーザー向けの現状まとめ＋日付入り変更履歴 |
| `docs/MIGRATION_PLAN.md` | 開発者向けの詳細な移植計画＋日付入り変更履歴（最も詳しい記録） |

**続きを実装する前に、必ず`README.md`と`docs/MIGRATION_PLAN.md`を最後まで読んでください。** 特に`docs/MIGRATION_PLAN.md`には、これまで発見・修正したバグとその原因（GDScriptの型推論の癖、テストの構造的な見落とし等）が詳細に記録されており、同じ落とし穴を繰り返さないために重要です。

## テストの実行方法

```
powershell -ExecutionPolicy Bypass -File "C:\GameCreate\chamber-clash\run_tests.ps1"
```

`tests/*.gd`を自動検出して一括実行し、結果を`.local/logs/`へ集約します。全ファイルPASS・SCRIPT ERRORなしを確認するまでは未完了として扱ってください。終了コード0はassert失敗時にも返る場合があるため、出力内容そのものを確認する必要があります。（このリポジトリには`これをテストして`と指示すると上記コマンドの実行・結果判定・失敗時の診断修正まで自動で行うスキル`chamber-clash-run-tests`が既に登録されています。同様の運用が可能な環境であれば流用してください。）

## 現在のマイルストーン状況

| 段階 | 内容 | 状況 |
|---|---|---|
| M0 保存・整理 | Webソース保存・素材コピー・カタログJSON化 | **完了** |
| M1 最小対戦 | 2人対戦の基本（移動・回避・近接・弾薬・勝敗） | **完了**（ユーザー実操作確認済み） |
| M2 配布検証 | Web/Windows書き出しの実機確認 | **未着手** |
| M3 戦闘同等化 | 全キャラ・武器4枠・CPU・パルス・危険地帯・3本先取 | 実装・自動テスト実行確認済み。対人（対CPU）での実感確認は未実施 |
| M4 全装備 | 20武器・12レリック・フィールド補給 | 実装・自動テスト実行確認済み |
| M5 UI | キャラ選択・ドラフト・ショップ・HUD | 実装・自動テスト実行確認済み。キャラ選択画面の見た目・Local/CPU切替ボタンの目視確認は未実施 |
| M6 演出・公開 | PNGアニメ・SE素材化・負荷確認・Web/Windows実機で一試合完走・公開切替 | **着手直後。詳細は次項** |

## M6（現在着手中）の残作業

2026-09-08、legacy-web全ファイル（`render.js`含む）とGodot実装を1関数ずつ突き合わせる監査を行い、自動テストでは検出されない4件の挙動差（近接の壁貫通、ドッジ無敵時間、弾の上端境界、P2キー配置）を発見・修正し、ユーザー環境で実行確認済みです（詳細はMIGRATION_PLAN.mdの「2026-09-08 M6着手」節）。これ以降、以下が未着手のまま残っています。

### 1. アニメーション
- `fighters.png`は4列×2行、各キャラ1コマの静止画のみ。歩行・射撃・回避の連続コマ画像は素材に存在しない（元Web版も簡易脚動作程度で、大掛かりなスプライトアニメではない）。
- 対応方針は要検討：既存の1枚絵のままGodot側でわずかな動き（バウンス・傾き等）を手続き的に付けるか、新規アニメーションコマを追加で用意するか、ユーザーに確認してから進めること。

### 2. 視覚演出（`render.js`が画像を使わず手続き的に描いている部分。素材は不要）
- **画面シェイク**：`shake`変数。被弾（`damage()`）・パルス使用（`blank()`、shake=5）・コメット直撃等で発生。GodotではCamera2Dのoffsetを短時間ランダムに揺らす形で再現可能。
- **被弾/回避/近接/拾得時のパーティクル散布**：`burst(x,y,color,count)`（render.js）。GodotではGPUParticles2D等で色・個数を合わせて再現。
- **武器エフェクトのコマアニメ**：`weaponEffect(row,x,y,angle)`（game.js）が`weapon-effects.png`（4行×4コマ、画像は既にインポート済み）から反射・破裂・変形・追射時に切り出して表示する。GodotではAnimatedSprite2DかSprite2D+タイマーで4コマ再生を実装。
- **危険地帯の視覚オーバーレイ**：`drawArena()`（render.js）が半透明の帯・破線境界・ラベルを描画。2026-09-08にGodot版へ半透明の帯・破線境界・ラベルを移植済み（末尾追記参照）。
- **レリックが周回する星アイコン**：`star()`（render.js:62）。プレイヤー周囲を周回する小さな星型アイコンで、現在HP/UIには反映されていない。
- **HPセグメントバー**：元WebはCSSの`<i>`タグによるバー表示。現在のGodot版HUDはテキストのみ。

### 3. 効果音（`tone()`/`combatSound()`、game.js/render.js）
- AudioStreamPlayer等によるSE実装は現状ゼロ。発射・被弾・ドッジ・近接・パルス・装填・購入等、どのアクションにどの音が鳴るかは`combatSound()`の呼び出し箇所を`game.js`全体でgrepして洗い出すこと。
- 音声素材（wav/ogg等）がプロジェクトに存在するか要確認。無ければ元Webがどう生成しているか（`tone()`はWeb Audio APIでの動的合成、ファイル素材ではない）を踏まえて方針を決める。

### 4. 負荷確認・M2（配布検証）
- Web/Windowsへの書き出し設定・実機確認は未着手。エンジンバージョン（project.godotのfeaturesは4.5、実開発は4.7.2）の扱いを含め、書き出し前に方針を確認すること。

## 元Webから意図的に変更している既知の差分（「バグ」として直さないこと）

- **P1の操作方式**：元WebはCPU対戦時のみマウス照準+クリック、ローカル対戦時は自動照準+Fキーと切り替わるが、Godot版は常に自動照準+左クリックで射撃する（2026-09-07にユーザー指定で変更）。
- **CPU AIの判断タイミング**：元Webはタイマー減算がCPU判断より先に行われるため、クールダウンが0になった瞬間から使用可能。Godot版は`CpuAI.decide()`を`Player.step()`（タイマー減算を持つ）より先に呼ぶ構成上、1フレーム（1/60秒）分の遅延がある。意図的な実装順序の簡略化としてcpu_ai.gd冒頭に明記済み。
- **補給品の満タン時消費ルール**：同武器が満タンでも取得試行で消費していた元Webの挙動を、Godot版は「満タンなら消費しない」に変更している（README「フィールド補給」参照）。

上記以外で元Webと異なる挙動を見つけた場合は、まず「意図的な変更として記録されているか」をREADME.md/MIGRATION_PLAN.mdで確認し、記録が無ければ元Webの該当箇所を読んでバグかどうか判断すること。

## 進め方の推奨

1. 上記M6項目のどれから着手するかをユーザーに確認する（アニメーション／視覚演出／効果音／M2配布検証は依存関係が薄く、どの順でも着手可能）。
2. 1項目ごとに実装→テスト追加→ユーザーにrun_tests.ps1実行を依頼→結果を正直に判定→README.md/MIGRATION_PLAN.mdへ日付入りで追記、のサイクルを繰り返す。
3. 見た目・音声・操作感などテストで自動検証できない要素は、必ずユーザー本人の目視・実操作での確認を仰ぐ（このプロジェクトはこれまで一貫してその方針）。

## 2026-09-08 危険地帯の視覚表示と資料の整合

引継ぎ後、元Webのrender.js:38（drawArena）を参照し、半透明のオレンジ帯・8px間隔の破線境界・「危険エリア」ラベルを移植した。新しいscenes/danger_zone_visual.tscnをArena/DangerZoneへ配置し、scripts/danger_zone_visual.gdが描画する。帯は元Webの座標・色・角の重なりを再現し、破線は既存のダメージ判定（横inset+25、縦inset×0.58+25）に一致する。帯と判定境界のわずかなずれも元Web通り。ラベルだけは既存HUDとの重なりを避けて上端84pxへ配置した。色とラベル位置は専用シーンのInspectorで編集可能。

表示は既存arena_inset()を参照する。60秒経過後から縮小し、停止中・決着後はその時点の表示を保持、次ラウンドでは即時消去する。ダメージ量・速度・CPU判断・入力は変更していない。legacy-web・assets・data/catalog.jsonは無変更。変更前ファイルは.local/backups/before-danger-visual-*へ保存した。

Godot 4.7.2でrun_tests.ps1を実行し、全14ファイル・19個のPASS出力、ERROR/SCRIPT ERRORなしを確認（.local/logs/run_tests-20260908-194114.log）。danger_zoneテストに表示境界とダメージ範囲の対応、停止・決着・再戦での表示を追加。Compatibility実描画テストもPASSし、縮小中・最大縮小の画像を目視確認した（.local/screenshots/danger-20260908-danger-growing.png、同-danger-max.png）。リセット後の描画も取得済み。ユーザー本人の実操作、最新版の4.5.1、Web/Windows書き出しは未検証。

現状説明の古い記述を修正：P1は自動照準＋左クリック（マウス照準ではない）、CPU・パルスリレーは実装済み、表示サイズは1120×800。直前の全14ファイルの結果は16個ではなく18個のPASS出力だった。過去の日付入り履歴は当時の記録として保持する。

次は被弾・回避・武器の視覚演出、効果音、配布検証。歩行等のアニメーション、HPセグメントバー、レリック周回表示も残っており、演出全体の移植完了ではない。
## 2026-09-08 被弾・回避・武器演出

元Webのgame.js burst/roll/damage/fire/explode/updateBulletsとrender.js drawWeaponEffects/drawを参照し、Arena/CombatVisuals（scenes/combat_visuals.tscn、scripts/combat_visuals.gd）へ手続き的な粒子と武器PNGのコマ再生を追加した。既存の戦闘ノードからシグナルまたはmain.gd経由で通知する構成で、粒子が当たり判定や弾薬を変更することはない。

- 被弾14粒、回避開始8粒、回避中は毎物理フレーム35%で2粒、近接での敵弾消去6粒、発砲4粒（プリズム12粒）、反射4粒、壁着弾7粒、分裂/クローバー破裂20粒、コメット破裂32粒。色・速度30〜180・寿命0.2〜0.7秒・サイズ2〜5・線状の描画は元Webに合わせた。
- weapon-effects.pngの4行×4列を再利用。レシート反射は0.22秒/幅58、小包破裂0.32秒/94、スイッチスパナ着弾0.20秒/54、エコー追射0.26秒/62。進行率で4コマ切替、基本不透明度0.85、最後30%でフェード。小包の近接消去やパルス消去では破裂演出を出さない。
- 粒子650個、PNG演出40個を上限とし、古いものから除去。演出専用RandomNumberGeneratorを使い、ショップ抽選・CPU判断の乱数系列へ影響させない。既存Godotの演出運用に合わせ、停止中・決着後は演出時間を凍結し、次ラウンドで全消去する（元Webは決着後にも演出時間が進むため、この点は既存Godot方針を継続した差分）。
- エディタではArena/CombatVisualsの専用シーンで画像と個数上限を変更できる。プレイヤーの歩行アニメーションや弾そのもののprojectile-sprites画像は今回の範囲に含まない。

Godot 4.7.2で全15テストファイル・20個のPASS出力、ERROR/SCRIPT ERRORなしを確認（.local/logs/run_tests-20260908-194610.log）。新規tests/combat_visuals.gdで実際の被弾・回避・反射・着弾・小包寿命・追射からの通知、拒否された行動/明示消去での演出抑止、停止/決着/再戦、個数上限と寿命消去を検証。Compatibilityで描画もPASSし、.local/screenshots/combat-20260908-combat-frame1.png、同-frame2.pngを比較してコマ切替・フェードを目視確認した。ユーザーによる実操作での印象、最新版の4.5.1、Web/Windows出力は未検証。

元Web・素材・カタログは無変更。変更前ファイルは.local/backups/before-combat-visual-*へ保存。残る演出は画面揺れ、拾得粒子、爆発/防御の追加リング、弾画像、歩行等のアニメーション、HPバー、レリック周回表示、効果音。演出全体の移植完了とは扱わない。
## 2026-09-08 画面揺れ・拾得粒子・爆発/防御リング

元Web game.jsのdamage/fire/blank/explode/acquire/pulseとrender.jsのdrawを参照し、CombatVisualsへ以下を接続した。

- 画面揺れ：被弾4、プリズム/コメット発砲3、パルス/コメット爆発5。新イベントの値で上書きし、毎秒30減衰。専用乱数による左右上下のオフセットをArena/CombatCamera（固定左上のCamera2D）へ適用する。物理座標・壁・HUDの位置は変えない。Arena/CombatVisualsのShake Scaleは0〜1、0で無効。元Webの描画フレーム更新に対しGodotでは固定物理フレームで揺れを更新する。
- 拾得粒子：成功時だけ22粒。武器はレアリティ色、レリックは定義色、弾薬は#a5e9ee。元WebのRARITIESはcatalog.jsonに含まれないため、色4種をsupplies.gdの定数へ転記した。満タン・取得待ち時間・二重取得などの拒否時には発生しない。
- 追加リング：初期半径5、寿命0.45秒、幅3、寿命に比例して薄くなり、拡大量は小包55、分裂/クローバー45、コメット95、重力場生成100、ガードベル65。ガードベルは実際に防いだ時だけ発生。爆発系は着弾/寿命終了時のみで、近接・パルス・吸収での明示消去では発生しない。既存のパルス専用リングは今回変更していない。

停止・決着中は既存Godot方針に合わせて演出を凍結し、再戦では粒子/リング/揺れとカメラオフセットを消去する。既存操作・戦闘数値・legacy-web・素材・catalog.jsonは無変更。変更前ファイルは.local/backups/before-rings-shake-*へ保存した。

Godot 4.7.2で全16テストファイル・21個のPASS出力、ERROR/SCRIPT ERRORなし（.local/logs/run_tests-20260908-195058.log）。新規tests/rings_shake.gdで発生条件、色、拒否時の抑止、減衰、停止/再戦、無効化、実座標の維持、各爆発リングと寿命を検証した。Compatibility描画もPASSし、.local/screenshots/rings-20260908-rings-pickup-shake.pngと同-shake-reset.pngを目視確認。ユーザーによる揺れの体感、最新版の4.5.1、Web/Windows出力は未検証。

次の残作業は弾画像のコマ表示、歩行等のアニメーション、HPバー、レリック周回表示、効果音、負荷/配布検証。今回も演出全体の移植完了とは扱わない。
## 2026-09-08 弾画像アニメーション・HPセグメントバー

元Web render.jsのprojectileFrames/projectileRow/drawProjectileSpriteとgame.jsのupdateHUD、style.cssのhpsegmentsを参照して移植した。

- scripts/projectile_art.gdをscenes/projectile.tscnのArt（Sprite2D）へ追加。既存projectile-sprites.pngから元Webと同じ16個の矩形を切り出し、floor(age×12)%4で再生する。レシート(ID16)幅30、小包(ID17の最終弾だけ)幅32、スパナ(ID18)幅23、エコー(ID19)幅28。画像原点は尾ではなく弾本体に合わせ、速度ベクトルの向きに回転する。AtlasTextureは共有キャッシュとし毎フレーム生成しない。
- 通常のID17弾、他の武器、破片は既存Polygon2Dを表示する。PNG表示とPolygonを二重表示しない。弾の半径・速度・威力・物理計算は変更していない。停止・決着時は既存の弾年齢が進まないためコマも停止し、再戦では弾ごと消去する。
- HUD/Root/HP1・HP2にscripts/hp_bar.gdを付けたControlを配置。P1はオレンジ、P2は青、幅190/高さ12/間隔3/傾斜12度。最大HP分の区画を生成し、clamp(HP-index,0,1)×0.8+0.2の不透明度で端数を表す（例7.5HPは8区画目が0.6）。元Web同様、失った区画も不透明度0.2で残る。キャラ能力・ライフアンプ・次ラウンドの最大HP変更に追従し、既存のHP数値表示も保持する。位置とサイズ・色はHUDシーンのInspectorで編集可能。マウス入力は遮らない。

Godot 4.7.2で全17テストファイル・22個のPASS出力、ERROR/SCRIPT ERRORなし（.local/logs/run_tests-20260908-195530.log）。新規tests/projectile_hp.gdで画像4行/4コマ/ループ/幅/原点/方向/代替表示、物理半径の維持、停止/再戦、HP端数/ゼロ/最大HP増加/再戦を検証。Compatibility描画もPASSし、.local/screenshots/projectile-hp-20260908-projectile-hp-frame0.pngと同-frame2.pngを目視比較した。ユーザー実操作、最新版の4.5.1、Web/Windows書き出しは未検証。

元Web・素材・カタログは無変更。変更前ファイルは.local/backups/before-projectile-hp-*へ保存。次はレリック周回表示、歩行等の簡易アニメーション、効果音、負荷/配布検証が残る。
## 2026-09-08 レリック周回・プレイヤー簡易アニメーション

元Web render.js drawPlayerとgame.js fire/updatePlayerを参照し、Player/Animation（scripts/player_animation.gd）へ描画を分離した。既存Spriteはエディタ上で編集する画像ソースとして残し、実行時だけ非表示にして、そのtexture/frame/position/scaleから体を描画する。フレームやTransformをアニメーションで上書きしない。新素材は生成していない。

- 歩行：腰の72%位置で画像を分割し、左右脚をsin(walk)×4に従って交互にずらす。歩行位相は入力方向がある時に毎秒14進行。体の上下動はabs(cos(walk))×2、傾きはsin(walk)×0.035。待機中はsin(time×2+playerIndex)×0.5の呼吸動作。照準方向に応じて立ち絵を左右反転する。
- 回避：回避タイマーに合わせて1回転し、縦を0.8倍にする。体と武器に共通のTransformを適用し、当たり判定やプレイヤー座標は変更しない。既存の武器位置・表示サイズは維持する。
- 射撃：反動1から毎秒9減衰、体と武器の後退、マズルフラッシュ0.075秒（レールは水色、他は淡黄色）。無敵中はfloor(time×22)%2で体と武器の不透明度を0.55にする。弾薬や発射間隔には影響しない。
- レリック：取得順に最大3個、角度time×0.6+index×2π/3、横半径32/縦14/中心y10の軌道を周回。半径3の星を各レリックの定義色で表示する。ガードベルは防御可能な時だけ中心(0,-7)・半径33の待機リングを表示。

演出時間は物理更新から進める。元Webの実時間に基づく描画に対し、Godotでは既存演出方針に合わせて停止・決着中は凍結し、次ラウンドで初期化する。エディタのSprite/Weapon構成・既存操作・戦闘数値・legacy-web・素材・カタログは保護した。変更前ファイルは.local/backups/before-player-animation-*へ保存。

Godot 4.7.2で全18テストファイル・23個のPASS出力、ERROR/SCRIPT ERRORなし（.local/logs/run_tests-20260908-200039.log）。新規tests/player_animation.gdで周回の数/移動/リセット、歩行/待機/回避、Sprite Transformと物理座標の維持、停止/決着、反動/フラッシュ/無敵の状態を検証した。Compatibility描画もPASSし、.local/screenshots/player-animation-20260908-walking-roll.pngと同-walking-roll-next.pngで脚動作・体と武器の回転・周回表示を確認した。ユーザーによる操作感、最新版の4.5.1、Web/Windows出力は未検証。

次の主要作業は効果音。その他、通常弾の形状/軌跡、床装飾、プレイヤー足元影/小HPバー等の描画差分、負荷確認、配布検証が残るため、M6全体の完了とは扱わない。
## 2026-09-08 合成効果音

元Web game.jsのtone/combatSoundと呼び出し箇所を参照し、Game/Sound（scripts/sound.gd）を追加。音声ファイルは元Webにもなく、Godotで44.1kHz/16bit/monoのAudioStreamWAVを合成し、プロファイルごとにキャッシュしてAudioStreamPlayerで再生する。

- 音ON/OFFは元Webと同じく既定OFF。キャラ選択後、画面上部中央の「音 OFF」をクリックすると有効になり、ON確認音が鳴る。準備画面・対戦・結果から操作可能。ラウンドをまたいで設定を保持するが、アプリ再起動後の永続化はしない。Game/SoundのVolume Dbで音量を調整可能。
- 発砲は武器に応じて通常/重火器/エネルギー系のノイズ・波形・長さ・周波数を選択。被弾、回避、近接、装填開始/完了、パルス、破裂、重力場生成、ガードベル、装備切替、取得、開始、Sレア到着、勝敗に接続した。追射は元Web同様に独立した追加発砲音を鳴らさない。
- 購入専用音は元Webにない。武器購入/ドラフト等で実際に装備が変わる時にはequipSlot由来の音が鳴る。レリック/パルス購入には新しい音を追加しない。取得拒否・回避の連打・発射待ち時間等で成功していない行動には音を出さず、明示消去された弾から爆発音を出さない。
- combatSoundの周波数/音量の指数減衰、波形、ノイズ、ローパス/バンドパス、コンプレッサー閾値-18dB/比率5を移植。toneは元Web通りコンプレッサーを迂回する。WebAudioとGodotのフィルター/オシレーター/コンプレッサーのDSP実装は同一ではないため、音の完全一致とは扱わない（現実装はQ=1のbiquadと直接生成波形）。専用乱数を使いゲーム抽選に干渉しない。
- 同時再生は16音、超過時は古い音を置き換える。ミュート・一時停止・再戦で再生中の音を停止する。シーン終了時は専用バスを除去する。決着音は結果画面でも最後まで再生する。元Webの開始済み音がそのまま鳴る一時停止挙動とは異なる。

初回検証で波形変数の型推論エラーにより全テストが失敗したため、floatを明示して修正。再実行ではGodot 4.7.2で全19テストファイル・24個のPASS出力、ERROR/SCRIPT ERRORなし（.local/logs/run_tests-20260908-200736.log）。tests/sound.gdでミュート/UI操作/発生ガード/主要アクションの再生通知、20武器のPCM長さと非無音データ、キャッシュ、同時音数、停止、バス終了処理を検証した。Compatibility描画もPASSし、音ボタンが準備画面から見えることを確認。音色・音量の聴感は未確認であり、ユーザーの実機で「音 ON」にして確認が必要。最新版4.5.1、Web/Windows出力、音声を有効にした長時間の負荷検証も未実施。

README・移行計画・引継ぎを更新。元Web・素材・カタログは無変更。変更前ファイルは.local/backups/before-audio-*へ保存。残作業は音の聴感/負荷確認、描画差分の整理、Web/Windows配布検証。M6全体は未完了。