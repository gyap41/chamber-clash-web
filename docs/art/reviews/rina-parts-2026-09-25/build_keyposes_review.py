"""Package unmodified full-body poses; preserve common scale and cell coordinates."""
import base64
from pathlib import Path

p = Path(__file__).resolve().parent
html = '''<!doctype html><html lang="ja"><meta charset="utf-8"><title>リナ・全身走行ポーズのレビュー</title>
<style>body{background:#19262e;color:#e7eded;font:16px system-ui;margin:24px}main{max-width:1040px;margin:auto}p{line-height:1.8}canvas{width:100%;background:#293d46;border-radius:12px}button,select{padding:10px;margin:5px;background:#48616b;color:white;border:0;border-radius:5px;font:inherit}.issue{color:#ffd08a}</style>
<main><h1>リナ・全身走行ポーズのレビュー</h1><p class="issue">生成素材の検証用・未採用。沈み込みはあるものの、左右の脚の入替が弱く、完成した走行周期にはなっていません。</p>
<button id="play">一時停止</button><button id="step">1コマ進める</button><button id="flip">左右反転</button><label>再生速度 <select id="speed"><option value="1">通常（周期0.64秒）</option><option value="0.5">半速</option><option value="0.25">1/4速</option></select></label>
<canvas width="1040" height="680"></canvas><p>上段：原画の8姿勢。下段：連続再生の拡大表示と約56px表示。<br>全コマ共通倍率・等分セルの同一原点を使用。コマごとの拡縮・足元合わせ・追加の上下揺れは行っていません。生成時の位置ずれもそのまま見えます。</p>
<p>レビュー：体重を受ける姿勢の変化は前のパーツ試作より明瞭。一方、近側の足が前へ出る形が両半周期に残り、蹴り出しから逆足の接地までが不十分。頭・銃の形状差も残ります。本編への組込みは保留です。</p><a style="color:#ddc39a" href="reference-motion.html">前のパーツ方式と比較</a></main>
<script>const im=new Image();im.src='DATA';const ctx=document.querySelector('canvas').getContext('2d');let playing=true,phase=0,flip=false,last=0,ready=false;
function sprite(n,x,y,s){const w=im.width/4,h=im.height/2;ctx.save();ctx.translate(x,y);if(flip)ctx.scale(-1,1);ctx.drawImage(im,(n%4)*w,Math.floor(n/4)*h,w,h,-w*s/2,-h*s,w*s,h*s);ctx.restore()}
function draw(){ctx.clearRect(0,0,1040,680);ctx.textAlign='center';ctx.font='14px system-ui';let n=Math.floor(phase)%8;for(let i=0;i<8;i++){let x=135+(i%4)*255,y=190+Math.floor(i/4)*205;ctx.fillStyle=i===n?'#597581':'#314953';ctx.fillRect(x-110,y-181,220,201);sprite(i,x,y,0.40);ctx.fillStyle='#e7eded';ctx.fillText('姿勢 '+(i+1),x,y+17)}sprite(n,400,650,0.50);sprite(n,755,610,56/420);ctx.fillStyle='#e7eded';ctx.fillText('連続再生 '+(n+1)+'/8',400,671);ctx.fillText('約56px',755,635)}
function tick(t){if(last&&playing)phase=(phase+Math.min(t-last,100)*Number(document.querySelector('#speed').value)/80)%8;last=t;if(ready)draw();requestAnimationFrame(tick)}
document.querySelector('#play').onclick=e=>{playing=!playing;e.target.textContent=playing?'一時停止':'再生'};document.querySelector('#step').onclick=()=>{playing=false;phase=(Math.floor(phase)+1)%8;document.querySelector('#play').textContent='再生'};document.querySelector('#flip').onclick=()=>flip=!flip;im.onload=()=>{ready=true};requestAnimationFrame(tick);</script></html>'''
for source, output in [('run-keyposes.png', 'run-keyposes-review.html'), ('run-keyposes-fix.png', 'run-keyposes-fix-review.html')]:
    other = 'run-keyposes-fix-review.html' if source == 'run-keyposes.png' else 'run-keyposes-review.html'
    label = '修正生成版を比較' if source == 'run-keyposes.png' else '初回生成版を比較'
    page = html.replace('</main>', f'<p><a style="color:#ddc39a" href="{other}">{label}</a></p></main>')
    (p / output).write_text(page.replace('DATA', 'data:image/png;base64,' + base64.b64encode((p / source).read_bytes()).decode()), encoding='utf-8')
