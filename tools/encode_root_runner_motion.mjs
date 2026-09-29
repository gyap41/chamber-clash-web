import sharp from 'sharp';
const walk=process.argv.includes("--walk");
const count=walk?144:240;
const prefix=walk?"walk":process.argv.includes("--bounce")?"bounce":"tackle";
const frames=[];
for(let i=0;i<count;i++)frames.push(await sharp(`.local/moss-${prefix}-frames/${String(i).padStart(3,'0')}.png`).ensureAlpha().raw().toBuffer());
await sharp(Buffer.concat(frames),{raw:{width:960,height:600*count,channels:4,pageHeight:600}}).webp({quality:88,effort:2,loop:0,delay:Array.from({length:count},(_,i)=>i%3===2?34:33)}).toFile(`docs/art/production/root-runner-motion/${prefix}-motion.webp`);
console.log(`PASS: ${prefix} animated WebP ${count} frames / ${count/30} seconds`);
