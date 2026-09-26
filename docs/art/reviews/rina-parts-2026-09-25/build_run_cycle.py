"""リナ側面走行サイクル（上体固定素材＋手描きベクター脚）の生成。

上体: run-keyposes-fix.png の3コマ目（横4×縦2の等分セル index=2）から裾より下を除去し、
      裾の輪郭線を補う。頭・髪・銃の形状はコマ間で完全に同一。
脚  : 近側/遠側を別々にベクター描画（腿・脛を同色で連続させ膝の継ぎ目なし）。
      2関節IK、靴は接地コマで靴底を床に一致させ、空中コマは持上げ量を指定。
出力: run-cycle-sheet.png（8コマ横並び RGBA）、run-cycle-meta.json
再現: python build_run_cycle.py  （このフォルダーで実行）
"""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'run-keyposes-fix.png')
S = 4                      # 描画の超解像倍率
CELL = 443                 # 原画セル寸法（px）
G = 428                    # 床のy（セル座標）
OUT_SCALE = 0.5            # 出力倍率（222px セル）

# ---- 上体の切出し --------------------------------------------------------
def build_upper():
    im = Image.open(SRC).convert('RGBA')
    cw, ch = im.width / 4, im.height / 2
    i = 2
    c = np.asarray(im.crop((int((i % 4) * cw), int((i // 4) * ch),
                            int((i % 4 + 1) * cw), int((i // 4 + 1) * ch)))).copy()
    c = c[:CELL, :CELL]
    H, W = c.shape[:2]
    pts = [(0, 318), (136, 318), (140, 331), (150, 336), (160, 342), (180, 349), (200, 352),
           (220, 351), (232, 343), (245, 335), (262, 338), (W, 338)]
    xs = np.arange(W)
    hem = np.interp(xs, [p[0] for p in pts], [p[1] for p in pts])
    yy = np.arange(H)[:, None]
    c[yy > hem[None, :]] = 0
    M = c[..., 3] > 128
    ring = M & ~ndi.binary_erosion(M, iterations=5)
    region = np.zeros_like(M)
    for x in range(128, 262):
        region[int(hem[x]) - 14:int(hem[x]) + 1, x] = True
    c[ring & region] = [20, 14, 12, 255]
    return Image.fromarray(c)

# ---- 脚の設計（右向き、+x=前、y下向き） ----------------------------------
L1, L2 = 42.0, 40.0
HIP_NEAR = (198.0, 338.0)
HIP_FAR = (184.0, 334.0)
BOB = [0, 7, 2, -6, 0, 7, 2, -6]            # 腰・上体の上下（+は下）
LEAN = [1.5, 2.5, 1.5, 0.0, 1.5, 2.5, 1.5, 0.0]  # 上体の前傾（度）
# 半周期ぶん: (hip相対dx, 接地なら None / 空中なら床からの持上げ, 靴角度(+でつま先下がり))
LEG = [
    (34, None, -10),   # 0 接地（踵から）
    (14, None, 0),     # 1 荷重・沈み込み
    (-6, None, 0),     # 2 通過（支持脚）
    (-30, 5, 40),      # 3 蹴り出し直後（両足空中の滞空）
    (-36, 14, 50),     # 4 後方へ跳ね上げ
    (-18, 30, 34),     # 5 回収（踵を尻へ）
    (8, 24, 4),        # 6 膝を前へ（通過）
    (32, 6, -14),      # 7 前へ振り出し（滞空）
]

NEAR = dict(pants=(110, 70, 54), pants_hi=(136, 90, 70), band=(240, 232, 214),
            boot=(128, 80, 62), boot_hi=(170, 114, 90), sole=(70, 44, 34))
FAR = dict(pants=(74, 46, 36), pants_hi=(92, 58, 45), band=(184, 174, 158),
           boot=(92, 58, 45), boot_hi=(120, 78, 60), sole=(50, 32, 25))
INK = (20, 14, 12, 255)
OL = 5.0  # 輪郭の太さ（セルpx）

def catmull(points, n=10):
    out = []
    P = points
    for i in range(len(P)):
        p0, p1, p2, p3 = P[i - 1], P[i], P[(i + 1) % len(P)], P[(i + 2) % len(P)]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t +
                                    (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 +
                                    (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in range(2)))
    return out

BOOT = [(x * 1.15, y * 1.15) for x, y in catmull(
    [(-9, -6), (-15, 4), (-14, 15), (-8, 21), (10, 22), (26, 21), (34, 14),
     (31, 4), (20, -1), (8, -4)])]
BAND = [(-14, -14), (14, -14), (14, -4), (-14, -4)]        # 裾の帯（脛の軸基準、xが幅方向）
BAND_INK = [(-16.5, -16.5), (16.5, -16.5), (16.5, -1.5), (-16.5, -1.5)]

def rot(pts, a, o=(0, 0)):
    ca, sa = math.cos(a), math.sin(a)
    return [(o[0] + x * ca - y * sa, o[1] + x * sa + y * ca) for x, y in pts]

def ik(hip, ank):
    dx, dy = ank[0] - hip[0], ank[1] - hip[1]
    d = math.hypot(dx, dy)
    d = min(d, L1 + L2 - 0.01)
    a = math.atan2(dy, dx)
    c = (L1 * L1 + d * d - L2 * L2) / (2 * L1 * d)
    b = math.acos(max(-1, min(1, c)))
    # 膝は前方（+x側）へ：y下向き座標で進行方向右 → 角度を減らす側
    ka = a - b
    return (hip[0] + L1 * math.cos(ka), hip[1] + L1 * math.sin(ka)), d

def leg_pose(frame, far):
    k = (frame + (4 if far else 0)) % 8
    dx, lift, ang = LEG[k]
    hip = HIP_FAR if far else HIP_NEAR
    hip = (hip[0], hip[1] + BOB[frame])
    a = math.radians(ang)
    boot = rot(BOOT, a)
    low = max(y for _, y in boot)
    ay = G - low - (lift or 0)
    ank = (hip[0] + dx, ay)
    knee, d = ik(hip, ank)
    return dict(hip=hip, knee=knee, ank=ank, ang=a, ground=lift is None, reach=d, key=k)

def sc(p):
    return (p[0] * S, p[1] * S)

def capsule(dr, a, b, w, col):
    dr.line([sc(a), sc(b)], fill=col, width=int(w * S))
    for p in (a, b):
        r = w * S / 2
        dr.ellipse([p[0] * S - r, p[1] * S - r, p[0] * S + r, p[1] * S + r], fill=col)

def draw_leg(img, P, pal):
    dr = ImageDraw.Draw(img)
    hip, knee, ank, a = P['hip'], P['knee'], P['ank'], P['ang']
    boot = [sc(p) for p in rot(BOOT, a, ank)]
    shin_dir = math.atan2(ank[1] - knee[1], ank[0] - knee[0]) - math.pi / 2
    band = [sc(p) for p in rot(BAND, shin_dir, ank)]
    band_ink = [sc(p) for p in rot(BAND_INK, shin_dir, ank)]
    wt, ws = 30.0, 25.0
    # 輪郭（全部品をまとめて太らせて先に描く → 膝に継ぎ目を出さない）
    capsule(dr, hip, knee, wt + 2 * OL, INK)
    capsule(dr, knee, ank, ws + 2 * OL, INK)
    dr.line(boot + [boot[0]], fill=INK, width=int(2 * OL * S), joint='curve')
    dr.polygon(boot, fill=INK)
    # 塗り
    capsule(dr, hip, knee, wt, pal['pants'])
    capsule(dr, knee, ank, ws, pal['pants'])
    # ハイライト（前上側へずらした細い帯）
    off = (1.8, -1.8)
    capsule(dr, (hip[0] + off[0], hip[1] + off[1]), (knee[0] + off[0], knee[1] + off[1]), wt * 0.55, pal['pants_hi'])
    capsule(dr, (knee[0] + off[0], knee[1] + off[1]), (ank[0] + off[0] - 2, ank[1] + off[1] - 8), ws * 0.5, pal['pants_hi'])
    dr.polygon(boot, fill=pal['boot'])
    # 靴底：靴の形から上へずらした形を引いた下側の三日月
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).polygon(boot, fill=255)
    up = [(x + math.sin(a) * 6 * S, y - math.cos(a) * 6 * S) for x, y in boot]
    m2 = Image.new('L', img.size, 0)
    ImageDraw.Draw(m2).polygon(up, fill=255)
    solem = Image.fromarray(np.where((np.asarray(mask) > 0) & (np.asarray(m2) == 0), 255, 0).astype(np.uint8))
    img.paste(Image.new('RGBA', img.size, pal['sole'] + (255,)), (0, 0), solem)
    hi = rot([(17, 7)], a, ank)[0]
    r1, r2 = 9 * S, 5 * S
    dr.ellipse([hi[0] * S - r1, hi[1] * S - r2, hi[0] * S + r1, hi[1] * S + r2], fill=pal['boot_hi'])
    dr.polygon(band_ink, fill=INK)
    dr.polygon(band, fill=pal['band'])

def render():
    upper = build_upper()
    frames, meta = [], []
    for f in range(8):
        big = Image.new('RGBA', (CELL * S, CELL * S), (0, 0, 0, 0))
        Pf = leg_pose(f, far=True)
        Pn = leg_pose(f, far=False)
        draw_leg(big, Pf, FAR)
        draw_leg(big, Pn, NEAR)
        legs = big.resize((CELL, CELL), Image.LANCZOS)
        # 上体：腰を中心に前傾、上下動
        pivot = (HIP_NEAR[0], HIP_NEAR[1])
        up = upper.rotate(-LEAN[f], resample=Image.BICUBIC, center=pivot,
                          translate=(0, BOB[f]))
        frame = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
        frame.alpha_composite(legs)
        frame.alpha_composite(up)
        frames.append(frame)
        meta.append(dict(frame=f, bob=BOB[f], lean=LEAN[f],
                         near=dict(key=Pn['key'], ground=Pn['ground'], ankle_x=round(Pn['ank'][0], 1), reach=round(Pn['reach'], 2)),
                         far=dict(key=Pf['key'], ground=Pf['ground'], ankle_x=round(Pf['ank'][0], 1), reach=round(Pf['reach'], 2))))
    return frames, meta

if __name__ == '__main__':
    frames, meta = render()
    w = int(CELL * OUT_SCALE)
    sheet = Image.new('RGBA', (w * 8, w), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.alpha_composite(fr.resize((w, w), Image.LANCZOS), (i * w, 0))
    sheet.save(os.path.join(HERE, 'run-cycle-sheet.png'))
    # 接地脚の1コマあたり足送り（セルpx）
    steps = []
    for f in range(8):
        for side in ('near', 'far'):
            g1 = meta[f][side]; g2 = meta[(f + 1) % 8][side]
            if g1['ground'] and g2['ground']:
                steps.append(g1['ankle_x'] - g2['ankle_x'])
    info = dict(cell=w, frames=8, ground_y=G * OUT_SCALE, origin_x=HIP_NEAR[0] * OUT_SCALE,
                stride_per_frame=round(sum(steps) / len(steps) * OUT_SCALE, 3),
                source='run-keyposes-fix.png cell 2 (upper body only)', frames_meta=meta)
    json.dump(info, open(os.path.join(HERE, 'run-cycle-meta.json'), 'w'), ensure_ascii=False, indent=1)
    print('steps', steps, 'reach max', max(max(m['near']['reach'], m['far']['reach']) for m in meta))
