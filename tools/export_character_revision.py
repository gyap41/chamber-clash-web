"""Crop revision setting sheets without changing artwork; retain original PNGs."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw
from export_character_settings import split_column

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/art/settings/character-revision-2026-09-12'
SLUGS = ['01-sora', '02-kohaku', '03-bolt', '04-mei', '05-luna', '06-rattle', '07-crow']

def main():
    records = []
    lineup = Image.new('RGB', (1200, 310), '#f6f1e7')
    draw = ImageDraw.Draw(lineup)
    designs = Image.new('RGB', (1440, 310), '#f6f1e7')
    dd = ImageDraw.Draw(designs)
    normals = Image.new('RGB', (1200, 1100), '#f6f1e7')
    nd = ImageDraw.Draw(normals)
    rina = Image.open(ROOT / 'tests/fixtures/art/legacy-rina-twohead/rina.png').convert('RGBA')
    # Comparison only: all characters get the same 56px total height, then 3x display.
    small = rina.resize((round(rina.width*56/rina.height), 56), Image.Resampling.LANCZOS)
    enlarged = small.resize((small.width*3, 168), Image.Resampling.NEAREST)
    lineup.paste(enlarged, ((150-enlarged.width)//2, 260-168), enlarged)
    draw.text((10, 16), '00-rina (in-game)', fill='#302f2c')
    rina_design = rina.resize((round(rina.width*190/rina.height),190), Image.Resampling.LANCZOS)
    designs.paste(rina_design, ((180-rina_design.width)//2,70),rina_design)
    dd.text((10,16),'00-rina (in-game)',fill='#302f2c')
    for index, slug in enumerate(SLUGS, 1):
        stem = 'fw-character-v2-' + slug + ('-retry1' if index == 1 else '')
        source = ROOT / 'assets/generated' / (stem + '.png')
        if not source.exists():
            continue
        im = Image.open(source).convert('RGB')
        folder = OUT / slug
        folder.mkdir(exist_ok=True)
        im.save(folder / 'sheet.png')
        cuts = [0, split_column(im, 390), split_column(im, 775), im.width]
        panels = {}
        normal_panels = []
        for j, label in enumerate(['front', 'back', 'chibi']):
            # Titles sit above the illustrated panels; preserve Sora's hair at y~96.
            top = 92 if index == 1 else 108
            if index == 3:
                top = 580 if label == 'chibi' else 0
            if index == 5:
                top = 540 if label == 'chibi' else 0
            if index == 6:
                top = 130
            if index == 7:
                top = 85
            rect = (cuts[j], top, cuts[j+1], im.height)
            if index == 5 and label == 'chibi':
                rect = (710, top, im.width, im.height)
            panel = im.crop(rect)
            clip = None
            if index == 5 and label == 'back':
                # Polygon crop excludes the neighboring chibi hat in the lower gutter.
                # Keep original subject pixels; this is not a repaint or proportion edit.
                panel = panel.convert('RGBA')
                clip = [(0,0),(panel.width,0),(panel.width,600),(713-rect[0],600),
                        (713-rect[0],panel.height),(0,panel.height)]
                mask = Image.new('L', panel.size)
                ImageDraw.Draw(mask).polygon(clip, fill=255)
                panel.putalpha(mask)
            bbox = panel.convert('L').point(lambda v: 255 if v < 180 else 0).getbbox()
            if bbox:
                panel = panel.crop(bbox)
            panel.save(folder / (label + '.png'))
            panels[label] = dict(source_rect=rect, trim=bbox, clip=clip)
            if label != 'chibi':
                normal_panels.append(panel.copy())
            if label == 'chibi':
                design = panel.resize((round(panel.width*190/panel.height),190), Image.Resampling.LANCZOS)
                designs.paste(design,(index*180+(180-design.width)//2,70))
                dd.text((index*180+10,16),slug,fill='#302f2c')
                small = panel.resize((round(panel.width*56/panel.height), 56), Image.Resampling.LANCZOS)
                big = small.resize((small.width*3, 168), Image.Resampling.NEAREST)
                lineup.paste(big, (index*150+(150-big.width)//2, 92))
                draw.text((index*150+10, 16), slug, fill='#302f2c')
            if label == 'front':
                panel.thumbnail((275, 480), Image.Resampling.LANCZOS)
                n = index-1
                normals.paste(panel, ((n%4)*300+(300-panel.width)//2, (n//4)*550+50))
                nd.text(((n%4)*300+12, (n//4)*550+15), slug, fill='#302f2c')
        combined = Image.new('RGB', (sum(p.width for p in normal_panels)+60,
                                    max(p.height for p in normal_panels)+40), '#f6f1e7')
        x = 20
        for panel in normal_panels:
            combined.paste(panel, (x, combined.height-20-panel.height),
                           panel if panel.mode == 'RGBA' else None)
            x += panel.width+20
        combined.save(folder / 'normal-proportions.png')
        metadata = json.loads(source.with_suffix('.json').read_text(encoding='utf-8'))
        records.append(dict(id=index, name=slug, source=source.relative_to(ROOT).as_posix(),
            sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
            prompt=f'docs/art/settings/character-revision-2026-09-12/{slug}.txt',
            panels=panels, pricing_estimate_usd=metadata['pricing_estimate_usd'], game_integration=False))
    lineup.save(OUT / 'chibi-lineup.png')
    designs.save(OUT / 'chibi-design-lineup.png')
    normals.save(OUT / 'normal-lineup.png')
    (OUT / 'manifest.json').write_text(json.dumps(dict(characters=records,
        pricing_estimate_usd=sum(r['pricing_estimate_usd'] for r in records),
        comparison='56px full height including hats/ears, enlarged 3x; paper retained'),
        ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'Exported {len(records)} revision sheets')

if __name__ == '__main__':
    main()
