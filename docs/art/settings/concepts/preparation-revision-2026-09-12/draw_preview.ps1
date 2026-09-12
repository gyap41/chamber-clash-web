Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap(1120,800)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#101922'))
function Box($x,$y,$w,$h,$fill,$border='#344551') {
 $b=New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($fill))
 $p=New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml($border),1)
 $g.FillRectangle($b,$x,$y,$w,$h); $g.DrawRectangle($p,$x,$y,$w,$h); $b.Dispose();$p.Dispose()
}
function Txt($x,$y,$s,$size=16,$color='#e8e6de') {
 $f=New-Object System.Drawing.Font('Yu Gothic UI',$size,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
 $b=New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($color))
 $g.DrawString([string]$s,$f,$b,[single]$x,[single]$y);$f.Dispose();$b.Dispose()
}
function Btn($x,$y,$w,$h,$s,$primary=$false) {
 Box $x $y $w $h $(if($primary){'#71cbb9'}else{'#263944'}) '#52736f'
 Txt ($x+10) ($y+8) $s 15 $(if($primary){'#102b2a'}else{'#e8e6de'})
}
function Shape($x,$y,$cells,$color='#91c9ca',$unit=8) {
 foreach($cell in $cells){Box ($x+$cell[0]*($unit+2)) ($y+$cell[1]*($unit+2)) $unit $unit $color $color}
}
$horizontal=@(@(0,0),@(1,0));$vertical=@(@(0,0),@(0,1));$single=@(@(0,0))
Txt 24 14 '携帯工房  /  ラウンド準備' 26
Txt 25 54 '準備 3    ・    SCORE 1 : 1    ・    5本先取' 16 '#9baeb6'
Txt 818 22 '所持金' 16 '#a5b5bd';Txt 882 15 '12 G' 30 '#eed096'
Btn 1002 24 94 38 '音 OFF'
Box 24 104 380 490 '#1c2a33'
Box 420 104 280 490 '#1c2a33'
Box 716 104 380 490 '#1c2a33'
Txt 42 120 '装備するもの' 21
Txt 257 124 '使用 6 / 12マス' 15 '#8ed7c5'
Txt 44 153 'ここに配置した装備で出撃します' 13 '#a6b7bd'
for($row=0;$row -lt 6;$row++){for($col=0;$col -lt 6;$col++){
 $open=($row -lt 3 -and $col -lt 4)
 Box (44+$col*54) (181+$row*54) 50 50 $(if($open){'#2e4651'}else{'#17232b'}) $(if($open){'#58747e'}else{'#2a3842'})
 if(-not $open){Txt (62+$col*54) (193+$row*54) '×' 18 '#40515a'}
}}
Box 46 183 100 46 '#3f6668' '#91c9ca';Txt 54 196 '標準ピストル' 13
Box 154 183 46 100 '#655d43' '#d1ba7b';Txt 165 207 'HP' 18 '#ffe3a0';Txt 169 236 '+1' 15 '#ffe3a0'
Box 46 291 100 46 '#365660' '#91c9ca';Txt 55 305 'フェザー' 17
Txt 45 513 '未開放マスは「拡張」で追加できます' 13 '#9baeb6'
Btn 44 540 144 36 'バッグを拡張'
Txt 206 547 '今回 未購入 / 上限24' 13 '#b9b5a7'
Txt 438 120 'アイテム詳細' 19
Box 439 158 242 28 '#294740' '#44635b';Txt 449 162 'ショップの商品を確認中' 13 '#92dbc5'
Txt 440 201 'クイックギア' 23
Txt 440 240 'レリック  /  2マス  /  4G' 15 '#b6c5cc'
Txt 440 284 '装填時間を12%短縮' 20 '#92dbc5'
Txt 440 322 '同種を複数装備できます。' 16
Txt 440 354 '装備中 0個' 15 '#a6b7bd'
Txt 440 383 '装填倍率  1.10 → 0.97' 16 '#eed096'
Shape 443 432 $horizontal '#91c9ca' 22
Txt 504 439 '横2マス' 15 '#a6b7bd'
Btn 440 488 240 40 '購入して控えへ  4G' $true
Txt 440 544 '購入だけでは装備されません' 14 '#b9b5a7'
Txt 734 120 'ショップ' 21
Btn 924 116 152 36 '商品更新  2G'
Txt 735 155 '購入は任意  /  更新は今回あと1回' 13 '#a6b7bd'
$products=@(
 @('P-12 サイドアーム','16発弾倉 / 継続射撃','3G',2),
 @('跳弾キャンディ','壁で2回反射','5G',2),
 @('クイックギア','装填時間 -12%','4G',2),
 @('フェザー','移動速度 +6%','4G',2),
 @('ライフアンプ','最大HP +1','4G',2)
)
for($i=0;$i -lt 5;$i++){
 $y=181+$i*79;$selected=$i -eq 2
 Box 734 $y 344 70 $(if($selected){'#2b4547'}else{'#243540'}) $(if($selected){'#8cdbca'}else{'#344551'})
 if($i -eq 4){Shape 745 ($y+13) $vertical '#a7c9cd' 9}else{Shape 745 ($y+13) $horizontal '#a7c9cd' 9}
 Txt 779 ($y+7) $products[$i][0] 17
 Txt 745 ($y+37) $products[$i][1] 14 '#b6c5cc'
 Btn 989 ($y+27) 78 34 ($products[$i][2]+' 購入') $true
}
Box 24 610 1072 96 '#1c2a33'
Txt 41 620 '控え 5 / 8' 18
Txt 183 623 '未装備  ・  クリックで詳細 / ドラッグで配置' 14 '#a6b7bd'
Txt 777 623 '装備をこの欄へ戻すと解除' 14 '#8ed7c5'
$reserves=@('ルーンペン','予備マガジン','ミニフェザー','パワーチップ','クールグリップ','','','')
for($i=0;$i -lt 8;$i++){
 $x=41+$i*130;Box $x 650 123 43 '#233741'
 Txt ($x+6) 654 ($i+1) 11 '#718991'
 if($reserves[$i]){Txt ($x+8) 670 $reserves[$i] 13}else{Txt ($x+47) 662 '空き' 13 '#718991'}
}
Box 24 722 1072 58 '#263b40' '#52736f'
Txt 42 730 'HP 9 / 9     パルス 3     携行武器 1丁' 18
Txt 42 758 '出撃装備：サービスピストル  /  ライフアンプ  /  フェザー' 13 '#bacacb'
Btn 824 731 254 40 'この装備で出撃する' $true
$bmp.Save((Join-Path $PSScriptRoot '01_preparation_preview.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose();$bmp.Dispose()
