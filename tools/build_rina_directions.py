"""Chroma-key and fixed-part extraction of the matched game turnaround; no API."""
from pathlib import Path
import json, hashlib
from PIL import Image, ImageDraw, ImageChops
from process_workshop_images import key_alpha

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/first-workshop/rina-directions'
REVIEW=ROOT/'docs/art/reviews/rina-directions-2026-09-12'
RECTS=[(0,0,357,1024),(357,0,683,1024),(683,0,1024,1024)]
FEET=[
    [[(108,645),(155,655),(166,671),(132,680),(106,673)],
     [(203,654),(248,643),(261,663),(248,677),(214,679)]],
    [[(445,649),(487,656),(502,672),(478,680),(444,676)],
     [(545,656),(585,649),(599,672),(576,682),(545,678)]],
    [[(824,660),(858,665),(884,661),(904,674),(892,688),(823,688)],
     [(876,647),(913,643),(929,657),(921,671),(884,672)]]]

def main():
    OUT.mkdir(exist_ok=True,parents=True)
    source=ROOT/'assets/generated/fw-rina-directions-v1.png'
    im=key_alpha(Image.open(source))
    boxes=[im.crop(rect).getbbox() for rect in RECTS]
    scale=224/max(b[3]-b[1] for b in boxes)
    contact=Image.new('RGB',(1024,340),'#405055'); d=ImageDraw.Draw(contact)
    records=[]
    for index,name in enumerate(['front','back','side']):
        rect=RECTS[index]; bbox=boxes[index]
        tile=im.crop(rect).crop(bbox)
        size=(round(tile.width*scale),round(tile.height*scale))
        offset=((256-size[0])//2,240-size[1])
        def export(part,label):
            out=Image.new('RGBA',(256,256))
            out.alpha_composite(part.resize(size,Image.Resampling.LANCZOS),offset)
            out.save(OUT/(name+label+'.png'))
            return out
        full=export(tile,'')
        masks=[]
        for foot,polygon in enumerate(FEET[index]):
            mask=Image.new('L',tile.size)
            points=[(x-rect[0]-bbox[0],y-bbox[1]) for x,y in polygon]
            ImageDraw.Draw(mask).polygon(points,fill=255)
            masks.append(mask)
            part=tile.copy(); part.putalpha(ImageChops.multiply(part.getchannel('A'),mask))
            export(part,'-foot-'+str(foot))
        body=tile.copy()
        body.putalpha(ImageChops.multiply(body.getchannel('A'),ImageChops.invert(ImageChops.lighter(*masks))))
        export(body,'-body')
        # Anchor to the support area of the feet, not the hair/backpack silhouette.
        foot_alpha=ImageChops.lighter(*[Image.open(OUT/(name+'-foot-'+str(f)+'.png')).getchannel('A') for f in range(2)])
        foot_bounds=foot_alpha.point(lambda a:255 if a>96 else 0).getbbox()
        shift=(round(128-(foot_bounds[0]+foot_bounds[2])/2),240-foot_bounds[3])
        for suffix in ['', '-body', '-foot-0', '-foot-1']:
            path=OUT/(name+suffix+'.png')
            original=Image.open(path).convert('RGBA')
            anchored=Image.new('RGBA',(256,256)); anchored.alpha_composite(original,shift)
            anchored.save(path)
            if suffix=='': full=anchored
        for n,(label,art) in enumerate([(name,full)]):
            contact.paste(art,(index*256,40),art); d.text((index*256+10,15),label,fill='white')
        if name=='side':
            left=full.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            contact.paste(left,(768,40),left); d.text((778,15),'left (mirrored)',fill='white')
        records.append(dict(view=name,source_rect=rect,crop=bbox,scale=scale,offset=offset,
                            ground_translation=shift,foot_bounds_before=foot_bounds,feet=FEET[index]))
    contact.save(REVIEW/'directions.png')
    (OUT/'manifest.json').write_text(json.dumps(dict(original=source.relative_to(ROOT).as_posix(),
        sha256=hashlib.sha256(source.read_bytes()).hexdigest(),cell=[256,256],origin=[128,240],
        scale=scale,views=records,method='One shared scale; translation aligns soles; fixed foot polygons; no anatomy deformation'),indent=2)+'\n')
    print('Extracted matched front/back/side and fixed feet with one shared scale.')

if __name__=='__main__': main()
