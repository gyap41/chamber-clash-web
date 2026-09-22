# Markdown一次監査（2026-09-22）

## 対象と確認の深さ

開始時の172ファイルを一覧化し、本文を機械走査した。対象はルート、docs、assets、tools、tests/fixtures、legacy-webのMarkdown。Git内部、.godot、.local、依存パッケージと仮想環境は除外した。

**全172件の一文一文を現行コード・画像・実機で検証し終えたという意味ではない。** 下表は全件の所在・分類と変更有無を記録する。現行操作、音響接続、探索の実装有無、壁の編集経路については対象コードを照合した。歴史資料は参照の到達性と資料区分を点検し、当時の数値・成功結果を再現検証していない。

## 修正した誤り

- READMEの取得GキーをFへ訂正。旧P2手動操作を現行操作から除き、探索入口とTab/Mを明記。
- SE既定OFF／ON、BGM未接続／接続済みの矛盾を解消。Music Autoloadと採用3曲、仮ループ・試聴未確認を明記。
- 通常弾の壁着弾音と汎用リングに関する旧説明を訂正。
- 探索インベントリ・ランダム階層・再訪保持を未実装とする旧説明を訂正。
- エディタガイドをFieldDefinition／Builderによる生成経路へ修正。
- 採用PNG、既定フォントの参照説明を訂正。
- 画像CLI・共通設定の累積した生成承認枠を別の履歴へ保存。過去の承認を新規生成の指示にしない。
- アーカイブの相対リンク切れ85件と、移動・整理で失われた見出しへの参照を修復。

主な照合先: human_input.gd、supplies.gd、arena.gd、field_builder.gd、sound.gd、music.gd、projectile.gd、exploration関連スクリプト、project.godot、skin.json。

## 残る精査・整理

|優先度|資料|残作業|
|---|---|---|
|中|GAME_RULES / ARCHITECTURE / TESTING|追記型の履歴が多い。今回確認した矛盾以外も節単位で照合し、現行仕様・実行手順・過去の結果に分離する|
|中|ASSET_PRODUCTION_PLAN / 音響素材計画|履歴である旨を明記済み。素材単位で採用台帳と照合し、未制作・採用済み・不要を確定してから計画を再編する。費用の再見積もりは未実施|
|中|ITEM_CATALOG / WEAPON_EXTENSIONS / CHARACTER_BIBLE|全性能値・全素材対応の個別照合は未完了。自動出力元にも古いアトラス説明があるため、再出力だけで正確になるとは扱わない|
|低|artの制作記録・旧Web資料|当時の画像・試聴・実行結果の再検証は対象外。履歴の指示を現行作業として採用しない|

外部URLの疎通・最新API仕様、画像の目視再審査、Godot実機試験、音源試聴は今回未実施。ゲームコード・生成設定・素材は変更していない。資料の修正に伴う有料生成なし。履歴の機械的な削除は行っていない。

## 今回の検証結果

整理後176ファイルのローカルMarkdownリンク1,187件を点検し、参照先ファイルの欠落は0件。見出し参照9件は対応する見出しを確認。git diff --check成功。外部リンク、インラインコードで書かれた全パス、参照形式リンクはこの件数に含まない。

## 全件一覧

「内容修正」は今回変更したことを示し、全記述の正しさを保証する印ではない。「走査」は分類・本文検索・ローカルリンク点検の範囲。

