import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import sharp from 'sharp';
import {capture,OUT,hash,manifest,atomic} from './core.mjs';
const results=[];
const guns=await capture(['weapon:4','weapon:10','weapon:20','weapon:37'],{action:'連射',fit:true,time:1,background:'実戦',guides:true},24);
assert.equal(guns.records.length,4);assert.equal(guns.frames,24);
for(let i=0;i<4;i++){const file=join(OUT,'renders',guns.key,`${i}-012.png`),image=await sharp(file).metadata();assert.equal(image.width,640);assert.equal(image.height,400);}
results.push({check:'four guns / gravity / 24 frames',key:guns.key});
const stageIds=(await manifest()).records.filter(r=>r.kind==='ステージ').map(r=>r.id);
const stages=await capture(stageIds,{fit:true},1);
const cached=await capture(stages.ids,{fit:true},1);assert.equal(cached.key,stages.key);assert.equal(cached.cached,true);
const png=join(OUT,'renders',stages.key,'0-000.png'),original=await readFile(png);await writeFile(png,'invalid-cache');
const repaired=await capture(stages.ids,{fit:true},1);assert.equal(repaired.cached,false);assert.equal(hash(await readFile(png)),hash(original));
const different=await capture(stages.ids,{fit:true,background:'明'},1);assert.notEqual(different.key,stages.key);
results.push({check:'two stages / cache hit / corrupted PNG repair / changed condition',keys:[stages.key,different.key]});
await atomic(join(OUT,'pipeline-verification.json'),{passed:true,at:new Date().toISOString(),results});
console.log('PASS: actual Hybrid pipeline',JSON.stringify(results));
