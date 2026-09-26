"""リナ側面走行サイクル v5：体と武器（腕+銃）の分離、髪2箇所とスカーフの遅延揺れ、弾み「中」「強」の2案。

土台はv4（build_run_cycle.py）と同じ run-keyposes-fix.png cell2（上体固定素材）・脚ベクター。
新規画像生成は行わない。上体画像から次の4パーツを別レイヤーとして切り出し、
胴体（body_base）にはその穴を開けて、各パーツを胴体のBOB/LEANに対して
位相遅れ・振幅の異なる独立した回転で重ね描きする。

  weapon   : 肩から先（腕・手・銃）。胴体の上下動に対しごく小さく遅延して追従＝銃の重さの示唆。
  hair_top : 頭頂の跳ね毛（アホ毛状の房）。
  hair_side: 後方へ流れる髪房の毛先。
  scarf    : 首元のスカーフの垂れ。

弾み「中」「強」：胴体BOB/LEAN振幅の2案。各パーツの追従振幅も同じ倍率で連動させる。

出力：run-cycle-v5-<variant>-sheet.png（8コマ横並び RGBA）× medium/strong、
      run-cycle-v5-meta.json（両案のフレーム情報とパーツ根本点）。
再現：python build_run_cycle_v5.py （このフォルダーで実行、先に build_run_cycle.py 不要＝独立）
"""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'run-keyposes-fix.png')
S = 4
CELL = 443
G = 428
OUT_SCALE = 0.5

# ---- 上体の切出し（v4と同一） --------------------------------------------
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
    return c  # numpy array, RGBA

# ---- 分離パーツの多角形（原画セル座標、443基準。目視トレースの近似値） -----
POLY = dict(
    weapon=[(248, 268), (270, 255), (310, 246), (400, 244), (400, 308), (330, 328),
            (300, 332), (275, 322), (255, 302), (243, 282)],
    scarf=[(97, 283), (108, 258), (132, 247), (158, 249), (168, 266), (160, 288),
           (138, 298), (112, 294)],
    hair_top=[(138, 58), (150, 15), (185, 8), (218, 18), (232, 62), (205, 95),
              (170, 85), (148, 75)],
    hair_side=[(55, 158), (78, 118), (118, 138), (122, 183), (92, 207), (58, 190)],
)
PIVOT = dict(weapon=(252, 280), scarf=(160, 258), hair_top=(185, 80), hair_side=(115, 150))
DILATE = dict(weapon=6, scarf=8, hair_top=9, hair_side=9)  # ピースの張り出し量（穴より少し大きく描く。揺れ角×半径の弧長より余裕を持たせる）

def poly_mask(poly, shape):
    m = Image.new('L', (shape[1], shape[0]), 0)
    ImageDraw.Draw(m).polygon(poly, fill=255)
    return np.asarray(m) > 0

def split_pieces(upper):
    alpha = upper[..., 3] > 0
    body = upper.copy()
    pieces = {}
    for name, poly in POLY.items():
        hole = poly_mask(poly, upper.shape[:2]) & alpha
        piece_mask = ndi.binary_dilation(hole, iterations=DILATE[name]) & alpha
        piece = upper.copy()
        piece[..., 3] = np.where(piece_mask, upper[..., 3], 0)
        pieces[name] = piece
        body[..., 3] = np.where(hole, 0, body[..., 3])
    return body, pieces

# ---- 脚（v4と同一のベクター描画） -----------------------------------------
L1, L2 = 42.0, 40.0
HIP_NEAR = (198.0, 338.0)
HIP_FAR = (184.0, 334.0)
LEG = [
    (34, None, -10), (14, None, 0), (-6, None, 0), (-30, 5, 40),
    (-36, 14, 50), (-18, 30, 34), (8, 24, 4), (32, 6, -14),
]
NEAR = dict(pants=(110, 70, 54), pants_hi=(136, 90, 70), band=(240, 232, 214),
            boot=(128, 80, 62), boot_hi=(170, 114, 90), sole=(70, 44, 34))
FAR = dict(pants=(74, 46, 36), pants_hi=(92, 58, 45), band=(184, 174, 158),
           boot=(92, 58, 45), boot_hi=(120, 78, 60), sole=(50, 32, 25))
INK = (20, 14, 12, 255)
OL = 5.0

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
BAND = [(-14, -14), (14, -14), (14, -4), (-14, -4)]
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
    ka = a - b
    return (hip[0] + L1 * math.cos(ka), hip[1] + L1 * math.sin(ka)), d

def leg_pose(frame, far, bob):
    k = (frame + (4 if far else 0)) % 8
    dx, lift, ang = LEG[k]
    hip = HIP_FAR if far else HIP_NEAR
    hip = (hip[0], hip[1] + bob[frame])
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
    capsule(dr, hip, knee, wt + 2 * OL, INK)
    capsule(dr, knee, ank, ws + 2 * OL, INK)
    dr.line(boot + [boot[0]], fill=INK, width=int(2 * OL * S), joint='curve')
    dr.polygon(boot, fill=INK)
    capsule(dr, hip, knee, wt, pal['pants'])
    capsule(dr, knee, ank, ws, pal['pants'])
    off = (1.8, -1.8)
    capsule(dr, (hip[0] + off[0], hip[1] + off[1]), (knee[0] + off[0], knee[1] + off[1]), wt * 0.55, pal['pants_hi'])
    capsule(dr, (knee[0] + off[0], knee[1] + off[1]), (ank[0] + off[0] - 2, ank[1] + off[1] - 8), ws * 0.5, pal['pants_hi'])
    dr.polygon(boot, fill=pal['boot'])
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

