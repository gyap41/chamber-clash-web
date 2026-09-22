# 資料の配置と更新ルール

[総合索引](README.md) / [全ファイル索引](CATALOG.md)

## 仕事を始めるとき

1. 最新の依頼とルート[AGENTS.md](../AGENTS.md)を読む。
2. [総合索引](README.md)の依頼別表から、対象分野の正本と手順だけを選ぶ。毎回すべての履歴を読む必要はない。
3. [ロードマップ](planning/ROADMAP.md)、対象コード・データ、既存差分を確認する。資料の古い「次の作業」で最新の依頼を置き換えない。
4. 変更する仕様の正本と検証方法を決めてから実装する。仕様追加のたびに新しい文書を作らず、既存の責務に収まればその節を更新する。
5. 終了時に実装済み仕様・残課題・必要な手順を更新し、結果と未確認事項を分けて報告する。

## 階層と責務

|置き場所|何を書くか|書かないもの|
|---|---|---|
|docs/README.md|依頼別の入口・分野別索引|詳細仕様の複製|
|docs/design/|現行のゲーム動作、UI、性能の参照、美術設定|未採用案を現行規則として記載|
|docs/planning/|今後の工程、提案、採用済み未実装の仕様、受入条件|過去の詳細な実行日誌|
|docs/development/|実装の責務・拡張方法・実行と検証の手順|ゲーム数値の別の正本|
|docs/art/|共通の制作規格、素材の設定・制作・採用記録|ファイルがあるだけで採用済みとする説明|
|docs/AUDIO_BIBLE.md|音響の方向性・採用状態・試聴基準|API設定や過去の生成予算の複製|
|docs/notes/|作業をまたいで共有する短期メモ、未決質問、調査途中|確定仕様の唯一の保存先|
|docs/archive/YYYY-MM-DD/topic/|完了・却下・置換された案、詳細な検証履歴|現在の作業指示|
|assets/**/README.md|その素材群の利用先・出所・置換方法|ゲーム全体の企画|
|tools/**/README.md|そのCLIの使い方・制約|過去の承認を新しい実行許可として記載|
|.local/|使い捨て出力・ログ・個人用メモ（Git除外）|引き継ぎに必要な唯一の情報|

既存の安定したパスは維持する。AUDIO_BIBLEなど例外配置も索引で案内し、見栄えだけを理由に移動しない。移動が必要な場合は参照元を更新し、原画・生成台帳内の履歴パスは勝手に書き換えない。

## 仕様を追加・変更したときの反映先

|変更内容|主な反映先|関連して更新するもの|
|---|---|---|
|操作、戦闘、装備、探索進行|[GAME_RULES](design/GAME_RULES.md)|操作が変わればルートREADME。未実装分はROADMAP|
|武器・レリックの性能、価格、形状|カタログ等の実装データ → [ITEM_CATALOG](design/ITEM_CATALOG.md)|生成表はexport_item_catalog.pyで再出力。バッグ説明等の手書き部分は個別確認。設計方針変更はITEM_FOOTPRINT_BALANCE|
|対戦HUD・準備画面|[BATTLE_UI_C](design/BATTLE_UI_C.md) / [PREPARATION_UI_B](design/PREPARATION_UI_B.md)|共通部品の責務変更はARCHITECTURE。探索固有の操作はGAME_RULES|
|敵・ボス・難度の提案|[EXPLORATION_DESIGN](planning/EXPLORATION_DESIGN.md)|寸法・パーツはENEMY_BOSS_ART_PLAN、実装後の動作はGAME_RULES|
|宝箱・報酬・演出の提案|[EXPLORATION_REWARDS](planning/EXPLORATION_REWARDS.md)|採用後の実装順はEXPLORATION_ROADMAP、実装済み動作はGAME_RULES|
|ステージ素材・壁・扉・家具|[STAGE_CREATION_TEMPLATE](art/STAGE_CREATION_TEMPLATE.md)から開始|共通規格はSTAGE_ASSET_GUIDE、データ構造はSTAGE_TEMPLATES、個別記録はart/production|
|キャラの設定・見た目・動作|[CHARACTER_BIBLE](design/CHARACTER_BIBLE.md) / [ACTOR_ANIMATION](development/ACTOR_ANIMATION.md)|採用画像と比較はart/reviews。身体設定とプログラムの責務を分ける|
|音響の方針・採用|[AUDIO_BIBLE](AUDIO_BIBLE.md)|生成物の事実は音響manifest。未試聴・仮ループは明記|
|構造変更・共通化|[ARCHITECTURE](development/ARCHITECTURE.md)|対象の開発ガイド、継続的に必要な検証手順はTESTING|
|API・素材生成環境|[ASSET_GENERATION_SETUP](development/ASSET_GENERATION_SETUP.md)|対象CLIのREADME。変更時の公式仕様確認等はAGENTSに従う|
|検証|[TESTING](development/TESTING.md)に再利用する実行方法|詳細な一回分の出力・比較・成功履歴はarchiveまたは対象制作記録|
|優先順位・未対応項目|[ROADMAP](planning/ROADMAP.md)|探索の依存順はEXPLORATION_ROADMAP。数値や長い仕様を重複させない|

## 状態の区別と資料の寿命

- **提案**：未採用のアイデア。ユーザー希望とこちらの具体案を分ける。
- **採用・未実装**：決定内容、対象範囲、受入条件をplanningに記す。採用しただけでGAME_RULESの現行動作にしない。
- **実装済み**：実際の動作をdesignへ反映。未検証部分と確認した範囲を併記する。
- **制作・検証記録**：原本・加工手順・確認画像・結果。自動テスト、目視、手動操作、試聴、ユーザー採用は別の事実として記録する。
- **履歴**：完了、却下、置換後は必要な理由をarchiveへ保存し、現在の入口から後継へ案内する。

一時メモ → 提案または採用仕様 → 実装と検証 → 現行資料へ反映 → メモを終了、の順で整理する。軽微な修正ではメモ作成を省略してよい。タスク完了ごとに全資料を複製しない。

新しい独立資料を作る場合は冒頭に「区分／状態／定義する範囲／関連する正本」を短く書く。混在する資料は節ごとに状態を明記する。旧資料は移行途中なので、分類だけで内容の正しさを保証しない。

## 食い違いを見つけたとき

依頼された仕様と現行動作の違いは意図された変更か確認する。現行動作の事実はコード・データ・検証から調べ、古い説明を訂正する。コードが誤っている場合もあるため、コードに合わせて採用仕様を無断で変更しない。判断できない選択肢だけユーザーへ質問する。

重複文書を削除する前に、固有の判断根拠・未決事項・制作レシピが後継へ残っているか確認する。全件分類の再生成は `python tools/docs_index.py`、索引の更新漏れとローカルリンクの点検は `python tools/docs_index.py --check`。
