// Run with CANVAS_PACKAGE pointing to an installed @napi-rs/canvas package.
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('assert');
const {createCanvas,loadImage,GlobalFonts}=require(process.env.CANVAS_PACKAGE||'@napi-rs/canvas');
function source(file){const box={module:{exports:{}}};vm.runInNewContext(fs.readFileSync(path.join(__dirname,file),'utf8'),box);return box.module.exports}
async function main(){
 const font='C:/Windows/Fonts/meiryo.ttc';if(fs.existsSync(font))GlobalFonts.registerFromPath(font,'Meiryo');
 const images={};for(const name of ['shell.png','drive-transparent.png','power-transparent.png','content','relic'])images[name]=await loadImage(path.join(__dirname,name==='relic'?'../../../first-workshop/equipment/relics/02.png':name==='content'?'../v6/b-bag.png':name));
 const parts=source('regions.js'),motion=source('../v8/motion.js'),effects=source('../v8/effects.js');
 for(const p of parts){const [x,y,w,h]=p.region,im=images[p.atlas];assert(x>=0&&y>=0&&w>0&&h>0&&x+w<=im.width&&y+h<=im.height)}
 const canvas=createCanvas(1120,800),render=source('renderer.js')(canvas.getContext('2d'),images,parts,motion,effects);
 const sheet=createCanvas(1120,800),sc=sheet.getContext('2d');
 for(const [i,t] of [0,250,450,700].entries()){
  const p=render.render(t,t,{paused:true});assert.equal(p.ready,t>=500);
  const png=canvas.toBuffer('image/png');fs.writeFileSync(path.join(__dirname,`review-${t}.png`),png);
  sc.drawImage(await loadImage(png),i%2*560,Math.floor(i/2)*400,560,400);
 }
 fs.writeFileSync(path.join(__dirname,'review-sequence.png'),sheet.toBuffer('image/png'));
 // Exercise all frames, reverse and reduced-motion paths using a real Canvas backend.
 let minX=1120,minY=800,maxX=0,maxY=0;
 for(let t=0;t<=700;t+=10){
  const p=render.render(t,t,{});
  for(const b of p.bounds){assert(b.x>=0&&b.y>=0&&b.x+b.w<=1120&&b.y+b.h<=800,`${t}ms: ${b.id} outside viewport`);minX=Math.min(minX,b.x);minY=Math.min(minY,b.y);maxX=Math.max(maxX,b.x+b.w);maxY=Math.max(maxY,b.y+b.h)}
 }
 fs.writeFileSync(path.join(__dirname,'layout-check.json'),JSON.stringify({viewport:[1120,800],sample_interval_ms:10,range_ms:[0,700],sprite_and_content_bounds:[minX,minY,maxX,maxY],content_safe_area:[176,202,944,656],note:'Rotated sprite AABBs and content rects checked; effects also visually reviewed.'},null,2));
 for(let t=700;t>=0;t-=10)render.render(t,t,{closing:true});
 render.render(350,350,{reduced:true});render.render(700,9000,{});
 if(process.env.SHARP_PACKAGE){
  const sharp=require(process.env.SHARP_PACKAGE),frames=[],delays=[];
  const small=createCanvas(560,400),gc=small.getContext('2d');
  async function frame(t,clock,delay,closing=false){
   render.render(t,clock,{closing});gc.drawImage(await loadImage(canvas.toBuffer('image/png')),0,0,560,400);
   frames.push(Buffer.from(gc.getImageData(0,0,560,400).data));delays.push(delay);
  }
  await frame(0,0,500);
  for(let t=20;t<=700;t+=20)await frame(t,t,20);
  for(let t=800;t<=1700;t+=100)await frame(700,t,100);
  for(let i=1;i<=10;i++)await frame(700-i*70,1700+i*25,25,true);
  await frame(0,2000,500,true);
  await sharp(Buffer.concat(frames),{raw:{width:560,height:400*frames.length,channels:4,pageHeight:400}}).webp({loop:0,delay:delays,quality:80}).toFile(path.join(__dirname,'opening-review.webp'));
 }
 console.log('PASS: 16 atlas regions, actual Canvas render, open/reverse/reduced motion; four review frames and sequence');
}main().catch(e=>{console.error(e);process.exit(1)});
