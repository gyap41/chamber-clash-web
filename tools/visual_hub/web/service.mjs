import {buildLive} from './build-live.mjs';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { join, extname } from 'node:path';
import { randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { ROOT,OUT,exists,json,manifest,updateCatalog,capture,captures,reviewData,saveReview,thumbnail,native } from './core.mjs';
const mime={'.html':'text/html; charset=utf-8','.js':'application/javascript','.css':'text/css','.png':'image/png','.webp':'image/webp','.ttf':'font/ttf'};
export async function startServer(port=4178) {
 const token=randomBytes(24).toString('hex');let job={state:'idle',message:''};let writingReview=false;
 const send=(res,status,data)=>{res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});res.end(JSON.stringify(data));};
 const work=async(label,fn)=>{job={state:'running',message:label};try {const result=await fn();job={state:'done',message:label+'が完了しました',result};}catch(error){job={state:'error',message:error.message};}};
 const server=createServer(async(req,res)=>{
  try{
   const host=req.headers.host;if(host!==`127.0.0.1:${port}`&&host!==`localhost:${port}`){send(res,403,{error:'Host拒否'});return;}
   const expected='http://'+host;
   if(req.headers.origin&&req.headers.origin!==expected){send(res,403,{error:'Origin拒否'});return;}
   const url=new URL(req.url,expected),path=url.pathname;
   if(req.method==='POST'){
    if(req.headers['x-hub-token']!==token||req.headers['content-type']!=='application/json'){send(res,403,{error:'ローカル操作トークンが必要です'});return;}
    let raw='';for await (const piece of req){raw+=piece;if(raw.length>64000){send(res,413,{error:'要求が大きすぎます'});return;}}
    const body=JSON.parse(raw||'{}');
    if(path==='/hub/review'){
     if(writingReview){send(res,409,{error:'レビュー保存中です'});return;}
     const data=await manifest();if(!data.records.some(r=>r.id===body.id))throw Error('削除された対象です');
     writingReview=true;try{send(res,200,await saveReview(body.id,body.entry,body.revision));}finally{writingReview=false;}return;
    }
    if(job.state==='running'){send(res,409,{error:'前の処理が完了するまでお待ちください'});return;}
    if(path==='/hub/live-build'){void work('実描画パック更新',async()=>{await updateCatalog();await buildLive();return {rebuilt:true};});send(res,202,{accepted:true});return;}
    if(path==='/hub/update'){void work('素材更新',updateCatalog);send(res,202,{accepted:true});return;}
    if(path==='/hub/capture'){void work('選択対象の撮影',()=>capture(body.ids,body.conditions,body.frames));send(res,202,{accepted:true});return;}
    if(path==='/hub/native'){send(res,200,await native(body.ids,body.conditions));return;}
    send(res,404,{error:'不明な操作'});return;
   }
   if(req.method!=='GET'){send(res,405,{error:'Method拒否'});return;}
   if(path==='/hub/data'){const history=await captures(),catalog=await manifest();catalog.errors=[...catalog.errors,...(history.warnings||[])];send(res,200,{catalog,reviews:await reviewData(),captures:history,token,job});return;}
   if(path.startsWith('/hub/live/')){const name=path.slice('/hub/live/'.length);if(!/^(index\.(html|js|wasm|audio\.worklet\.js|audio\.position\.worklet\.js)|hub\.pck|version\.json)$/.test(name))throw Error('不正な実描画パス');const bytes=await readFile(join(OUT,'live',name));res.writeHead(200,{'Content-Type':name.endsWith('.wasm')?'application/wasm':name.endsWith('.html')?'text/html; charset=utf-8':name.endsWith('.js')?'application/javascript':name.endsWith('.json')?'application/json':'application/octet-stream','Cache-Control':'no-cache'});res.end(bytes);return;}
   if(path==='/hub/job'){send(res,200,job);return;}
   if(path==='/hub/thumb'){
    const data=await manifest(),record=data.records.find(r=>r.id===url.searchParams.get('id'));if(!record)throw Error('対象なし');
    const bytes=await readFile(await thumbnail(record));res.writeHead(200,{'Content-Type':'image/webp','Cache-Control':'no-cache'});res.end(bytes);return;
   }
   if(path.startsWith('/hub/render/')){
    const match=path.match(/^\/hub\/render\/([a-f0-9]{64})\/([0-3])-([0-9]{3})\.png$/);if(!match)throw Error('不正な出力名');
    const folder=join(OUT,'renders',match[1]);if(!await exists(join(folder,'capture.json')))throw Error('未完了の撮影');
    const bytes=await readFile(join(folder,`${match[2]}-${match[3]}.png`));res.writeHead(200,{'Content-Type':'image/png','Cache-Control':'public,max-age=31536000,immutable'});res.end(bytes);return;
   }
   if(path==='/hub/font'){res.writeHead(200,{'Content-Type':'font/ttf','Cache-Control':'public,max-age=86400'});res.end(await readFile(join(ROOT,'assets/fonts/ipag.ttf')));return;}
   // Serve only the compiled app, never the project tree, .env or source manifests.
   const relative=path==='/'?'index.html':path.slice(1);
   if(!/^(index\.html|assets\/[a-zA-Z0-9_.-]+\.(js|css))$/.test(relative)){send(res,404,{error:'Not found'});return;}
   const file=join(OUT,'web-dist',relative);res.writeHead(200,{'Content-Type':mime[extname(file)]||'application/octet-stream','Cache-Control':'no-cache','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer'});res.end(await readFile(file));
  }catch(error){if(res.headersSent){res.end();return;}send(res,error.status||400,{error:error.message});}
 });
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(port,'127.0.0.1',resolve);});return server;
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 if(!await exists(join(OUT,'web-dist/index.html')))throw Error('先に npm run visual-hub:build を実行してください');
 if(!await exists(join(OUT,'catalog.json')))await updateCatalog();
 const port=Number(process.env.HUB_PORT||4178);await startServer(port);console.log(`Visual Hub: http://127.0.0.1:${port}`);
}
