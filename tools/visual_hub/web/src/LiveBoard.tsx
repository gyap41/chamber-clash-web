import React,{useEffect,useRef,useState} from 'react';
import './live.css';
type Asset={id:string;name:string;kind:string;image_hash:string;preview:boolean;facts:Record<string,unknown>};
type Data={catalog:{records:Asset[];fingerprint:string};token:string};
type Report={metrics?:Record<string,{damage:number;projectiles:number;wells:number;weapon:number}>;ready?:boolean;error?:string;errors?:string[];slots?:number;fps?:number;time?:number};
function Shape({asset}:{asset:Asset}){const cells=(asset.facts.shape||[]) as number[][];return <span className="shape-info"><svg width="72" height="54" viewBox="0 0 96 72" aria-label={`${cells.length}マスの占有形状`}>{Array.from({length:24},(_,i)=><rect key={i} x={i%6*16+1} y={Math.floor(i/6)*16+1} width="14" height="14" fill="#202c32"/>)}{cells.map(([x,y],i)=><rect key={'c'+i} x={x*16+1} y={y*16+1} width="14" height="14" fill="#dab97b"/>)}</svg><small>{cells.length}マス</small></span>;}
export default function LiveBoard({data,kind}:{data:Data;kind:string}){
 const [saved]=useState(()=>{try{return JSON.parse(localStorage.getItem('chamber-live-v1')||'{}');}catch{return {};}});
 const [query,setQuery]=useState(''),[sort,setSort]=useState('id'),[background,setBackground]=useState(saved.background??'暗'),[weapon,setWeapon]=useState(saved.weapon??20),[aim,setAim]=useState(saved.aim??0),[movement,setMovement]=useState(saved.movement??0),[sync,setSync]=useState(saved.sync??'実時間'),[zoom,setZoom]=useState(saved.zoom??1),[fit,setFit]=useState(saved.fit??true),[guides,setGuides]=useState(saved.guides??false),[scenario,setScenario]=useState(saved.scenario??'target'),[playing,setPlaying]=useState(true),[speed,setSpeed]=useState(saved.speed??1),[report,setReport]=useState<Report>({}),[expanded,setExpanded]=useState<{asset:Asset;action:string;scenario:string}|null>(null),[version,setVersion]=useState(''),[building,setBuilding]=useState(false);
 useEffect(()=>{localStorage.setItem('chamber-live-v1',JSON.stringify({background,weapon,aim,movement,sync,zoom,fit,guides,scenario,speed}));},[background,weapon,aim,movement,sync,zoom,fit,guides,scenario,speed]);
 const frame=useRef<HTMLIFrameElement>(null),toolbar=useRef<HTMLDivElement>(null),command=useRef({restart:false,step:false}),revision=useRef(0);
 const assets=data.catalog.records.filter(a=>a.kind===kind&&`${a.name} ${a.id} ${a.facts.effect||''}`.toLowerCase().includes(query.toLowerCase())).sort((a,b)=>sort==='price'?Number(a.facts.price)-Number(b.facts.price):sort==='area'?((a.facts.shape||[]) as unknown[]).length-((b.facts.shape||[]) as unknown[]).length:a.id.localeCompare(b.id,undefined,{numeric:true}));
 const weapons=data.catalog.records.filter(a=>a.kind==='武器'&&a.preview);
 const columns=kind==='キャラ'?[['待機','待機','target'],['歩行','歩行','target'],['回避','回避','target']]:[['装備・発射','連射','equipment'],['弾丸・軌道','連射','flight'],['命中・固有効果','連射',scenario],['リロード','リロード','target']];
 useEffect(()=>{void fetch('/hub/live/version.json').then(r=>r.json()).then(v=>setVersion(v.fingerprint)).catch(()=>setReport({error:'実描画パックがありません。「実描画を更新」で作成してください。'}));},[]);
 useEffect(()=>{setQuery('');setExpanded(null);},[kind]);
 useEffect(()=>{const receive=(event:MessageEvent)=>{if(event.origin!==location.origin||event.source!==frame.current?.contentWindow||event.data?.kind!=='hub-live-state')return;setReport(old=>({...old,...event.data.value}));};window.addEventListener('message',receive);return()=>window.removeEventListener('message',receive);},[]);
 useEffect(()=>{
  if(kind==='レリック')return;
  let atlasSize=[0,0];
  let layout='',pending:{key:string;rect:number[];canvas:HTMLCanvasElement}[]=[];
  const paint=(event:Event)=>{
   const detail=(event as CustomEvent).detail;
   if(detail.source!==frame.current?.contentWindow||detail.revision!==revision.current||detail.canvas.width!==atlasSize[0]||detail.canvas.height!==atlasSize[1])return;
   for(const slot of pending){
    const [x,y,w,h]=slot.rect,c=slot.canvas;
    if(c.width!==w||c.height!==h){c.width=w;c.height=h;}
    const ctx=c.getContext('2d');if(!ctx)continue;
    ctx.clearRect(0,0,w,h);ctx.drawImage(detail.canvas,x,y,w,h,0,0,w,h);
    c.dataset.painted='true';
   }
  };
  window.addEventListener('hub-live-frame',paint);
  const update=()=>{
   const left=Math.max(0,document.querySelector('.sidebar')?.getBoundingClientRect().right||0);
   const top=expanded?0:Math.max(0,toolbar.current?.getBoundingClientRect().bottom||0),bottom=window.innerHeight-38;
   const elements=[...document.querySelectorAll<HTMLElement>(expanded?'.live-dialog .live-cell':'.live-table .live-cell')];
   const slots=elements.map(el=>({el,r:el.getBoundingClientRect()})).filter(({r})=>r.bottom>top&&r.top<bottom&&r.right>left&&r.left<innerWidth).slice(0,24).map(({el,r})=>({key:el.dataset.liveKey,id:el.dataset.liveId,rect:[r.left,r.top,r.width,r.height],conditions:{background,weapon,aim,movement,sync,zoom,fit,guides,action:el.dataset.liveAction,scenario:el.dataset.liveScenario,seed:719,dt:1/60}}));
   // Render an atlas independent of scroll coordinates; DOM canvases travel with their cards.
   const width=Math.max(1,...slots.map(s=>Math.ceil(s.rect[2]))),height=Math.max(1,...slots.map(s=>Math.ceil(s.rect[3])));
   const cols=Math.min(4,Math.max(1,slots.length)),atlasWidth=width*cols,atlasHeight=height*Math.max(1,Math.ceil(slots.length/cols));
   slots.forEach((s,i)=>{s.rect=[i%cols*width,Math.floor(i/cols)*height,Math.ceil(s.rect[2]),Math.ceil(s.rect[3])];});
   atlasSize=[atlasWidth,atlasHeight];
   const nextLayout=JSON.stringify([slots,atlasWidth,atlasHeight]);
   if(nextLayout!==layout){layout=nextLayout;revision.current++;}
   pending=slots.flatMap(s=>{const el=elements.find(e=>e.dataset.liveKey===s.key);const canvas=el?.querySelector('canvas');return canvas?[{key:s.key!,rect:s.rect,canvas}]:[];});
   if(frame.current){frame.current.style.width=atlasWidth+'px';frame.current.style.height=atlasHeight+'px';}
   frame.current?.contentWindow?.postMessage({kind:'hub-live-update',value:{revision:revision.current,signature:JSON.stringify([background,weapon,aim,movement,sync,zoom,fit,guides,kind,scenario]),playing:playing&&!document.hidden,speed,slots,clip:[0,0,atlasWidth,atlasHeight],...command.current}},location.origin);
   command.current={restart:false,step:false};
  };
  update();const timer=setInterval(update,100);window.addEventListener('scroll',update,true);window.addEventListener('resize',update);return()=>{clearInterval(timer);window.removeEventListener('hub-live-frame',paint);window.removeEventListener('scroll',update,true);window.removeEventListener('resize',update);};
 },[kind,background,weapon,aim,movement,sync,zoom,fit,guides,scenario,playing,speed,expanded,assets.map(a=>a.id).join('|')]);
 async function rebuild(){setBuilding(true);setReport({});try{const response=await fetch('/hub/live-build',{method:'POST',headers:{'Content-Type':'application/json','X-Hub-Token':data.token},body:'{}'});const result=await response.json();if(!response.ok)throw Error(result.error);const poll=async()=>{const job=await(await fetch('/hub/job')).json();if(job.state==='running'){setTimeout(()=>void poll().catch(e=>{setReport({error:String(e)});setBuilding(false);}),800);return;}if(job.state==='error')throw Error(job.message);location.reload();};await poll();}catch(e){setReport({error:String(e)});setBuilding(false);}}
 function cell(asset:Asset,action:string,scene:string,large=false){return <button className={'live-cell'+(large?' enlarged':'')} data-live-key={asset.id+':'+action+':'+scene} data-live-id={asset.id} data-live-action={action} data-live-scenario={scene} onClick={()=>!large&&setExpanded({asset,action,scenario:scene})} aria-label={`${asset.name} ${action} ${scene}を拡大`}><canvas aria-hidden="true"/><span>{asset.preview?(report.ready?'リアルタイム描画':'Godotを読込中…'):'未対応：詳細を確認してください'}</span></button>;}
 return <section className="live-board"><div className="live-toolbar" ref={toolbar}>
 <div className="live-controls"><input aria-label="一覧を検索" placeholder="名前・ID・効果を検索" value={query} onChange={e=>setQuery(e.target.value)}/><select aria-label="一覧の並び順" value={sort} onChange={e=>setSort(e.target.value)}><option value="id">ID順</option><option value="price">価格順</option><option value="area">占有マス順</option></select><strong>{assets.length} 件</strong>{kind!=='レリック'&&<><button onClick={()=>setPlaying(v=>!v)}>{playing?'一時停止':'再生'}</button><button onClick={()=>{command.current.restart=true;}}>最初から</button><button onClick={()=>{setPlaying(false);command.current.step=true;}}>1ステップ</button><select aria-label="再生速度" value={speed} onChange={e=>setSpeed(Number(e.target.value))}>{[.25,.5,1,2].map(n=><option key={n} value={n}>{n}×</option>)}</select></>}</div>
 {kind!=='レリック'&&<div className="live-controls"><label>背景<select value={background} onChange={e=>setBackground(e.target.value)}>{['暗','明','透過','実戦'].map(x=><option key={x}>{x}</option>)}</select></label><label>照準<select value={aim} onChange={e=>setAim(Number(e.target.value))}>{['右','左','下','上'].map((x,i)=><option key={x} value={i}>{x}</option>)}</select></label>{kind==='キャラ'?<><label>全員の装備武器<select value={weapon} onChange={e=>setWeapon(Number(e.target.value))}>{weapons.map(a=><option key={a.id} value={Number(a.id.split(':')[1])}>{a.name}</option>)}</select></label><label>移動方向<select value={movement} onChange={e=>setMovement(Number(e.target.value))}>{['右','左','下','上'].map((x,i)=><option key={x} value={i}>{x}</option>)}</select></label><label>回避同期<select value={sync} onChange={e=>setSync(e.target.value)}><option>実時間</option><option>進捗</option></select></label></>:<label>効果の確認場面<select value={scenario} onChange={e=>setScenario(e.target.value)}><option value="target">標的に命中</option><option value="wall">壁に衝突・跳弾</option><option value="effect">固有効果・引き寄せ</option></select></label>}<label><input type="checkbox" checked={fit} onChange={e=>setFit(e.target.checked)}/>枠に収める</label><label>倍率<select value={zoom} onChange={e=>{setFit(false);setZoom(Number(e.target.value));}}>{[.5,1,2,4].map(n=><option key={n} value={n}>{n}倍</option>)}</select></label><label><input type="checkbox" checked={guides} onChange={e=>setGuides(e.target.checked)}/>判定・銃口</label></div>}
 <div className="live-status" data-live-weapons={JSON.stringify(Object.values(report.metrics||{}).map(m=>m.weapon))}>{kind==='レリック'?'定義から取得した効果と占有形状。回転前の形です。':`${report.ready?'Godot Web 実描画':'Godotを起動しています'} · 表示中 ${report.slots||0}枠 · ${Math.round(report.fps||0)}fps · ${(report.time||0).toFixed(2)}秒 / 6秒ループ`} <button disabled={building} onClick={()=>void rebuild()}>{building?'実描画を更新中…':'実描画を更新'}</button></div>
 {version&&version!==data.catalog.fingerprint&&<p className="warning">素材情報が実描画パックより新しくなっています。「実描画を更新」で再ビルドしてください。</p>}{report.error&&<p role="alert" className="warning">{report.error}</p>}{report.errors?.map((e,i)=><p className="warning" key={i}>{e}</p>)}
 </div>
 <div className="live-table" style={{'--live-columns':kind==='レリック'?1:columns.length} as React.CSSProperties}><div className="live-table-head"><span>{kind==='キャラ'?'キャラ':'デザイン・名前・収納'}</span>{kind==='レリック'?<span>効果</span>:columns.map(([title])=><span key={title}>{title}</span>)}</div>{assets.map(asset=><article className="live-row" key={asset.id}><div className="live-identity"><img loading="lazy" src={'/hub/thumb?id='+encodeURIComponent(asset.id)+'&v='+asset.image_hash} alt={asset.name}/><div><strong>{asset.name}</strong><small>{asset.id}</small>{kind==='武器'&&<b>{Number(asset.facts.price)<0?'非売品':`${asset.facts.price} G`}</b>}</div>{kind!=='キャラ'&&<Shape asset={asset}/>}</div>{kind==='レリック'?<p className="relic-effect">{String(asset.facts.effect||asset.facts.desc||'効果説明なし')}</p>:columns.map(([title,action,scene])=><div className="live-panel" key={title}>{cell(asset,action,scene)}<small>{title}{guides&&report.metrics?.[asset.id+':'+action+':'+scene]&&` · ダメージ ${report.metrics[asset.id+':'+action+':'+scene].damage.toFixed(1)} / 弾 ${report.metrics[asset.id+':'+action+':'+scene].projectiles} / 重力場 ${report.metrics[asset.id+':'+action+':'+scene].wells}`}</small></div>)}</article>)}</div>
 {kind!=='レリック'&&<iframe key={version} ref={frame} className="godot-overlay" src="/hub/live/index.html" title="Godotリアルタイム描画" aria-hidden="true" tabIndex={-1}/>}
 {expanded&&<div className="live-dialog" style={{top:Math.max(84,toolbar.current?.getBoundingClientRect().bottom||80)+12}}><div className="live-dialog-header"><h2>{expanded.asset.name} · {expanded.action}</h2><button onClick={()=>setExpanded(null)}>一覧に戻る</button></div>{cell(expanded.asset,expanded.action,expanded.action==='連射'&&['target','wall','effect'].includes(expanded.scenario)?scenario:expanded.scenario,true)}<p>{String(expanded.asset.facts.effect||'')}　閉じると一覧の表示対象だけを再開します。</p></div>}
 </section>;
}
