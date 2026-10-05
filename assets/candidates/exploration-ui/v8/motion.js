/* Shared deterministic timeline: milliseconds, independent of browser frame rate. */
const WorkshopMotion = (() => {
 const clamp = x => Math.max(0,Math.min(1,x));
 const smooth = x => {x=clamp(x);return x*x*(3-2*x)};
 function pose(ms,reduced=false) {
  ms=Math.max(0,Math.min(700,ms));
  const lid=smooth((ms-100)/350),power=smooth((ms-350)/250);
  return {ms,latch:smooth(ms/120),lid,angle:reduced?0:lid*96,
   scale:reduced?1:.78+.22*smooth((ms-80)/370),
   content:smooth((ms-430)/120),power,
   corePower:.3*smooth(ms/85)+.7*power,
   ready:ms>=500,settled:ms===700,closed:ms===0,
   stage:ms===0?'閉じた携帯工房':ms<120?'留め具を解除':ms<450?'蓋を展開':ms<600?'遺物核を起動':'起動完了'};
 }
 function advance(ms,target,dt,{slow=false,reduced=false}={}) {
  const duration=reduced?100:target===700?700:250;
  const delta=Math.max(0,dt)*700/duration/(slow?4:1);
  return target===700?Math.min(700,ms+delta):Math.max(0,ms-delta);
 }
 return {pose,advance};
})();
if(typeof module!=='undefined')module.exports=WorkshopMotion;
