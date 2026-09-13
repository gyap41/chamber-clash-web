"""Crop approved prototype sheets and make review boards; no API or game edits."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from process_workshop_images import key_alpha

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'docs/art/reviews/weapon-relic-prototype-2026-09-12'
SHEETS = [('weapons-prototype-a', 2, [21, 22, 23, 24]),
          ('weapons-prototype-b', 2, [25, 26, 27]),
          ('relics-prototype-a', 3, list(range(9)))]


def main():
    catalog = json.loads((ROOT / 'data/catalog.json').read_text(encoding='utf-8'))
    DEST.mkdir(parents=True, exist_ok=True)
    font_path = 'C:/Windows/Fonts/meiryo.ttc'
    font = ImageFont.truetype(font_path, 18)
    small = ImageFont.truetype(font_path, 14)
    recipe = []
    for stem, grid, ids in SHEETS:
        kind = 'relics' if stem.startswith('relics') else 'guns'
        source = ROOT / 'assets/generated' / ('fw-' + stem + '.png')
        keyed = key_alpha(Image.open(source))
        board = Image.new('RGB', (1024, 140 + 350 * ((len(ids) + 2) // 3)), '#172330')
        draw = ImageDraw.Draw(board)
        draw.text((24, 16), '武器・レリック試作 / ' + stem, font=font, fill='white')
        draw.text((24, 48), '上：拡大確認　下：小型表示（左）と4倍拡大（右）', font=small, fill='#b9cbd8')
        draw.text((24, 74), '武器は40×30px枠・レリックは24px枠。実ゲームへの組込み前の静止比較です。', font=small, fill='#b9cbd8')
        for index, item_id in enumerate(ids):
            x, y = index % grid, index // grid
            cell = (x * keyed.width // grid, y * keyed.height // grid,
                    (x + 1) * keyed.width // grid, (y + 1) * keyed.height // grid)
            # Inspected object spacing differs slightly from the nominal grid.
            # Keep Nova separate from the magazine, and preserve battery caps.
            if stem == 'relics-prototype-a' and item_id == 5:
                cell = (640, 340, 1024, 650)
            if stem == 'relics-prototype-a' and item_id >= 6:
                cell = (cell[0], 650, cell[2], cell[3])
            tile = keyed.crop(cell)
            box = tile.getbbox()
            if box is None:
                raise ValueError(f'Empty cell: {stem}/{item_id}')
            if box[0] < 8 or box[1] < 8 or box[2] > tile.width - 8 or box[3] > tile.height - 8:
                raise ValueError(f'Object touches cell boundary: {stem}/{item_id}')
            crop = tile.crop(box)
            output = DEST / kind / f'{item_id:02d}.png'
            output.parent.mkdir(exist_ok=True)
            crop.save(output)
            bx, by = index % 3 * 340 + 12, index // 3 * 350 + 110
            draw.rounded_rectangle((bx, by, bx + 324, by + 334), radius=10, fill='#263647')
            name = catalog[kind][item_id]['name']
            draw.text((bx + 10, by + 8), f'{item_id:02d} {name}', font=font, fill='white')
            large = crop.copy()
            large.thumbnail((276, 156), Image.Resampling.LANCZOS)
            board.paste(large, (bx + (324 - large.width) // 2, by + 42 + (156 - large.height) // 2), large)
            tiny = crop.copy()
            tiny.thumbnail((24, 24) if kind == 'relics' else (40, 30), Image.Resampling.LANCZOS)
            board.paste(tiny, (bx + 35, by + 264 - tiny.height // 2), tiny)
            zoom = tiny.resize((tiny.width * 4, tiny.height * 4), Image.Resampling.NEAREST)
            board.paste(zoom, (bx + 128, by + 264 - zoom.height // 2), zoom)
            recipe.append(dict(kind=kind, id=item_id, name=name, source=str(source.relative_to(ROOT)),
                               source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                               cell=list(cell), alpha_crop=list(box), output=str(output.relative_to(ROOT)),
                               preview_pixels=list(tiny.size)))
        board.save(DEST / (stem + '-review.png'))
    (DEST / 'extraction.json').write_bytes((json.dumps(dict(
        status='prototype_pending_user_review', processing='Existing key_alpha; crop only. Lanczos preview, nearest 4x.',
        items=recipe), ensure_ascii=False, indent=2) + '\n').encode('utf-8'))
    print(f'Packaged {len(recipe)} prototypes to {DEST}')


if __name__ == '__main__':
    main()
