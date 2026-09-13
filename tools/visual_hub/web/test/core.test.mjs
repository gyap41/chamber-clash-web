import test from 'node:test';
import {request} from 'node:http';
import assert from 'node:assert/strict';
import {mkdtemp,readFile} from 'node:fs/promises';
import {join} from 'node:path';
import {OUT,validateConditions,validateIds,captureKey,reviewData,saveReview,sourceFile,thumbnail,manifest} from '../core.mjs';
import {startServer} from '../service.mjs';
test('conditions reject invalid values; defaults and supported fixed steps',()=>{
 assert.equal(validateConditions({}).seed,719);
 assert.equal(validateConditions({dt:0.016666666667}).dt,1/60);
 for(const value of [{seed:1.2},{zoom:Infinity},{aim:4},{action:'unknown'},{fit:'false'},{dt:.1}])assert.throws(()=>validateConditions(value));
 assert.equal(validateConditions({dt:1/120,action:'回避',movement:3}).movement,3);
});
test('typed IDs detect deletion, duplicate and excessive selection',()=>{
 const data={records:[{id:'weapon:0'},{id:'character:0'}]};
 assert.equal(validateIds(['weapon:0','character:0'],data).length,2);
 for(const ids of [[],['weapon:0','weapon:0'],['weapon:999'],Array(5).fill('weapon:0')])assert.throws(()=>validateIds(ids,data));
});
test('capture cache includes source revision, order, seed, time and animation length',()=>{
 const records=[{id:'character:0',source_hash:'a'},{id:'character:1',source_hash:'b'}],c=validateConditions({});const key=captureKey(records,c,1);
 assert.equal(key,captureKey(records,validateConditions({}),1));
 for(const args of [[records,{...c,seed:2},1],[records,{...c,time:1},1],[records,c,24],[[...records].reverse(),c,1],[[{...records[0],source_hash:'changed'},records[1]],c,1]])assert.notEqual(key,captureKey(...args));
});
test('review persistence, tags and optimistic conflict protection use isolated file',async()=>{
 const folder=await mkdtemp(join(OUT,'review-test-')),path=join(folder,'reviews.json');const initial=await reviewData(path);
 const entry={status:'review',tags:[' test ','test'],note:'検証',source_hash:'revision-a'};
 const saved=await saveReview('weapon:0',entry,initial.revision,path);assert.deepEqual(saved.entries['weapon:0'].tags,['test']);assert.equal((await reviewData(path)).entries['weapon:0'].note,'検証');
 await assert.rejects(saveReview('weapon:0',{...entry,note:'lost'},initial.revision,path),{status:409});
 assert.equal((await reviewData(path)).entries['weapon:0'].note,'検証');
 await assert.rejects(saveReview('weapon:0',{...entry,status:'bad'},saved.revision,path));
});
test('image paths restricted and stale thumbnails fail explicitly',async()=>{
 await assert.rejects(sourceFile({image:'res://.env'}));await assert.rejects(sourceFile({image:'res://assets/../.env.png'}));
 const data=await manifest(),record=data.records.find(r=>r.kind==='キャラ'&&r.image);assert.ok(record);
 const path=await thumbnail(record);assert.ok((await readFile(path)).length>100);assert.equal(await thumbnail(record),path);
 await assert.rejects(thumbnail({...record,image_hash:'stale'}),{status:409});
});
test('local service blocks foreign origins, tokens and project files',async()=>{
 const port=4179,server=await startServer(port),base=`http://127.0.0.1:${port}`;
 try {
 assert.equal((await fetch(base+'/hub/data',{headers:{Origin:'https://foreign.invalid'}})).status,403);
 assert.equal(await new Promise((resolve,reject)=>{const req=request(base+'/hub/data',{headers:{Host:'foreign.invalid:4179'}},res=>{res.resume();resolve(res.statusCode);});req.on('error',reject);req.end();}),403);
 assert.equal((await fetch(base+'/hub/update',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'})).status,403);
 for(const path of ['/.env','/data/catalog.json','/tools/visual_hub/reviews.json','/package.json'])assert.equal((await fetch(base+path)).status,404);
 const response=await fetch(base+'/hub/data');assert.equal(response.status,200);const data=await response.json();assert.equal(data.catalog.counts['武器'],38);assert.ok(data.token);
 }finally{await new Promise(resolve=>server.close(resolve));}
});
