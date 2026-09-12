"""Local guide and faithful sprite playback for the two-head design review."""
import sys, json, hashlib
from pathlib import Path
from PIL import Image, ImageDraw
from process_workshop_images import key_alpha
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/art/settings/concepts/rina-two-head-2026-09-12'
def guide():
    im=Image.new('RGB',(1024,1024),'#eeeeee'); d=ImageDraw.Draw(im)
    feet=[((211,423),(282,394)),((223,404),(275,418)),((211,394),(282,423)),((223,418),(275,404))]
    for i,(left,right) in enumerate(feet):
        x,y=i%2*512,i//2*512
        d.ellipse((x+127,y+60,x+365,y+292),fill='#d0c6b0',outline='black',width=4)
        d.rounded_rectangle((x+191,y+274,x+302,y+386),radius=45,fill='#a4b8b4',outline='black',width=4)
        for point,color in [(left,'#d44837'),(right,'#3067cd')]:
            px,py=x+point[0],y+point[1]
            d.ellipse((px-24,py-14,px+24,py+14),fill=color,outline='black',width=3)
        d.text((x+24,y+465),str(i+1)+' RED=character right foot, BLUE=character left foot',fill='black')
    im.save(OUT/'walk-guide.png')
    print('Saved local foot alternation guide')
def preview():
    design=key_alpha(Image.open(ROOT/'assets/generated/fw-twohead-design.png'))
    design=design.crop(design.getbbox()); design.save(OUT/'design.png')
    raw=ROOT/'assets/generated/fw-twohead-walk.png'
    im=key_alpha(Image.open(raw)); tiles=[]; boxes=[]
    for i in range(4):
        rect=(i%2*512,i//2*512,i%2*512+512,i//2*512+512)
        tile=im.crop(rect); box=tile.getchannel('A').point(lambda a:255 if a>=96 else 0).getbbox()
        if box is None: raise ValueError('Empty frame')
        tiles.append(tile.crop(box)); boxes.append({'cell':rect,'crop':box})
    scale=min(104/max(t.height for t in tiles),104/max(t.width for t in tiles))
    sheet=Image.new('RGBA',(512,128)); contact=Image.new('RGB',(800,280),'#384448')
    cd=ImageDraw.Draw(contact)
    for i,t in enumerate(tiles):
        t=t.resize((round(t.width*scale),round(t.height*scale)),Image.Resampling.LANCZOS)
        sheet.alpha_composite(t,(i*128+(128-t.width)//2,112-t.height))
        cell=sheet.crop((i*128,0,i*128+128,128)).resize((192,192),Image.Resampling.NEAREST)
        contact.paste(cell,(i*200,35),cell); cd.text((i*200+16,12),'Frame '+str(i+1),fill='white')
    sheet.save(OUT/'walk.png'); contact.save(OUT/'walk-contact.png')
    floor=Image.open(ROOT/'assets/first-workshop/floor.png').convert('RGB').resize((660,420))
    old=Image.open(ROOT/'docs/archive/2026-09-12/art-organization/unused-candidates/superseded-assets/chibi/idle.png').convert('RGBA').crop((0,0,128,128))
    frames=[]
    for tick in range(80):
        frame=floor.copy(); d=ImageDraw.Draw(frame)
        d.rectangle((0,0,660,38),fill='#192126')
        for col,label in enumerate(['CURRENT / 68px (idle)','NEW / 64px','NEW / 48px']):
            d.text((col*220+12,13),label,fill='white')
        oldpic=old.resize((84,84),Image.Resampling.LANCZOS)
        frame.paste(oldpic,(68,180),oldpic)
        # Same actual pixels as a game sprite: only vertical translation and phase.
        down=tick<40; phase=int(tick*.05*8)%4
        if not down: phase=(-phase)%4
        offset=(tick if down else 80-tick)*2
        tile=sheet.crop((phase*128,0,phase*128+128,128))
        for col,height in [(1,64),(2,48)]:
            size=round(height/104*128)
            pic=tile.resize((size,size),Image.Resampling.LANCZOS)
            x=col*220+110-size//2; y=130+offset-size//2
            d.ellipse((col*220+94,y+round(112*size/128)-3,col*220+126,y+round(112*size/128)+4),fill='#4b4c46')
            frame.paste(pic,(x,y),pic)
        frames.append(frame)
    frames[20].save(OUT/'size-comparison.png')
    frames[0].save(OUT/'walk-preview.gif',save_all=True,append_images=frames[1:],duration=50,loop=0)
    (OUT/'processing.json').write_text(json.dumps({'source':str(raw.relative_to(ROOT)),
      'sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'scale':scale,'frames':boxes,
      'notes':'Constant scale, bottom alignment, no limb warping or invented gait; 8fps original 4 poses. Preview composite, not game capture.'},indent=2)+'\n',encoding='utf-8')
    print('Saved design, walk atlas, contact sheet and actual-size comparison GIF')
if __name__=='__main__':
    guide() if '--guide' in sys.argv else preview()
