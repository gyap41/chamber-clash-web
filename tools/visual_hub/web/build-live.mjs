import {mkdir,copyFile,readFile} from 'node:fs/promises';
import {join} from 'node:path';
import {ROOT,OUT,runGodot,atomic,manifest,updateCatalog} from './core.mjs';
export async function buildLive(){
 await updateCatalog();
 const folder=join(OUT,'live');await mkdir(folder,{recursive:true});
 const wasm=await readFile(join(ROOT,'web-build/index.wasm'));
 if(!wasm.includes(Buffer.from('4.7.2.stable.official')))throw Error('Godot 4.7.2のWebエンジンが必要です');
 await runGodot(['--headless','--export-pack','Web',join(folder,'base.zip')],'live-base');
 await runGodot(['--headless','--script','res://tools/visual_hub/pack_live.gd'],'live-pack');
 for(const name of ['index.js','index.wasm','index.audio.worklet.js','index.audio.position.worklet.js'])await copyFile(join(ROOT,'web-build',name),join(folder,name));
 await copyFile(join(ROOT,'tools/visual_hub/web/live-shell.html'),join(folder,'index.html'));
 const data=await manifest();await atomic(join(folder,'version.json'),{fingerprint:data.fingerprint,built_at:new Date().toISOString(),engine:'4.7.2'});
 console.log('Live Web preview built');
}
if(process.argv[1]?.endsWith('build-live.mjs'))await buildLive();
