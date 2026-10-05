/* The same atlas assembly is used by browser playback and offline Canvas review. */
function createWorkshopRenderer(ctx,images,parts,motion,effects){
 const regions=Object.fromEntries(parts.map(p=>[p.id,p]));
 let bounds=[],currentScale=1;
 function track(id,x,y,w,h,angle=0){
  const a=angle*Math.PI/180,ww=Math.abs(w*Math.cos(a))+Math.abs(h*Math.sin(a)),hh=Math.abs(w*Math.sin(a))+Math.abs(h*Math.cos(a));
  bounds.push({id,x:560+(x+w/2-ww/2-560)*currentScale,y:420+(y+h/2-hh/2-420)*currentScale,w:ww*currentScale,h:hh*currentScale});
 }
 function sprite(id,x,y,w,h,{angle=0,mirror=false,alpha=1,brightness=1}={}){
  if(w<.1||h<.1||alpha<=0)return;
  track(id,x,y,w,h,angle);
  const p=regions[id];ctx.save();ctx.translate(x+w/2,y+h/2);ctx.rotate(angle*Math.PI/180);ctx.scale(mirror?-1:1,1);ctx.globalAlpha=alpha;
  ctx.filter=`brightness(${brightness})`;ctx.drawImage(images[p.atlas],...p.region,-w/2,-h/2,w,h);ctx.restore();
 }
 function line(points,color,width){ctx.beginPath();points.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.strokeStyle=color;ctx.lineWidth=width;ctx.lineJoin='round';ctx.stroke()}
 function frame(){
  // Keep corner guards at 66px instead of stretching them over the content.
  const p=regions.body_frame,[sx,sy,w,h]=p.region;
  const xx=[0,120,w-120,w],yy=[0,100,h-100,h];
  const dx=[94,160,960,1026],dy=[135,201,649,715];
  for(let y=0;y<3;y++)for(let x=0;x<3;x++){
   ctx.drawImage(images[p.atlas],sx+xx[x],sy+yy[y],xx[x+1]-xx[x],yy[y+1]-yy[y],dx[x],dy[y],dx[x+1]-dx[x],dy[y+1]-dy[y]);
  }track('body_frame',94,135,932,580);
 }
 function content(alpha){
  ctx.save();ctx.globalAlpha=alpha;
  // Only artwork/grid samples remain from v6. Labels are separate from art, not baked UI.
  // The content safe area (176,202)..(944,656) clears the frame's large corner guards.
  ctx.textAlign='left';
  ctx.drawImage(images.content,153,213,384,384,180,229,360,360);
  track('grid',180,229,360,360);
  // Stitched pockets convey reserve storage without explanatory labels.
  line([[180,605],[540,605]],'#566657',1);
  ctx.drawImage(images.content,122,646,512,42,180,620,384,32);
  track('reserve',180,620,384,32);
  ctx.fillStyle='rgba(6,28,30,.86)';ctx.strokeStyle='#7c734f';ctx.lineWidth=1.5;
  ctx.beginPath();ctx.roundRect(606,218,328,418,10);ctx.fill();ctx.stroke();track('details',606,218,328,418);
  ctx.fillStyle='#e0e8da';ctx.font='25px Meiryo, sans-serif';ctx.fillText('プリズムレンズ',628,259);
  ctx.fillStyle='#c9a3ec';ctx.font='16px Meiryo, sans-serif';ctx.fillText('A',629,289);
  ctx.fillStyle='#b0bdb5';ctx.font='14px Meiryo, sans-serif';ctx.fillText('重複効果なし',657,289);
  ctx.drawImage(images.relic,710,319,120,120);
  ctx.fillStyle='#edf2dd';ctx.font='22px Meiryo, sans-serif';ctx.fillText('壁での跳ね返り ＋1回',628,480);
  ctx.fillStyle='#a8c0b5';ctx.font='15px Meiryo, sans-serif';
  for(const [i,t] of ['通常・散弾・追尾・螺旋・','レール弾に有効','分裂・往復などの特殊弾は対象外'].entries())ctx.fillText(t,628,522+i*25);
  ctx.restore();
 }
 function render(ms,clock,options={}){
  const p=motion.pose(ms,options.reduced),e=effects.state(ms,clock,options);
  bounds=[];currentScale=p.scale;
  ctx.clearRect(0,0,1120,800);ctx.fillStyle='#111d1e';ctx.fillRect(0,0,1120,800);
  ctx.save();ctx.translate(560,420);ctx.scale(p.scale,p.scale);ctx.translate(-560,-420);
  sprite('inner_backing',106,147,908,555);
  frame();
  content(p.content);
  // Two physical inlet rails. They ignite before the gears and run to the drive housing.
  for(const side of [-1,1]){
   const x=560+side*475;
   line([[560+side*48,130],[x,130],[x,156]],'#776040',12);
   line([[560+side*48,130],[x,130],[x,156]],`rgba(113,233,198,${Math.min(1,ms/85)*.65})`,2);
   sprite('elbow',x-10,122,20,25,{mirror:side>0});
  }
  // Lid faces and backs share the exact hinge origin. Projection is a 2D timing study.
  const width=456*Math.abs(Math.cos(p.angle*Math.PI/180));
  for(const side of [-1,1]){
   const hinge=side<0?104:1016;
   const back=p.angle>90;
   const x=side<0?(back?hinge-width:hinge):(back?hinge:hinge-width);
   sprite(back?'lid_back':'lid_front',x,146,width,554,{mirror:side>0,alpha:options.reduced?1-p.lid:1});
   sprite('hinge',hinge-9,239,18,35);sprite('hinge',hinge-9,530,18,35);
  }
  sprite('latch',104+width-25-p.latch*10,370,25,60,{alpha:1-p.lid});
  sprite('latch',1016-width+p.latch*10,370,25,60,{alpha:1-p.lid,mirror:true});
  for(const side of [-1,1]){
   const x=560+side*475;
   sprite('shaft',x-6,216,28,28,{mirror:side>0});
   sprite('gear_housing',x-29,155,58,88);
   sprite('gear_large',x-24,161,48,48,{angle:side*e.rotation});
   sprite('gear_small',x-16,204,32,32,{angle:-side*e.rotation*1.5+11.25});
   sprite('connector',x-5,241,10,18);sprite('connector',x-6,382,12,53);
   for(const y of [248,430]){
    for(const yy of [y+20,y+112])sprite('bracket',x-17,yy,40,14,{mirror:side>0});
    sprite('tube',x-14,y,28,140);
    const power=Math.max(0,Math.min(1,(ms-(y===248?400:480))/100));
    ctx.save();ctx.beginPath();ctx.rect(x-7,y+32,14,76);ctx.clip();
    ctx.fillStyle=`rgba(2,17,20,${(1-power)*.65})`;ctx.fillRect(x-7,y+32,14,76);
    ctx.globalCompositeOperation='screen';ctx.fillStyle=`rgba(70,228,185,${power*.17})`;ctx.fillRect(x-7,y+32,14,76);
    if(!options.reduced)for(let i=0;i<3;i++){
     const py=y+32+((e.flow+i/3)%1)*76;
     const g=ctx.createLinearGradient(0,py-12,0,py+5);g.addColorStop(0,'rgba(110,255,212,0)');g.addColorStop(.75,`rgba(110,255,212,${power*.7})`);g.addColorStop(1,'rgba(110,255,212,0)');ctx.fillStyle=g;ctx.fillRect(x-7,py-12,14,17);
    }ctx.restore();
   }
  }
  // Glow is composited separately; no changes to source PNGs.
  const pulse=p.settled&&!options.reduced&&!options.paused?.92+.08*Math.sin(clock/1100):1;
  sprite('crystal',532,100,56,66,{brightness:.45+p.corePower*.75*pulse});
  sprite('holder',509,82,102,102);
  if(p.corePower>0){const g=ctx.createRadialGradient(560,134,4,560,134,48);g.addColorStop(0,`rgba(66,232,184,${p.corePower*.15})`);g.addColorStop(1,'rgba(66,232,184,0)');ctx.fillStyle=g;ctx.fillRect(512,86,96,96)}
  for(const s of e.sparks){ctx.globalAlpha=s.alpha;ctx.fillStyle=s.warm?'#ebc778':'#a9ffe4';ctx.beginPath();ctx.arc(s.x,s.y,s.r,0,Math.PI*2);ctx.fill()}ctx.globalAlpha=1;
  ctx.restore();
  return {...p,bounds};
 }
 return {render};
}
if(typeof module!=='undefined')module.exports=createWorkshopRenderer;
