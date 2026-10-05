const fs=require('fs'),path=require('path'),assert=require('assert');
const {createCanvas,loadImage,GlobalFonts}=require(process.env.CANVAS_PACKAGE||'@napi-rs/canvas');
const base=__dirname,root=path.resolve(base,'../../../..'),data=JSON.parse(fs.readFileSync(path.join(base,'data.json'),'utf8'));
const dir=path.join(root,'assets/ui/exploration/workshop'),parts=Object.fromEntries(JSON.parse(fs.readFileSync(path.join(dir,'regions.json'),'utf8')).parts.map(p=>[p.id,p]));
GlobalFonts.registerFromPath('C:/Windows/Fonts/meiryo.ttc','Meiryo');
const cv=createCanvas(1120,800),c=cv.getContext('2d');let imgs={};const checks=[];let time=2,pulse=0;
function rect(x,y,w,h,color,stroke,r=0){c.beginPath();c.roundRect(x,y,w,h,r);c.fillStyle=color;c.fill();if(stroke){c.strokeStyle=stroke;c.lineWidth=1;c.stroke()}}
function txt(t,x,y,size=18,color='#e5e9dd',align='left'){c.font=`${size}px Meiryo`;c.fillStyle=color;c.textAlign=align;c.fillText(t,x,y);c.textAlign='left';checks.push({text:t,x,y,width:c.measureText(t).width,size});}
function wrap(t,x,y,w,size=19,color='#e5e9dd'){let line='',yy=y;c.font=`${size}px Meiryo`;for(const ch of t){if(c.measureText(line+ch).width>w){txt(line,x,yy,size,color);line=ch;yy+=size*1.6}else line+=ch}if(line)txt(line,x,yy,size,color);return yy+size*1.6}
function sprite(id,x,y,w,h){const p=parts[id],r=p.region;c.drawImage(imgs[p.atlas],...r,x,y,w,h)}
function frame(x,y,w,h){sprite('inner_backing',x+10,y+10,w-20,h-20);const r=parts.body_frame.region,sx=[0,120,r[2]-120,r[2]],sy=[0,100,r[3]-100,r[3]],dx=[x,x+54,x+w-54,x+w],dy=[y,y+54,y+h-54,y+h];for(let j=0;j<3;j++)for(let i=0;i<3;i++)c.drawImage(imgs['shell.png'],r[0]+sx[i],r[1]+sy[j],sx[i+1]-sx[i],sy[j+1]-sy[j],dx[i],dy[j],dx[i+1]-dx[i],dy[j+1]-dy[j])}
function art(im,x,y,w,h){const k=Math.min(w/im.width,h/im.height);c.drawImage(im,x+(w-im.width*k)/2,y+(h-im.height*k)/2,im.width*k,im.height*k)}
function coin(x,y){c.beginPath();c.arc(x,y,8,0,Math.PI*2);c.fillStyle='#b79a58';c.fill();c.strokeStyle='#e4ce87';c.stroke();c.beginPath();c.moveTo(x,y-4);c.lineTo(x,y+4);c.stroke()}
function button(label,price,disabled){const x=624,y=578,w=280,h=62;const g=c.createLinearGradient(0,y,0,y+h);g.addColorStop(0,disabled?'#343b36':'#477d6c');g.addColorStop(1,disabled?'#252e2b':'#254c43');rect(x,y,w,h,g,disabled?'#667263':'#c4b278',9);rect(x+5,y+5,w-10,h-10,'#00000000',disabled?'#445049':'#72927a',6);for(const xx of [x+14,x+w-14]){c.beginPath();c.arc(xx,y+h/2,2,0,7);c.fillStyle='#ad9c67';c.fill()}txt(time>=5.1?'✓':`${label}  ${price} G`,x+w/2,y+40,22,disabled?'#9ca79e':'#fff0cf','center')}
function render(mode,t=2,save=true){time=t;pulse=Math.max(0,1-Math.abs(t-4.25)/.55);const item=data.items[mode==='weapon'?0:1],exp=mode==='expansion',disabled=mode==='insufficient',gold=disabled?5:data.gold-(t>=5.1?item.price:0);checks.length=0;c.drawImage(imgs.bg,0,0);rect(0,0,1120,800,'#071211ad');c.save();c.shadowColor='#000b';c.shadowBlur=40;c.shadowOffsetY=12;rect(118,134,884,550,'#102d2e',null,16);c.restore();frame(118,134,884,550);
// Small hardware accent; the shop panel shares materials, not the bag's opening machinery.
sprite('latch',532,112-Math.min(1,time/.3)*10,56,55);rect(936,155,34,34,'#0a2223','#887e57',6);txt('×',953,180,25,'#d7d9be','center');coin(825,209);txt(`${gold} G`,915,216,19,'#e4d197','right');
rect(176,232,284,311,'#0c2526b8','#58614b',10);
if(!exp){displayBase();product(imgs[item.kind]);const shape=item.shape,maxX=Math.max(...shape.map(p=>p[0])),maxY=Math.max(...shape.map(p=>p[1])),unit=20;const sx=318-(maxX+1)*unit/2,sy=493-(maxY+1)*unit/2;for(const [x,y]of shape)rect(sx+x*unit,sy+y*unit,18,18,'#527367','#b3b48a',2);txt(item.definition.name,496,272,27);rect(496,290,42,28,'#334e43','#879e78',5);txt(item.definition.rarity,517,311,17,'#e0dba7','center');let end=wrap(item.definition.desc,496,353,420,21);if(item.kind==='weapon'){const d=item.definition;const stats=[['威力',d.damage.toFixed(2)],['弾倉',`${d.mag} 発`],['予備',`${d.stock} 発`],['発射間隔',`${d.rate} 秒`],['装填',`${d.reload_time} 秒`],['初速',`${d.speed}`]];let yy=451;for(let i=0;i<stats.length;i++){let xx=496+(i%3)*146,y=yy+Math.floor(i/3)*56;txt(stats[i][0],xx,y,13,'#91a99e');txt(stats[i][1],xx,y+24,20)}}else{rect(496,416,421,92,'#123937','#426252',8);txt('重ねて装備',514,443,15,'#a1bdad');txt('2個で 22.6% 短縮',514,479,25,'#a4e1c3');wrap(item.definition.details,496,539,420,15,'#a6bbb0')}button('購入',item.price,disabled);if(disabled)txt('9 G 不足',600,616,17,'#e6aa88','right')}
else{const chosen=data.expansion[0],unit=37,sx=207,sy=264;for(let y=0;y<6;y++)for(let x=0;x<6;x++){const has=list=>list.some(p=>p[0]===x&&p[1]===y),active=has(data.usable),possible=has(data.expansion),selected=chosen[0]===x&&chosen[1]===y;rect(sx+x*unit,sy+y*unit,33,33,selected?'#568e77':active?'#294b43':'#101e20',selected?'#f1d78e':possible?'#8a956b':'#2c4841',3);if(possible)txt(selected?'✓':'+',sx+x*unit+16,sy+y*unit+24,21,selected?'#fff3bc':'#b5c7a7','center')}
txt('バッグ拡張',496,272,27);txt('上限 24マス',496,352,20,'#b8cbbb');rect(496,413,421,92,'#123937','#426252',8);txt('次回の価格',514,444,15,'#a1bdad');txt('10 G',514,481,26,'#dfd199');button('拡張',8,false)}
mechanism(disabled);opening();
for(const t of checks){assert(t.y<675&&t.y-t.size>145,JSON.stringify(t));assert(t.width<440,JSON.stringify(t))}if(save)fs.writeFileSync(path.join(base,mode+'.png'),cv.toBuffer('image/png'));return cv.toBuffer('image/png')}

