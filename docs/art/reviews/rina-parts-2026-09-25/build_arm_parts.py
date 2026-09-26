"""腕・手袋の生成パーツ（assets/generated/rina-arm-parts-v2.png）を切り出して書き出す。

生成画像は白背景に3行：
  1行目 S1 上腕の袖・S2 前腕の袖（横向き、左端が肩/肘側）
  2行目 G1 握り（横・親指が上）・G2 握り（正面）・G3 握り（手の甲）・G4 握り（斜め）
  3行目 H1 支える手（手のひら上）・H2 前へ伸ばす手（横）・H3 前へ伸ばす手（正面）
手袋はいずれも左が手首、右が指先。ゲーム側（rina_run_rig.gd）は、袖を肩→肘→手の線に沿って伸ばし、
手袋を銃の向き（握り）または前腕の向き（伸ばす手）へ回して描く。
出力: assets/first-workshop/rina-run-8dir/arm-<key>.png と、rig.json に入れる寸法・基準点（export() の戻り値）。
build_run_cycle_v8.py から呼ばれる。
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
import build_run_cycle_v7 as V7

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
SRC = os.path.join(ROOT, 'assets', 'generated', 'rina-arm-parts-v2.png')
KEYS = [['sleeve_upper', 'sleeve_lower'],
        ['grip_side', 'grip_front', 'grip_back', 'grip_diag'],
        ['support', 'reach_side', 'reach_front']]
GLOVE_W = 5.5       # 手袋の幅（ゲーム画素）。参考動画に合わせ銃が主役になるよう小さめ（2026-09-26 7.0→5.5）
OUT_H = 64          # 書き出し画像の高さの目安（画素）

def export(out_dir):
    rgba = V7.remove_white(np.asarray(Image.open(SRC).convert('RGB')))
    lab, n = ndi.label(rgba[..., 3] > 0)
    comps = []
    for i in range(1, n + 1):
        m = lab == i
        if m.sum() < 1500: continue
        ys, xs = np.nonzero(m)
        comps.append(dict(m=m, x0=xs.min(), x1=xs.max() + 1, y0=ys.min(), y1=ys.max() + 1, cx=xs.mean(), cy=ys.mean()))
    comps.sort(key=lambda c: c['cy'])
    rows, cur = [], []
    for c in comps:
        if cur and c['cy'] - cur[-1]['cy'] > 120:
            rows.append(cur); cur = []
        cur.append(c)
    rows.append(cur)
    assert [len(r) for r in rows] == [2, 4, 3], [len(r) for r in rows]
    glove_px = np.mean([c['x1'] - c['x0'] for c in rows[1]])
    k = GLOVE_W / glove_px           # 生成画像の画素→ゲーム画素
    info = {}
    for row, keys in zip(rows, KEYS):
        for c, key in zip(sorted(row, key=lambda c: c['cx']), keys):
            p = rgba[c['y0'] - 2:c['y1'] + 2, c['x0'] - 2:c['x1'] + 2].copy()
            m = ndi.binary_dilation(c['m'], iterations=2)[c['y0'] - 2:c['y1'] + 2, c['x0'] - 2:c['x1'] + 2]
            p[..., 3] = np.where(m, p[..., 3], 0)
            im = Image.fromarray(p)
            s = OUT_H / im.height
            im.resize((max(1, round(im.width * s)), OUT_H), Image.LANCZOS).save(os.path.join(out_dir, f'arm-{key}.png'))
            info[key] = dict(size=[round(im.width * k, 3), round(im.height * k, 3)])
    # 袖は長さを肩→肘／肘→手の距離に合わせて伸縮するので、太さ（高さ）だけを使う
    return info
