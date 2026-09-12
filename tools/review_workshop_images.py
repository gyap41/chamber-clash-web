"""Build contact sheets at actual runtime sizes from locally processed originals."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/first-workshop'
LEGACY=ROOT/'docs/archive/2026-09-12/art-organization/unused-candidates/superseded-assets/first-workshop'
OUT=ROOT/'docs/archive/2026-09-12/first-workshop'
OUT.mkdir(parents=True,exist_ok=True)
panel=Image.new('RGB',(840,440),'#424b4b')
draw=ImageDraw.Draw(panel)
for row,name in enumerate(['idle','move','roll']):
    path=LEGACY/(('move-corrected' if name=='move' else name)+'.png')
    if not path.exists(): continue
    sheet=Image.open(path).convert('RGBA')
    draw.text((12,10+row*120),name,fill='white')
    for i in range(sheet.width//128):
        cell=sheet.crop((i*128,0,(i+1)*128,128))
        cell=cell.resize((128,84),Image.Resampling.LANCZOS)
        panel.paste(cell,(35+i*130,32+row*120),cell)
        draw.text((90+i*130,112+row*120),str(i),fill='white')
panel.save(OUT/'animation-contact-sheet.png')
print('Saved actual-size contact sheet')
props=Image.new('RGB',(840,130),'#424b4b')
pd=ImageDraw.Draw(props)
for i,(name,size) in enumerate([('bullet',(18,8)),('muzzle',(22,16)),('impact',(22,22)),('trail',(42,25)),('ammo',(40,36)),('pistol',(28,22))]):
    path=ASSETS/(name+'.png')
    if not path.exists(): continue
    pic=Image.open(path).convert('RGBA').resize(size,Image.Resampling.LANCZOS)
    props.paste(pic,(60+i*130-size[0]//2,55-size[1]//2),pic)
    pd.text((25+i*130,95),name,fill='white')
props.save(OUT/'props-actual-size.png')
if all((OUT/f'roll-{i:02d}.png').exists() for i in range(6)):
    frames=[]
    for i in range(78):
        time=i*.02
        frame=Image.new('RGB',(660,204),'#192126')
        fd=ImageDraw.Draw(frame)
        for j,name in enumerate(['idle','move','roll']):
            index=int(time*3)%4 if name=='idle' else (int(time*10)%6 if name=='move' else min(5,int((time%.26)/.26*6)))
            shot=Image.open(OUT/f'{name}-{index:02d}.png')
            crop=shot.crop((320,342,430,430)).resize((220,176),Image.Resampling.NEAREST)
            frame.paste(crop,(j*220,25))
            fd.text((j*220+12,7),name+' (2x)',fill='white')
        frames.append(frame)
    frames[0].save(OUT/'pose-preview.gif',save_all=True,append_images=frames[1:],duration=20,loop=0)
