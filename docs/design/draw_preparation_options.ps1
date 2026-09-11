Add-Type -AssemblyName System.Drawing
$script:out = Join-Path $PSScriptRoot 'preparation-options'
New-Item -ItemType Directory -Force $script:out | Out-Null
function Rect($x,$y,$w,$h,$c) {
 $b=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($c)); $g.FillRectangle($b,$x,$y,$w,$h); $b.Dispose()
}
function Text($x,$y,$t,$s=16,$c='#e8f0f7') {
 $f=[System.Drawing.Font]::new('Yu Gothic',$s); $b=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($c))
 $g.DrawString($t,$f,$b,$x,$y); $f.Dispose(); $b.Dispose()
}
function Line($x,$y,$xx,$yy,$c='#7adcca',$w=2,$dash=$false) {
 $p=[System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml($c),$w)
 if($dash){$p.DashStyle='Dash'}
 $g.DrawLine($p,$x,$y,$xx,$yy); $p.Dispose()
}
function Border($x,$y,$w,$h,$c='#557086',$dash=$false) {
 Line $x $y ($x+$w) $y $c 2 $dash
 Line ($x+$w) $y ($x+$w) ($y+$h) $c 2 $dash
 Line $x ($y+$h) ($x+$w) ($y+$h) $c 2 $dash
 Line $x $y $x ($y+$h) $c 2 $dash
}
function Icon($x,$y,$kind,$c='#e8f0f7') {
 switch($kind) {
 'gun' { Rect $x ($y+9) 40 12 $c; Rect ($x+26) ($y+5) 9 6 $c; Rect ($x+8) ($y+21) 10 14 $c; Rect ($x+40) ($y+12) 7 6 $c }
 'prism' { Line ($x+23) $y ($x+44) ($y+20) $c 3; Line ($x+44) ($y+20) ($x+23) ($y+40) $c 3; Line ($x+23) ($y+40) ($x+2) ($y+20) $c 3; Line ($x+2) ($y+20) ($x+23) $y $c 3 }
 'hp' { Rect ($x+17) ($y+1) 13 40 $c; Rect ($x+3) ($y+15) 41 13 $c }
 'feather' { Line ($x+8) ($y+35) ($x+35) ($y+5) $c 3; foreach($i in @(0,1,2)){ Line ($x+14+$i*7) ($y+28-$i*7) ($x+10+$i*7) ($y+14-$i*7) $c 3; Line ($x+14+$i*7) ($y+28-$i*7) ($x+29+$i*7) ($y+26-$i*7) $c 3 } }
 'bell' { $p=[System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml($c),3); $g.DrawArc($p,$x+10,$y+6,26,32,180,180); $p.Dispose(); Line ($x+10) ($y+22) ($x+6) ($y+35) $c 3; Line ($x+36) ($y+22) ($x+40) ($y+35) $c 3; Line ($x+6) ($y+35) ($x+40) ($y+35) $c 3; Rect ($x+20) ($y+39) 7 4 $c }
 'gear' { $p=[System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml($c),6); $g.DrawEllipse($p,$x+10,$y+8,27,27); $p.Dispose(); foreach($a in @(0,90,180,270)){ $r=$a*[Math]::PI/180; Line ($x+23+12*[Math]::Cos($r)) ($y+21+12*[Math]::Sin($r)) ($x+23+22*[Math]::Cos($r)) ($y+21+22*[Math]::Sin($r)) $c 5 } }
 }
}
function Grid($x,$y,$cell=88,$ghost=$false) {
 $step=$cell+6
 for($r=0;$r -lt 4;$r++){ for($c=0;$c -lt 4;$c++){ Rect ($x+$c*$step) ($y+$r*$step) $cell $cell '#233749'; Border ($x+$c*$step) ($y+$r*$step) $cell $cell '#355068' } }
 # Same build in every proposal: a 2-cell gun, L-shaped prism, vertical HP relic.
 $parts=@(@(0,0,'#286b88'),@(1,0,'#286b88'),@(2,0,'#4a558b'),@(3,0,'#4a558b'),@(2,1,'#4a558b'),@(0,2,'#346d5e'),@(0,3,'#346d5e'))
 foreach($p in $parts){ Rect ($x+$p[0]*$step) ($y+$p[1]*$step) $cell $cell $p[2] }
 # Connect occupied cells belonging to a single item, preserving an obvious footprint.
 Rect ($x+$cell) $y 6 $cell '#286b88'
 Rect ($x+2*$step+$cell) $y 6 $cell '#4a558b'
 Rect ($x+2*$step) ($y+$cell) $cell 6 '#4a558b'
 Rect $x ($y+2*$step+$cell) $cell 6 '#346d5e'
 Icon ($x+18) ($y+12) 'gun'; Text ($x+9) ($y+59) '跳弾' 14
 Icon ($x+2*$step+18) ($y+12) 'prism'; Text ($x+2*$step+9) ($y+59) 'プリズム' 12
 Icon ($x+18) ($y+2*$step+12) 'hp'; Text ($x+9) ($y+2*$step+59) 'HP +2' 13
 if($ghost){ Border ($x+3*$step) ($y+3*$step) $cell $cell '#8ff4bf' $true; Icon ($x+3*$step+18) ($y+3*$step+16) 'feather' '#8ff4bf' }
}
function Reward($x,$y,$w,$name,$effect,$kind,$compact=$false) {
 Rect $x $y $w 112 '#223648'
 Icon ($x+12) ($y+12) $kind '#83deca'
 Text ($x+66) ($y+10) $name 16
 Text ($x+66) ($y+42) $effect 12 '#afc1d0'
 Rect ($x+$w-90) ($y+78) 76 25 '#406d64'; Text ($x+$w-78) ($y+79) '取得' 12
 Text ($x+12) ($y+81) '1マス' 11 '#afc1d0'
}
function Header($caption,$sub) {
 $script:bmp=[System.Drawing.Bitmap]::new(1600,1040); $script:g=[System.Drawing.Graphics]::FromImage($bmp)
 $g.SmoothingMode='AntiAlias'; $g.Clear([System.Drawing.ColorTranslator]::FromHtml('#0b111a'))
 Text 28 18 $caption 28; Text 28 74 $sub 16 '#9cb1c4'
 Rect 24 144 1120 800 '#101925'
 Text 48 166 'P1  ラウンド準備' 25
 Text 48 212 '成長 4    SCORE 2 : 1    時間制限なし' 14 '#9cb1c4'
 Text 1180 166 '見やすさの設計' 24
}
function Note($y,$heading,$a,$b) {
 Text 1180 $y $heading 19 '#83deca'; Text 1180 ($y+42) $a 14; Text 1180 ($y+72) $b 14 '#9cb1c4'
}
function Foot($cta='報酬をあと1個選ぶ') {
 Rect 48 862 1072 58 '#203243'; Text 66 876 'HP 10    パルス 2    携行 1丁    報酬残り 1回' 16
 Rect 822 870 280 42 '#314254'; Text 836 878 $cta 15 '#afc1d0'
}
function Save($name){$bmp.Save((Join-Path $script:out $name));$g.Dispose();$bmp.Dispose()}
Header 'A / 一覧型 ── 比較しながら組む' '報酬・装備・控えを常設。操作に慣れたプレイヤーが、全体を一度に見渡せる。'
Rect 48 256 248 586 '#182534'; Rect 312 256 504 586 '#182534'; Rect 832 256 288 318 '#182534'; Rect 832 590 288 252 '#182534'
Text 64 274 '01 報酬を選ぶ' 20; Text 64 311 '残り1回 / 取得後は控えへ' 12 '#83deca'
Reward 64 352 216 'ギア' '装填 -35%' 'gear'
Reward 64 476 216 'スターター' '初射 +20%' 'prism'
Reward 64 600 216 'パリィ' '弾消しで回避補助' 'gear'
Text 332 274 '02 装備を配置' 20; Text 332 316 '7 / 16 マス    武器1丁・レリック2個' 13 '#83deca'
Grid 376 362
Text 332 778 '同じ色でつながる部分 = 1つの装備' 14 '#afc1d0'
Text 848 274 '03 控え' 20; Text 848 313 '所持 5 / 8 個' 12 '#9cb1c4'
Rect 848 352 256 70 '#223648'; Icon 860 365 'feather'; Text 918 372 'フェザー' 16
Rect 848 436 256 70 '#223648'; Icon 860 449 'bell'; Text 918 456 'ガードベル' 16
Border 848 524 256 34 '#83deca' $true; Text 862 529 'ドロップで控えへ戻す' 13 '#83deca'
Text 848 610 'アイテム詳細' 18
Icon 848 657 'feather'; Text 908 662 'フェザー' 18 '#83deca'
Text 848 716 '移動速度 +12%' 17
Text 848 758 '1マス / 配置すると発動' 13 '#afc1d0'
Foot
Note 258 '全体を同時に比較' '報酬と空きマスを見比べる。' 'タブ移動は不要。'
Note 390 '形 + アイコン + 名前' '色だけに意味を依存させない。' '同じ装備の占有マスをつなぐ。'
Note 522 '常設のアイテム詳細' 'ホバーかクリックで説明更新。' '長文は専用欄に集約する。'
Note 654 '注意する点' '情報量は3案で最も多い。' '各欄の視線移動も多め。'
Text 1180 840 '向いている人：比較・最適化重視' 13 '#83deca'
Save 'A-overview.png'
Header 'B / 配置中心型 ── 見て、つかんで、置く' 'おすすめ。大きなバックパックと手元の控えを近づけ、配置の操作を視覚で伝える。'
Rect 48 256 704 482 '#182534'; Rect 772 256 348 586 '#182534'
Text 68 272 'バックパック' 22; Text 360 281 '7 / 16 マス' 15 '#83deca'
Grid 96 330 88 $true
Text 518 346 '選択中' 13 '#9cb1c4'; Icon 532 394 'feather' '#83deca'
Text 518 452 'フェザー' 19 '#83deca'; Text 518 495 '移動 +12%' 17
Text 518 534 '1マス' 14 '#afc1d0'
Rect 512 583 210 78 '#24443e'; Text 526 596 'ここに置けます' 16 '#8ff4bf'; Text 526 628 '緑の枠を確認して離す' 12 '#afc1d0'
Text 68 710 'ドラッグ中：置ける位置だけ緑の枠で表示' 13 '#afc1d0'
Text 792 272 '報酬を選ぶ' 22; Text 792 316 '残り1回 / 取得 → 下の控えへ' 14 '#83deca'
Reward 792 362 308 'クイックギア' '装填時間 -35%' 'gear'
Reward 792 488 308 'スターターセル' '満タンの初射 +20%' 'prism'
Reward 792 614 308 'パリィ' '弾消しで回避補助' 'gear'
Text 792 774 '取得後は、下の控えから配置。' 13 '#afc1d0'
Rect 48 756 704 86 '#1f303e'; Text 64 770 '控え' 18; Text 64 806 '5 / 8 個 所持' 11 '#9cb1c4'
Rect 200 766 164 64 '#2d5148'; Icon 210 776 'feather' '#83deca'; Text 262 784 'フェザー' 13 '#83deca'
Rect 374 766 174 64 '#223648'; Icon 384 776 'bell'; Text 436 784 'ガードベル' 13
Border 566 767 166 62 '#83deca' $true; Text 580 781 'ここへ戻す' 14 '#83deca'; Text 580 807 '装備解除' 11 '#afc1d0'
Line 282 762 422 718 '#83deca' 2 $true
Foot
Note 258 '配置が画面の主役' '中央に大きなグリッド。' '武器やレリックの形が見える。'
Note 390 '手元から上へ置く' '控えはグリッドのすぐ下。' '移動距離が短く、関係も明快。'
Note 522 '結果を置く前に見せる' '緑の枠 = 配置できる場所。' '置けない時は理由も表示。'
Note 654 '注意する点' 'ドラッグ中の表示が実装の要。' '多数の控えは横スクロール。'
Text 1180 840 'おすすめ：配置する楽しさ重視' 14 '#83deca'
Text 1180 885 'この画像はドラッグ中の例。' 13 '#9cb1c4'
Save 'B-backpack.png'
Header 'C / 手順型 ── 一度に一つだけ考える' 'はじめてでも迷いにくい。報酬 → 配置 → 確認を分け、現在の操作を大きく見せる。'
Rect 48 254 1072 64 '#182534'
Text 80 270 '01  報酬を選ぶ' 19 '#9cb1c4'
Text 404 270 '02  装備を配置' 20 '#83deca'; Rect 400 309 254 3 '#83deca'
Text 782 270 '03  確認して出撃' 19 '#9cb1c4'
Rect 48 336 680 506 '#182534'; Rect 748 336 372 506 '#182534'
Text 68 354 '控えからグリッドへドラッグ' 22
Text 68 396 '7 / 16 マス    武器1丁・レリック2個' 14 '#83deca'
Grid 190 444
Text 768 356 '配置するアイテム' 20
Rect 768 410 332 94 '#2d5148'; Icon 786 430 'feather' '#83deca'; Text 844 423 'フェザー' 18; Text 844 461 '移動 +12% / 1マス' 14 '#afc1d0'
Rect 768 518 332 94 '#223648'; Icon 786 538 'bell'; Text 844 531 'ガードベル' 18; Text 844 569 '攻撃を1回防ぐ / 1マス' 14 '#afc1d0'
Text 768 658 '使わない品は控えのままでOK。' 15
Text 768 700 '武器が0丁なら近接のみ。' 15 '#afc1d0'
Border 768 762 332 54 '#83deca' $true; Text 790 776 'ここへドロップで装備解除' 15 '#83deca'
Rect 48 862 1072 58 '#203243'; Text 68 878 '← 報酬へ戻る' 16 '#afc1d0'
Text 344 878 'HP 10 / パルス 2 / 携行 1丁' 16
Rect 822 870 280 42 '#83deca'; Text 852 876 '装備を確認する →' 17 '#101925'
Note 258 '今やることを一つに' '配置中は報酬候補を隠す。' '画面内の情報を減らす。'
Note 390 '現在地が分かる' '上の3ステップを常に表示。' '前の操作にも戻れる。'
Note 522 '最後に出撃内容を確認' '武器・HP・効果を一覧に。' '丸腰の見落としも減らせる。'
Note 654 '注意する点' '報酬との比較に画面往復が必要。' '慣れると操作回数が多く感じる。'
Text 1180 840 '向いている人：初回の分かりやすさ重視' 12 '#83deca'
Text 1180 885 '画像は「02 配置」の表示例。' 13 '#9cb1c4'
Save 'C-guided.png'
