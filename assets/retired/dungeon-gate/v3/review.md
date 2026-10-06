# 鉄格子の門 v3：開口・通路との接続

2026-10-07：ユーザー採用・本編適用。正式画像はassets/stages/ashen-foundry-v2/dungeon-gate、音響はassets/audio/seのheavy_02 WAV。通常起動で同じ表示と開閉を使う。以下は採用前の制作・検証履歴。

区分：制作・検証記録。状態：修正候補、ユーザー未採用。正本：[旧鋳造区の制作記録](../../../../docs/art/production/ashen-foundry-v2/README.md)。2026-10-06。

## 修正した点

- 北：門の奥へ86pxの通路床と内側の壁面を描き、奥ほど暗くした。石模様が壁のように見えていた部分は元々床材であり、衝突壁を切り抜いた変更ではない。案内溝は石材の側面へ埋め込む形に変更。
- 南：手前壁と同じ断面表示として上の梁を省略し、格子の下32pxを見せる。開口の先には60pxの通路と両側の壁上面を続けた。
- 東西：格子を覆っていた長い梁を省略。厚み18pxの二面の格子と連結材を描き、閉鎖時は格子、開放時は敷居と通路が見えるようにした。
- 昇降70px、閉鎖.35秒、開放.65秒、停止・再訪・開放待ちの規則は維持。通路奥は遷移先の表現で、操作点・衝突・歩行領域は変更しない。
- 新しい画像・SE生成は0件。素材・描画コード・撮影条件は[recipe.json](recipe.json)。v1/v2は比較用に保持。

## 確認画像

通常倍率の四方向で閉・途中・開の12枚を保存。確認室に加え、seed 1の本編カタログで北（authored_0）・東（authored_2）を確認した。

|方向|閉鎖|開放|
|---|---|---|
|北|[画像](views/north/closed.png)|[画像](views/north/open.png)|
|南|[画像](views/south/closed.png)|[画像](views/south/open.png)|
|東|[画像](views/east/closed.png)|[画像](views/east/open.png)|
|西|[画像](views/west/closed.png)|[画像](views/west/open.png)|

本編の連続記録：各100コマ、20fps、5秒。画像サイズ1120×800、カメラ倍率は現行通常値。WebPは表示用圧縮、原フレームは.localに保存。

- [北の開閉](views/production/north-animation.webp)
- [東の開閉](views/production/east-animation.webp)

静止画では、北の奥が暗くなったこと、東西の開閉で格子の有無が変わること、南の高い枠がなくなり壁に沿うことを確認。東西は正投影の側面なので依然細く見える。上部の省略は意図した断面表現であり、収納機構全体を描いたものではない。連続記録の作成と、ユーザーによる連続再生・操作感の受入は分ける。

## 自動確認と制限

- 全体：PASS 161 / FAIL 0 / NO-PASS 4 / 合計165。ログ：`.local/logs/run_tests-20261006-223328.log`。
- NO-PASS：enemy_animation_review、enemy_art_preview、enemy_death_review、quillback_art。エラーのない撮影用。
- v3有効のexploration_rooms：20回往復、資源・タイマー保持、停止／死亡ガード、再開始はPASS。終了時に2件のObjectDB残り警告。
- 追加実行した既存production_doorsは、v3有効時に16行の即時通行assertでFAIL。既存テストは敵撃破後.016秒で通行を要求し、候補の開放完了待ちと両立しない。そこから巡回状態がずれて後続assertと配置エラーも発生。通常モードでは同じテストがPASS。
- 原テストとassertは変更せず、別の検証スクリプトで各cross前・ボス報酬取得後にrefresh_hudとOPEN_SECONDS分のdoor.stepを入れ、全門の非封鎖・passage_readyを追加assert。29回通行・宝箱・状態保持・ボス報酬取得・帰還がエラーなしでPASS（`.local/gate-v3-campaign-check.log`）。これを元の即時通行テストの成功とは数えない。
- 未確認：全本編部屋の美術適合、ユーザーの手動通行と連続再生の受入。通常起動へは未採用。

後続のSE依頼で開閉音を接続し、さらに「重厚感＝開閉SEの重さ」の指定で[音響v2](../../dungeon-gate-audio/v2/review.md)へ改訂。門の画像と開閉時間は維持。試聴未確認。
