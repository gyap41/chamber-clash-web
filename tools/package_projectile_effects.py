"""Extract approved projectile/VFX sheets. Pillow only; no API calls."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw
from package_diverse_equipment import key_magenta

ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / 'docs/art/production/projectile-effects-2026-09-13/plan.json'
OUT = ROOT / 'assets/first-workshop/projectiles'
REVIEW = ROOT / 'docs/art/reviews/projectile-effects-2026-09-13'

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    plan = json.loads(PLAN.read_text(encoding='utf-8'))
    for batch in plan['batches']:
        if len(sys.argv)>1 and batch['name']!=sys.argv[1]: continue
        source = ROOT/'assets/generated'/f"{batch['name']}.png"
        if not source.exists(): continue
        art = key_magenta(Image.open(source))
        cols, rows = batch['grid']
        w, h = art.width//cols, art.height//rows
        cuts=[]
        alpha=art.getchannel('A')
        for axis,count,step in [(0,cols,w),(1,rows,h)]:
            bounds=[0]
            for i in range(1,count):
                candidates=[]
                for n in range(i*step-60,i*step+61):
                    strip=alpha.crop((n-3,0,n+4,art.height) if axis==0 else (0,n-3,art.width,n+4))
                    if strip.point(lambda v:255 if v>160 else 0).getbbox() is None:candidates.append(n)
                bounds.append(min(candidates,key=lambda n:abs(n-i*step)) if candidates else i*step)
            bounds.append(art.width if axis==0 else art.height);cuts.append(bounds)
        records=[]
        board=Image.new('RGB',(1024,1024),'#34434b')
        draw=ImageDraw.Draw(board)
        for index in range(cols*rows):
            if 'cells' in batch and index>=len(batch['cells']): continue
            x,y=index%cols,index//cols
            region=(cuts[0][x],cuts[1][y],cuts[0][x+1],cuts[1][y+1])
            cell=art.crop(region)
            box=cell.getbbox()
            if box is None: raise ValueError(f"Empty cell: {batch['name']} {index}")
            # Reject solid content at cell edges. Faint keyed fringe is excluded.
            solid=cell.getchannel('A').point(lambda a:255 if a>160 else 0).getbbox()
            if solid and (solid[0]<2 or solid[1]<2 or solid[2]>cell.width-2 or solid[3]>cell.height-2):
                raise ValueError(f"Clipped cell: {batch['name']} {index} {solid}")
            preview=cell.copy();preview.thumbnail((210,190))
            px,py=x*256+(256-preview.width)//2,y*(1024//rows)+30
            board.paste(preview,(px,py),preview)
            if 'rows' in batch:
                key=f"impact_{batch['rows'][y]}"
                label=f'{key} / {x}'
            else:
                key=str(batch['cells'][index])
                if key.isdigit():key=f'{int(key):02d}'
                if 'muzzles' in batch['name']:key='muzzle_'+key
                label=key
                tight=cell.crop(box)
                tight.thumbnail((96,96),Image.Resampling.LANCZOS)
                tight.save(OUT/f'{key}.png')
                small=tight.copy();small.thumbnail((20,16))
                board.paste(small,(x*256+115,y*(1024//rows)+225),small)
            draw.text((x*256+12,y*(1024//rows)+8),label,fill='white')
            records.append(dict(key=key,cell=index,source_box=region,alpha_box=box))
        if 'rows' in batch:
            for y,family in enumerate(batch['rows']):
                strip=Image.new('RGBA',(512,128))
                first=art.crop((cuts[0][0],cuts[1][y],cuts[0][1],cuts[1][y+1]))
                box=first.getbbox()
                origin_x=(box[0]+box[2])/2
                origin_y=cuts[1][y]+(box[1]+box[3])/2
                for x in range(4):
                    region=(cuts[0][x],cuts[1][y],cuts[0][x+1],cuts[1][y+1])
                    canvas=Image.new('RGBA',(320,320))
                    canvas.alpha_composite(art.crop(region),(round(region[0]-(x*w+origin_x)+160),round(region[1]-origin_y+160)))
                    frame=canvas.resize((128,128),Image.Resampling.LANCZOS)
                    strip.paste(frame,(x*128,0))
                strip.save(OUT/f'impact_{family}.png')
        board.save(REVIEW/f"{batch['name']}-review.png")
        (REVIEW/f"{batch['name']}-extraction.json").write_text(json.dumps(records,indent=2)+'\n',encoding='utf-8')
        print('Packaged',batch['name'])

if __name__=='__main__':main()
