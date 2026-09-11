Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 1600,1000
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#0b111a'))
function Box($x,$y,$w,$h,$color) {
 $b = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($color))
 $g.FillRectangle($b,$x,$y,$w,$h)
 $b.Dispose()
}
function Txt($x,$y,$text,$size=18,$color='#e4edf5') {
 $f = New-Object System.Drawing.Font 'Yu Gothic',$size
 $b = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($color))
 $g.DrawString($text,$f,$b,$x,$y)
 $f.Dispose(); $b.Dispose()
}
Txt 28 20 'CHAMBER CLASH / 準備画面の設計イメージ' 28
Txt 28 72 '報酬を選ぶ → 配置を考える → 次のラウンドへ。タブ移動なしで完結。' 17 '#91a7bc'
Box 24 132 1120 800 '#101925'
Txt 48 154 'ROUND PREPARATION' 14 '#69d9c2'
Txt 48 184 'P1  次のラウンドに備える' 24
Txt 48 228 '成長 4    SCORE  2 : 1    時間制限なし' 14 '#91a7bc'
Box 48 264 248 540 '#182534'
Box 312 264 504 540 '#182534'
Box 832 264 288 302 '#182534'
Box 832 582 288 222 '#182534'
Txt 64 280 '01  報酬を選ぶ' 19
Txt 64 320 '残り 1 回 / 取得後は控えへ' 12 '#69d9c2'
foreach ($r in @(@('クイックギア','装填時間を短縮',360),@('ライフアンプ','最大HPを増やす',474),@('スターターセル','満タンの初射を強化',588))) {
 Box 64 $r[2] 216 96 '#223648'
 Txt 76 ($r[2]+10) $r[0] 17
 Txt 76 ($r[2]+46) $r[1] 12 '#91a7bc'
}
Txt 332 280 '02  装備を配置' 19
Txt 332 320 'グリッド 7 / 16 マス' 13 '#69d9c2'
for ($y=0;$y -lt 4;$y++) { for($x=0;$x -lt 4;$x++) { Box (364+$x*94) (366+$y*94) 88 88 '#2b4053' } }
Box 364 366 88 88 '#30758a'; Box 458 366 88 88 '#30758a'
Box 552 366 88 88 '#38665b'
Box 646 366 88 88 '#38665b'; Box 646 460 88 88 '#38665b'
Txt 369 391 '跳弾' 19; Txt 557 391 'ギア' 19; Txt 651 391 'HP' 19
Txt 332 758 '武器もレリックも、ここへドラッグ。' 14 '#91a7bc'
Txt 848 280 '03  控え' 19
Txt 848 318 '所持 5 / 8 個' 13 '#91a7bc'
Box 848 354 256 62 '#223648'; Txt 860 367 'ガードベル  /  1マス' 15
Box 848 426 256 62 '#223648'; Txt 860 439 'フェザー  /  1マス' 15
Txt 848 514 'ここへドロップで装備解除' 13 '#69d9c2'
Txt 848 598 'アイテム詳細' 18
Txt 848 641 'クイックギア' 18 '#69d9c2'
Txt 848 682 '効果：装填時間 -35%' 14
Txt 848 718 'マス数：1 / 配置して発動' 13 '#91a7bc'
Box 48 824 1072 84 '#203243'
Txt 66 842 'HP 10    パルス 2    携行武器 1丁' 17
Txt 66 876 '装備順はグリッドの左上から。' 12 '#91a7bc'
Box 824 838 280 56 '#69d9c2'; Txt 856 849 '準備完了・対戦開始' 19 '#101925'
Txt 1180 158 'UIの説明' 25
$notes = @(
 @('01 / 報酬','候補を比較して取得。','取得した品は右の控えへ。',254),
 @('02 / 装備グリッド','中央が主役。1マス88px。','最大4×4でも縮小しない。',382),
 @('03 / 控え・詳細','所持品からドラッグで配置。','選んだ品の説明を常設。',510),
 @('04 / 出撃情報','HP・携行武器・残り報酬を確認。','準備完了は右下に固定。',638)
)
foreach($n in $notes) { Txt 1180 $n[3] $n[0] 20 '#69d9c2'; Txt 1180 ($n[3]+42) $n[1] 15; Txt 1180 ($n[3]+72) $n[2] 15 '#91a7bc' }
Txt 1180 824 '準備中は戦闘HUDを覆う。' 15
Txt 1180 858 '注釈は設計資料のみ。' 15 '#91a7bc'
Txt 1180 892 '数値・品名は表示例です。' 14 '#91a7bc'
$bmp.Save('C:/GameCreate/chamber-clash/docs/design/preparation-ui-concept.png')
$g.Dispose()
$bmp.Dispose()
