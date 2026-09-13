"""Derive approved equipment from preserved sheets; no network or generation.

Run with Pillow. Optional sheet name processes only that completed sheet.
Runtime images are small; originals and review boards remain export-excluded.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from process_workshop_images import key_alpha

ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / 'docs/art/production/equipment-rollout-2026-09-12/plan.json'
OUT = ROOT / 'docs/art/reviews/equipment-rollout-2026-09-12'
RUNTIME = ROOT / 'assets/first-workshop/equipment'


def empty_cut(alpha, nominal, axis):
    # Choose a truly empty divider near the nominal cell edge. A zero-pixel
    # gutter prevents adjacent objects being included or a cap being clipped.
    candidates = sorted(range(nominal-64, nominal+65), key=lambda n: abs(n-nominal))
    for n in candidates:
        rect = (n-3, 0, n+4, alpha.height) if axis == 0 else (0, n-3, alpha.width, n+4)
        if alpha.crop(rect).getbbox() is None:
            return n
    raise ValueError(f'No clear gutter near {nominal}; inspect before cropping')


def process(batch, catalog):
    source = ROOT / 'assets/generated' / (batch['name']+'.png')
    original = Image.open(source).convert('RGBA')
    im = key_alpha(original)
    if batch['name']=='fw-diverse-guns-03-v1':
        # The enclosed helix chamber intentionally contains bright purple light.
        rect=(208,194,410,266)
        im.paste(original.crop(rect),rect[:2])
    if batch['name']=='fw-equipment-rollout-guns-03':
        # The gravity core is purple, unlike the requested palette. It is fully
        # enclosed by metal, so retain its original pixels instead of chroma-keying it.
        keep=Image.new('L',original.size)
        ImageDraw.Draw(keep).ellipse((177,632,260,721),fill=255)
        im.paste(original,(0,0),keep)
    alpha = im.getchannel('A').point(lambda v: 255 if v > 96 else 0)
    grid = 2 if batch['kind'] == 'guns' else 3
    rows = [0]+[empty_cut(alpha, im.height*i//grid, 1) for i in range(1,grid)]+[im.height]
    folder = OUT / batch['kind']; folder.mkdir(parents=True, exist_ok=True)
    runtime = RUNTIME / batch['kind']; runtime.mkdir(parents=True, exist_ok=True)
    records = []
    for i, item_id in enumerate(batch['ids']):
        row = i//grid
        band = alpha.crop((0, rows[row], im.width, rows[row+1]))
        columns = [0]+[empty_cut(band, im.width*j//grid, 0) for j in range(1,grid)]+[im.width]
        cell = (columns[i%grid], rows[row], columns[i%grid+1], rows[row+1])
        if batch['name']=='fw-equipment-rollout-guns-01' and item_id==1:
            # Reference-independent bounce illustration is detached from the gun.
            # Keep the whole muzzle and discard only the separate demonstration.
            cell=(cell[0],cell[1],823,cell[3])
        tile = im.crop(cell)
        box = tile.getbbox()
        if box is None or min(box[0],box[1],tile.width-box[2],tile.height-box[3]) < 2:
            raise ValueError(f'Empty or clipped asset {batch["kind"]}/{item_id}: {box}')
        crop = tile.crop(box)
        mirrored = batch['name']=='fw-diverse-guns-05-v1' and item_id==18
        mirrored = mirrored or (batch['name']=='fw-diverse-guns-06-v1' and item_id==28)
        if mirrored: crop=crop.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        rotation = -90 if batch['name']=='fw-diverse-guns-02-v1' and item_id==11 else 0
        if batch['name']=='fw-diverse-guns-03-v1' and item_id==14: rotation=-45
        if batch['name']=='fw-diverse-guns-04-v1' and item_id==2: rotation=120
        if batch['name']=='fw-diverse-guns-04-v1' and item_id==33: rotation=-90
        if rotation:
            crop=crop.rotate(rotation,expand=True,resample=Image.Resampling.BICUBIC)
            crop=crop.crop(crop.getbbox())
        crop.save(folder / f'{item_id:02d}.png')
        small = crop.copy()
        small.thumbnail((256,192) if batch['kind']=='guns' else (88,88), Image.Resampling.LANCZOS)
        if batch['kind']=='relics':
            canvas = Image.new('RGBA',(96,96))
            canvas.alpha_composite(small,((96-small.width)//2,(96-small.height)//2))
            small=canvas
        small.save(runtime / f'{item_id:02d}.png')
        if batch['kind'] == 'guns' and item_id == 4 and (ROOT / 'assets/generated/doubleback-body-v2.png').exists():
            # Preserve the approved single-weapon revision on historical repacks.
            from package_doubleback_body import main as restore_doubleback
            restore_doubleback()
        records.append(dict(id=item_id, kind=batch['kind'], name=catalog[batch['kind']][item_id]['name'],
                            source=source.relative_to(ROOT).as_posix(), sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                            cell=cell, crop=box, mirrored=mirrored, rotation_degrees=rotation, runtime=(runtime / f'{item_id:02d}.png').relative_to(ROOT).as_posix()))
    return records


def board(records, name):
    columns=4
    im=Image.new('RGB',(1200,70+240*((len(records)+columns-1)//columns)),'#172330')
    draw=ImageDraw.Draw(im)
    font=ImageFont.truetype('C:/Windows/Fonts/meiryo.ttc',16)
    draw.text((18,15),name+' / 上：拡大　下：40×30・24px枠と3倍拡大',font=font,fill='white')
    for i,r in enumerate(records):
        x=i%columns*300;y=65+i//columns*240
        draw.rounded_rectangle((x+6,y,x+294,y+232),8,fill='#28394a')
        draw.text((x+14,y+7),f'{r["id"]:02d} {r["name"]}',font=font,fill='white')
        crop=Image.open(OUT/r['kind']/f'{r["id"]:02d}.png').convert('RGBA')
        large=crop.copy();large.thumbnail((258,120),Image.Resampling.LANCZOS)
        im.paste(large,(x+(300-large.width)//2,y+35+(120-large.height)//2),large)
        tiny=crop.copy();tiny.thumbnail((40,30) if r['kind']=='guns' else (24,24),Image.Resampling.LANCZOS)
        im.paste(tiny,(x+44,y+190-tiny.height//2),tiny)
        zoom=tiny.resize((tiny.width*3,tiny.height*3),Image.Resampling.NEAREST)
        im.paste(zoom,(x+130,y+190-zoom.height//2),zoom)
    im.save(OUT/(name+'.png'))


def main():
    parser=argparse.ArgumentParser();parser.add_argument('sheet',nargs='?');args=parser.parse_args()
    plan=json.loads(PLAN.read_text(encoding='utf-8'))
    catalog=json.loads((ROOT/'data/catalog.json').read_text(encoding='utf-8'))
    records=[]
    for batch in plan['batches']:
        if args.sheet and args.sheet!=batch['name']: continue
        records.extend(process(batch,catalog))
    OUT.mkdir(parents=True,exist_ok=True)
    recipe=OUT/((args.sheet+'-extraction.json') if args.sheet else 'extraction.json')
    recipe.write_bytes((json.dumps(records,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
    for kind in ['guns','relics']:
        selected=[r for r in records if r['kind']==kind]
        for start in range(0,len(selected),16):
            board(selected[start:start+16],(args.sheet or kind)+f'-review-{start//16+1}')
    print(f'Packaged {len(records)} equipment assets')


if __name__=='__main__': main()
