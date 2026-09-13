import { readFile, writeFile, rename, mkdir, stat, access, readdir, realpath } from 'node:fs/promises';
import { createHash, randomUUID } from 'node:crypto';
import { dirname, resolve, join, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import sharp from 'sharp';
export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
export const OUT = join(ROOT,'.local/visual-hub');
export const REVIEW_PATH = join(ROOT,'tools/visual_hub/reviews.json');
export const hash = value => createHash('sha256').update(value).digest('hex');
export const json = async path => JSON.parse((await readFile(path,'utf8')).replace(/^\uFEFF/,''));
export async function atomic(path, value) {
  await mkdir(dirname(path),{recursive:true}); const temporary=path+'.'+randomUUID()+'.tmp';
  await writeFile(temporary,JSON.stringify(value,null,2)+'\n'); await rename(temporary,path);
}
export async function exists(path) {try {await access(path);return true;}catch{return false;}}
export async function manifest() {const data=await json(join(OUT,'catalog.json')); if(data.schema_version!==1||!Array.isArray(data.records))throw Error('素材情報の形式が不正です'); return data;}
export function validateConditions(input={}) {
 const out={background:'暗',action:'待機',aim:0,movement:0,zoom:2,fit:false,icon:false,time:0,seed:719,dt:1/60,sync:'実時間',weapon:20,guides:false,camera:'俯瞰',movement_bounds:true,bullet_bounds:true,spawns:true,supplies:true};
 const enums={background:['暗','明','透過','実戦'],action:['待機','歩行','回避','単発','連射','リロード'],sync:['実時間','進捗'],camera:['俯瞰','実戦カメラ']};
 for(const [key,values] of Object.entries(enums)) {if(input[key]!==undefined&&!values.includes(input[key]))throw Error('不正な条件: '+key);if(input[key]!==undefined)out[key]=input[key];}
 const ranges={aim:[0,3],movement:[0,3],zoom:[.125,8],time:[0,30],seed:[0,2147483647],weapon:[0,999999]};
 for(const [key,[min,max]] of Object.entries(ranges)){if(input[key]!==undefined){if(typeof input[key]!=='number'||!Number.isFinite(input[key])||input[key]<min||input[key]>max)throw Error('不正な数値: '+key);out[key]=input[key];}}
 for(const key of ['aim','movement','seed','weapon'])if(!Number.isInteger(out[key]))throw Error('整数が必要: '+key);
 for(const key of ['fit','icon','guides','movement_bounds','bullet_bounds','spawns','supplies']){if(input[key]!==undefined){if(typeof input[key]!=='boolean')throw Error('真偽値が必要: '+key);out[key]=input[key];}}
 if(input.dt!==undefined){const step=[1/60,1/120].find(value=>typeof input.dt==='number'&&Math.abs(value-input.dt)<1e-10);if(!step)throw Error('刻み幅は60/120Hz');out.dt=step;}
 return out;
}
export function validateIds(ids,data,max=4) {
 if(!Array.isArray(ids)||!ids.length||ids.length>max||new Set(ids).size!==ids.length)throw Error('1〜4個の重複しない対象を選択してください');
 return ids.map(id=>{const record=data.records.find(r=>r.id===id);if(!record)throw Error('削除された対象: '+id);return record;});
}
export function captureKey(records,conditions,frames) {return hash(JSON.stringify({version:1,ids:records.map(r=>[r.id,r.source_hash]),conditions,frames}));}
export async function godotPath() {
 const candidates=[process.env.HUB_GODOT,join(ROOT,'.local/tools/Godot_v4.7.2-stable_win64_console.exe')].filter(Boolean);
 for(const path of candidates)if(await exists(path))return path;
 throw Error('Godotがありません。HUB_GODOTにGodot実行ファイルの絶対パスを指定してください');
}
export async function runGodot(args,logName='godot') {
 const executable=await godotPath(); await mkdir(OUT,{recursive:true});
 return new Promise((resolve,reject)=>{
  const child=spawn(executable,['--path',ROOT,...args],{cwd:ROOT,windowsHide:true,shell:false});let output='';
  const timeout=setTimeout(()=>{child.kill();reject(Error('Godotが180秒以内に完了しませんでした。処理は停止しました'));},180000);
  child.stdout.on('data',b=>output+=b);child.stderr.on('data',b=>output+=b);
  child.on('error',error=>{clearTimeout(timeout);reject(error);});
  child.on('close',async code=>{clearTimeout(timeout);await writeFile(join(OUT,logName+'.log'),output);
   if(code!==0||/SCRIPT ERROR|^ERROR:|Assertion/m.test(output))reject(Error('Godot処理が失敗しました。出力先の '+logName+'.log を確認してください'));
   else resolve(output);
  });
 });
}
export async function updateCatalog(){await runGodot(['--headless','--script','res://tools/visual_hub/export_catalog.gd'],'export');return manifest();}
export async function capture(ids,input,frames=1) {
 const data=await updateCatalog(); const records=validateIds(ids,data);const conditions=validateConditions(input);
 if(![1,24,36].includes(frames))throw Error('撮影枚数が不正です');
 if(records.some(r=>!r.preview))throw Error('未対応の対象があります。詳細の診断を確認してください');
 conditions.time=Math.round(conditions.time/conditions.dt)*conditions.dt;
 const key=captureKey(records,conditions,frames), directory=join(OUT,'renders',key);
 const done=join(directory,'capture.json');
 if(await exists(done)) {
  const previous=await json(done); let intact=true;
  for(let n=0;n<records.length;n++)for(let f=0;f<frames;f++){const name=`${n}-${String(f).padStart(3,'0')}.png`;if(!await exists(join(directory,name))||previous.image_hashes?.[name]!==hash(await readFile(join(directory,name))))intact=false;}
  if(intact)return {...previous,cached:true};
 }
 await mkdir(directory,{recursive:true});
 const job={ids,conditions,frames,output:'res://.local/visual-hub/renders/'+key};
 const jobPath=join(directory,'job.json');await atomic(jobPath,job);
 await runGodot(['--rendering-method','gl_compatibility','--script','res://tools/visual_hub/export_preview.gd','--',jobPath],'capture');
 const result=await json(join(directory,'result.json'));
 const image_hashes={};for(let n=0;n<records.length;n++)for(let f=0;f<frames;f++){const name=`${n}-${String(f).padStart(3,'0')}.png`;image_hashes[name]=hash(await readFile(join(directory,name)));}
 const snapshot={...result,conditions:validateConditions(result.conditions),image_hashes,key,created_at:new Date().toISOString(),fingerprint:data.fingerprint,records:records.map(r=>({id:r.id,name:r.name,source_hash:r.source_hash})),cached:false};
 await atomic(done,snapshot);return snapshot;
}
export async function captures() {
 const folder=join(OUT,'renders');if(!await exists(folder))return [];
 const result=[];result.warnings=[];for(const dir of await readdir(folder))if(/^[a-f0-9]{64}$/.test(dir)&&await exists(join(folder,dir,'capture.json'))){try{const value=await json(join(folder,dir,'capture.json'));if(!Array.isArray(value.records)||!value.conditions||!value.created_at)throw Error('invalid metadata');result.push(value);}catch{result.warnings.push('撮影履歴の読込失敗: renders/'+dir+'/capture.json');}}
 return result.sort((a,b)=>b.created_at.localeCompare(a.created_at));
}
export async function reviewData(path=REVIEW_PATH) {
 const value=await exists(path)?await json(path):{schema_version:1,entries:{}};
 return {...value,revision:hash(JSON.stringify(value))};
}
export function reviewEntry(value) {
 if(!value||typeof value!=='object')throw Error('レビュー形式が不正です');
 if(!['unreviewed','draft','review','approved','deprecated'].includes(value.status))throw Error('レビュー状態が不正です');
 if(!Array.isArray(value.tags)||value.tags.length>20||value.tags.some(t=>typeof t!=='string'||t.length>40))throw Error('タグは20個まで、各40文字までです');
 if(typeof value.note!=='string'||value.note.length>4000)throw Error('コメントは4000文字までです');
 return {status:value.status,tags:[...new Set(value.tags.map(t=>t.trim()).filter(Boolean))],note:value.note,source_hash:String(value.source_hash||''),updated_at:new Date().toISOString()};
}
export async function saveReview(id,entry,revision,path=REVIEW_PATH) {
 const current=await reviewData(path);if(current.revision!==revision){const error=Error('別画面でレビューが更新されています。再読込して確認してください');error.status=409;throw error;}
 const value={schema_version:1,entries:{...current.entries,[id]:reviewEntry(entry)}};await atomic(path,value);return reviewData(path);
}
export async function sourceFile(record) {
 if(!record.image?.startsWith('res://')||!/^res:\/\/(assets|docs|tests)\//.test(record.image)||record.image.includes('..')||!['.png','.svg','.gif'].some(e=>record.image.toLowerCase().endsWith(e)))throw Error('画像パスが許可されていません');
 const path=await realpath(join(ROOT,record.image.slice(6)));const base=await realpath(ROOT);
 if(!path.toLowerCase().startsWith(base.toLowerCase()+sep))throw Error('プロジェクト外の画像です');
 return path;
}
const pendingThumbs=new Map();
export async function thumbnail(record) {
 const source=await sourceFile(record);const bytes=await readFile(source); const digest=hash(bytes);
 if(record.image_hash!==digest){const error=Error('元画像が変更されました。素材を更新してください');error.status=409;throw error;}
 const target=join(OUT,'thumbs',digest+'.webp');if(await exists(target))return target;
 if(!pendingThumbs.has(digest))pendingThumbs.set(digest,(async()=>{await mkdir(dirname(target),{recursive:true}); const temp=target+'.'+randomUUID()+'.tmp';await sharp(bytes,{limitInputPixels:64000000}).resize({width:320,height:240,fit:'inside',withoutEnlargement:true}).webp({quality:86}).toFile(temp);await rename(temp,target);return target;})().finally(()=>pendingThumbs.delete(digest)));
 return pendingThumbs.get(digest);
}
export async function native(ids,conditions) {
 const data=await manifest();validateIds(ids,data);
 const path=join(OUT,'native-'+randomUUID()+'.json');const value={...validateConditions(conditions),compare:ids,selected:ids[0],screen:ids.length>1?'比較':'単体',playing:false};
 await atomic(path,{conditions:value,fingerprint:data.fingerprint});
 const child=spawn(await godotPath(),['--path',ROOT,'res://tools/visual_hub/visual_hub.tscn','--','--conditions',path],{cwd:ROOT,windowsHide:true,stdio:'ignore',shell:false,detached:true});
 await new Promise((resolve,reject)=>{child.once('spawn',resolve);child.once('error',reject);});child.unref();return {opened:true};
}
