"""Derive approved chibi sheets locally; preserve originals and record fixed scales."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw
from process_workshop_images import key_alpha

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/archive/2026-09-12/art-organization/unused-candidates/superseded-assets/chibi'
REVIEW = ROOT / 'docs/archive/2026-09-12/rina-chibi'

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    manifest = {'reference': 'assets/generated/fw-rina-chibi-concept.png',
                'cell': [128,128], 'origin': [64,112], 'assets': []}
    contact = Image.new('RGB',(840,900),'#384448')
    draw = ImageDraw.Draw(contact)
    previews = []
    for index,(name,cols,rows,count) in enumerate([('idle',4,2,4),('move',3,4,6),('roll',3,4,6)]):
        source = ROOT / f'assets/generated/fw-chibi-{name}.png'
        im = key_alpha(Image.open(source))
        tiles = []
        records = []
        for i in range(count*2):
            rect = (i%cols*im.width//cols,i//cols*im.height//rows,
                    (i%cols+1)*im.width//cols,(i//cols+1)*im.height//rows)
            tile = im.crop(rect)
            # Remove tiny alpha fringes before finding the content bounds.
            mask = tile.getchannel('A').point(lambda a: 255 if a >= 96 else 0)
            box = mask.getbbox()
            if box is None: raise ValueError('Empty frame')
            tiles.append(tile.crop(box))
            records.append({'source_cell':list(rect),'crop':list(box)})
        # One scale per sheet, never enlarge individual crouched/breathing frames.
        scale = min(104/max(t.width for t in tiles),104/max(t.height for t in tiles))
        sheet = Image.new('RGBA',(count*128,256))
        for i,tile in enumerate(tiles):
            tile = tile.resize((max(1,round(tile.width*scale)),max(1,round(tile.height*scale))),Image.Resampling.LANCZOS)
            x,y = (128-tile.width)//2,112-tile.height
            sheet.alpha_composite(tile,((i%count)*128+x,(i//count)*128+y))
            records[i].update(rect=[i%count*128,i//count*128,128,128],offset=[x,y])
        output = OUT / f'{name}.png'
        sheet.save(output)
        manifest['assets'].append({'id':name,'original':str(source.relative_to(ROOT)),
            'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'output':str(output.relative_to(ROOT)),
            'scale':scale,'frames':records,'adopted':name != 'move',
            'consumer':'review only: repeated leg poses' if name == 'move' else 'scripts/visuals/player_animation.gd'})
        for direction in range(2):
            y = index*300+direction*145
            draw.text((12,y+8),name+(' front' if direction==0 else ' back')+(' NOT ADOPTED' if name=='move' else ''),fill='white')
            for frame in range(count):
                tile = sheet.crop((frame*128,direction*128,(frame+1)*128,(direction+1)*128))
                contact.paste(tile,(30+frame*130,y+22),tile)
        previews.append((name,sheet,count))
        if name == 'idle':
            portrait = sheet.crop((0,0,128,128))
            portrait.crop(portrait.getbbox()).save(OUT/'rina.png')
    contact.save(REVIEW/'contact-sheet.png')
    frames=[]
    for tick in range(78):
        panel=Image.new('RGB',(660,350),'#384448')
        d=ImageDraw.Draw(panel)
        for col,(name,sheet,count) in enumerate(previews):
            frame=int(tick*.02*(3 if name=='idle' else 10))%count
            if name=='roll': frame=int((tick*.02%.26)/.26*6)%6
            d.text((col*220+10,8),name+(' NOT ADOPTED' if name=='move' else ' / front + back'),fill='white')
            for direction in range(2):
                tile=sheet.crop((frame*128,direction*128,(frame+1)*128,(direction+1)*128))
                panel.paste(tile,(col*220+46,25+direction*155),tile)
        frames.append(panel)
    frames[0].save(REVIEW/'pose-preview.gif',save_all=True,append_images=frames[1:],duration=20,loop=0)
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Saved chibi sheets, portrait, manifest and visual review')

if __name__ == '__main__': main()