|資料|区分|今回の扱い|
|---|---|---|
|[AGENTS.md](../../../../AGENTS.md)|現行・計画候補|内容修正またはリンク修復|
|[README.md](../../../../README.md)|現行・計画候補|内容修正またはリンク修復|
|[assets/README.md](../../../../assets/README.md)|現行・計画候補|内容修正またはリンク修復|
|[assets/first-workshop/README.md](../../../../assets/first-workshop/README.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[assets/first-workshop/equipment/README.md](../../../../assets/first-workshop/equipment/README.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[assets/first-workshop/projectiles/README.md](../../../../assets/first-workshop/projectiles/README.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[assets/generated/README.md](../../../../assets/generated/README.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[assets/ui/hud/README.md](../../../../assets/ui/hud/README.md)|現行・計画候補|内容修正またはリンク修復|
|[docs/AUDIO_BIBLE.md](../../../AUDIO_BIBLE.md)|現行・計画候補|内容修正またはリンク修復|
|[docs/README.md](../../../README.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/AUDIO_403_DIAGNOSIS.md](../../2026-09-11/AUDIO_403_DIAGNOSIS.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/AUDIO_SETUP_REPORT.md](../../2026-09-11/AUDIO_SETUP_REPORT.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/AUDIO_TLS_DIAGNOSIS.md](../../2026-09-11/AUDIO_TLS_DIAGNOSIS.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/BEFORE_ARCHITECTURE.md](../../2026-09-11/BEFORE_ARCHITECTURE.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/BEFORE_FIELD_RESERVE_GAME_RULES.md](../../2026-09-11/BEFORE_FIELD_RESERVE_GAME_RULES.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-11/BEFORE_FIELD_RESERVE_TESTING.md](../../2026-09-11/BEFORE_FIELD_RESERVE_TESTING.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-11/BEFORE_FINE_GRID_ROADMAP.md](../../2026-09-11/BEFORE_FINE_GRID_ROADMAP.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/BEFORE_GAME_RULES.md](../../2026-09-11/BEFORE_GAME_RULES.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/BEFORE_HANDOFF_FOR_CLAUDE.md](../../2026-09-11/BEFORE_HANDOFF_FOR_CLAUDE.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/BEFORE_ITEM_EXPANSION_FOOTPRINT.md](../../2026-09-11/BEFORE_ITEM_EXPANSION_FOOTPRINT.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-11/BEFORE_ITEM_EXPANSION_TESTING.md](../../2026-09-11/BEFORE_ITEM_EXPANSION_TESTING.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/BEFORE_PURCHASE_FINE_GRID_ROADMAP.md](../../2026-09-11/BEFORE_PURCHASE_FINE_GRID_ROADMAP.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-11/BEFORE_PURCHASE_ROADMAP.md](../../2026-09-11/BEFORE_PURCHASE_ROADMAP.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-11/BEFORE_PURCHASE_TESTING.md](../../2026-09-11/BEFORE_PURCHASE_TESTING.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-11/BEFORE_README.md](../../2026-09-11/BEFORE_README.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/BEFORE_ROADMAP.md](../../2026-09-11/BEFORE_ROADMAP.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/BEFORE_TESTING.md](../../2026-09-11/BEFORE_TESTING.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/EXPANSION_GUIDANCE.md](../../2026-09-11/EXPANSION_GUIDANCE.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/INITIAL_PREPARATION_FIX.md](../../2026-09-11/INITIAL_PREPARATION_FIX.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/ITEM_EXPANSION_PROPOSAL.md](../../2026-09-11/ITEM_EXPANSION_PROPOSAL.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/P9_BEFORE_FOOTPRINT_BALANCE_TESTING.md](../../2026-09-11/P9_BEFORE_FOOTPRINT_BALANCE_TESTING.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-11/P9_BEFORE_SELECTABLE_EXPANSION_TESTING.md](../../2026-09-11/P9_BEFORE_SELECTABLE_EXPANSION_TESTING.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-11/P9_FINE_GRID_VALIDATION.md](../../2026-09-11/P9_FINE_GRID_VALIDATION.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/PREPARATION_UI_B_BEFORE_FINE_GRID.md](../../2026-09-11/PREPARATION_UI_B_BEFORE_FINE_GRID.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-11/PREPARATION_UI_OPTIONS.md](../../2026-09-11/PREPARATION_UI_OPTIONS.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/PURCHASE_ECONOMY_VALIDATION.md](../../2026-09-11/PURCHASE_ECONOMY_VALIDATION.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/README.md](../../2026-09-11/README.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-11/ROGUELIKE_PVP_PLAN.md](../../2026-09-11/ROGUELIKE_PVP_PLAN.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/BEFORE_CPU_STRENGTHENING_TESTING.md](../../2026-09-12/BEFORE_CPU_STRENGTHENING_TESTING.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-12/BEFORE_CPU_TACTICS_TESTING.md](../../2026-09-12/BEFORE_CPU_TACTICS_TESTING.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-12/BEFORE_EXTENSION_ARCHITECTURE.md](../../2026-09-12/BEFORE_EXTENSION_ARCHITECTURE.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-12/BEFORE_EXTENSION_TESTING.md](../../2026-09-12/BEFORE_EXTENSION_TESTING.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-12/BEFORE_REFACTOR_TESTING.md](../../2026-09-12/BEFORE_REFACTOR_TESTING.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-12/BEFORE_SHARED_SUPPLIES_TESTING.md](../../2026-09-12/BEFORE_SHARED_SUPPLIES_TESTING.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-12/BEFORE_SMALL_IMPROVEMENTS_TESTING.md](../../2026-09-12/BEFORE_SMALL_IMPROVEMENTS_TESTING.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-12/BEFORE_WEAPON_DIFFERENTIATION_TESTING.md](../../2026-09-12/BEFORE_WEAPON_DIFFERENTIATION_TESTING.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/EXTENSION_REFACTOR.md](../../2026-09-12/EXTENSION_REFACTOR.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/FIELD_DEFINITION_REFACTOR.md](../../2026-09-12/FIELD_DEFINITION_REFACTOR.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/PREPARATION_UI_BEFORE_REVISION.md](../../2026-09-12/PREPARATION_UI_BEFORE_REVISION.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-12/REFACTOR_VALIDATION.md](../../2026-09-12/REFACTOR_VALIDATION.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/WEAPON_DIFFERENTIATION_PROPOSAL.md](../../2026-09-12/WEAPON_DIFFERENTIATION_PROPOSAL.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/art-organization/REPORT.md](../../2026-09-12/art-organization/REPORT.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/art-organization/unused-candidates/README.md](../../2026-09-12/art-organization/unused-candidates/README.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/character-directions/CHARACTER_BIBLE_BEFORE.md](../../2026-09-12/character-directions/CHARACTER_BIBLE_BEFORE.md)|履歴|内容修正またはリンク修復|
|[docs/archive/2026-09-12/character-directions/REPORT.md](../../2026-09-12/character-directions/REPORT.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/character-integration/REPORT.md](../../2026-09-12/character-integration/REPORT.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/first-workshop/REPORT.md](../../2026-09-12/first-workshop/REPORT.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/first-workshop/USAGE.md](../../2026-09-12/first-workshop/USAGE.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/rina-chibi/INITIAL_PLAN.md](../../2026-09-12/rina-chibi/INITIAL_PLAN.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/rina-chibi/REPORT.md](../../2026-09-12/rina-chibi/REPORT.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/rina-dive/REPORT.md](../../2026-09-12/rina-dive/REPORT.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/rina-gait-dodge/REPORT.md](../../2026-09-12/rina-gait-dodge/REPORT.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-12/rina-twohead/REPORT.md](../../2026-09-12/rina-twohead/REPORT.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/GAME_RULES-before-equipment-completion.md](../../2026-09-13/GAME_RULES-before-equipment-completion.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/ROADMAP-before-equipment-completion.md](../../2026-09-13/ROADMAP-before-equipment-completion.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/SE_GAME_INTEGRATION.md](../../2026-09-13/SE_GAME_INTEGRATION.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/SE_HTTP400_DIAGNOSIS.md](../../2026-09-13/SE_HTTP400_DIAGNOSIS.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/SE_REMAINING_INTEGRATION.md](../../2026-09-13/SE_REMAINING_INTEGRATION.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/TESTING-before-equipment-completion.md](../../2026-09-13/TESTING-before-equipment-completion.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/VISUAL_HUB_COMPARE_UPDATE_FIX.md](../../2026-09-13/VISUAL_HUB_COMPARE_UPDATE_FIX.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/VISUAL_HUB_HYBRID.md](../../2026-09-13/VISUAL_HUB_HYBRID.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/VISUAL_HUB_MILESTONES.md](../../2026-09-13/VISUAL_HUB_MILESTONES.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/VISUAL_HUB_SCROLL_FIX.md](../../2026-09-13/VISUAL_HUB_SCROLL_FIX.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/VISUAL_HUB_SURVEY.md](../../2026-09-13/VISUAL_HUB_SURVEY.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/VISUAL_HUB_WEB_LIVE.md](../../2026-09-13/VISUAL_HUB_WEB_LIVE.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/VISUAL_HUB_WEB_PLAYBACK_FIX.md](../../2026-09-13/VISUAL_HUB_WEB_PLAYBACK_FIX.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/bgm3-action-review/README.md](../../2026-09-13/bgm3-action-review/README.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/bgm3-review/README.md](../../2026-09-13/bgm3-review/README.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/se-review-revisions/README.md](../../2026-09-13/se-review-revisions/README.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/se16-review/README.md](../../2026-09-13/se16-review/README.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-13/se34-review/README.md](../../2026-09-13/se34-review/README.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-14/WEB_AUDIO_FIX.md](../../2026-09-14/WEB_AUDIO_FIX.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-14/battle-bgm-candidates/README.md](../../2026-09-14/battle-bgm-candidates/README.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-21/ACTOR_ANIMATION_STATE.md](../../2026-09-21/ACTOR_ANIMATION_STATE.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-21/CHARACTER_MOTION.md](../../2026-09-21/CHARACTER_MOTION.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-21/shared-combat-hud/REPORT.md](../../2026-09-21/shared-combat-hud/REPORT.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-21/two-room-exploration/REPORT.md](../../2026-09-21/two-room-exploration/REPORT.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-22/planning-cleanup/EXPLORATION_ROADMAP.md](../planning-cleanup/EXPLORATION_ROADMAP.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-22/planning-cleanup/FINE_GRID_ROADMAP.md](../planning-cleanup/FINE_GRID_ROADMAP.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-22/planning-cleanup/HANDOFF_FOR_CLAUDE.md](../planning-cleanup/HANDOFF_FOR_CLAUDE.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-22/planning-cleanup/README.md](../planning-cleanup/README.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/2026-09-22/planning-cleanup/ROADMAP.md](../planning-cleanup/ROADMAP.md)|履歴|内容修正またはリンク修復|
|[docs/archive/HANDOFF_FOR_GPT6_ASTRA.md](../../HANDOFF_FOR_GPT6_ASTRA.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/MIGRATION_PLAN.md](../../MIGRATION_PLAN.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/README.md](../../README.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/archive/README_BEFORE_REFACTOR.md](../../README_BEFORE_REFACTOR.md)|履歴|走査（詳細照合完了を示さない）|
|[docs/art/README.md](../../../art/README.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/art/ROOM_VISUAL_DIRECTION.md](../../../art/ROOM_VISUAL_DIRECTION.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/art/STAGE_ASSET_GUIDE.md](../../../art/STAGE_ASSET_GUIDE.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/art/STAGE_CREATION_TEMPLATE.md](../../../art/STAGE_CREATION_TEMPLATE.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/art/production/README.md](../../../art/production/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/production/equipment-diversity-2026-09-13/README.md](../../../art/production/equipment-diversity-2026-09-13/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/production/equipment-rollout-2026-09-12/DESIGN_REVISION.md](../../../art/production/equipment-rollout-2026-09-12/DESIGN_REVISION.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/production/equipment-rollout-2026-09-12/README.md](../../../art/production/equipment-rollout-2026-09-12/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/production/exploration-first-enemy/README.md](../../../art/production/exploration-first-enemy/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/production/projectile-effects-2026-09-13/ARCHITECTURE.md](../../../art/production/projectile-effects-2026-09-13/ARCHITECTURE.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/production/projectile-effects-2026-09-13/README.md](../../../art/production/projectile-effects-2026-09-13/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/production/random-workshop-floor/README.md](../../../art/production/random-workshop-floor/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/production/wall-kit-v2/README.md](../../../art/production/wall-kit-v2/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/production/workshop-annex/README.md](../../../art/production/workshop-annex/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/production/workshop-room-variants/README.md](../../../art/production/workshop-room-variants/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/production/workshop-showcase/FURNITURE_SCALE.md](../../../art/production/workshop-showcase/FURNITURE_SCALE.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/production/workshop-showcase/README.md](../../../art/production/workshop-showcase/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/production/workshop-walls-2026-09-21/README.md](../../../art/production/workshop-walls-2026-09-21/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/README.md](../../../art/reviews/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/aurora-ribbon-2026-09-13/README.md](../../../art/reviews/aurora-ribbon-2026-09-13/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/character-directions-2026-09-12/README.md](../../../art/reviews/character-directions-2026-09-12/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/character-motion-2026-09-21/README.md](../../../art/reviews/character-motion-2026-09-21/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/doubleback-body-2026-09-13/README.md](../../../art/reviews/doubleback-body-2026-09-13/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/dynamic-motion-2026-09-21/README.md](../../../art/reviews/dynamic-motion-2026-09-21/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/equipment-diversity-2026-09-13/README.md](../../../art/reviews/equipment-diversity-2026-09-13/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/exploration-bag-2026-09-22/README.md](../../../art/reviews/exploration-bag-2026-09-22/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/gravity-legendary-2026-09-13/README.md](../../../art/reviews/gravity-legendary-2026-09-13/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/gravity-residue-2026-09-13/README.md](../../../art/reviews/gravity-residue-2026-09-13/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/preparation-ui-2026-09-12/README.md](../../../art/reviews/preparation-ui-2026-09-12/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/projectile-effects-2026-09-13/README.md](../../../art/reviews/projectile-effects-2026-09-13/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/projectile-personality-2026-09-13/README.md](../../../art/reviews/projectile-personality-2026-09-13/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/rina-directions-2026-09-12/README.md](../../../art/reviews/rina-directions-2026-09-12/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/rina-dodge-2026-09-12/README.md](../../../art/reviews/rina-dodge-2026-09-12/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/weapon-diversity-2026-09-12/README.md](../../../art/reviews/weapon-diversity-2026-09-12/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/weapon-readability-audit-2026-09-13/README.md](../../../art/reviews/weapon-readability-audit-2026-09-13/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/weapon-readability-audit-2026-09-13/measurements.md](../../../art/reviews/weapon-readability-audit-2026-09-13/measurements.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/weapon-readability-fix-2026-09-13/README.md](../../../art/reviews/weapon-readability-fix-2026-09-13/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/reviews/weapon-relic-prototype-2026-09-12/README.md](../../../art/reviews/weapon-relic-prototype-2026-09-12/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/settings/README.md](../../../art/settings/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/settings/character-revision-2026-09-12/README.md](../../../art/settings/character-revision-2026-09-12/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/settings/character-settings-2026-09-12/README.md](../../../art/settings/character-settings-2026-09-12/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/settings/concepts/battle-play-2026-09-12/README.md](../../../art/settings/concepts/battle-play-2026-09-12/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/settings/concepts/first-workshop-2026-09-11/README.md](../../../art/settings/concepts/first-workshop-2026-09-11/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/settings/concepts/preparation-revision-2026-09-12/README.md](../../../art/settings/concepts/preparation-revision-2026-09-12/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/settings/concepts/rina-chibi-2026-09-12/README.md](../../../art/settings/concepts/rina-chibi-2026-09-12/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/settings/concepts/rina-two-head-2026-09-12/README.md](../../../art/settings/concepts/rina-two-head-2026-09-12/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/art/settings/concepts/screen-overview-2026-09-12/README.md](../../../art/settings/concepts/screen-overview-2026-09-12/README.md)|制作・美術記録|走査（詳細照合完了を示さない）|
|[docs/design/BATTLE_UI_C.md](../../../design/BATTLE_UI_C.md)|現行・計画候補|内容修正またはリンク修復|
|[docs/design/CHARACTER_BIBLE.md](../../../design/CHARACTER_BIBLE.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/design/GAME_RULES.md](../../../design/GAME_RULES.md)|現行・計画候補|内容修正またはリンク修復|
|[docs/design/ITEM_CATALOG.md](../../../design/ITEM_CATALOG.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/design/ITEM_FOOTPRINT_BALANCE.md](../../../design/ITEM_FOOTPRINT_BALANCE.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/design/PREPARATION_UI_B.md](../../../design/PREPARATION_UI_B.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/development/ACTOR_ANIMATION.md](../../../development/ACTOR_ANIMATION.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/development/ARCHITECTURE.md](../../../development/ARCHITECTURE.md)|現行・計画候補|内容修正またはリンク修復|
|[docs/development/ASSET_GENERATION_SETUP.md](../../../development/ASSET_GENERATION_SETUP.md)|現行・計画候補|内容修正またはリンク修復|
|[docs/development/EDITOR_GUIDE.md](../../../development/EDITOR_GUIDE.md)|現行・計画候補|内容修正またはリンク修復|
|[docs/development/HANDOFF_FOR_CLAUDE.md](../../../development/HANDOFF_FOR_CLAUDE.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/development/STAGE_TEMPLATES.md](../../../development/STAGE_TEMPLATES.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/development/TESTING.md](../../../development/TESTING.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/development/WEAPON_EXTENSIONS.md](../../../development/WEAPON_EXTENSIONS.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/planning/ASSET_PRODUCTION_PLAN.md](../../../planning/ASSET_PRODUCTION_PLAN.md)|現行・計画候補|内容修正またはリンク修復|
|[docs/planning/AUDIO_ASSET_INVENTORY_2026-09-13.md](../../../planning/AUDIO_ASSET_INVENTORY_2026-09-13.md)|現行・計画候補|内容修正またはリンク修復|
|[docs/planning/ENEMY_BOSS_ART_PLAN.md](../../../planning/ENEMY_BOSS_ART_PLAN.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/planning/EXPLORATION_DESIGN.md](../../../planning/EXPLORATION_DESIGN.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/planning/EXPLORATION_REWARDS.md](../../../planning/EXPLORATION_REWARDS.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/planning/EXPLORATION_ROADMAP.md](../../../planning/EXPLORATION_ROADMAP.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/planning/PURCHASE_ECONOMY_PROPOSAL.md](../../../planning/PURCHASE_ECONOMY_PROPOSAL.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/planning/ROADMAP.md](../../../planning/ROADMAP.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[docs/planning/se16-2026-09-13/README.md](../../../planning/se16-2026-09-13/README.md)|現行・計画候補|内容修正またはリンク修復|
|[docs/planning/se34-2026-09-13/README.md](../../../planning/se34-2026-09-13/README.md)|現行・計画候補|内容修正またはリンク修復|
|[legacy-web/README.md](../../../../legacy-web/README.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[tests/fixtures/art/README.md](../../../../tests/fixtures/art/README.md)|現行・計画候補|走査（詳細照合完了を示さない）|
|[tools/README.md](../../../../tools/README.md)|現行・計画候補|内容修正またはリンク修復|
|[tools/asset_generator/README.md](../../../../tools/asset_generator/README.md)|現行・計画候補|内容修正またはリンク修復|
|[tools/visual_hub/README.md](../../../../tools/visual_hub/README.md)|現行・計画候補|走査（詳細照合完了を示さない）|
