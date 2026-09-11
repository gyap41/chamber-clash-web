Add-Type -AssemblyName System.Drawing
$bmp=[System.Drawing.Bitmap]::new(1600,1050)
$g=[System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode='AntiAlias'
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#0b111a'))
function Text($x,$y,$t,$s=16,$c='#e8f0f7') {
 $f=[System.Drawing.Font]::new('Yu Gothic',$s)
 $b=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($c))
 $g.DrawString($t,$f,$b,$x,$y)
 $f.Dispose(); $b.Dispose()
}
Text 28 20 'B案 / 寸法を検証した実装レイアウト' 28
Text 28 76 '左はGodotの実描画（1120×800）。右の注釈は設計資料専用です。' 17 '#9cb1c4'
$source=[System.Drawing.Image]::FromFile((Join-Path $PSScriptRoot 'preparation-b-preview.png'))
$g.DrawImageUnscaled($source,24,132)
$source.Dispose()
function Note($y,$title,$line1,$line2,$line3) {
 Text 1180 $y $title 19 '#83deca'
 Text 1180 ($y+38) $line1 14
 Text 1180 ($y+66) $line2 14 '#afc1d0'
 Text 1180 ($y+94) $line3 14 '#afc1d0'
}
Note 146 '① グリッドを固定' '88pxのマス + 6pxの間隔。' '最大370×370px。' '成長しても左上の位置は不変。'
Note 296 '② 詳細は独立した領域' '名前は2行。説明は縦スクロール。' '配置先との重なりを検査済み。' 'クリック選択中は別の品に変えない。'
Note 446 '③ 報酬は右に集約' '幅352px。取得ボタンを分離。' '長文は省略、全文は詳細で確認。' '候補が増えても他の領域は動かない。'
Note 596 '④ 控えと解除枠を近づける' '幅704px。控え8個は横スクロール。' '解除枠はスクロールの外に固定。' '破棄は詳細欄の別ボタンに分離。'
Note 746 '⑤ 出撃操作は下端固定' '出撃ボタンは280×56px。' '取得可能な報酬が残る間は無効。' '武器0丁なら「近接のみ」を明記。'
Text 28 966 '緑枠：配置可能  /  橙枠＋理由：配置不可  /  クリック配置とドラッグの両方に対応' 17 '#83deca'
Text 28 1004 '1120×600ウィンドウでは比率を維持して縮小。スクロール・長文・最大所持・GUI入力を自動検証。' 15 '#9cb1c4'
$bmp.Save((Join-Path $PSScriptRoot 'preparation-b-reviewed.png'))
$g.Dispose(); $bmp.Dispose()
