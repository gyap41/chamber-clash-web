> 履歴資料（2026-09-11に整理）。当時の計画・結果を保存したもので、現在の作業指示ではありません。現行情報は [資料索引](../../README.md) を参照。

# BGM通信エラー調査

## 修正・検証の追記

後続の修正依頼によりtransport.pyへWindows ROOTストア方式を反映した。
Windows以外は既定TLS設定。明示的なSSL_CERT_FILE/SSL_CERT_DIRは追加ロードする。
証明書とホスト名検証を維持し、TLS失敗は秘密情報を含まない専用メッセージで報告する。
既存13件と追加TLSテスト5件、合計18件成功。
修正後の実際のhttps_openerで認証なしHEADを各1回実行し、StabilityはHTTP403、
ElevenLabsはHTTP404を返した。両方でTLS検証成功。生成APIの認証・課金・音声生成は未検証。
この修正作業でも生成POST/キー送信は0回。OS証明書設定、素材、manifest、試行履歴は変更なし。
以下は先行する調査時点の記録。

調査日: 2026-09-11。今回の生成POSTは0回、APIキー送信も0回。
生成履歴、音声素材、manifest、ゲームコード、OS証明書設定は変更していない。

## 結論

Pythonの既定TLSコンテキストが選択する証明書チェーンに、期限切れの
ISRG Root X2（ISRG Root X1によるクロス署名）が含まれるため検証に失敗する。
Stabilityのサーバー証明書自体が期限切れだったわけではない。
前回は例外を一般化して表示したため、Network/TLS/proxy failureとだけ報告されていた。
今回同じPython環境の認証なし通信でTLSエラーを再現した。

## 観測結果

|確認|結果|
|---|---|
|端末日時|2026-09-11 17:49 JST|
|Python TLS実装|OpenSSL 3.0.11|
|DNS|Stability / ElevenLabsとも成功|
|明示プロキシ設定|Python getproxies()でなし|
|独自CA環境変数|SSL_CERT_FILE / SSL_CERT_DIR / REQUESTS_CA_BUNDLEなし|
|制限環境のHTTPS|両サービスPermissionError。切り分けは承認済みの制限外実行で行った|
|Python既定・Stability|SSLCertVerificationError、verify_code=10|
|Python既定・ElevenLabs|HEAD / がHTTP404を返す。TLS接続は成功|
|Windows SslStream・Stability|証明書/ホスト名の検証成功|
|Python・Windows ROOTストアのみ|証明書必須・ホスト名検証有効でHEAD / がHTTP403を返す。TLS接続は成功|

HTTP403/404は認証なしのルートパスに対する応答で、生成APIの権限・残高・モデル利用可否を
示すものではない。透明な通信検査装置の存在まで否定したものでもない。

## チェーン比較

Stabilityが提示したapi.stability.ai証明書は2026-08-01から2026-10-30まで有効。
提示チェーンのISRG Root X2は2026-05-13から2032-09-02まで有効。
Windows標準TLSはこの有効なチェーンで成功した。

Pythonの検証時チェーンは同じ位置で、2020-09-04から2025-09-15 16:00 UTCまでの
古いISRG Root X2を選んだ。サーバー提示チェーンと検証時チェーンの公開証明書情報を比較した。
検証エラーコード10は [OpenSSL公式資料](https://docs.openssl.org/1.0.2/man1/verify/)
のX509_V_ERR_CERT_HAS_EXPIRED（有効期限切れ）に対応する。

## 対処候補と検証範囲

Windowsでは信頼済みROOTストアからサーバー認証用ルートだけをロードした
SSLContextを利用する修正候補がある。今回この構成でStabilityへのTLS接続成功を確認した。
CERT_REQUIREDとcheck_hostname=Trueを維持しており、検証無効化による回避ではない。
実装する場合はWindows以外の既定処理、独自CA/企業ネットワークへの対応、両providerの
通信テストを含めて扱う。別案はWindows標準の証明書検証を利用するHTTP/TLS構成への変更。

今回の依頼は調査のため、本番transport.pyへの変更は行っていない。
OSの証明書削除、検証の無効化、キーの変更は行っていない。
調査スクリプトは `.local/asset_generator/` に保存した。

前回POSTの詳細例外は保存されておらず、その送信・課金成否を今回のHEADだけで
遡って断定することはできない。生成の再試行は行わず、元の試行履歴を保持している。
