/* Deterministic UI effects: bounded particles, no timers or random allocations. */
const WorkshopEffects=(()=>{
 const clamp=x=>Math.max(0,Math.min(1,x));
 function state(ms,clock,{reduced=false,closing=false}={}){
  const opening=clamp((ms-100)/350),power=clamp((ms-350)/250);
  // 2026-10-05: two brisk turns, with acceleration/braking rather than an abrupt stop.
  const rotation=reduced?0:(opening*opening*(3-2*opening))*720;
  const sparks=[];
  if(!reduced&&!closing){
   for(let port=0;port<4;port++)for(let i=0;i<7;i++){
    // Each burst follows the arriving pulse at its actual tube inlet.
    const age=ms-((port<2?400:480)+i*6),life=95+i*7;
    if(age<0||age>=life)continue;
    const t=age/life,side=port%2===0?-1:1;
    sparks.push({x:(side<0?85:1035)+side*(5+((i*13)%17)*t),
     y:(port<2?248:430)-t*(14+i*3)+t*t*10,
     alpha:(1-t)*.8,r:1+(i%3)*.45,warm:i%3===0});
   }
  }
  return {rotation,power,flow:reduced?0:(clock%1600)/1600,sparks};
 }
 function gear(ctx,x,y,r,angle,teeth){
  ctx.save();ctx.translate(x,y);ctx.rotate(angle*Math.PI/180);
  ctx.beginPath();for(let i=0;i<teeth*4;i++){
   const a=i*Math.PI*2/(teeth*4),rr=i%4<2?r:r*.79;
   const px=Math.cos(a)*rr,py=Math.sin(a)*rr;i?ctx.lineTo(px,py):ctx.moveTo(px,py);
  }ctx.closePath();ctx.fillStyle='#9c7d48';ctx.strokeStyle='#322d23';ctx.lineWidth=3;ctx.fill();ctx.stroke();
  ctx.beginPath();ctx.arc(0,0,r*.58,0,Math.PI*2);ctx.fillStyle='#283c37';ctx.fill();ctx.stroke();
  ctx.strokeStyle='#bc9f64';ctx.lineWidth=4;for(let i=0;i<4;i++){
   const a=i*Math.PI/2;ctx.beginPath();ctx.moveTo(Math.cos(a)*5,Math.sin(a)*5);ctx.lineTo(Math.cos(a)*r*.55,Math.sin(a)*r*.55);ctx.stroke();
  }ctx.beginPath();ctx.arc(0,0,5,0,Math.PI*2);ctx.fillStyle='#c6ac75';ctx.fill();ctx.restore();
 }
 function draw(ctx,ms,clock,options={}){
  const s=state(ms,clock,options);ctx.clearRect(0,0,1120,800);
  // Hinge-side housings: clear of the core, content (x120..1000), and tubes (y248+).
  // Pitch radii 21:14 match the 12:8 ratio; the small gear drives the hinge below.
  for(const side of [-1,1]){
   const x=560+side*475;
   ctx.fillStyle='#172b2b';ctx.strokeStyle='#746142';ctx.lineWidth=3;
   ctx.beginPath();ctx.roundRect(x-29,155,58,88,12);ctx.fill();ctx.stroke();
   ctx.strokeStyle='#ad8d54';ctx.lineWidth=5;
   ctx.beginPath();ctx.moveTo(x,220);ctx.lineTo(x,241);ctx.lineTo(x-side*20,241);ctx.stroke();
   gear(ctx,x,185,24,side*s.rotation,12);
   gear(ctx,x,220,16,-side*s.rotation*1.5+11.25,8);
  }
  // Physical conduit: core -> drive housing -> upper tube -> lower tube.
  for(const x of [85,1035]){
   const side=x<560?-1:1;
   ctx.strokeStyle='#65583e';ctx.lineWidth=10;ctx.lineJoin='round';
   ctx.beginPath();ctx.moveTo(560+side*52,136);ctx.lineTo(x,136);ctx.lineTo(x,155);ctx.stroke();
   ctx.beginPath();ctx.moveTo(x,243);ctx.lineTo(x,248);ctx.moveTo(x,388);ctx.lineTo(x,430);ctx.stroke();
   // Early ignition powers the hinge before the long tubes charge.
   ctx.strokeStyle=`rgba(120,239,202,${clamp((ms-20)/65)*.65})`;ctx.lineWidth=2;
   ctx.beginPath();ctx.moveTo(560+side*52,136);ctx.lineTo(x,136);ctx.lineTo(x,155);ctx.stroke();
   // Brackets visibly fasten the external tube assembly to the case edge.
   for(const y of [272,364,454,546]){
    ctx.fillStyle='#89734b';ctx.strokeStyle='#332e23';ctx.lineWidth=2;
    const bx=x<560?x-15:1010;
    ctx.fillRect(bx,y,40,9);ctx.strokeRect(bx,y,40,9);
    ctx.fillStyle='#d0b57e';ctx.beginPath();ctx.arc(x<560?105:1015,y+4.5,2,0,Math.PI*2);ctx.fill();
   }
  }
  for(const x of [85,1035])for(const y of [248,430]){
   const tubePower=clamp((ms-(y===248?400:480))/100);
   ctx.fillStyle='#091c20';ctx.strokeStyle='#94764c';ctx.lineWidth=3;
   ctx.beginPath();ctx.roundRect(x-11,y,22,140,10);ctx.fill();ctx.stroke();
   // Glass reflection stays faint when unpowered.
   ctx.fillStyle='rgba(180,223,215,.2)';ctx.fillRect(x-6,y+13,2,112);
   ctx.save();ctx.beginPath();ctx.roundRect(x-7,y+8,14,124,5);ctx.clip();
   ctx.fillStyle=`rgba(68,200,174,${tubePower*.28})`;ctx.fillRect(x-7,y+8,14,124);
   if(!options.reduced&&tubePower>0){
    for(let i=0;i<3;i++){
     const f=(s.flow+i/3+(x===85?0:.15))%1,py=y+8+f*124;
     const g=ctx.createLinearGradient(0,py-18,0,py+8);g.addColorStop(0,'rgba(117,255,221,0)');g.addColorStop(.75,`rgba(117,255,221,${tubePower*.75})`);g.addColorStop(1,'rgba(117,255,221,0)');ctx.fillStyle=g;ctx.fillRect(x-7,py-18,14,26);
    }
   }ctx.restore();
   ctx.fillStyle='#8d744d';ctx.strokeStyle='#312e24';ctx.lineWidth=2;
   for(const capY of [y,y+130]){ctx.fillRect(x-14,capY,28,10);ctx.strokeRect(x-14,capY,28,10)}
  }
  for(const p of s.sparks){ctx.globalAlpha=p.alpha;ctx.fillStyle=p.warm?'#e3bb71':'#9df9d9';ctx.beginPath();ctx.arc(p.x,p.y,p.r,0,Math.PI*2);ctx.fill()}ctx.globalAlpha=1;
 }
 return {state,draw};
})();
if(typeof module!=='undefined')module.exports=WorkshopEffects;
