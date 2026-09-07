const projectileSprite=new Image();projectileSprite.src='assets/projectile-sprites.png';
// Tight source rectangles preserve the alpha artwork; anchors sit in the solid projectile, not its trail.
const projectileFrames=[
 [[88,53,277,141],[492,70,330,124],[921,92,334,102],[1385,71,307,121]],
 [[101,273,254,142],[537,271,263,148],[980,277,262,145],[1412,276,253,142]],
 [[123,496,213,133],[539,492,224,138],[973,491,222,142],[1406,491,228,143]],
 [[84,693,285,132],[527,677,284,155],[970,692,286,133],[1420,693,276,132]]
];
function projectileRow(b){return b.shard?-1:b.gun===16?0:b.gun===17&&b.parcel?1:b.gun===18?2:b.gun===19?3:-1}
function drawProjectileSprite(b){
 const row=projectileRow(b);if(row<0||!projectileSprite.complete||!projectileSprite.naturalWidth)return false;
 const frame=Math.floor(b.age*12)%4,[sx,sy,sw,sh]=projectileFrames[row][frame],width=[30,32,23,28][row],height=width*sh/sw,anchor=[.76,.63,.75,.75][row];
 ctx.save();ctx.translate(b.x,b.y);ctx.rotate(Math.atan2(b.vy,b.vx));ctx.drawImage(projectileSprite,sx,sy,sw,sh,-width*anchor,-height/2,width,height);ctx.restore();return true;
}
// Four columns are successive frames; rows match the four new weapon concepts.
function drawWeaponEffects(){
 if(!effectSprite.complete||!effectSprite.naturalWidth)return;
 const cw=effectSprite.naturalWidth/4,ch=effectSprite.naturalHeight/4;
 for(const e of weaponEffects){const progress=e.age/e.duration,frame=Math.min(3,Math.floor(progress*4)),height=e.size*ch/cw;
 ctx.save();ctx.translate(e.x,e.y);ctx.rotate(e.angle);ctx.globalAlpha=.85*(progress>.7?(1-progress)/.3:1);
 ctx.drawImage(effectSprite,frame*cw,e.row*ch,cw,ch,-e.size/2,-height/2,e.size,height);ctx.restore();
 }
}
 'use strict';
function paintWeapon(id,x,y,w,h){const a=weaponAtlas(id),im=a.image;if(!im.complete||!im.naturalWidth)return false;const cw=im.naturalWidth/a.grid,ch=im.naturalHeight/a.grid;ctx.drawImage(im,(a.index%a.grid)*cw,Math.floor(a.index/a.grid)*ch,cw,ch,x,y,w,h);return true}

