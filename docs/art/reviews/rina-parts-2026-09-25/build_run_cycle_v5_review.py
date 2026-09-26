"""v5（medium/strong）2案のシートとメタを内包したレビューHTMLを生成する。
再現: python build_run_cycle_v5_review.py （このフォルダーで実行。先に build_run_cycle_v5.py）
"""
import base64, json, os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
meta = json.load(open(os.path.join(HERE, 'run-cycle-v5-meta.json'), encoding='utf-8'))

sheets = {}
for variant in ('medium', 'strong'):
    path = os.path.join(HERE, f'run-cycle-v5-{variant}-sheet.png')
    im = Image.open(path)
    cell = meta[variant]['cell']
    tops, bottoms = [], []
    for i in range(meta[variant]['frames']):
        bb = im.crop((i * cell, 0, (i + 1) * cell, cell)).getbbox()
        tops.append(bb[1]); bottoms.append(bb[3])
    meta[variant]['bbox_top_min'] = min(tops)
    meta[variant]['bbox_bottom_max'] = max(bottoms)
    meta[variant]['ground_y'] = max(bottoms) - 1
    sheets[variant] = base64.b64encode(open(path, 'rb').read()).decode()

html = open(os.path.join(HERE, 'run-cycle-v5-review.template.html'), encoding='utf-8').read()
html = html.replace('__SHEET_MEDIUM__', sheets['medium']).replace('__SHEET_STRONG__', sheets['strong'])
html = html.replace('__META__', json.dumps(meta, ensure_ascii=False))
open(os.path.join(HERE, 'run-cycle-v5-review.html'), 'w', encoding='utf-8').write(html)
print('ok', meta['medium']['bbox_top_min'], meta['medium']['bbox_bottom_max'])
