import sharp from 'sharp';
const ranges = [['walk',0,45],['attack',45,300],['death',300,315]];
for (const [name,start,end] of ranges) {
 const frames=[];
 for(let i=start;i<end;i++) frames.push(await sharp(`.local/elite-frames/${String(i).padStart(3,'0')}.png`).ensureAlpha().raw().toBuffer());
 await sharp(Buffer.concat(frames),{raw:{width:1120,height:760*(end-start),channels:4,pageHeight:760}}).webp({quality:84,effort:1,loop:0,delay:67}).toFile(`docs/art/production/enemy-animation-v2/elite-${name}.webp`);
 console.log(`PASS: ${name}, ${end-start} frames, 15fps`);
}
