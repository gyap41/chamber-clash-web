"""Package approved diverse sheets with color-preserving magenta extraction.

Run with Pillow; optional sheet name processes one completed sheet. No network.
"""
from PIL import Image, ImageDraw, ImageFilter
import package_equipment_rollout as base


def key_magenta(image):
    image=image.convert('RGBA')
    original=image.copy()
    pixels=[]
    for r,g,b,a in image.get_flattened_data():
        # Distance from the specified background, rather than general purple
        # saturation: retain blue/violet materials and red/pink equipment.
        dominance=min(r,b)-g
        coverage=1.0
        if min(r,b)>180 and dominance>100:
            coverage=max(0.0,min(1.0,(130-dominance)/30.0))
        if coverage == 0:
            pixels.append((0,0,0,0))
        elif coverage < 1:
            rgb=[max(0,min(255,round((value-bg*(1-coverage))/coverage)))
                 for value,bg in zip((r,g,b),(255,0,255))]
            pixels.append((*rgb,min(a,round(coverage*255))))
        else:
            pixels.append((r,g,b,a))
    image.putdata(pixels)
    # Some sheets include a white cross between cells. Remove only full-span
    # separator rows/columns; no weapon or relic extends across the whole sheet.
    draw=ImageDraw.Draw(image)
    for axis,length in [(0,image.width),(1,image.height)]:
        for n in range(length):
            rect=(n,0,n+1,image.height) if axis==0 else (0,n,image.width,n+1)
            extrema=original.crop(rect).getextrema()
            if extrema[0][0]>240 and extrema[2][0]>240 and extrema[1][0]>20:
                draw.rectangle((max(0,n-3),0,min(image.width-1,n+3),image.height-1) if axis==0 else (0,max(0,n-3),image.width-1,min(image.height-1,n+3)),fill=(0,0,0,0))
    nearby=image.getchannel('A').filter(ImageFilter.MinFilter(5))
    image.putdata([(min(r,g+30),g,min(b,g+30),a) if low==0 and min(r,b)-g>35 else (r,g,b,a)
                   for (r,g,b,a),low in zip(image.get_flattened_data(),nearby.get_flattened_data())])
    return image


base.PLAN=base.ROOT/'docs/art/production/equipment-diversity-2026-09-13/plan.json'
base.OUT=base.ROOT/'docs/art/reviews/equipment-diversity-2026-09-13'
base.key_alpha=key_magenta

if __name__=='__main__':base.main()
