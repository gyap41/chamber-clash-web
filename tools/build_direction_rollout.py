"""Extract twelve-pose sheets, with explicit shoe regions and ground anchors."""
from pathlib import Path
import json,hashlib,argparse
from PIL import Image,ImageDraw,ImageChops
from process_workshop_images import key_alpha
from prepare_direction_rollout import CHARACTERS
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/first-workshop/directional-characters'
REVIEW=ROOT/'docs/art/reviews/character-directions-2026-09-12'

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('name'); args=parser.parse_args()
    name=args.name
    source=ROOT/'assets/generated'/f'fw-directions-{name}.png'
    art=key_alpha(Image.open(source))
    recipe=json.loads((REVIEW/name/'extraction.json').read_text())
    folder=OUT/name; folder.mkdir(parents=True,exist_ok=True)
    crops=[]
    for row in range(3):
        for col in range(4):
            edges=recipe.get('column_edges',{}).get(str(row),[0,256,512,768,1024])
            row_edges=recipe.get('row_edges',[0,341,682,1024])
            rect=(edges[col],row_edges[row],edges[col+1],row_edges[row+1])
            cell=art.crop(rect); box=cell.getbbox()
            if not box: raise ValueError('Missing pose')
            crops.append((rect,box,cell.crop(box)))
    # Calibrate each view using its standing pose, then keep that exact scale
    # for all dodge stages in the view. Never independently fit shorter poses.
    scales=[min(224/crops[r*4][2].height,236/crops[r*4][2].width) for r in range(3)]
    records=[]
    preview=Image.new('RGB',(1024,780),'#405055'); draw=ImageDraw.Draw(preview)
    for row,view in enumerate(['front','back','side']):
        scale=scales[row]
        for col in range(4):
            rect,box,tile=crops[row*4+col]
            size=(round(tile.width*scale),round(tile.height*scale))
            if col==0:
                masks=[]
                for polygon in recipe[view]:
                    mask=Image.new('L',tile.size)
                    ImageDraw.Draw(mask).polygon([(x-rect[0]-box[0],y-rect[1]-box[1]) for x,y in polygon],fill=255)
                    masks.append(mask)
                parts={'':tile}
                for foot,mask in enumerate(masks):
                    piece=tile.copy(); piece.putalpha(ImageChops.multiply(tile.getchannel('A'),mask))
                    parts[f'-foot-{foot}']=piece
                body=tile.copy(); body.putalpha(ImageChops.multiply(tile.getchannel('A'),ImageChops.invert(ImageChops.lighter(*masks))))
                parts['-body']=body
                shoe_alpha=ImageChops.lighter(parts['-foot-0'].getchannel('A'),parts['-foot-1'].getchannel('A'))
                support=shoe_alpha.point(lambda a:255 if a>96 else 0).getbbox()
                if not support: raise ValueError('Missing shoe region')
                offset=(round(128-(support[0]+support[2])*.5*scale),round(240-support[3]*scale))
                for suffix,piece in parts.items():
                    result=Image.new('RGBA',(256,256)); result.alpha_composite(piece.resize(size,Image.Resampling.LANCZOS),offset)
                    result.save(folder/(view+suffix+'.png'))
                    if not suffix: full=result
                # Snap alpha support after resampling to avoid rounding artifacts.
                feet=[Image.open(folder/f'{view}-foot-{f}.png') for f in range(2)]
                bounds=ImageChops.lighter(*[f.getchannel('A') for f in feet]).point(lambda a:255 if a>96 else 0).getbbox()
                shift=(round(128-(bounds[0]+bounds[2])*.5),240-bounds[3])
                for suffix in parts:
                    path=folder/(view+suffix+'.png'); old=Image.open(path)
                    result=Image.new('RGBA',(256,256));result.alpha_composite(old,shift)
                    if view=='side' and recipe.get('mirror_side',False): result=result.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                    result.save(path)
                    if not suffix:full=result
                display=full
            else:
                offset=(256-size[0]//2,320-size[1])
                result=Image.new('RGBA',(512,384));result.alpha_composite(tile.resize(size,Image.Resampling.LANCZOS),offset)
                if view=='side' and recipe.get('mirror_side',False): result=result.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                result.save(folder/f'{view}-dodge-{col-1}.png')
                display=result.crop((128,80,384,336))
            preview.paste(display,(col*256,row*260),display)
            draw.text((col*256+5,row*260+3),view+' '+['idle','takeoff','active','land'][col],fill='white')
            records.append(dict(view=view,col=col,source_rect=rect,crop=box,offset=offset))
    preview.save(REVIEW/name/'processed.png')
    (folder/'manifest.json').write_text(json.dumps(dict(original=source.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        view_scales=scales,standing_cell=[256,256],standing_origin=[128,240],dodge_cell=[512,384],dodge_origin=[256,320],
        shoe_polygons=recipe,poses=records),indent=2)+'\n')
    print('Extracted '+name+' with standing-calibrated view scales and support anchors.')
if __name__=='__main__':main()
