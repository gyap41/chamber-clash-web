"""Review real Godot pose captures at 2x; no API and no game-state simulation."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/archive/2026-09-12/rina-chibi'
if '--twohead' in sys.argv: OUT=ROOT/'docs/archive/2026-09-12/rina-twohead'
frames=[]
for tick in range(78):
    panel=Image.new('RGB',(660,520),'#192126')
    d=ImageDraw.Draw(panel)
    for row,direction in enumerate(['down','up']):
        for col,name in enumerate(['idle','move','roll']):
            index=int(tick*.02*10)%6 if name=='move' else int((tick*.02%.26)/.26*6)%6
            filename=f'idle-{direction}.png' if name=='idle' else f'{name}-{direction}-{index:02d}.png'
            im=Image.open(OUT/filename)
            crop=im.crop((315,325,425,435)).resize((220,220),Image.Resampling.NEAREST)
            panel.paste(crop,(col*220,row*260+25))
            d.text((col*220+8,row*260+7),name+' '+direction+' / 2x',fill='white')
    frames.append(panel)
frames[0].save(OUT/'game-pose-preview.gif',save_all=True,append_images=frames[1:],duration=20,loop=0)
print('Saved game-pose-preview.gif from Godot captures')
