import { updateCatalog,native } from './core.mjs';
const mode=process.argv[2];
if(mode==='update'){const result=await updateCatalog();console.log('Updated:',result.counts,'records:',result.records.length);}
else if(mode==='native')await native(['character:0'],{});
else throw Error('Use update or native');
