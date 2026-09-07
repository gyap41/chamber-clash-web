const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const noop=()=>{},nodes={},frames=[];
const context=new Proxy({measureText:t=>({width:t.length*7}),createRadialGradient:()=>({addColorStop:noop}),drawImage(img,...args){if(args.some(v=>!Number.isFinite(v)))throw Error("Non-finite sprite coordinates")},ellipse(...args){if(args.length<7)throw new TypeError("Canvas ellipse requires 7 arguments")}},{get:(o,k)=>o[k]||noop});
function element(){return {style:{},classList:{toggle:noop},textContent:'',innerHTML:'',open:false,querySelectorAll:()=>[],addEventListener:noop,getContext:()=>context,showModal(){this.open=true},close(){this.open=false}}}
const sandbox={console,Math,Set,Infinity,performance:{now:()=>1000},Image:class{complete=true;naturalWidth=1536;naturalHeight=1024},document:{getElementById:id=>nodes[id]??=element(),addEventListener:noop},window:{addEventListener:noop},requestAnimationFrame:callback=>frames.push(callback),confirm:()=>true};
vm.createContext(sandbox);for(const file of ['data.js','game.js','shop.js','render.js'])vm.runInContext(fs.readFileSync(path.join(__dirname,'../dist',file),'utf8'),sandbox,{filename:file});
function advanceFrame(t){const callback=frames.shift();if(!callback)throw Error('Animation loop stopped');callback(t);if(frames.length!==1)throw Error('Expected one scheduled frame')}
sandbox.advanceFrame=advanceFrame;
vm.runInContext(`
function check(ok,msg){if(!ok)throw Error(msg)}
function completeShop(){if(state==='shop')readyShop();if(state==='shop')readyShop()}
advanceFrame(1000); // Render the menu through the actual animation callback.
showCharacters();advanceFrame(1016);selectCharacter(0);advanceFrame(1032);selectGun(choices[0]);completeShop();
const startTime=time,startX=players[0].x;keys={KeyD:true};
for(let i=1;i<=20;i++)advanceFrame(1032+i*16);
check(state==='play'&&time<startTime&&players[0].x>startX,'weapon selection starts a moving match');keys={};
function fresh(){selectedChars=[0,0];mode='local';startMatch();selectGun(1);selectGun(3);completeShop();players.forEach(p=>p.inv=999)}
function tick(n){for(let i=0;i<n;i++)update(1/60)}
fresh();check(state==='play'&&players.every(p=>p.inventory.length===2),'local draft');
const p=players[0];equipSlot(p,0);let w=weapon(p);w.clip=3;w.reserve=4;reload(p);tick(85);check(w.clip===7&&w.reserve===0,'reload conserves finite ammo');
w.clip=0;w.reserve=3;reload(p);equipSlot(p,1);tick(85);check(w.clip===0&&w.reserve===3,'cancelled reload preserves rounds');
equipSlot(p,0);p.reload=0;p.shot=0;w.clip=0;w.reserve=0;const before=bullets.length;fire(p);check(bullets.length===before,'empty gun cannot fire');
addGun(p,2);addGun(p,4);check(p.inventory.length===4,'four slots');const snapshot=JSON.stringify(p.inventory);check(addGun(p,5)===false&&JSON.stringify(p.inventory)===snapshot,'full inventory never silently discards');
const previous=p.active;check(addGun(p,5,true)&&p.inventory.length===4&&weapon(p).id===5&&p.active===previous,'explicit swap');
weapon(p).reserve=0;const count=p.inventory.length;addGun(p,5);check(p.inventory.length===count&&weapon(p).reserve>0,'duplicates replenish same gun');
const pack={kind:'ammo',age:1,x:p.x,y:p.y};p.inventory.forEach(w=>w.reserve=0);check(acquire(p,pack)&&p.inventory.every(w=>w.reserve>0),'ammo replenishes all weapons');
check(!acquire(players[1],pack),'pickup can only be claimed once');
p.relics=[];p.hp=3;check(addRelic(p,4)&&p.maxHp===10&&p.hp===5,'heart adds max hp and heals');check(!addRelic(p,4),'no duplicate relic stacking');addRelic(p,0);addRelic(p,1);check(!addRelic(p,2)&&p.relics.length===3,'three relic cap');
p.inventory=[makeWeapon(0)];p.active=0;p.reload=0;weapon(p).clip=1;reload(p);check(Math.abs(p.reload-.82225)<.001,'ribbon reload bonus');
p.relics=[0];p.roll=0;keys={KeyD:true};let px=p.x;updatePlayer(p,.01);check(Math.abs(p.x-px-205*1.12*.01)<.001,'feather increases move speed');keys={};p.relics=[2];p.reload=0;p.shot=0;bullets=[];fire(p);check(bullets[0].bounce===1,'lens adds real bounce');
p.relics=[5];p.dodge=0;bullets=[];roll(p);check(bullets.length===6,'brooch fires six dodge stars');
p.relics=[3];p.inv=0;p.shield=0;const hp=p.hp;damage(p,1);check(p.hp===hp&&p.shield===12,'bell blocks hit');p.inv=0;damage(p,1);check(p.hp===hp-1,'bell cooldown permits damage');
p.inv=0;p.shield=0;damage(p,1,true);check(p.hp===hp-2,'hazard bypasses shield');
fresh();for(let g=0;g<guns.length;g++){const p=players[0];p.inventory=[makeWeapon(g)];p.active=0;p.shot=0;p.reload=0;bullets=[];const initial=weapon(p).clip;fire(p);check(weapon(p).clip===initial-1&&bullets.length>0,'weapon consumes finite ammo '+g);for(let i=0;i<120;i++){updateBullets(1/60);updateWells(1/60)}draw();check(bullets.every(b=>Number.isFinite(b.x)&&Number.isFinite(b.vx)),'finite projectile state '+g)}
fresh();players[0].inventory=[makeWeapon(10)];players[0].active=0;players[0].shot=0;fire(players[0]);for(let i=0;i<70;i++)updateBullets(1/60);check(wells.length===1,'gravity weapon creates well');blank(players[1]);check(wells.length===0&&bullets.every(b=>b.owner===1),'blank clears enemy projectiles and wells');
fresh();pause();const oldTime=time;update(1);check(state==='paused'&&time===oldTime,'pause freezes game');pause();check(state==='play','resume');
fresh();tick(1810);check(legendarySpawned&&pickups.some(i=>i.kind==='weapon'&&guns[i.gun].rarity==='S'),'legendary timed delivery');
fresh();players[1].inv=0;const q=players[1],qh=q.hp;damage(q,.55,false,77);damage(q,.55,false,77);check(Math.abs(q.hp-(qh-1.1))<.001,'same volley pellets each deal damage');check(!damage(q,1,false,78),'different volley respects invulnerability');fresh();players[1].hp=0;update(.016);check(state==='result'&&scores[0]===1,'round victory');nextRound();check(players.every(p=>p.relics.length===0&&p.inventory.length===1&&p.hp===8),'round resets loot');
fresh();tick(5410);check(state==='result','timeout ends round');
mode='cpu';selectedChars=[0,3];startMatch();selectGun(2);completeShop();for(let i=0;i<5500&&state==='play';i++)update(1/60);check(state==='result','cpu match ends without exception');draw();

fresh();const edge=players[0],m=movementBounds;
for(const pos of [{x:-50,y:-50},{x:W+50,y:H+50},{x:270,y:175},{x:550,y:300}]){Object.assign(edge,pos);move(edge,0,0,.016);check(edge.x>=m.left&&edge.x<=m.right&&edge.y>=m.top&&edge.y<=m.bottom&&!blocks.some(b=>circleRect(edge.x,edge.y,edge.r,b)),'recover outside or embedded position');}
Object.assign(edge,{x:170,y:180});move(edge,2000,0,.3);check(edge.x<235-edge.r,'dash cannot tunnel through obstacle');
for(const [x,y] of [[m.left,m.top],[m.right,m.top],[m.left,m.bottom],[m.right,m.bottom]]){edge.x=x;edge.y=y;move(edge,x<W/2?-590:590,y<H/2?-590:590,.26);check(edge.x===x&&edge.y===y,'corner stays in bounds');move(edge,x<W/2?100:-100,y<H/2?100:-100,.1);check(edge.x!==x&&edge.y!==y,'can leave corner');}
fresh();const fighter=players[0],enemy=players[1];fighter.x=150;fighter.y=300;fighter.angle=0;enemy.x=800;enemy.y=300;bullets=[];
for(let i=0;i<5;i++)spawnBullet(enemy,Math.PI,{gun:0,x:180+i,y:300});spawnBullet(enemy,0,{gun:0,x:120,y:300});spawnBullet(fighter,0,{gun:0,x:180,y:300});const invBefore=fighter.inv;melee(fighter);check(bullets.length===4&&bullets.some(b=>b.x===120)&&bullets.some(b=>b.owner===0),'melee clears only three forward enemy shots');check(fighter.inv===invBefore&&fighter.shot>=.3&&fighter.melee===1.1,'melee gives no immunity and has recovery');melee(fighter);check(bullets.length===4,'melee cooldown prevents spam');draw();
fresh();const shooter=players[0];shooter.x=150;shooter.y=300;shooter.angle=0;
for(const id of [11,12,13,14,15]){shooter.inventory=[makeWeapon(id)];shooter.active=0;shooter.shot=0;bullets=[];fire(shooter);check(bullets.length===(guns[id].count||1),'new weapon volley');if(id===11){for(let i=0;i<40;i++)updateBullets(.016);check(bullets.some(b=>b.vx===0&&b.vy===0),'seed stops');}if(id===12){updateBullets(.1);check(Math.hypot(bullets[0].vx,bullets[0].vy)>130,'pencil accelerates');}if(id===13){for(let i=0;i<65;i++)updateBullets(.016);check(bullets.some(b=>b.launched),'bubble launches after delay');}if(id===14){for(let i=0;i<51;i++)updateBullets(.016);check(bullets.filter(b=>b.shard).length===4,'clover splits four ways');}draw();}
for(let c=0;c<characters.length;c++){selectedChars=[c,c];startMatch();selectGun(1);selectGun(1);completeShop();const hero=players[0],stats=characters[c];check(hero.hp===stats.hp&&hero.blanks===stats.blanks,'character durability and blanks');roll(hero);check(hero.dodge===stats.dodge,'character dodge');hero.roll=0;weapon(hero).clip=0;reload(hero);check(Math.abs(hero.reload-1.15*stats.reload)<.001,'character reload');hero.reload=0;hero.x=170;hero.y=300;keys={KeyD:true};updatePlayer(hero,.01);check(Math.abs(hero.x-170-stats.speed*.01)<.001,'character speed');keys={};}
selectedChars=[2,3];startMatch();selectGun(1);selectGun(1);completeShop();endRound();check(scores[0]===0&&scores[1]===0,'full-health timeout fair across different max HP');

fresh();const actor=players[0];actor.shot=0;actor.roll=0;fire(actor);check(actor.recoil===1&&actor.muzzle>0,'shot triggers recoil and flash');updatePlayer(actor,.01);check(actor.recoil<1&&actor.muzzle<.075,'shot animation decays');
for(let c=0;c<characters.length;c++){actor.char=c;for(const angle of [0,Math.PI,-Math.PI/2,Math.PI/2]){actor.angle=angle;actor.moving=true;for(const phase of [0,Math.PI/2,Math.PI,Math.PI*1.5]){actor.walk=phase;drawPlayer(actor,1)}}}
let sources=0;
function param(){return {value:0,setValueAtTime(v){check(Number.isFinite(v),'finite audio parameter')},exponentialRampToValueAtTime(v){check(v>0,'positive exponential audio ramp')}}}
function audioNode(){return {connect(){},disconnect(){},start(){sources++},stop(){},frequency:param(),gain:param(),threshold:param(),ratio:param()}}
window.AudioContext=class{state='running';sampleRate=8000;currentTime=0;destination={};createBuffer(c,n){return {getChannelData:()=>new Float32Array(n)}}createDynamicsCompressor(){return audioNode()}createBufferSource(){return audioNode()}createBiquadFilter(){return audioNode()}createGain(){return audioNode()}createOscillator(){return audioNode()}};
sound=true;for(let g=0;g<guns.length;g++)combatSound('shot',g);for(const kind of ['boom','reload','dodge','slash','hit'])combatSound(kind);check(sources===(guns.length+5)*2,'all combat sound profiles start noise and body layers');sound=false;

fresh();nextRound();selectGun(1);selectGun(3);check(state==='shop','draft opens shop');
const frozen=time;update(2);check(time===frozen,'shop freezes simulation');
check(!buyShop(1,0),'wrong player blocked');
shopOffers=[{kind:'weapon',id:16,price:45},{kind:'relic',id:6,price:40},{kind:'weapon',id:19,price:60}];
check(buyShop(0,0)&&credits[0]===55,'purchase debits');check(!buyShop(0,0)&&credits[0]===55,'duplicate blocked');check(!buyShop(0,2),'overspending blocked');check(buyShop(0,1)&&credits[0]===15,'second purchase');check(!buyShop(0,2),'two purchase cap');readyShop();check(state==='shop'&&shopTurn===1,'wait for P2');check(buyShop(1,0)&&credits[1]===55,'separate stock');readyShop();check(state==='play','both ready launches');check(!buyShop(1,1),'no purchases in combat');scores=[0,2];nextRound();check(credits[0]===130&&credits[1]===100&&players[0].relics.length===0,'reset and capped comeback budget');
fresh();let testp=players[0];testp.inventory=[makeWeapon(0)];testp.active=0;testp.shot=0;testp.relics=[6,7];bullets=[];fire(testp);check(Math.abs(bullets[0].damage-guns[0].damage*1.38)<.001,'heavy and starter combine');check(Math.abs(Math.hypot(bullets[0].vx,bullets[0].vy)-guns[0].speed*.8)<.001,'heavy speed tradeoff');
fresh();testp=players[0];testp.relics=[8];weapon(testp).clip=0;const reserve=weapon(testp).reserve;equipSlot(testp,0);check(testp.inventory[1].clip===1&&testp.inventory[1].reserve===reserve-1,'holster transfers finite ammo');equipSlot(testp,1);check(testp.holster===1.5,'holster cooldown');
fresh();testp=players[0];testp.relics=[9];bullets=[];const blanks=testp.blanks;blank(testp);check(bullets.length===6&&testp.blanks===blanks-1,'relay uses one pulse');
fresh();testp=players[0];testp.inventory=[makeWeapon(18)];testp.active=0;testp.shot=0;weapon(testp).clip=2;reload(testp);finishReload(testp);testp.reload=0;check(weapon(testp).mode===1,'reload toggles spanner');bullets=[];fire(testp);check(bullets.length===3,'spanner scatter mode');
fresh();testp=players[0];testp.inventory=[makeWeapon(19)];testp.active=0;testp.shot=0;bullets=[];fire(testp);check(bullets.length===1&&delayedShots.length===1,'echo queued');update(.25);check(delayedShots.length===0&&weapon(testp).clip===5&&bullets.length===2,'echo second shot without extra ammo');
fresh();testp=players[0];testp.inventory=[makeWeapon(17)];testp.active=0;testp.shot=0;weapon(testp).clip=1;bullets=[];fire(testp);check(bullets[0].parcel,'last parcel special');explode(bullets[0]);check(bullets.filter(b=>b.shard).length===5,'parcel five fragments');

fresh();testp=players[0];testp.relics=[11];bullets=[];spawnBullet(testp,Math.PI,{gun:16,x:34,y:300});const speedBefore=Math.hypot(bullets[0].vx,bullets[0].vy);updateBullets(.02);check(bullets[0].rebounds===1&&Math.abs(bullets[0].damage-.9)<.001&&Math.abs(Math.hypot(bullets[0].vx,bullets[0].vy)-speedBefore*1.2)<.001,'bank and rebound on wall');
fresh();testp=players[0];testp.relics=[10];testp.dodge=1;testp.angle=0;bullets=[];for(let i=0;i<3;i++)spawnBullet(players[1],Math.PI,{gun:0,x:testp.x+30+i,y:testp.y});melee(testp);check(Math.abs(testp.dodge-.7)<.001,'dynamo once per swing');
fresh();testp=players[0];testp.inventory=[makeWeapon(19)];testp.active=0;testp.shot=0;fire(testp);blank(players[1]);check(delayedShots.length===0,'pulse cancels queued echo');
fresh();weaponEffects=[];weaponEffect(0,100,100);pause();update(.1);check(weaponEffects[0].age===0,'VFX respects pause');pause();update(.1);drawWeaponEffects();update(.3);check(weaponEffects.length===0,'VFX expires');for(let i=0;i<50;i++)weaponEffect(i%4,100,100);check(weaponEffects.length===40,'VFX bounded');nextRound();check(weaponEffects.length===0,'VFX cleared between rounds');
fresh();for(const id of [16,17,18,19]){const b={gun:id,parcel:id===17,shard:false,age:0,x:100,y:100,vx:200,vy:0};check(projectileRow(b)===id-16,'projectile art mapping');for(let frame=0;frame<8;frame++){b.age=frame/12;b.vy=frame%2?100:-100;check(drawProjectileSprite(b),'animated projectile rendering')}}check(projectileRow({gun:17,parcel:false})===-1&&projectileRow({gun:16,shard:true})===-1,'normal parcel rounds and fragments retain original rendering');projectileSprite.complete=false;check(!drawProjectileSprite({gun:16}),'unloaded sprite uses fallback');projectileSprite.complete=true;
console.log('PASS: finite inventory/reload/cancel, loot ownership, 4 weapon slots, 3 relic cap, relic effects, 20 weapons, shop budgets/readiness/reset, boundaries/recovery, melee limits, character stats, gravity/blank, timed S loot, pause, round reset, timeout, CPU match');
`,sandbox);
