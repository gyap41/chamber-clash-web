"""Local schematic pose constraints, not a final game asset."""
from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1]
im=Image.new('RGB',(1024,1024),'white')
d=ImageDraw.Draw(im)
# Side view moving right. Red: near leg; blue: far leg.
poses=[([(0,0),(35,70),(70,140)],[(0,0),(-40,45),(-65,115)]),
       ([(0,0),(8,78),(0,150)],[(0,0),(-40,35),(0,70)]),
       ([(0,0),(-35,75),(-70,130)],[(0,0),(35,25),(65,70)]),
       ([(0,0),(-40,45),(-65,115)],[(0,0),(35,70),(70,140)]),
       ([(0,0),(-40,35),(0,70)],[(0,0),(8,78),(0,150)]),
       ([(0,0),(35,25),(65,70)],[(0,0),(-35,75),(-70,130)])]
for i,(near,far) in enumerate(poses):
    x,y=(i%3)*341+170,(i//3)*512+280
    d.line([(x-18,y-100),(x,y)],fill='black',width=15)
    d.ellipse((x-42,y-166,x+14,y-110),outline='black',width=10)
    d.line([(x+6,y-144),(x+32,y-140)],fill='black',width=8)
    d.rectangle((x-58,y-108,x-30,y-35),outline='#317b70',width=9)
    for points,color in [(far,'#3266cc'),(near,'#d74130')]:
        pts=[(x+a,y+b) for a,b in points]
        d.line(pts,fill=color,width=14)
        xx,yy=pts[-1]
        d.line([(xx,yy),(xx+22,yy)],fill=color,width=12)
    d.text((x-80,y+190),str(i+1),fill='black')
im.save(root/'docs/archive/2026-09-12/art-organization/unused-candidates/superseded-assets/first-workshop/pose-guide.png')
