"""残り4向き生成の参照画像（白背景PNG）：ターンアラウンド全体（1536幅に縮小）と、側面の生成パーツ（そのまま）。"""
import sys
sys.path.insert(0, '.local/video-deps')
from PIL import Image
t = Image.open('docs/art/reviews/rina-parts-2026-09-25/turnaround.png').convert('RGBA')
bg = Image.new('RGBA', t.size, (255, 255, 255, 255)); bg.alpha_composite(t)
w = 1536; h = round(t.height * w / t.width)
bg.convert('RGB').resize((w, h), Image.LANCZOS).save('.local/rina-v6/ref-turnaround-3view.png')
Image.open('assets/generated/rina-side-body-parts-v1.png').convert('RGB').save('.local/rina-v6/ref-side-parts-v1.png')
print('ok', w, h)
