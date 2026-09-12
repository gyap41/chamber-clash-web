"""Non-generative export of setting sheets into separate reference panels."""
from pathlib import Path
import json, hashlib
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/art/settings/character-settings-2026-09-12'
NAMES=['00-rina','01-sora','02-kohaku','03-bolt','04-mei','05-luna','06-rattle','07-crow']

def split_column(im, target):
    # Find the paper gutter, not a cut through clothing. Final exports are reviewed.
    rgb=im.convert('RGB')
    def score(x):
        dark=sum(min(rgb.getpixel((x,y)))<170 for y in range(110,990,2))
        return dark*1000+abs(x-target)
    return min(range(target-60,target+61),key=score)

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    gallery=Image.new('RGB',(1040,1160),'#f6f1e7')
    gd=ImageDraw.Draw(gallery)
    mini=Image.new('RGB',(1040,270),'#f6f1e7')
    md=ImageDraw.Draw(mini)
    records=[]
    for i,name in enumerate(NAMES):
        source=ROOT/f'assets/generated/fw-character-{name}.png'
        if not source.exists(): continue
        im=Image.open(source).convert('RGB')
        cuts=[0,split_column(im,390),split_column(im,775),1024]
        folder=OUT/name; folder.mkdir(exist_ok=True)
        im.save(folder/'sheet.png')
        rects={}
        for j,label in enumerate(['front','back','chibi']):
            rect=(cuts[j],[60 if name=='02-kohaku' else 0,65,100][j],cuts[j+1],1024)
            panel=im.crop(rect)
            # Keep the setting-sheet paper; only trim empty margin around the outline.
            mask=panel.convert('L').point(lambda v:255 if v<180 else 0)
            box=mask.getbbox()
            if box:
                box=(max(0,box[0]-12),max(0,box[1]-12),min(panel.width,box[2]+12),min(panel.height,box[3]+12))
                panel=panel.crop(box)
            panel.save(folder/(label+'.png'))
            rects[label]={'source_rect':list(rect),'trim':list(box) if box else None}
            if label=='front':
                view=panel.copy(); view.thumbnail((235,515),Image.Resampling.LANCZOS)
                x=i%4*260+(260-view.width)//2; y=i//4*580+42
                gallery.paste(view,(x,y)); gd.text((i%4*260+20,i//4*580+16),name,fill='#302f2c')
            if label=='chibi':
                view=panel.copy(); view.thumbnail((115,160),Image.Resampling.LANCZOS)
                mini.paste(view,(i*130+(130-view.width)//2,230-view.height)); md.text((i*130+8,16),name,fill='#302f2c')
        im.crop((0,0,cuts[2],1024)).save(folder/'normal-proportions.png')
        metadata=json.loads(source.with_suffix('.json').read_text(encoding='utf-8'))
        records.append({'id':i,'name':name,'original':str(source.relative_to(ROOT)),
            'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'metadata':str(source.with_suffix('.json').relative_to(ROOT)),
            'pricing_estimate_usd':metadata['pricing_estimate_usd'],
            'prompt':f'docs/art/production/character-prompts/{name}.txt',
            'panels':rects,'game_integration':False})
    gallery.save(OUT/'normal-lineup.png'); mini.save(OUT/'chibi-lineup.png')
    (OUT/'manifest.json').write_text(json.dumps({'characters':records,
        'pricing_estimate_usd':sum(r['pricing_estimate_usd'] for r in records),
        'method':'gutter crops, paper background preserved; originals retained'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Exported {len(records)} character sheets and separate normal/chibi panels')

if __name__=='__main__': main()