function glowLine(points,width=3,alpha=1){c.save();c.globalAlpha=alpha;c.strokeStyle='#91ffe1';c.lineWidth=width;c.shadowColor='#44e4be';c.shadowBlur=12;c.lineJoin='round';c.beginPath();points.forEach(([x,y],i)=>i?c.lineTo(x,y):c.moveTo(x,y));c.stroke();c.restore()}
function displayBase(){c.save();const g=c.createRadialGradient(318,423,8,318,423,121);g.addColorStop(0,'#63e4bf32');g.addColorStop(1,'#63e4bf00');c.fillStyle=g;c.fillRect(191,296,254,176);rect(225,447,186,27,'#142c2d','#8c825c',8);rect(239,452,158,8,'#3a6051','#7a9b76',3);glowLine([[249,453],[387,453]],2,.55+pulse*.45);for(const x of [229,391])sprite('bracket',x,461,17,7);c.restore()}

const clamp=v=>Math.max(0,Math.min(1,v));
const smooth=v=>{v=clamp(v);return v*v*(3-2*v)};
function angle(t){return .32*t+5*smooth(t/1.15)+3*smooth((t-3.7)/1.4)}
function pipe(points,level){c.save();c.lineJoin='round';c.lineCap='round';for(const [w,color]of [[12,'#09191b'],[9,'#a48c57'],[6,'#293f3a']]){c.beginPath();c.lineWidth=w;c.strokeStyle=color;points.forEach(([x,y],i)=>i?c.lineTo(x,y):c.moveTo(x,y));c.stroke()}glowLine(points,2,level);for(const [x,y]of [points[0],points[points.length-1]]){rect(x-5,y-6,10,12,'#9b8454','#d1b77a',2)}c.restore()}
function product(im){const q=smooth((time-4.25)/.85);c.save();c.beginPath();c.rect(191,238,258,334);c.clip();if(q<1){const k=1-q*.78,w=250*k,h=206*k;art(im,318-w/2,258+q*325,w,h)}c.restore();
 // A receiving drawer remains after purchase; its mouth closes around the item.
 rect(271,557,94,29,'#18302e','#99825a',5);rect(280,561,76,8*(1-smooth((time-5.05)/.2))+2,'#051616','#526b59',3);
 for(const x of [276,359]){c.beginPath();c.arc(x,578,2,0,7);c.fillStyle='#b9a26b';c.fill()}
 if(time>5.1)glowLine([[289,578],[347,578]],2,.75);
}
function mechanism(disabled){
 const on=(delay)=>.18+.5*smooth((time-delay)/.3)+(disabled?0:pulse*.25);
 // All metal routes have visible physical endpoints. Branches occupy the margins.
 pipe([[295,640],[237,640],[237,535],[164,535],[164,511]],on(.4));
 pipe([[164,294],[164,222],[443,222],[443,460],[409,460]],on(.7));
 pipe([[295,648],[591,648],[607,612],[624,612]],on(1));
 pipe([[591,648],[935,648],[969,529],[969,511]],on(.8));
 for(const x of [151,955]){sprite('tube',x,265,28,253);glowLine([[x+14,294],[x+14,485]],2,on(.5));
  for(let i=0;i<3;i++){const yy=479-((Math.max(0,time-.5)*58+i*66)%182);glowLine([[x+14,yy+10],[x+14,yy]],3,on(.5))}}
 // Circular recess, stationary axle and a foreground cover physically embed the gears.
 for(const [x,d]of [[188,1],[949,-1]]){
  c.save();c.beginPath();c.arc(x,615,32,0,7);c.fillStyle='#071718';c.fill();c.strokeStyle='#a48b54';c.lineWidth=4;c.stroke();c.clip();c.translate(x,615);c.rotate(d*angle(time));sprite('gear_large',-31,-31,62,62);c.restore();
  c.beginPath();c.arc(x,615,5,0,7);c.fillStyle='#394b41';c.fill();c.strokeStyle='#c8ae75';c.stroke();
  rect(x-36,623,72,26,'#29443c','#a68f59',6);rect(x-25,629,50,6,'#122526','#546854',2);
  for(const xx of [x-29,x+29]){c.beginPath();c.arc(xx,639,2,0,7);c.fillStyle='#c4ad77';c.fill()}
 }
 sprite('holder',264,609,64,56);sprite('crystal',282,620,28,29);
 if(!disabled)glowLine([[641,631],[887,631]],2,on(1.1));
 for(let i=0;i<5;i++){const age=(time*1.1+i*.19)%1;c.globalAlpha=(1-age)*(.15+pulse*.55);rect(296+Math.sin(i*5.2)*age*19,631-age*30,2,2,'#c5ffe4')}c.globalAlpha=1;
}
function opening(){
 const o=smooth((time-.25)/1.05);
 // Rails and fixed-width shutter leaves: translate under fixed side jambs, never scale.
 for(const y of [228,548]){rect(181,y,751,7,'#0a1e20','#796e49',2)}
 if(o<1){c.save();c.beginPath();c.rect(180,234,754,311);c.clip();
  for(const [x,right]of [[180-377*o,false],[557+377*o,true]]){
   const g=c.createLinearGradient(x,0,x+377,0);g.addColorStop(0,'#203c36');g.addColorStop(.5,'#355047');g.addColorStop(1,'#142d2d');rect(x,234,377,311,g,'#af945e',5);
   for(let i=0;i<8;i++){const xx=x+15+i*47;rect(xx,240,7,299,'#142b29','#5b6a50',2)}
   for(const yy of [245,530]){rect(x+8,yy,361,7,'#8b784d','#c0a56a',2)}
   rect(x+(right?9:350),365,17,48,'#102221','#d1b579',4);
  }c.restore();}
 for(const x of [176,930]){rect(x,229,10,325,'#2b433b','#a08a55',4);for(const y of [238,540]){c.beginPath();c.arc(x+5,y,2,0,7);c.fillStyle='#d7bd7a';c.fill()}}
}
(async()=>{for(const name of ['shell.png','drive.png','power.png'])imgs[name]=await loadImage(path.join(dir,name));imgs.bg=await loadImage(path.join(base,'background.png'));for(const kind of ['weapon','relic'])imgs[kind]=await loadImage(path.join(base,kind+'-art.png'));
 const sheet=createCanvas(1120,800),sc=sheet.getContext('2d');for(const [i,mode]of ['weapon','relic','expansion','insufficient'].entries()){const png=render(mode);sc.drawImage(await loadImage(png),i%2*560,Math.floor(i/2)*400,560,400)}fs.writeFileSync(path.join(base,'comparison.png'),sheet.toBuffer('image/png'));
 for(let t=0;t<7;t+=1/60)assert(angle(t+1/60)>=angle(t),'gear rotation reversed');
 const frames=path.join(root,'.local/shop-v12-frames');fs.mkdirSync(frames,{recursive:true});
 for(let i=0;i<105;i++)fs.writeFileSync(path.join(frames,String(i).padStart(3,'0')+'.png'),render('relic',i/15,false));
 fs.writeFileSync(path.join(base,'layout-check.json'),JSON.stringify({viewport:[1120,800],states:['weapon','relic','expansion','insufficient'],animation:{fps:15,seconds:7,opening:[0,1.3],purchasePulse:[3.7,5.25]},status:'candidate only; no production code changes'},null,2));console.log('PASS: 4 comps and 105 preview frames; text bounds checked');
})().catch(e=>{console.error(e);process.exit(1)});
