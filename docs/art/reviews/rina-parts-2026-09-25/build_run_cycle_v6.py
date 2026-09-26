"""リナ側面走行サイクル v6：体と武器の分離（本編の銃画像＋コード描画の腕）、弾み「中」「強」の作り直し。

v5レビュー（2026-09-25）の指摘への対応:
  - 武器は1枚絵から切り抜かない。上体原画から銃・手袋・前腕の先を消し（仮の胴体）、
    銃は assets/first-workshop/equipment/guns/*.png を data/weapon_visuals.json の grip で手に合わせて
    レビューHTML側で別レイヤーとして描く。腕は同HTMLのコードで描き、手を grip（長い武器は銃身の支持点）へ届かせる。
  - 髪・ポニーテール・スカーフは切り抜かず、上体画像全体を1回のワープで変形する（根本0→毛先1の滑らかな重み）。
    穴と貼り戻しをしないので切れ目・二重輪郭が出ない。揺れ角は頭の上下加速度を入力にした減衰ばねで求める。
  - 弾み：半周期4コマ＝着地(縮み)→蹴り出し(伸び)→滞空→滞空。両足空中は8コマ中4コマ。
    脚は前後に大きく開き、後ろ足を高く跳ね上げる新しい脚表を使う。
  - 銃は照準角0°を保ち、体の上下に1コマ遅れ・縮小した量だけ追従する（銃口は体より跳ねない）。

仮の胴体について：近側の上腕〜前腕の袖は原画に描かれたまま残るため、近側の腕は「原画の手首→銃の grip」までを
コードの手袋で描く。遠側の腕は肩からコードで描く。腕と銃のない胴体素材（gpt-image-2）が用意できたら
UPPER_SOURCE を差し替え、近側も肩から描く。

出力: run-cycle-v6-<variant>-sheet.png（体＋脚のみ、8コマ横並び RGBA）、run-cycle-v6-meta.json（各コマの腕・銃の基準点、
      足送り、接地、表示倍率の基準）。
再現: python build_run_cycle_v6.py （このフォルダーで実行。Pillow/numpy/scipy が必要）
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
# 表示倍率の基準：直立・上下動0のときの全高（セル画素）。レビューではこれを56pxにする。
# v5までのページは全コマの上下幅込みの高さで割っていたため、弾みが大きい案ほど小さく表示されていた。
NOMINAL_HEIGHT = 410.0
HIP = (198.0, 338.0)          # 上体の回転・拡縮の中心（近側の腰）
HIP_FAR = (184.0, 334.0)
INK = (20, 14, 12, 255)

# ---- 上体（v4と同じ切出し）から銃・手袋・前腕の先を消す ------------------------------
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
    c[ring & region] = INK
    return c

# 銃・両手袋・撃鉄を含む領域（目視で決めた多角形。顎・スカーフ・胴の前端は含めない）
WEAPON_ERASE = [(251, 350), (251, 300), (257, 291), (268, 285), (283, 276), (292, 262),
                (296, 246), (430, 236), (430, 350)]
WRIST_NEAR = (252.0, 312.0)   # 消した後の袖口（近側の手袋はここから描く）
SHOULDER_FAR = (212.0, 292.0) # 遠側の肩（胴の後ろに隠れる位置）
HAND_BASE = (282.0, 314.0)    # 近側の手（銃の grip）の基準位置

def erase_weapon(upper):
    c = upper.copy()
    m = Image.new('L', (CELL, CELL), 0)
    ImageDraw.Draw(m).polygon(WEAPON_ERASE, fill=255)
    E = np.asarray(m) > 0
    c[E] = 0
    # 消した境界に接する不透明画素を輪郭色にして、袖口・顎下の切り口を閉じる
    opaque = c[..., 3] > 100
    edge = opaque & ndi.binary_dilation(E, iterations=4)
    c[edge] = INK
    return c

# ---- ワープ（上体全体を1回で変形：前傾・拡縮・上下＋毛先の揺れ） ------------------------
# 根本点、毛先方向の重み領域（多角形）、根本から毛先までの距離
BENDS = dict(
    ponytail=dict(root=(186.0, 92.0), poly=[(128, 64), (146, 6), (196, 0), (238, 14), (240, 70), (210, 100), (170, 96)], reach=90.0),
    hair_back=dict(root=(128.0, 150.0), poly=[(40, 150), (76, 108), (126, 120), (136, 160), (120, 214), (80, 222), (44, 196)], reach=80.0),
    scarf=dict(root=(166.0, 262.0), poly=[(84, 280), (104, 250), (140, 240), (176, 248), (178, 290), (140, 304), (100, 300)], reach=80.0),
)

def bend_weights():
    yy, xx = np.mgrid[0:CELL, 0:CELL].astype(np.float32)
    out = {}
    for name, b in BENDS.items():
        m = Image.new('L', (CELL, CELL), 0)
        ImageDraw.Draw(m).polygon(b['poly'], fill=255)
        soft = ndi.gaussian_filter(np.asarray(m, np.float32) / 255.0, 7)
        rx, ry = b['root']
        ramp = np.clip(np.hypot(xx - rx, yy - ry) / b['reach'], 0, 1)
        ramp = ramp * ramp * (3 - 2 * ramp)  # smoothstep：根本は動かさず毛先ほど大きく回す
        out[name] = soft * ramp
    return out

def premult(a):
    f = a.astype(np.float32) / 255.0
    f[..., :3] *= f[..., 3:4]
    return f

def warp(upper_pm, weights, lean_deg, sx, sy, bob, bends_deg):
    """出力画素→元画素の逆写像。全体: 腰中心の拡縮→前傾(時計回り)→上下。局所: 毛先の回転。"""
    yy, xx = np.mgrid[0:CELL, 0:CELL].astype(np.float32)
    hx, hy = HIP
    px, py = xx - hx, yy - (hy + bob)
    a = math.radians(lean_deg)
    ca, sa = math.cos(a), math.sin(a)
    qx = (px * ca + py * sa) / sx + hx     # 時計回り回転の逆
    qy = (-px * sa + py * ca) / sy + hy
    dx = np.zeros_like(qx); dy = np.zeros_like(qy)
    for name, w in weights.items():
        t = math.radians(bends_deg.get(name, 0.0))
        rx, ry = BENDS[name]['root']
        wq = ndi.map_coordinates(w, [qy, qx], order=1, cval=0.0)
        ux, uy = qx - rx, qy - ry
        c2, s2 = math.cos(t), math.sin(t)
        # 時計回りに t 回した内容を見せる → 元画素は反時計回りに t 戻した位置
        bx = ux * c2 + uy * s2 + rx
        by = -ux * s2 + uy * c2 + ry
        dx += wq * (bx - qx); dy += wq * (by - qy)
    sxp, syp = qx + dx, qy + dy
    out = np.zeros_like(upper_pm)
    for k in range(4):
        out[..., k] = ndi.map_coordinates(upper_pm[..., k], [syp, sxp], order=1, cval=0.0)
    al = np.clip(out[..., 3:4], 1e-6, 1)
    rgb = np.where(out[..., 3:4] > 1e-4, out[..., :3] / al, 0)
    res = np.concatenate([np.clip(rgb, 0, 1), np.clip(out[..., 3:4], 0, 1)], -1)
    return Image.fromarray((res * 255 + 0.5).astype(np.uint8))

def body_point(p, lean_deg, sx, sy, bob):
    """上体の点を全体変換（拡縮→前傾→上下）で移した位置。"""
    hx, hy = HIP
    x, y = (p[0] - hx) * sx, (p[1] - hy) * sy
    a = math.radians(lean_deg)
    return (hx + x * math.cos(a) - y * math.sin(a), hy + x * math.sin(a) + y * math.cos(a) + bob)

# ---- 脚 ----------------------------------------------------------------------------
L1, L2 = 42.0, 40.0
STRIDE = 22.0   # 接地脚の1コマあたり後退量＝体の前進量（セル画素）
# 片脚8相：(腰からのdx, 接地ならNone/空中なら床からの持上げ, 靴角度(+でつま先下がり))
# 0 着地(踵〜足裏、縮み) 1 蹴り出し(つま先で押す) 2 後ろへ高く跳ね上げ 3 踵を尻へ回収
# 4 膝を前へ高く 5 前へ振り出し 6 前へ伸ばし切る(大きく開く) 7 着地へ降ろす
LEG = [
    (14, None, -4),
    (14 - STRIDE, None, 28),
    (-44, 24, 62),
    (-22, 44, 78),
    (6, 40, 20),
    (30, 26, -10),
    (40, 12, -18),
    (30, 3, -10),
]
NEAR = dict(pants=(110, 70, 54), pants_hi=(136, 90, 70), band=(240, 232, 214),
            boot=(128, 80, 62), boot_hi=(170, 114, 90), sole=(70, 44, 34))
FAR = dict(pants=(74, 46, 36), pants_hi=(92, 58, 45), band=(184, 174, 158),
           boot=(92, 58, 45), boot_hi=(120, 78, 60), sole=(50, 32, 25))
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
    dd = min(d, L1 + L2 - 0.01)
    a = math.atan2(dy, dx)
    c = (L1 * L1 + dd * dd - L2 * L2) / (2 * L1 * dd)
    b = math.acos(max(-1, min(1, c)))
    ka = a - b
    return (hip[0] + L1 * math.cos(ka), hip[1] + L1 * math.sin(ka)), d

def leg_pose(frame, far, bob):
    k = (frame + (4 if far else 0)) % 8
    dx, lift, ang = LEG[k]
    hip = HIP_FAR if far else HIP
    hip = (hip[0], hip[1] + bob[frame])
    a = math.radians(ang)
    low = max(y for _, y in rot(BOOT, a))
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

# ---- 弾み2案 --------------------------------------------------------------------------
# 半周期4コマ：着地(縮み・最下点) → 蹴り出し(伸び) → 滞空(最高点付近) → 滞空(下降)
# bob: 腰の上下(+下, セル画素)。7.3セル画素 ≒ 56px表示で1px。頭の上下は bob に縮み・前傾の変化が加わり、
# 56px換算で中≒2.6px、強≒3.2px（ゴーグル位置）になるよう合わせた（大頭なので縮みの量が頭の移動に強く効く）。
VARIANTS = {
    'medium': dict(bob=[6, 0, -5, -3], lean_base=5.0, lean=[1.0, -0.3, -0.5, 0.0],
                   squash=[(1.015, 0.978), (0.99, 1.012), (1.0, 1.006), (1.0, 1.0)],
                   gun_follow=0.40, spring_gain=1.0),
    'strong': dict(bob=[7, 0, -6, -3], lean_base=8.0, lean=[1.5, -0.5, -0.8, 0.0],
                   squash=[(1.02, 0.972), (0.99, 1.014), (0.998, 1.008), (1.0, 1.0)],
                   gun_follow=0.35, spring_gain=0.85),
}
# 減衰ばね（毛先の追従）：固有角速度(rad/コマ)、減衰比、入力倍率、常時の後方なびき(度)
SPRINGS = dict(ponytail=(1.25, 0.35, 0.55, -2.0), hair_back=(1.45, 0.40, 0.45, -1.0), scarf=(1.05, 0.30, 0.60, -5.0))
HEAD = (200.0, 120.0)  # 揺れの入力にする頭の代表点

def expand(half):
    return list(half) + list(half)

def spring_angles(head_y, gain):
    """頭の上下位置（周期8コマ）から、各毛先の角度を減衰ばねで求める（収束後の1周期）。"""
    n = len(head_y)
    acc = [head_y[(f + 1) % n] - 2 * head_y[f] + head_y[f - 1] for f in range(n)]
    out = {}
    sub = 16
    for name, (w, z, g, rest) in SPRINGS.items():
        th, om = 0.0, 0.0
        res = [0.0] * n
        for loop in range(30):
            for f in range(n):
                for s in range(sub):
                    t = f + s / sub
                    i0 = int(t) % n; fr = t - int(t)
                    a = acc[i0] * (1 - fr) + acc[(i0 + 1) % n] * fr
                    # 頭が下へ加速すると毛先は相対的に上へ（時計回り＝＋）遅れる
                    dom = -w * w * th - 2 * z * w * om + g * gain * a
                    om += dom / sub; th += om / sub
                res[f] = th
        out[name] = [round(rest * gain + v, 3) for v in res]  # 度
    return out

def frame_params(V):
    bob = expand(V['bob'])
    lean = [V['lean_base'] + d for d in expand(V['lean'])]
    sq = expand(V['squash'])
    head_y = [body_point(HEAD, lean[f], sq[f][0], sq[f][1], bob[f])[1] for f in range(8)]
    bends = spring_angles(head_y, V['spring_gain'])
    return bob, lean, sq, bends

def render_variant(upper_pm, weights, variant):
    V = VARIANTS[variant]
    bob, lean, sq, bends = frame_params(V)
    frames, meta = [], []
    for f in range(8):
        big = Image.new('RGBA', (CELL * S, CELL * S), (0, 0, 0, 0))
        Pf = leg_pose(f, far=True, bob=bob)
        Pn = leg_pose(f, far=False, bob=bob)
        draw_leg(big, Pf, FAR)
        draw_leg(big, Pn, NEAR)
        legs = big.resize((CELL, CELL), Image.LANCZOS)
        body = warp(upper_pm, weights, lean[f], sq[f][0], sq[f][1], bob[f], {k: v[f] for k, v in bends.items()})
        frame = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
        frame.alpha_composite(legs)
        frame.alpha_composite(body)
        frames.append(frame)
        # 銃：照準角0°、体の上下へ1コマ遅れ・縮小して追従。基準は平均の前傾での手の位置。
        gb = V['gun_follow'] * bob[(f - 1) % 8]
        hand = body_point(HAND_BASE, V['lean_base'], 1.0, 1.0, gb)
        wrist = body_point(WRIST_NEAR, lean[f], sq[f][0], sq[f][1], bob[f])
        shoulder_far = body_point(SHOULDER_FAR, lean[f], sq[f][0], sq[f][1], bob[f])
        o = OUT_SCALE
        meta.append(dict(frame=f, bob=bob[f], lean=round(lean[f], 2), squash=[sq[f][0], sq[f][1]],
                         bend={k: round(v[f], 2) for k, v in bends.items()},
                         hand=[round(hand[0] * o, 2), round(hand[1] * o, 2)],
                         wrist_near=[round(wrist[0] * o, 2), round(wrist[1] * o, 2)],
                         shoulder_far=[round(shoulder_far[0] * o, 2), round(shoulder_far[1] * o, 2)],
                         near=dict(key=Pn['key'], ground=Pn['ground'], ankle_x=round(Pn['ank'][0], 1), reach=round(Pn['reach'], 2)),
                         far=dict(key=Pf['key'], ground=Pf['ground'], ankle_x=round(Pf['ank'][0], 1), reach=round(Pf['reach'], 2))))
    return frames, meta

def load_upper():
    return premult(erase_weapon(build_upper()))

if __name__ == '__main__':
    upper_pm = load_upper()
    weights = bend_weights()
    result = {}
    w = int(CELL * OUT_SCALE)
    for variant in ('medium', 'strong'):
        frames, meta = render_variant(upper_pm, weights, variant)
        sheet = Image.new('RGBA', (w * 8, w), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            sheet.alpha_composite(fr.resize((w, w), Image.LANCZOS), (i * w, 0))
        sheet.save(os.path.join(HERE, f'run-cycle-v6-{variant}-sheet.png'))
        over = [(m['frame'], s) for m in meta for s in ('near', 'far') if m[s]['reach'] > L1 + L2]
        if over:
            raise SystemExit(f'{variant}: 脚が届かないコマ {over}')
        result[variant] = dict(frames_meta=meta)
    result.update(cell=w, frames=8, ground_y=G * OUT_SCALE, origin_x=HIP[0] * OUT_SCALE,
                  nominal_height=NOMINAL_HEIGHT * OUT_SCALE, stride_per_frame=STRIDE * OUT_SCALE,
                  source='run-keyposes-fix.png cell 2 (upper body; gun, gloves and forearm tips erased = provisional body). '
                         'Guns are drawn separately from assets/first-workshop/equipment/guns via data/weapon_visuals.json.')
    json.dump(result, open(os.path.join(HERE, 'run-cycle-v6-meta.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('ok')
