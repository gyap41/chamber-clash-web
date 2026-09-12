"""Deterministic game cutouts from approved setting art. No API calls."""
from collections import deque
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/archive/2026-09-12/art-organization/unused-candidates/superseded-assets/characters'
NAMES = ['00-rina','01-sora','02-kohaku','03-bolt','04-mei','05-luna','06-rattle','07-crow']
HEAD_END = [.22,.23,.25,.33,.29,.27,.22,.23]
BODY_END = [.50,.48,.57,.63,.56,.70,.75,.54]
SHOE_START = [.94,.93,.91,.90,.95,.94,.91,.89]

def paper_alpha(source):
    im = source.convert('RGBA')
    w,h = im.size
    pixels = list(im.get_flattened_data())
    eligible = bytearray(int(a == 0 or (min(r,g,b)>140 and max(r,g,b)-min(r,g,b)<90))
                         for r,g,b,a in pixels)
    visited = bytearray(w*h)
    queue = deque()
    for i in list(range(w))+list(range((h-1)*w,h*w))+list(range(0,w*h,w))+list(range(w-1,w*h,w)):
        if eligible[i] and not visited[i]: visited[i]=1; queue.append(i)
    while queue:
        i=queue.popleft(); x=i%w
        for n in (i-w if i>=w else -1,i+w if i<w*(h-1) else -1,
                  i-1 if x else -1,i+1 if x<w-1 else -1):
            if n>=0 and eligible[n] and not visited[n]: visited[n]=1; queue.append(n)
    im.putdata([(r,g,b,0 if visited[i] else a) for i,(r,g,b,a) in enumerate(pixels)])
    return im.crop(im.getbbox())

def canvas_part(tile,x,y):
    out=Image.new('RGBA',(256,256))
    out.alpha_composite(tile,(x,y))
    return out

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    records=[]
    contact=Image.new('RGB',(1024,560),'#405055'); d=ImageDraw.Draw(contact)
    for index,name in enumerate(NAMES):
        folder=OUT/name; folder.mkdir(exist_ok=True)
        src=(ROOT/'docs/art/settings/character-settings-2026-09-12'/name if index==0 else
             ROOT/'docs/art/settings/character-revision-2026-09-12'/name)
        front_path=ROOT/'tests/fixtures/art/legacy-rina-twohead/rina.png' if index==0 else src/'chibi.png'
        front=Image.open(front_path).convert('RGBA') if index==0 else paper_alpha(Image.open(front_path))
        original_size=front.size
        shoe_y=round(front.height*SHOE_START[index])
        # Shorten only the long trouser region, keeping the head and shoes unchanged.
        if index in (1,4,7):
            start=round(front.height*.78)
            upper=front.crop((0,0,front.width,start))
            trouser=front.crop((0,start,front.width,shoe_y))
            trouser=trouser.resize((front.width,max(1,round(trouser.height*.45))),Image.Resampling.LANCZOS)
            shoes=front.crop((0,shoe_y,front.width,front.height))
            adjusted=Image.new('RGBA',(front.width,start+trouser.height+shoes.height))
            adjusted.alpha_composite(upper); adjusted.alpha_composite(trouser,(0,start))
            adjusted.alpha_composite(shoes,(0,start+trouser.height))
            shoe_y=start+trouser.height; front=adjusted
        scale=min(224/front.height,236/front.width)
        front=front.resize((round(front.width*scale),round(front.height*scale)),Image.Resampling.LANCZOS)
        shoe_y=round(shoe_y*scale)
        x=(256-front.width)//2; y=240-front.height
        full=canvas_part(front,x,y); full.save(folder/'front.png')
        canvas_part(front.crop((0,0,front.width,shoe_y+2)),x,y).save(folder/'front-body.png')
        for foot in range(2):
            left=foot*front.width//2; right=(foot+1)*front.width//2
            canvas_part(front.crop((left,shoe_y,right,front.height)),x+left,y+shoe_y).save(folder/f'front-foot-{foot}.png')
        back_path=src/'back.png'
        back=paper_alpha(Image.open(back_path))
        head_y=round(back.height*HEAD_END[index]); boot_y=round(back.height*.87)
        # Fit the existing rear drawing as a chibi rig: head / compact torso / tiny boots.
        head=back.crop((0,0,back.width,head_y)); head=head.crop(head.getbbox())
        head.thumbnail((220,148),Image.Resampling.LANCZOS)
        # thumbnail does not enlarge; rear sources are larger than the game cutouts.
        head=head.resize((min(220,round(head.width*148/head.height)),148),Image.Resampling.LANCZOS)
        body=back.crop((0,head_y,back.width,round(back.height*BODY_END[index])))
        body=body.resize((min(168,round(front.width*.75)),58),Image.Resampling.LANCZOS)
        boots=back.crop((0,boot_y,back.width,back.height))
        boots=boots.resize((round(body.width*.75),22),Image.Resampling.LANCZOS)
        rear_body=Image.new('RGBA',(256,256)); rear_body.alpha_composite(head,((256-head.width)//2,16))
        rear_body.alpha_composite(body,((256-body.width)//2,162))
        if index == 2:
            # Preserve Kohaku's signature tail from the existing rear drawing.
            mask=Image.new('L',back.size)
            ImageDraw.Draw(mask).polygon([(165,379),(191,408),(223,451),(253,470),
                (242,476),(255,516),(248,565),(220,614),(177,635),(124,647),
                (77,640),(36,615),(14,586),(0,542),(10,547),(7,524),(10,503),
                (40,511),(82,512),(121,501),(140,477),(150,434)],fill=255)
            tail=back.copy(); tail.putalpha(mask)
            tail=tail.crop(tail.getbbox()); tail.thumbnail((64,60),Image.Resampling.LANCZOS)
            rear_body.alpha_composite(tail,((256-tail.width)//2,174))
        rear_body.save(folder/'back-body.png')
        rear=rear_body.copy()
        for foot in range(2):
            left=foot*boots.width//2; right=(foot+1)*boots.width//2
            piece=canvas_part(boots.crop((left,0,right,boots.height)),(256-boots.width)//2+left,218)
            piece.save(folder/f'back-foot-{foot}.png'); rear.alpha_composite(piece)
        rear.save(folder/'back.png')
        for row,tile in enumerate((full,rear)):
            tile=tile.resize((128,128),Image.Resampling.LANCZOS)
            contact.paste(tile,(index*128,row*260+40),tile)
        d.text((index*128+5,12),name,fill='white')
        records.append(dict(id=index,name=name,front_source=front_path.relative_to(ROOT).as_posix(),
            back_source=back_path.relative_to(ROOT).as_posix(),front_original_size=original_size,
            front_sha256=hashlib.sha256(front_path.read_bytes()).hexdigest(),
            back_sha256=hashlib.sha256(back_path.read_bytes()).hexdigest(),
            shoe_start=SHOE_START[index],rear_head_end=HEAD_END[index],
            trouser_scale=.45 if index in (1,4,7) else 1.0))
    review=ROOT/'docs/archive/2026-09-12/character-integration'; review.mkdir(parents=True,exist_ok=True)
    contact.save(review/'cutouts.png')
    (OUT/'manifest.json').write_text(json.dumps(dict(cell=[256,256],origin=[128,240],
        display_scale=.25,method='fixed cutouts; flood-connected paper removal; rear setting art refit; no API',
        characters=records),indent=2)+'\n',encoding='utf-8')
    print('Built eight front/rear fixed rigs; no API requests.')

if __name__=='__main__': main()
