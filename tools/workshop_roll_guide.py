"""Schematic shoulder-roll key poses for the first roll request; no API."""
from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1]
im=Image.new('RGB',(1024,1024),'white')
d=ImageDraw.Draw(im)
poses=[
 [(0,-100),(0,-65),(-15,-10),(40,25),(55,65),(-35,25),(-45,65),(45,-35),(65,0)],
 [(50,-70),(20,-60),(-45,-45),(-10,0),(-50,50),(-70,-10),(-100,20),(50,-25),(65,15)],
 [(55,30),(35,5),(-20,-70),(-55,-20),(5,5),(0,-20),(40,-20),(65,0),(50,50)],
 [(0,50),(0,20),(25,-65),(-30,-100),(-70,-70),(65,-95),(85,-45),(-40,0),(-35,40)],
 [(-15,-70),(-30,-40),(-55,-10),(0,35),(45,70),(-85,15),(-105,65),(15,-15),(45,25)],
 [(0,-95),(-10,-60),(-20,-10),(30,25),(50,65),(-45,25),(-55,65),(25,-25),(50,-5)]
]
for i,p in enumerate(poses):
    x,y=i%3*341+170,i//3*512+270
    pts=[(x+a,y+b) for a,b in p]
    h=pts[0]
    d.ellipse((h[0]-24,h[1]-24,h[0]+24,h[1]+24),outline='black',width=8)
    for ids,color in [([0,1,2],'black'),([2,3,4],'#d74130'),([2,5,6],'#3266cc'),([1,7,8],'#6d6d6d')]:
        d.line([pts[j] for j in ids],fill=color,width=13)
    d.line((x-125,y+88,x+125,y+88),fill='#cccccc',width=2)
    d.text((x-20,y+150),str(i+1),fill='black')
im.save(root/'docs/archive/2026-09-12/art-organization/unused-candidates/superseded-assets/first-workshop/roll-guide.png')
