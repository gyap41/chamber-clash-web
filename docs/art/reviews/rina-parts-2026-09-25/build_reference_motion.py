"""Build reference-informed movement lab reusing the fixed side-view artwork."""
from pathlib import Path
import base64
p=Path(__file__).resolve().parent
s=(p/'run-review.template.html').read_text(encoding='utf-8')
s=s.replace('リナ・アクション走行試作','リナ・参考動画モーション').replace('RINA / ACTION RUN STUDY','RINA / AIM + MOVEMENT').replace('構えを保って、軽快に走る。','移動と照準を、別々に動かす。')
s=s.replace('同じ頭・胴体を使い、短い脚の接地と蹴り出し、胴体の上下動、頭と布の遅れを組み合わせた側面試作。','参考動画の横移動・後退・構え直しを基準にした試作。自動デモ、またはWASD／矢印キーで移動し、画面上のポインターで左右の構えを変えられます。')
start=s.index('<div class="controls">');end=s.index('<canvas',start)
s=s[:start]+'''<div class="controls"><button id="demo" class="active">自動デモ：ON</button><button id="pause">一時停止</button><button id="step">1/8周期進める</button><label>速度 <input id="speed" type="range" min="0.2" max="1.2" value="1" step="0.1"></label><label><input id="bob" type="checkbox" checked>上下動</label><label><input id="rig" type="checkbox">関節</label><button id="reset">中央へ戻す</button><label>確認場面 <select id="scene"><option value="0">右移動・右照準</option><option value="1">右移動・左照準</option><option value="2">下移動・左照準</option><option value="4">左移動・右照準</option><option value="5">上移動・右照準</option></select></label></div>'''+s[end:]
s=s.replace('width="1020" height="570"','width="1020" height="640" tabindex="0" aria-label="移動プレビュー。WASDまたは矢印キーで操作"')
s=s.replace('上段は拡大、下段は全高約56px。背景の流れは接地を比較するための目印です。','上段は約56pxのキャラクターが移動する確認エリア。下段は現在の姿勢を3倍で表示。青線は移動方向、金色の目印は構える方向です。')
s=s.replace('右向き素材の左右反転を含む側面試作です。前後移動・照準方向を変えた移動・射撃・回避・本編接続は未対応。','左右の側面素材で、移動と構えを独立させた試作です。正面・背面の構え、自由角度の銃口、射撃・回避、本編接続は未対応です。')
s=s.replace('running=true,paused=false,flip=false,last=0;','running=true,paused=false,flip=false,last=0;\nlet demo=true,moveX=1,moveY=0,pos={x:360,y:205},pointer={x:780,y:205},keys=new Set(),demoStage=0;')
s=s.replace('(-.25-1.45*Math.cos(4*Math.PI*ph+.8))','(-.1-.65*Math.cos(4*Math.PI*ph+.8))')
a=s.index('function foot(');b=s.index('function leg(',a)
s=s[:a]+'''function foot(ph,side,m){const p=mod(ph+side*.5),stance=.50;let travel,up;if(p<stance){travel=5-10*p/stance;up=0}else{let u=(p-stance)/(1-stance);travel=-5+10*u*u*u*(u*(u*6-15)+10);up=1.8*Math.sin(Math.PI*u)**2}const localX=moveX*(flip?-1:1);return [(travel*localX+(side?-.65:.65))*m+(side?1.8:-1.8)*(1-m),-2.5+(travel*moveY-up)*m,p<stance]}
'''+s[b:]
# Avoid the deep, rapidly changing IK fold for these tiny stylized limbs.
a=s.index('function leg(');b=s.index('function actor(',a)
leg=s[a:b]
start=leg.index(',dx=f[0]');end=leg.index(';c.save()',start)
leg=leg[:start]+",k=[hip[0]*.45+f[0]*.55+1.25,hip[1]*.45+f[1]*.55]"+leg[end:]
leg=leg.replace("f[2]?0:-.45*Math.sin(Math.PI*mod(ph+side*.5))", "f[2]?0:-.16*Math.sin(Math.PI*(mod(ph+side*.5)-.5)/.5)**2")
s=s[:a]+leg+s[b:]
s=s.replace('hip=[0,-10+b]','hip=[0,-8+b]').replace('lift(phase-.045)*.6','lift(phase-.035)*.72')
s=s.replace('c.translate(1.3*m,b);c.rotate(.035*m);','const lean=.025*moveX*(flip?-1:1)*m;c.translate(.65*moveX*(flip?-1:1)*m,b);c.rotate(lean);')
s=s.replace("Math.sin(phase*4*Math.PI-.8)*.12*m","Math.sin(phase*4*Math.PI-.8)*.09*m")
s=s.replace('-.035*m);part(\'head\'','-lean);part(\'head\'')
s=s.replace('-.02*m+Math.sin','-lean*.55+Math.sin')
a=s.index('function draw()');b=s.index('atlas.decode()',a)
s=s[:a]+'''const stages=[{x:1,y:0,aim:1,name:'右へ走る / 右へ構える'},{x:1,y:0,aim:-1,name:'右へ走る / 左へ構え直す'},{x:0,y:1,aim:-1,name:'下へ移動 / 左を維持'},{x:-1,y:0,aim:-1,name:'左へ走る / 左へ構える'},{x:-1,y:0,aim:1,name:'左へ走る / 右へ構え直す'},{x:0,y:-1,aim:1,name:'上へ移動 / 右を維持'},{x:0,y:0,aim:1,name:'停止して構えを維持'}];
function draw(){c.clearRect(0,0,1020,640);c.save();c.beginPath();c.rect(25,35,970,285);c.clip();c.strokeStyle='#49616a';c.lineWidth=.6;for(let x=25;x<1020;x+=48){c.beginPath();c.moveTo(x,35);c.lineTo(x,320);c.stroke()}for(let y=35;y<=320;y+=36){c.beginPath();c.moveTo(25,y);c.lineTo(995,y);c.stroke()}if(blend>.1){c.strokeStyle='#83bdce';c.lineWidth=2;c.beginPath();c.moveTo(pos.x,pos.y+7);c.lineTo(pos.x+moveX*25,pos.y+7+moveY*25);c.stroke()}actor(pos.x,pos.y,1);c.strokeStyle='#e7c58a';c.beginPath();let aimX=pos.x+(flip?-65:65);c.moveTo(aimX-5,pos.y-21);c.lineTo(aimX+5,pos.y-21);c.moveTo(aimX,pos.y-26);c.lineTo(aimX,pos.y-16);c.stroke();c.restore();label(demo?stages[demoStage].name:'手動：WASD移動 / ポインターで左右の構え',510,24);actor(510,568,3);label('同じ姿勢を3倍表示 / '+(flip?'左向き':'右向き'),510,355);label('足の入替 0.52秒周期 / 胴体の上下動に頭が少し遅れて追従',510,615)}
function updateDemo(){demoStage=Math.floor(time/1.9)%stages.length;let q=stages[demoStage];moveX=q.x;moveY=q.y;running=Boolean(q.x||q.y);flip=q.aim<0}
function updateInput(){let dx=Number(keys.has('d')||keys.has('ArrowRight'))-Number(keys.has('a')||keys.has('ArrowLeft')),dy=Number(keys.has('s')||keys.has('ArrowDown'))-Number(keys.has('w')||keys.has('ArrowUp')),len=Math.hypot(dx,dy);running=len>0;if(len){moveX=dx/len;moveY=dy/len}if(Math.abs(pointer.x-pos.x)>6)flip=pointer.x<pos.x}
function frame(now){let dt=Math.min(.04,(now-last)/1000||0);last=now;if(!paused){dt*=Number(document.querySelector('#speed').value);time+=dt;if(demo)updateDemo();else updateInput();blend+=(Number(running)-blend)*(1-Math.exp(-dt*18));phase+=dt/.52*blend;const speed=10/(.52*.50);pos.x=Math.max(65,Math.min(955,pos.x+moveX*speed*blend*dt));pos.y=Math.max(112,Math.min(297,pos.y+moveY*speed*blend*dt));}draw();requestAnimationFrame(frame)}
document.querySelector('#demo').onclick=e=>{demo=!demo;keys.clear();e.target.classList.toggle('active',demo);e.target.textContent='自動デモ：'+(demo?'ON':'OFF');cv.focus()};document.querySelector('#pause').onclick=e=>{paused=!paused;e.target.textContent=paused?'再生':'一時停止'};document.querySelector('#step').onclick=()=>{paused=true;document.querySelector('#pause').textContent='再生';phase+=.125;draw()};document.querySelector('#reset').onclick=()=>{pos={x:360,y:205};time=0;phase=0;keys.clear()};
cv.addEventListener('pointermove',e=>{let r=cv.getBoundingClientRect();pointer={x:(e.clientX-r.left)*1020/r.width,y:(e.clientY-r.top)*640/r.height}});cv.addEventListener('pointerdown',()=>cv.focus());
document.querySelector('#scene').onchange=e=>{demo=true;time=Number(e.target.value)*1.9+.25;pos={x:450,y:205};document.querySelector('#demo').textContent='自動デモ：ON';document.querySelector('#demo').classList.add('active');updateDemo();draw()};
window.addEventListener('keydown',e=>{if(e.target.tagName==='INPUT')return;let k=e.key.length===1?e.key.toLowerCase():e.key;if(['w','a','s','d','ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(k)){e.preventDefault();keys.add(k);demo=false;document.querySelector('#demo').textContent='自動デモ：OFF';document.querySelector('#demo').classList.remove('active')}});window.addEventListener('keyup',e=>keys.delete(e.key.length===1?e.key.toLowerCase():e.key));window.addEventListener('blur',()=>keys.clear());
''' +s[b:]
s=s.replace('走行周期0.42秒。接地中の足送りと背景速度を同期。銃の向きは保ち、頭の上下動は胴体より抑制。','参考動画8.5〜9.5秒付近を動作設計の参考に使用。周期や揺れ幅はリナ用の調整値で、動画の厳密な計測値ではありません。')
(p/'reference-motion.template.html').write_text(s,encoding='utf-8')
s=s.replace('__ATLAS__','data:image/png;base64,'+base64.b64encode((p/'run-parts-key.png').read_bytes()).decode())
(p/'reference-motion.html').write_text(s,encoding='utf-8')
print('Built reference-motion.html')
