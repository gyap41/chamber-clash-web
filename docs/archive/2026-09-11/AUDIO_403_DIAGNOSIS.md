> 履歴資料（2026-09-11に整理）。当時の計画・結果を保存したもので、現在の作業指示ではありません。現行情報は [資料索引](../../README.md) を参照。

# Stability 403調査・修正

2026-09-11。生成POSTは0回。読み取りGETのみ5回。
APIキー/個人情報/残高実値/エラー本文は表示・保存していない。

## 結果

Python urllibの既定User-Agentによるアクセスが拒否されていた。
同一キー・同一アカウントGETで、実アプリ名のUser-Agentにすると403から200へ変化した。
生成プロンプトを送らないAPIでも再現しており、今回の検証はプロンプト変更を必要としない。
内部の遮断ルールそのものは公開応答だけでは確定できない。

|要求|認証|クライアント識別|結果|
|---|---|---|---|
|GET /v1/user/balance|あり|urllib既定|403|
|GET /v1/user/account|あり|urllib既定|403|
|GET /|なし|urllib既定|403|
|GET /v1/user/account|あり|ChamberClashAssetGenerator/1.0 (Python urllib)|200|
|GET /v1/user/balance|あり|修正した本番https_openerの識別|200|

初期エラー本文はメモリ内で固定カテゴリに分類したのみ。
「account_restriction」等のキーワード一致はアカウント停止を確定するものではなく、
実アプリ識別で認証成功したため、キー無効・アカウント停止と断定しない。
最後の残高確認では20 credits以上であることのみ確認できた。
生成APIへのモデル権限や今後の実生成成功までは保証しない。

## 修正

transport.pyのhttps_openerに実アプリ名のUser-Agentを設定した。
ブラウザーへの偽装、TLS検証の無効化、キー変更、自動retry追加は行っていない。
テストを1件追加し、全19件成功。READMEに仕様を追記した。
素材、manifest、生成試行履歴、ゲーム本体は変更していない。

残高・アカウント確認GETは [Stability公式API](https://platform.stability.ai/docs/api-reference)
掲載の /v1/user/balance と /v1/user/account を使用。
前回の生成POSTを再送していないため、生成側403の解消確認は次の明示的な生成依頼時に行う。