function rect(x,y,w,h,color){ctx.fillStyle=color;ctx.fillRect(x,y,w,h)}
function roundRect(x,y,w,h,r,color){ctx.fillStyle=color;ctx.beginPath();ctx.roundRect(x,y,w,h,r);ctx.fill()}
function star(x,y,r,color,rotation=0,points=5){ctx.save();ctx.translate(x,y);ctx.rotate(rotation);ctx.fillStyle=color;ctx.beginPath();for(let i=0;i<points*2;i++){const a=-Math.PI/2+i*Math.PI/points,rad=i%2?r*.45:r;if(i===0)ctx.moveTo(Math.cos(a)*rad,Math.sin(a)*rad);else ctx.lineTo(Math.cos(a)*rad,Math.sin(a)*rad)}ctx.closePath();ctx.fill();ctx.restore()}
function label(text,x,y,color='#f5f0e5',font='13px sans-serif'){ctx.font=font;ctx.textAlign='center';const width=ctx.measureText(text).width;roundRect(x-width/2-8,y-16,width+16,23,7,'#1d2528ed');ctx.fillStyle=color;ctx.fillText(text,x,y)}
function drawArena(t){rect(0,0,W,H,'#303532');
 for(let y=32;y<H-20;y+=40)for(let x=24;x<W-20;x+=48){const k=((x*7+y*13)%19);roundRect(x,y,46,38,3,k<8?'#62665d':'#67695f');rect(x+5,y+33,36,1,'#51554d');if(k<3)star(x+24,y+18,2,'#72756b')}
 roundRect(17,17,W-34,H-32,18,'#7d8074');roundRect(28,32,W-56,H-59,13,'#555c52');
 for(let y=38;y<H-30;y+=40)for(let x=34;x<W-32;x+=48){const k=((x+y*3)%17);roundRect(x,y,46,38,3,k<8?'#666b5f':'#6c7064');}
 ctx.strokeStyle='#d3cbb322';ctx.lineWidth=2;ctx.strokeRect(64,65,W-128,H-125);ctx.beginPath();ctx.arc(W/2,H/2,131,0,Math.PI*2);ctx.stroke();ctx.beginPath();ctx.arc(W/2,H/2,118,0,Math.PI*2);ctx.stroke();
 for(const b of blocks){roundRect(b.x+5,b.y+10,b.w,b.h,10,'#241c385f');roundRect(b.x,b.y,b.w,b.h,9,'#565e55');roundRect(b.x,b.y,b.w,14,7,'#9b9c86');rect(b.x+6,b.y+12,b.w-12,4,'#7c8271');roundRect(b.x+7,b.y+23,b.w-14,b.h-30,6,'#464f46');rect(b.x+12,b.y+30,b.w-24,3,'#879079')}
 if(state==='menu'||state==='characters'){for(let i=0;i<4;i++){const p=makePlayer(i%2);p.char=i;p.x=120+i*290;p.y=i%2?415:185;p.angle=i%2?Math.PI:0;drawPlayer(p,t)}for(let i=0;i<16;i++){const a=i*Math.PI/8+t*.25;star(560+Math.cos(a)*210,300+Math.sin(a)*150,4,['#ffbfdc','#b6e2f0','#ffe29e'][i%3],a)}}
 const inset=arenaInset();if(inset){ctx.fillStyle='#de683b40';ctx.fillRect(28,35,inset,H-62);ctx.fillRect(W-inset-28,35,inset,H-62);ctx.fillRect(28,35,W-56,inset*.58);ctx.fillRect(28,H-inset*.58-28,W-56,inset*.58);ctx.strokeStyle='#ef914c';ctx.setLineDash([8,8]);ctx.strokeRect(inset+25,inset*.58+25,W-2*inset-50,H-2*inset*.58-50);ctx.setLineDash([]);label('危険エリア',W/2,60,'#ffd398')}
 if(state==='play'&&elapsed>=25&&elapsed<30){for(const y of [205,395]){ctx.strokeStyle='#ffdb78';ctx.setLineDash([4,5]);ctx.beginPath();ctx.arc(560,y,25,0,7);ctx.stroke();ctx.setLineDash([]);label('Sレアまで '+Math.ceil(30-elapsed)+'s',560,y-35,'#ffdb78')}}}
function itemInfo(item){if(item.kind==='weapon'){const g=guns[item.gun];return {color:RARITIES[g.rarity].color,glyph:g.glyph,text:g.rarity+' '+g.name}}if(item.kind==='relic'){const r=relics[item.relic];return {color:r.color,glyph:r.glyph,text:r.name}}return {color:'#a6ede3',glyph:'▥',text:'弾薬箱'}}
function drawItem(item,t){const {color,glyph,text}=itemInfo(item),bob=Math.sin(t*3+item.x)*3;ctx.save();ctx.translate(item.x,item.y+bob);ctx.fillStyle='#20132f55';ctx.beginPath();ctx.ellipse(0,19-bob,23,7,0,0,Math.PI*2);ctx.fill();
 ctx.shadowColor=color;ctx.shadowBlur=item.kind==='weapon'&&guns[item.gun].rarity==='S'?24:10;ctx.strokeStyle=color;ctx.lineWidth=2;
 if(item.kind==='relic'){ctx.rotate(Math.PI/4);roundRect(-13,-13,26,26,6,'#61507c');ctx.strokeRect(-11,-11,22,22);ctx.rotate(-Math.PI/4)}else{roundRect(-19,-13,38,28,6,'#3c3150');ctx.strokeRect(-17,-11,34,24);roundRect(-19,-13,38,7,4,color)}ctx.shadowBlur=0;ctx.fillStyle=color;ctx.font='bold 21px sans-serif';ctx.textAlign='center';if(item.kind==='weapon'&&weaponSprite.complete&&weaponSprite.naturalWidth){paintWeapon(item.gun,-22,-15,44,33)}else ctx.fillText(glyph,0,9);ctx.restore();
 const near=players.find(p=>dist(p,item)<82);if(near){let hint='';if(item.kind==='weapon'&&!near.inventory.some(w=>w.id===item.gun)&&near.inventory.length>=4)hint=' · '+(near.id?'H':'G')+'で交換';if(item.kind==='relic'){if(near.relics.includes(item.relic))hint=' · 装備済み';else if(near.relics.length>=3)hint=' · レリック満杯'}label(text+hint,item.x,item.y-30,color)}else if(item.kind==='weapon'&&guns[item.gun].rarity==='S')label('S LEGENDARY',item.x,item.y-30,color,'bold 12px sans-serif');}
