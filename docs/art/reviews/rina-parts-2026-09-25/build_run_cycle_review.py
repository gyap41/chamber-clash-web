"""run-cycle-sheet.png と run-cycle-meta.json を内包したレビューHTMLを生成する。
再現: python build_run_cycle_review.py （このフォルダーで実行。先に build_run_cycle.py）
"""
import base64, json, os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sheet = os.path.join(HERE, 'run-cycle-sheet.png')
meta = json.load(open(os.path.join(HERE, 'run-cycle-meta.json'), encoding='utf-8'))
im = Image.open(sheet)
cell = meta['cell']
tops, bottoms = [], []
for i in range(meta['frames']):
    bb = im.crop((i * cell, 0, (i + 1) * cell, cell)).getbbox()
    tops.append(bb[1]); bottoms.append(bb[3])
meta['bbox_top_min'] = min(tops)
meta['bbox_bottom_max'] = max(bottoms)
meta['ground_y'] = max(bottoms) - 1  # 接地コマの靴底（輪郭込み）を床線にする
b64 = base64.b64encode(open(sheet, 'rb').read()).decode()
html = open(os.path.join(HERE, 'run-cycle-review.template.html'), encoding='utf-8').read()
html = html.replace('__SHEET__', b64).replace('__META__', json.dumps(meta, ensure_ascii=False))
open(os.path.join(HERE, 'run-cycle-review.html'), 'w', encoding='utf-8').write(html)
print('ok', meta['bbox_top_min'], meta['bbox_bottom_max'])
