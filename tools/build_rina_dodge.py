"""Extract dedicated generated dodge poses; preserve originals and shared scale."""
from pathlib import Path
import json, hashlib
from PIL import Image, ImageDraw
from process_workshop_images import key_alpha

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/first-workshop/rina-dodge'
REVIEW=ROOT/'docs/art/reviews/rina-dodge-2026-09-12'
# A shared physical scale for all nine poses, reviewed against the standing head.
SCALE=.9

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    source=ROOT/'assets/generated/fw-rina-dodge-poses-v1.png'
    art=key_alpha(Image.open(source))
    records=[]
    preview=Image.new('RGB',(1024,900),'#405055')
    draw=ImageDraw.Draw(preview)
    for row,view in enumerate(['front','back','side']):
        for stage in range(3):
            rect=(stage*1024//3,row*1024//3,(stage+1)*1024//3,(row+1)*1024//3)
            cell=art.crop(rect)
            bounds=cell.getbbox()
            if not bounds: raise ValueError('Empty pose')
            tile=cell.crop(bounds)
            size=(round(tile.width*SCALE),round(tile.height*SCALE))
            # Feet/hands contact the same plane. Flight has its own drawn posture
            # and receives a small smooth lift in Godot, without rotating the art.
            offset=(256-size[0]//2,320-size[1])
            assert offset[0]>=0 and offset[1]>=0
            result=Image.new('RGBA',(512,384))
            result.alpha_composite(tile.resize(size,Image.Resampling.LANCZOS),offset)
            result.save(OUT/f'{view}-{stage}.png')
            thumb=result.resize((384,288),Image.Resampling.LANCZOS)
            preview.paste(thumb,(stage*341-21,row*300),thumb)
            draw.text((stage*341+15,row*300+15),f'{view}: '+['takeoff','dive','landing'][stage],fill='white')
            records.append(dict(view=view,stage=stage,source_rect=rect,crop=bounds,offset=offset))
    preview.save(REVIEW/'poses.png')
    (OUT/'manifest.json').write_text(json.dumps(dict(original=source.relative_to(ROOT).as_posix(),
        sha256=hashlib.sha256(source.read_bytes()).hexdigest(),cell=[512,384],origin=[256,320],
        scale=SCALE,poses=records,method='Chroma key; one shared scale; bottom contact alignment; no anatomy redraw'),indent=2)+'\n')
    print('Extracted nine Rina dodge poses with one shared scale.')

if __name__=='__main__': main()
