const $=id=>document.getElementById(id);
let ms=0,target=0,last=null,paused=false,effectClock=0;
const effectContext=$('effects').getContext('2d');
$('reduce').checked=matchMedia('(prefers-reduced-motion: reduce)').matches;
new ResizeObserver(()=>{$('stage').style.transform=`scale($('viewport').clientWidth/1120)`}).observe($('viewport'));
function paint(now){
 const reduced=$('reduce').checked,p=WorkshopMotion.pose(ms,reduced);
 $('case').style.transform=`scale(${p.scale})`;
 $('doorL').style.transform=`rotateY(${-p.angle}deg)`;
 $('doorR').style.transform=`rotateY(${p.angle}deg)`;
 const lidOpacity=reduced?1-p.lid:1;
 $('doorL').style.opacity=lidOpacity;$('doorR').style.opacity=lidOpacity;
 $('catchL').style.transform=`translateX(${-p.latch*24}px)`;
 $('catchR').style.transform=`translateX(${p.latch*24}px)`;
 $('catchL').style.opacity=1-p.lid;$('catchR').style.opacity=1-p.lid;
 $('content').style.opacity=p.content;
 WorkshopEffects.draw(effectContext,ms,paused?ms:effectClock,{reduced,closing:!paused&&target===0});
 const pulse=p.settled&&!reduced&&!paused?.9+.1*Math.sin(now/1100):1;
 $('gem').style.filter=`grayscale(${1-p.corePower}) brightness(${.25+p.corePower*.75*pulse})`;
 $('core').style.boxShadow=`0 4px 0 #443d2c,0 0 ${p.corePower*18}px rgba(90,230,194,${p.corePower*.35})`;
 document.querySelectorAll('.wire').forEach(w=>{w.style.strokeDashoffset=950*(1-p.power);w.style.opacity=p.power*.75});
 $('sample').disabled=!p.ready;$('sample').style.opacity=p.content;$('sample').style.pointerEvents=p.ready?'auto':'none';
 $('scrub').value=Math.round(ms);$('time').textContent=Math.round(ms)+' ms';
 $('status').textContent=p.stage+(p.ready?' ／ 操作可能':'');
 $('hint').textContent=p.closed?'閉じた携帯工房 ／ 開くボタンで展開':p.ready?'起動の余韻中も操作できます ／ Escで閉じる':'留め具 → 蓋の展開 → 起動';
}
function go(value){target=value;paused=false;$('toggle').textContent=value===700?'閉じる':'開く'}
function tick(now){const dt=last===null?0:now-last;last=now;if(!paused&&!document.hidden)effectClock+=Math.min(dt,50)/($('slow').checked?4:1);if(!paused&&ms!==target)ms=WorkshopMotion.advance(ms,target,dt,{slow:$('slow').checked,reduced:$('reduce').checked});paint(now);requestAnimationFrame(tick)}
$('toggle').onclick=()=>go(target===700?0:700);
$('replay').onclick=()=>{ms=0;effectClock=0;go(700)};
$('scrub').oninput=()=>{ms=Number($('scrub').value);paused=true;$('toggle').textContent='ここから開く';target=0;paint(0)};
$('sample').onclick=()=>{$('sample').textContent='操作を受け付けました（確認用）'};
addEventListener('keydown',e=>{if(e.code==='Escape')go(0)});
requestAnimationFrame(tick);
