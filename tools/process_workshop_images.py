"""Deterministic local derivation of preserved API originals; no API calls.
Run with the bundled Python/Pillow runtime. Processing recipes are recorded in manifest.
"""
import argparse
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/first-workshop'

def key_alpha(im):
    im = im.convert('RGBA')
    pixels = []
    for r,g,b,a in im.get_flattened_data():
        # Magenta dominance is absent from the specified ivory/teal/amber palette.
        dominance = min(r,b)-g
        alpha = max(0, min(255, int((100-dominance)*255/65)))
        if dominance > 35:
            r, b = min(r,g+30), min(b,g+30)
        pixels.append((r,g,b,min(a,alpha)))
    im.putdata(pixels)
    return im

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('name')
    parser.add_argument('--mode',choices=['floor','object','sheet','icons'],default='object')
    parser.add_argument('--grid',nargs=2,type=int,default=[1,1])
    parser.add_argument('--count',type=int,default=1)
    args = parser.parse_args()
    source = ROOT / 'assets/generated' / ('fw-'+args.name+'.png')
    im = Image.open(source)
    recipe = dict(id=args.name,original=str(source.relative_to(ROOT)),mode=args.mode,grid=args.grid)
    if args.mode == 'floor':
        output = DEST/(args.name+'.png')
        im.convert('RGB').save(output)
        recipe.update(output=str(output.relative_to(ROOT)),display='1120x600 field rectangle')
    else:
        im = key_alpha(im)
        if args.mode == 'object':
            box = im.getbbox()
            if not box: raise ValueError('Empty alpha extraction')
            output = DEST/(args.name+'.png')
            derived = im.crop(box)
            derived.thumbnail((256,256) if args.name in ['rina','cover'] else (128,128),Image.Resampling.LANCZOS)
            derived.save(output)
            recipe.update(crop=list(box),output=str(output.relative_to(ROOT)),size=list(derived.size),resample='Lanczos')
        elif args.mode == 'icons':
            outputs=[]
            for i,name in enumerate(['dodge','melee','pulse']):
                cell=im.crop((i*im.width//3,0,(i+1)*im.width//3,im.height))
                box=cell.getbbox()
                if box is None: raise ValueError('Empty HUD icon')
                icon=cell.crop(box)
                icon.thumbnail((60,60),Image.Resampling.LANCZOS)
                canvas=Image.new('RGBA',(64,64))
                canvas.alpha_composite(icon,((64-icon.width)//2,(64-icon.height)//2))
                output=DEST/(name+'.png')
                canvas.save(output)
                outputs.append(dict(name=name,output=str(output.relative_to(ROOT)),source_cell=[i*im.width//3,0,im.width//3,im.height],crop=list(box)))
            recipe.update(outputs=outputs,display_size=[24,24])
        else:
            cols,rows=args.grid
            w,h=im.width//cols,im.height//rows
            output = DEST/(args.name+'.png')
            atlas=Image.new('RGBA',(128*args.count,128))
            frames=[]
            for i in range(args.count):
                tile=im.crop((i%cols*w,i//cols*h,(i%cols+1)*w,(i//cols+1)*h))
                box=tile.getbbox()
                if not box: raise ValueError('Empty animation frame')
                tile=tile.crop(box)
                if args.name == 'roll':
                    # Keep tucked poses smaller than the standing body, not scaled to full height.
                    tile=tile.resize((round(tile.width*.24),round(tile.height*.24)),Image.Resampling.LANCZOS)
                else:
                    tile.thumbnail((104,104),Image.Resampling.LANCZOS)
                xy=((128-tile.width)//2,112-tile.height)
                atlas.alpha_composite(tile,(128*i+xy[0],xy[1]))
                frames.append(dict(rect=[128*i,0,128,128],origin=[64,112],source_cell=[i%cols*w,i//cols*h,w,h],crop=list(box)))
            atlas.save(output)
            recipe.update(output=str(output.relative_to(ROOT)),frames=frames)
    manifest_path=DEST/'manifest.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    manifest['assets']=[a for a in manifest['assets'] if a['id']!=args.name]+[recipe]
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Processed '+str(output))

if __name__ == '__main__': main()
