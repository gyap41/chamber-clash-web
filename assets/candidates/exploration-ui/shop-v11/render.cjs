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
function button(label,price,disabled){const x=624,y=578,w=280,h=62;const g=c.createLinearGradient(0,y,0,y+h);g.addColorStop(0,disabled?'#343b36':'#477d6c');g.addColorStop(1,disabled?'#252e2b':'#254c43');rect(x,y,w,h,g,disabled?'#667263':'#c4b278',9);rect(x+5,y+5,w-10,h-10,'#00000000',disabled?'#445049':'#72927a',6);for(const xx of [x+14,x+w-14]){c.beginPath();c.arc(xx,y+h/2,2,0,7);c.fillStyle='#ad9c67';c.fill()}txt(`${label}  ${price} G`,x+w/2,y+40,22,disabled?'#9ca79e':'#fff0cf','center')}
function render(mode,t=2,save=true){time=t;pulse=Math.max(0,1-Math.abs(t-4.25)/.55);const item=data.items[mode==='weapon'?0:1],exp=mode==='expansion',disabled=mode==='insufficient',gold=disabled?5:data.gold;checks.length=0;c.drawImage(imgs.bg,0,0);rect(0,0,1120,800,'#071211ad');c.save();c.shadowColor='#000b';c.shadowBlur=40;c.shadowOffsetY=12;rect(118,134,884,550,'#102d2e',null,16);c.restore();frame(118,134,884,550);
// Small hardware accent; the shop panel shares materials, not the bag's opening machinery.
sprite('latch',532,112-Math.max(0,1-time/.3)*12,56,55);rect(936,155,34,34,'#0a2223','#887e57',6);txt('×',953,180,25,'#d7d9be','center');coin(825,209);txt(`${gold} G`,915,216,19,'#e4d197','right');
rect(176,232,284,311,'#0c2526b8','#58614b',10);
if(!exp){displayBase();c.save();c.globalAlpha=1-pulse*.45;art(imgs[item.kind],193,258-pulse*16,250,206);c.restore();const shape=item.shape,maxX=Math.max(...shape.map(p=>p[0])),maxY=Math.max(...shape.map(p=>p[1])),unit=20;const sx=318-(maxX+1)*unit/2,sy=493-(maxY+1)*unit/2;for(const [x,y]of shape)rect(sx+x*unit,sy+y*unit,18,18,'#527367','#b3b48a',2);txt(item.definition.name,496,272,27);rect(496,290,42,28,'#334e43','#879e78',5);txt(item.definition.rarity,517,311,17,'#e0dba7','center');let end=wrap(item.definition.desc,496,353,420,21);if(item.kind==='weapon'){const d=item.definition;const stats=[['威力',d.damage.toFixed(2)],['弾倉',`${d.mag} 発`],['予備',`${d.stock} 発`],['発射間隔',`${d.rate} 秒`],['装填',`${d.reload_time} 秒`],['初速',`${d.speed}`]];let yy=451;for(let i=0;i<stats.length;i++){let xx=496+(i%3)*146,y=yy+Math.floor(i/3)*56;txt(stats[i][0],xx,y,13,'#91a99e');txt(stats[i][1],xx,y+24,20)}}else{rect(496,416,421,92,'#123937','#426252',8);txt('重ねて装備',514,443,15,'#a1bdad');txt('2個で 22.6% 短縮',514,479,25,'#a4e1c3');wrap(item.definition.details,496,539,420,15,'#a6bbb0')}button('購入',item.price,disabled);if(disabled)txt('9 G 不足',600,616,17,'#e6aa88','right')}
else{const chosen=data.expansion[0],unit=37,sx=207,sy=264;for(let y=0;y<6;y++)for(let x=0;x<6;x++){const has=list=>list.some(p=>p[0]===x&&p[1]===y),active=has(data.usable),possible=has(data.expansion),selected=chosen[0]===x&&chosen[1]===y;rect(sx+x*unit,sy+y*unit,33,33,selected?'#568e77':active?'#294b43':'#101e20',selected?'#f1d78e':possible?'#8a956b':'#2c4841',3);if(possible)txt(selected?'✓':'+',sx+x*unit+16,sy+y*unit+24,21,selected?'#fff3bc':'#b5c7a7','center')}
txt('バッグ拡張',496,272,27);txt('上限 24マス',496,352,20,'#b8cbbb');rect(496,413,421,92,'#123937','#426252',8);txt('次回の価格',514,444,15,'#a1bdad');txt('10 G',514,481,26,'#dfd199');button('拡張',8,false)}
mechanism(disabled);opening();
for(const t of checks){assert(t.y<675&&t.y-t.size>145,JSON.stringify(t));assert(t.width<440,JSON.stringify(t))}if(save)fs.writeFileSync(path.join(base,mode+'.png'),cv.toBuffer('image/png'));return cv.toBuffer('image/png')}

