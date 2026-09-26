"""Package unmodified source images in an offline, size-normalized review."""
import base64
from pathlib import Path
p=Path(__file__).resolve().parent
root=p.parents[3]
images=[root/'assets/first-workshop/rina-directions/front.png',p/'redraw-standing.png']
data=['data:image/png;base64,'+base64.b64encode(i.read_bytes()).decode() for i in images]
html='''<!doctype html><html lang="ja"><meta charset="utf-8"><title>リナ・立ち絵の再生成</title><style>body{background:#19262e;color:#e7eded;font:16px system-ui;margin:28px}main{max-width:960px;margin:auto}p{color:#b4c6c9}canvas{background:#293d46;max-width:100%;border-radius:12px}</style><main><h1>リナ・立ち絵からの再設計</h1><p>左：本編の現行素材 ／ 右：新しく生成した立ち絵。全高を揃えた静止比較です。</p><canvas width="960" height="500"></canvas><p>上：4倍表示 ／ 下：通常サイズ56px。新しい立ち絵はパーツ化・本編接続前です。</p></main><script>
const urls=IMAGES,c=document.querySelector('canvas').getContext('2d');
Promise.all(urls.map(async u=>{let i=new Image();i.src=u;await i.decode();let a=document.createElement('canvas');a.width=i.width;a.height=i.height;let x=a.getContext('2d');x.drawImage(i,0,0);let d=x.getImageData(0,0,a.width,a.height).data,l=a.width,t=a.height,r=0,b=0;for(let y=0;y<a.height;y++)for(let z=0;z<a.width;z++)if(d[(y*a.width+z)*4+3]>20){l=Math.min(l,z);r=Math.max(r,z);t=Math.min(t,y);b=Math.max(b,y)}return {i,l,t,w:r-l+1,h:b-t+1}})).then(arr=>{arr.forEach((a,n)=>{let x=250+n*460;c.fillStyle='#e7eded';c.font='18px system-ui';c.textAlign='center';c.fillText(n?'再生成・立ち絵':'本編の現行素材',x,40);for(let [s,y] of [[4,310],[1,445]])c.drawImage(a.i,a.l,a.t,a.w,a.h,x-a.w/a.h*56*s/2,y-56*s,a.w/a.h*56*s,56*s)});c.font='14px system-ui';c.fillText('通常サイズ 56px',480,370)});
</script></html>'''
import json
(p/'standing-review.html').write_text(html.replace('IMAGES',json.dumps(data)),encoding='utf-8')