function drawPlayer(p,t){if(p.slash>0){ctx.save();ctx.strokeStyle=p.color;ctx.lineWidth=7;ctx.globalAlpha=p.slash/.16;ctx.beginPath();ctx.arc(p.x,p.y,64,p.slashAngle-Math.PI/3,p.slashAngle+Math.PI/3);ctx.stroke();ctx.restore()}ctx.save();ctx.translate(Math.round(p.x),Math.round(p.y));ctx.fillStyle='#20132f66';ctx.beginPath();ctx.ellipse(0,15,22,9,0,0,Math.PI*2);ctx.fill();ctx.strokeStyle=p.color;ctx.lineWidth=2;ctx.beginPath();ctx.ellipse(0,14,20,8,0,0,Math.PI*2);ctx.stroke();
 if(hasRelic(p,'bell')&&p.shield<=0){ctx.strokeStyle='#ffe2a0aa';ctx.lineWidth=2;ctx.beginPath();ctx.arc(0,-7,33,0,7);ctx.stroke()}
 if(p.inv>0&&Math.floor(t*22)%2)ctx.globalAlpha=.55;
 const moving=p.moving&&p.roll<=0,phase=p.walk,step=moving?Math.sin(phase)*4:0,bob=moving?Math.abs(Math.cos(phase))*2:Math.sin(t*2+p.id)*.5;
 // One local transform drives body, grip and weapon so they never drift apart.
 ctx.save();ctx.translate(-Math.cos(p.angle)*p.recoil*2,-bob);if(p.roll>0){ctx.rotate((.26-p.roll)/.26*Math.PI*2);ctx.scale(1,.8)}
 ctx.save();if(Math.cos(p.angle)<0)ctx.scale(-1,1);ctx.rotate(moving?Math.sin(phase)*.035:0);
 if(sprite.complete&&sprite.naturalWidth){const [sx,sy,sw,sh]=spriteRects[p.char],h=68,w=h*sw/sh,hip=.72;
 // Split below the hips: alternate legs rather than sliding the entire still image.
 for(let leg=0;leg<2;leg++){const shift=leg?-step:step;ctx.drawImage(sprite,sx+leg*sw/2,sy+sh*hip,sw/2,sh*(1-hip),-w/2+leg*w/2+shift*.3,-45+h*hip+shift*.55,w/2,h*(1-hip))}
 ctx.drawImage(sprite,sx,sy,sw,sh*hip,-w/2,-45,w,h*hip);
 }else{star(0,-9,23,characters[p.char].color)}ctx.restore();
 ctx.save();ctx.translate(0,-4);ctx.rotate(p.angle);if(Math.cos(p.angle)<0)ctx.scale(1,-1);const gunId=weapon(p).id,g=guns[gunId],kick=p.recoil*3;
 if(weaponSprite.complete&&weaponSprite.naturalWidth){paintWeapon(gunId,-12-kick,-10,42,31.5)}else roundRect(-4,-3,26,10,3,g.color);
 if(p.muzzle>0&&p.roll<=0){ctx.globalAlpha=Math.min(1,p.muzzle/.035);ctx.strokeStyle=g.rail?'#b4edff':'#fff0b0';ctx.lineWidth=4;ctx.beginPath();ctx.moveTo(26,0);ctx.lineTo(40+p.recoil*8,0);ctx.stroke();ctx.lineWidth=2;for(const sign of [-1,1]){ctx.beginPath();ctx.moveTo(27,0);ctx.lineTo(36,sign*7);ctx.stroke()}}
 ctx.restore();ctx.restore();ctx.globalAlpha=1;
 label((p.id===1&&mode==='cpu'?'CPU':'P'+(p.id+1))+' '+characters[p.char].name,0,-53,p.color,'bold 12px sans-serif');roundRect(-23,26,46,4,2,'#241b32');roundRect(-23,26,46*p.hp/p.maxHp,4,2,p.color);
 for(let i=0;i<p.relics.length;i++){const r=relics[p.relics[i]],a=t*.6+i*Math.PI*2/3;star(Math.cos(a)*32,Math.sin(a)*14+10,3,r.color,a)}ctx.restore()}