function glowLine(points,width=3,alpha=1){c.save();c.globalAlpha=alpha;c.strokeStyle='#91ffe1';c.lineWidth=width;c.shadowColor='#44e4be';c.shadowBlur=12;c.lineJoin='round';c.beginPath();points.forEach(([x,y],i)=>i?c.lineTo(x,y):c.moveTo(x,y));c.stroke();c.restore()}
function displayBase(){c.save();const g=c.createRadialGradient(318,423,8,318,423,121);g.addColorStop(0,'#63e4bf32');g.addColorStop(1,'#63e4bf00');c.fillStyle=g;c.fillRect(191,296,254,176);rect(225,447,186,27,'#142c2d','#8c825c',8);rect(239,452,158,8,'#3a6051','#7a9b76',3);glowLine([[249,453],[387,453]],2,.55+pulse*.45);for(const x of [229,391])sprite('bracket',x,461,17,7);c.restore()}
function mechanism(disabled){
 // Recessed gear wells: kept below the product/text areas, clear of the buy button.
 for(const [x,d]of [[189,1],[964,-1]]){
  c.save();c.beginPath();c.roundRect(x-45,554,88,112,13);c.clip();rect(x-45,554,88,112,'#081c20','#847c55',13);
  c.translate(x,609);c.rotate(d*(time*.32+Math.min(time,1)*5+pulse*1.8));sprite('gear_large',-40,-40,80,80);c.restore();
  rect(x-46,645,92,15,'#253c37','#a28c5d',5);for(const xx of [x-34,x+34]){c.beginPath();c.arc(xx,652,3,0,7);c.fillStyle='#bc9c61';c.fill()}
 }
 // Crystal in the lower frame feeds two side tubes and the purchase switch.
 sprite('holder',264,599,68,65);sprite('crystal',283,614,30,33);
 for(const x of [151,955]){sprite('tube',x,265,28,253);glowLine([[x+14,294],[x+14,485]],2,.4+pulse*.6);
 for(let i=0;i<3;i++){const yy=479-((time*58+i*66)%182);glowLine([[x+14,yy+10],[x+14,yy]],3,.7)}}
 glowLine([[319,642],[568,642],[603,608],[624,608]],2,disabled?.15:.42+pulse*.55);
 glowLine([[280,644],[255,644],[255,531],[164,531],[164,518]],2,.36);
 glowLine([[603,648],[926,648],[969,535],[969,518]],2,.22);
 if(!disabled){glowLine([[641,631],[887,631]],2,.35+pulse*.65);}
 // Connection sparks stay away from product text.
 for(let i=0;i<9;i++){const age=(time*1.1+i*.117)%1;const xx=298+Math.sin(i*5.2)*age*25,yy=624-age*42;c.globalAlpha=(1-age)*(.35+pulse*.65);rect(xx,yy,2,2,'#c5ffe4');}c.globalAlpha=1;
}
function opening(){if(time>=1.15)return;const ease=Math.min(1,Math.max(0,(time-.15)/1));const o=1-Math.pow(1-ease,3);c.save();c.beginPath();c.roundRect(174,196,750,443,8);c.clip();const width=375*(1-o);for(const [x,dir]of [[174,1],[924-width,-1]]){rect(x,196,width,443,'#163232','#aa9160',6);if(width>8)glowLine([[dir===1?x+width-3:x+3,207],[dir===1?x+width-3:x+3,624]],2,.75)}c.restore()}
(async()=>{for(const name of ['shell.png','drive.png','power.png'])imgs[name]=await loadImage(path.join(dir,name));imgs.bg=await loadImage(path.join(base,'background.png'));for(const kind of ['weapon','relic'])imgs[kind]=await loadImage(path.join(base,kind+'-art.png'));
 const sheet=createCanvas(1120,800),sc=sheet.getContext('2d');for(const [i,mode]of ['weapon','relic','expansion','insufficient'].entries()){const png=render(mode);sc.drawImage(await loadImage(png),i%2*560,Math.floor(i/2)*400,560,400)}fs.writeFileSync(path.join(base,'comparison.png'),sheet.toBuffer('image/png'));
 const frames=path.join(root,'.local/shop-v11-frames');fs.mkdirSync(frames,{recursive:true});
 for(let i=0;i<90;i++)fs.writeFileSync(path.join(frames,String(i).padStart(3,'0')+'.png'),render('relic',i/15,false));
 fs.writeFileSync(path.join(base,'layout-check.json'),JSON.stringify({viewport:[1120,800],states:['weapon','relic','expansion','insufficient'],animation:{fps:15,seconds:6,opening:[0,1.15],purchasePulse:[3.7,4.8]},status:'candidate only; no production code changes'},null,2));console.log('PASS: 4 comps and 90 preview frames; text bounds checked');
})().catch(e=>{console.error(e);process.exit(1)});
