"""v7胴体パーツ生成（rina-side-body-parts-v1）の参照画像2枚を作る。リポジトリルートで実行し、.local/rina-v6/ へ白背景PNGを出力する。
  ref-side-turnaround.png: turnaround.png の右側面（x690〜1200）
  ref-upper-v4.png      : v4上体原画から銃・手袋を消したもの（build_run_cycle_v6.erase_weapon）を2倍
実行: python docs/art/reviews/rina-parts-2026-09-25/build_body_parts_refs.py"""
import sys, os
sys.path.insert(0, 'docs/art/reviews/rina-parts-2026-09-25')
sys.path.insert(0, '.local/video-deps')
from PIL import Image
import build_run_cycle_v6 as B
os.makedirs('.local/rina-v6', exist_ok=True)
t = Image.open('docs/art/reviews/rina-parts-2026-09-25/turnaround.png').convert('RGBA')
side = t.crop((690, 0, 1200, 825))
bg = Image.new('RGBA', side.size, (255, 255, 255, 255)); bg.alpha_composite(side)
bg.convert('RGB').save('.local/rina-v6/ref-side-turnaround.png')
up = Image.fromarray(B.erase_weapon(B.build_upper()))
bg = Image.new('RGBA', up.size, (255, 255, 255, 255)); bg.alpha_composite(up)
bg.convert('RGB').resize((886, 886), Image.LANCZOS).save('.local/rina-v6/ref-upper-v4.png')
print('ok')