function drawBullet(b,t){if(drawProjectileSprite(b))return;ctx.save();ctx.strokeStyle=b.color;ctx.lineWidth=b.r*(guns[b.gun].rail?1.6:1);ctx.globalAlpha=.35;ctx.lineCap='round';ctx.beginPath();const trail=guns[b.gun].rail?.09:.035;ctx.moveTo(b.x-b.vx*trail,b.y-b.vy*trail);ctx.lineTo(b.x,b.y);ctx.stroke();ctx.globalAlpha=1;ctx.fillStyle=b.color;ctx.shadowColor=b.color;ctx.shadowBlur=10;
 if(b.shape==='star')star(b.x,b.y,b.r,b.color,t*4);else if(b.shape==='moon'){ctx.translate(b.x,b.y);ctx.rotate(t*12);ctx.lineWidth=5;ctx.beginPath();ctx.arc(0,0,b.r,-1.7,1.7);ctx.stroke()}else if(b.shape==='diamond')star(b.x,b.y,b.r+2,b.color,Math.atan2(b.vy,b.vx),4);else{ctx.translate(b.x,b.y);ctx.rotate(Math.atan2(b.vy,b.vx));roundRect(-b.r*1.2,-b.r*.5,b.r*2.4,b.r,2,b.color)}ctx.shadowBlur=0;ctx.restore()}
function drawWell(w,t){ctx.save();ctx.translate(w.x,w.y);ctx.globalAlpha=Math.min(1,w.life*2);const gr=ctx.createRadialGradient(0,0,5,0,0,118);gr.addColorStop(0,'#f0bcff99');gr.addColorStop(.35,'#b578ee55');gr.addColorStop(1,'#ae7ce600');ctx.fillStyle=gr;ctx.fillRect(-118,-118,236,236);ctx.fillStyle='#2b153f';ctx.beginPath();ctx.arc(0,0,17,0,7);ctx.fill();ctx.lineWidth=2;for(let i=0;i<3;i++){ctx.strokeStyle=['#dab0ff','#fcc1ef','#b6b8ff'][i];ctx.beginPath();const a=t*3+i*Math.PI*2/3;ctx.arc(0,0,24+i*16,a,a+Math.PI*1.2);ctx.stroke();star(Math.cos(a)*70,Math.sin(a)*70,5,'#ecd0ff',a)}ctx.restore()}
function draw(t=performance.now()/1000){ctx.save();ctx.translate(shake?rnd(-shake,shake):0,shake?rnd(-shake,shake):0);drawArena(t);wells.forEach(w=>drawWell(w,t));pickups.forEach(p=>drawItem(p,t));drawWeaponEffects();players.slice().sort((a,b)=>a.y-b.y).forEach(p=>drawPlayer(p,t));bullets.forEach(b=>drawBullet(b,t));particles.forEach(p=>{ctx.globalAlpha=Math.min(1,p.life*3);ctx.strokeStyle=p.color;ctx.lineWidth=Math.max(1,p.size*.45);ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.lineTo(p.x-p.vx*.028,p.y-p.vy*.028);ctx.stroke()});ctx.globalAlpha=1;rings.forEach(r=>{ctx.globalAlpha=r.life/r.duration;ctx.strokeStyle=r.color;ctx.lineWidth=3;ctx.beginPath();ctx.arc(r.x,r.y,r.r,0,7);ctx.stroke()});ctx.globalAlpha=1;ctx.restore()}
function frame(t){const dt=Math.min((t-last)/1000||0,.033);last=t;update(dt);draw(t/1000);requestAnimationFrame(frame)}
requestAnimationFrame(frame);