# ---- 弾み「中」「強」の2案 --------------------------------------------------
# 中はv4と同じ値。強は胴体の上下・前傾を約1.6倍に拡大。
VARIANTS = {
    'medium': dict(
        bob=[0, 7, 2, -6, 0, 7, 2, -6],
        lean=[1.5, 2.5, 1.5, 0.0, 1.5, 2.5, 1.5, 0.0],
        sway=dict(weapon=1.0, scarf=2.0, hair_top=2.0, hair_side=2.2),
        lag=dict(weapon=1, scarf=2, hair_top=2, hair_side=3),
        weapon_dy=0.15,
    ),
    'strong': dict(
        bob=[0, 11, 3, -10, 0, 11, 3, -10],
        lean=[2.5, 4.0, 2.5, 0.0, 2.5, 4.0, 2.5, 0.0],
        sway=dict(weapon=2.0, scarf=4.0, hair_top=4.0, hair_side=4.5),
        lag=dict(weapon=1, scarf=2, hair_top=2, hair_side=3),
        weapon_dy=0.30,
    ),
}

def sway_series(bob, amp, lag):
    # 胴体の上下動(bob)を lag コマ分遅らせた値との差分を揺れ角(度)にする＝追従の遅れ表現
    n = len(bob)
    out = []
    for f in range(n):
        delayed = bob[(f - lag) % n]
        out.append(amp * (delayed - bob[f]) / 10.0)
    return out

def render_variant(upper_body, pieces, variant):
    V = VARIANTS[variant]
    bob, lean = V['bob'], V['lean']
    sways = {name: sway_series(bob, V['sway'][name], V['lag'][name]) for name in pieces}
    body_img = Image.fromarray(upper_body)
    piece_imgs = {name: Image.fromarray(p) for name, p in pieces.items()}
    frames, meta = [], []
    for f in range(8):
        big = Image.new('RGBA', (CELL * S, CELL * S), (0, 0, 0, 0))
        Pf = leg_pose(f, far=True, bob=bob)
        Pn = leg_pose(f, far=False, bob=bob)
        draw_leg(big, Pf, FAR)
        draw_leg(big, Pn, NEAR)
        legs = big.resize((CELL, CELL), Image.LANCZOS)
        pivot = (HIP_NEAR[0], HIP_NEAR[1])
        body = body_img.rotate(-lean[f], resample=Image.BICUBIC, center=pivot, translate=(0, bob[f]))
        frame = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
        frame.alpha_composite(legs)
        frame.alpha_composite(body)
        dy_w = round(V['weapon_dy'] * (bob[(f - V['lag']['weapon']) % 8] - bob[f]))
        for name in ('weapon', 'hair_side', 'hair_top', 'scarf'):
            # 1) パーツ固有の小さな遅延揺れ（元のセル座標・自パーツの根本点まわり）
            dy_local = dy_w if name == 'weapon' else 0
            local = piece_imgs[name].rotate(-sways[name][f], resample=Image.BICUBIC,
                                            center=PIVOT[name], translate=(0, dy_local))
            # 2) 胴体と全く同じ変換（HIP_NEAR中心の前傾＋上下）を重ねて適用→穴と隙間なく揃う
            layer = local.rotate(-lean[f], resample=Image.BICUBIC, center=pivot, translate=(0, bob[f]))
            frame.alpha_composite(layer)
        frames.append(frame)
        meta.append(dict(frame=f, bob=bob[f], lean=lean[f],
                         sway={k: round(v[f], 3) for k, v in sways.items()},
                         near=dict(ground=Pn['ground']), far=dict(ground=Pf['ground'])))
    return frames, meta

if __name__ == '__main__':
    upper = build_upper()
    body, pieces = split_pieces(upper)
    result = {}
    for variant in ('medium', 'strong'):
        frames, meta = render_variant(body, pieces, variant)
        w = int(CELL * OUT_SCALE)
        sheet = Image.new('RGBA', (w * 8, w), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            sheet.alpha_composite(fr.resize((w, w), Image.LANCZOS), (i * w, 0))
        sheet.save(os.path.join(HERE, f'run-cycle-v5-{variant}-sheet.png'))
        # 足送り（stride_per_frame）はv4と同じ脚設計（LEGのdx）を変更していないため v4 のもの（10px/コマ、シート画素）を流用する。
        result[variant] = dict(cell=w, frames=8,
                                ground_y=G * OUT_SCALE, origin_x=HIP_NEAR[0] * OUT_SCALE,
                                frames_meta=meta)
    result['pivots'] = {k: [round(v[0] * OUT_SCALE, 1), round(v[1] * OUT_SCALE, 1)] for k, v in PIVOT.items()}
    result['source'] = 'run-keyposes-fix.png cell 2 (upper body only); weapon/hair_top/hair_side/scarf cut from same source, no new generation'
    json.dump(result, open(os.path.join(HERE, 'run-cycle-v5-meta.json'), 'w'), ensure_ascii=False, indent=1)
    print('ok')
