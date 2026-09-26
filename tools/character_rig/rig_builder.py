"""8方向キャラクターリグの共通ビルダー（2026-09-26、リナ v8 を一般化）。

キャラごとに用意するもの：
  - 生成パーツ画像（assets/generated/*.png、白背景）：向きごとの 頭＋胴、揺れ物（髪・布など任意個）、腕・手袋
  - 設定ファイル tools/character_rig/characters/<name>.json：部品の取り出し位置、向きごとの基準点、揺れ物、脚と腕の色
動き（走行・待機・回避の体と脚、揺れの基準角）はこのファイルの共通コードが作る。
出力：<out_dir>/<view>-<action>-lower.png / -upper.png、<view>-<swing>.png、arm-*.png、rig.json（ゲーム座標）。
ゲーム側の描画は scripts/visuals/character_rig8.gd。

座標系：セル（CW×CH、セル画素）→ シート（×OUT_SCALE）→ ゲーム画素（WORLD_K、足元 y=FOOT_Y）。
"""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
GEN = os.path.join(ROOT, 'assets', 'generated')

# ---- セルと体の共通寸法（リナ v7/v8 と同じ値） -----------------------------------------------
PAD = 40
CW, CH = 443 + 80, 443 + PAD      # 回避で頭が前へ出るため右へ80広げたセル
OUT_SCALE = 0.5
S4 = 4                            # 脚の超解像描画の倍率
G = 428 + PAD                     # 床の高さ
HIP_C = (191.0, 336.0 + PAD)      # 左右の腰の中央
PIVOT_Y = 338.0 + PAD             # 前傾・縮みの支点の高さ
HIP_W = 18.0                      # 腰の左右の半幅
DEPTH_Y = 2.0 / 18.0              # 奥行きを画面の下方向へ写す比率
SIDE_SPREAD = 7.0                 # 側面で近側/遠側の腰を前後へずらす量
BOOT_W = 12.0                     # 靴の左右の半幅
RING_TO_HEM = 608.0 * 0.44        # 頭頂の基準点〜裾（セル画素）。全向きをこの長さにそろえる
HEM_Y = 350.0 + PAD               # 裾の中央を置く高さ
SPRING_HIP = (198.0, 338.0 + PAD) # 揺れの入力（頭の上下）を求めるときの支点
# ゲーム座標への変換（v7 の全高基準：シートで210画素＝56ゲーム画素、原点 x=99・床 y=234 → 足元 y=15）
WORLD_K = 56.0 / 210.0
ORIGIN = (99.0, 234.0)
FOOT_Y = 15.0
INK = (20, 14, 12, 255)
OL = 5.0
L1, L2 = 42.0, 40.0               # 腿・脛の長さ
MIRROR = {'e': ['side', False], 'se': ['diag_front', False], 's': ['front', False], 'sw': ['diag_front', True],
          'w': ['side', True], 'nw': ['diag_back', True], 'n': ['back', False], 'ne': ['diag_back', False]}

# ---- 小道具 ----------------------------------------------------------------------------
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
    [(-9, -6), (-15, 4), (-14, 15), (-8, 21), (10, 22), (26, 21), (34, 14), (31, 4), (20, -1), (8, -4)])]
BAND = [(-14, -14), (14, -14), (14, -4), (-14, -4)]
BAND_INK = [(-16.5, -16.5), (16.5, -16.5), (16.5, -1.5), (-16.5, -1.5)]

def rot(pts, a, o=(0, 0)):
    ca, sa = math.cos(a), math.sin(a)
    return [(o[0] + x * ca - y * sa, o[1] + x * sa + y * ca) for x, y in pts]

def capsule(dr, a, b, w, col):
    sc = lambda p: (p[0] * S4, p[1] * S4)
    dr.line([sc(a), sc(b)], fill=col, width=int(w * S4))
    for p in (a, b):
        r = w * S4 / 2
        dr.ellipse([p[0] * S4 - r, p[1] * S4 - r, p[0] * S4 + r, p[1] * S4 + r], fill=col)

def remove_white(rgb):
    """外周とつながる白背景を透明にし、輪郭の白混じりを白から分離する。"""
    a = rgb.astype(np.float32)
    near_white = a.min(-1) > 225
    lab, _ = ndi.label(near_white)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    alpha = np.where(bg, 0.0, 1.0)
    ring = ~bg & ndi.binary_dilation(bg, iterations=2)
    k = np.clip((255.0 - a.min(-1)) / (255.0 - 30.0), 0, 1)
    alpha = np.where(ring, np.minimum(alpha, k), alpha)
    col = np.where(alpha[..., None] > 1e-3, (a - 255.0 * (1 - alpha[..., None])) / np.maximum(alpha[..., None], 1e-3), 0)
    return np.dstack([np.clip(col, 0, 255), alpha * 255]).astype(np.uint8)

def over(dst, src):
    return src + dst * (1.0 - src[..., 3:4])

def to_image(pm):
    al = np.clip(pm[..., 3:4], 1e-6, 1)
    rgb = np.where(pm[..., 3:4] > 1e-4, pm[..., :3] / al, 0)
    return Image.fromarray((np.dstack([np.clip(rgb, 0, 1), np.clip(pm[..., 3:4], 0, 1)]) * 255 + 0.5).astype(np.uint8))

def warp(src, pivot, lean, sx, sy, bob, local=None, weight=None):
    """出力→元の逆写像。全体：支点中心の拡縮→前傾→上下。local=(根本, 角度)：weight（無ければ全体）で根本まわりに回す。"""
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    hx, hy = pivot
    px, py = xx - hx, yy - (hy + bob)
    a = math.radians(lean)
    ca, sa = math.cos(a), math.sin(a)
    qx = (px * ca + py * sa) / sx + hx
    qy = (-px * sa + py * ca) / sy + hy
    if local:
        (rx, ry), t = local
        t = math.radians(t)
        ux, uy = qx - rx, qy - ry
        bx = ux * math.cos(t) + uy * math.sin(t) + rx
        by = -ux * math.sin(t) + uy * math.cos(t) + ry
        w = 1.0 if weight is None else ndi.map_coordinates(weight, [qy, qx], order=1, cval=0.0)
        qx, qy = qx + w * (bx - qx), qy + w * (by - qy)
    out = np.zeros_like(src)
    for k in range(4):
        out[..., k] = ndi.map_coordinates(src[..., k], [qy, qx], order=1, cval=0.0)
    return out

def body_point(p, lean, sx, sy, bob, pivot):
    hx, hy = pivot
    x, y = (p[0] - hx) * sx, (p[1] - hy) * sy
    a = math.radians(lean)
    return (hx + x * math.cos(a) - y * math.sin(a), hy + x * math.sin(a) + y * math.cos(a) + bob)

# ---- 生成画像の部品 -----------------------------------------------------------------------
def components(src):
    """白背景を除去し、pick の点に重心が最も近い連結成分をその名前の部品として返す。"""
    rgba = remove_white(np.asarray(Image.open(os.path.join(GEN, src['file'] + '.png')).convert('RGB')))
    lab, n = ndi.label(rgba[..., 3] > 0)
    comps = []
    for i in range(1, n + 1):
        m = lab == i
        if m.sum() < 2000: continue
        ys, xs = np.nonzero(m)
        comps.append((m, xs.mean(), ys.mean()))
    out = {}
    for name, (px, py) in src['pick'].items():
        m = min(comps, key=lambda c: (c[1] - px) ** 2 + (c[2] - py) ** 2)[0]
        p = rgba.copy()
        p[..., 3] = np.where(ndi.binary_dilation(m, iterations=2), rgba[..., 3], 0)
        out[name] = p
    return out

def view_geometry(v):
    yaw = math.radians(v['yaw'])
    s = RING_TO_HEM / (v['hem'][1] - v['ring'][1])
    hem_cell = (HIP_C[0] + 24.0 * math.cos(yaw), HEM_Y)
    place = lambda p: ((p[0] - v['hem'][0]) * s + hem_cell[0], (p[1] - v['hem'][1]) * s + hem_cell[1])
    return yaw, s, place

def to_cell(part, s, place, offset=(0.0, 0.0), flip_about=None):
    """生成画像の部品を倍率sでセルへ置く（premultiplied）。flip_about=x なら生成画像上のxを軸に左右反転。"""
    im = Image.fromarray(part)
    if flip_about is not None:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
        offset = (offset[0] + (2 * flip_about - im.width), offset[1])
    w, h = round(im.width * s), round(im.height * s)
    small = np.asarray(im.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255.0
    small[..., :3] *= small[..., 3:4]
    out = np.zeros((CH, CW, 4), np.float32)
    x0, y0 = place(offset)
    x0, y0 = int(round(x0)), int(round(y0))
    sx0, sy0, dx0, dy0 = max(0, -x0), max(0, -y0), max(0, x0), max(0, y0)
    ww, hh = min(w - sx0, CW - dx0), min(h - sy0, CH - dy0)
    if ww > 0 and hh > 0:
        out[dy0:dy0 + hh, dx0:dx0 + ww] = small[sy0:sy0 + hh, sx0:sx0 + ww]
    return out

def head_only(body, cut):
    """首の線（数値＝水平、[[x,y],...]＝折れ線）より上だけを残す。"""
    h = body.copy()
    yy, xx = np.mgrid[0:h.shape[0], 0:h.shape[1]]
    if isinstance(cut, (int, float)):
        line = np.full(h.shape[1], float(cut))
    else:
        line = np.interp(np.arange(h.shape[1]), [p[0] for p in cut], [p[1] for p in cut])
    h[..., 3] = np.where(yy < line[None, :], h[..., 3], 0)
    return h

def transform_part(arr, root, move=(0.0, 0.0), tilt=0.0, squash=1.0):
    """部品を付け根まわりに回転・縦縮みし、平行移動する（逆写像）。"""
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    rx, ry = root[0] + move[0], root[1] + move[1]
    ux, uy = xx - rx, yy - ry
    t = math.radians(tilt)
    qx = ux * math.cos(t) + uy * math.sin(t)
    qy = (-ux * math.sin(t) + uy * math.cos(t)) / squash
    sx, sy = qx + root[0], qy + root[1]
    out = np.zeros_like(arr)
    for c in range(4):
        out[..., c] = ndi.map_coordinates(arr[..., c], [sy, sx], order=1, cval=0.0)
    return out

def erase_ring(arr, box):
    """揺れ物の付け根を動かしたとき、頭側に残る留め具を消し、頭の輪郭を放物線で補う（セル座標）。"""
    x0, y0, x1, y1 = [int(round(v)) for v in box]
    a = arr[..., 3]
    pts = []
    for x in list(range(x0 - 24, x0 - 2)) + list(range(x1 + 3, x1 + 25)):
        col = np.nonzero(a[max(0, y0 - 40):y1 + 60, x] > .5)[0]
        if len(col): pts.append((x, col[0] + max(0, y0 - 40)))
    if len(pts) < 6: return arr
    px, py = np.array(pts, float).T
    coef = np.polyfit(px, py, 2)
    out = arr.copy()
    rgb = np.where(out[..., 3:4] > 1e-4, out[..., :3] / np.maximum(out[..., 3:4], 1e-4), 0)
    gold = (rgb[..., 0] > .62) & (rgb[..., 1] > .45) & (rgb[..., 2] < .5) & (rgb[..., 0] - rgb[..., 2] > .22) & (out[..., 3] > .3)
    inbox = np.zeros(a.shape, bool); inbox[y0:y1 + 1, x0:x1 + 1] = True
    gold &= inbox
    near_gold = ndi.binary_dilation(gold, iterations=4) & inbox
    dark = (rgb.max(-1) < .32) & (out[..., 3] > .3)
    ring_ink = dark & ndi.binary_dilation(gold, iterations=9) & inbox
    ink = np.array([20, 14, 12], np.float32) / 255
    yc_mid = np.polyval(coef, (x0 + x1) / 2)
    ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    sample = (ys > yc_mid + 10) & (ys < yc_mid + 30) & (xs >= x0) & (xs <= x1) & (out[..., 3] > .95) & ~near_gold
    hair = np.median(rgb[sample], axis=0) if sample.sum() > 10 else np.array([.45, .29, .2], np.float32)
    for x in range(x0, x1 + 1):
        yc = int(round(np.polyval(coef, x)))
        for y in range(max(0, y0 - 10), y1 + 1):
            if y < yc:
                out[y, x] = 0
            elif y < yc + 4:
                out[y, x, :3] = ink; out[y, x, 3] = 1
            elif near_gold[y, x] or ring_ink[y, x]:
                out[y, x, :3] = hair; out[y, x, 3] = 1
    return out

def load_view(v, comps):
    """1向きの部品をセルへ置く。戻り値：parts（torso/head/揺れ物/warp重み）、roots（付け根）、yaw、s、place。"""
    yaw, s, place = view_geometry(v)
    body = comps[v['torso']]
    parts = {'torso': to_cell(body, s, place)}
    if v.get('head_cut') is not None:
        parts['head'] = to_cell(head_only(body, v['head_cut']), s, place)
    roots = {}
    if 'warp' in v:
        wp = v['warp']
        m = Image.new('L', (body.shape[1], body.shape[0]), 0)
        ImageDraw.Draw(m).polygon([tuple(p) for p in wp['poly']], fill=255)
        hb = np.asarray(m, np.uint8)
        cell = to_cell(np.dstack([np.zeros(hb.shape + (3,), np.uint8), hb]), s, place)[..., 3]
        cell = ndi.gaussian_filter(cell, wp.get('blur', 5))
        yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
        r = place(wp['root'])
        ramp = np.clip(np.hypot(xx - r[0], yy - r[1]) / wp.get('reach', 60), 0, 1)
        parts['warp_w'] = cell * ramp * ramp * (3 - 2 * ramp)
        roots['warp'] = r
    for sw in v.get('swing', []):
        off = (sw['attach'][0] - sw['src_root'][0], sw['attach'][1] - sw['src_root'][1])
        parts[sw['name']] = to_cell(comps[sw['comp']], s, place, off, flip_about=sw['src_root'][0] if sw.get('flip') else None)
        roots[sw['name']] = place(sw['attach'])
        st = sw.get('style')
        if st:
            move = tuple(st.get('move', (0.0, 0.0)))
            if 'erase_box' in st and move != (0.0, 0.0):
                bx = st['erase_box']
                (cx0, cy0), (cx1, cy1) = place((bx[0], bx[1])), place((bx[2], bx[3]))
                for name in ('torso', 'head'):
                    if name in parts: parts[name] = erase_ring(parts[name], (cx0, cy0, cx1, cy1))
            parts[sw['name']] = transform_part(parts[sw['name']], roots[sw['name']], move, st.get('tilt', 0.0), st.get('squash', 1.0))
            roots[sw['name']] = (roots[sw['name']][0] + move[0], roots[sw['name']][1] + move[1])
    return parts, roots, yaw, s, place

# ---- 脚（側面の足の軌跡を向きごとに投影） -----------------------------------------------------
FOOT_OUT = 16.0      # 正面・背面で足首を腰より外へ出す量（ハの字）
SWING_OUT = 8.0      # 持ち上げた足を外へ振る量（持上げ40あたり）
TOE_OUT = 18.0       # つま先を外へ向ける角（度）
LIFT_FB = 0.35       # 正面・背面で持ち上げを弱める割合

def convex_hull(pts):
    pts = sorted(set((round(x, 3), round(y, 3)) for x, y in pts))
    if len(pts) < 3: return pts
    def cross(o, a, b): return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0: lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0: upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]

def leg3(key, side, bob, yaw):
    """key=(前後のずれ, 接地ならNone/空中なら持上げ, 靴角度)。side=+1 近側/-1 遠側。"""
    dx, lift, ang = key
    fb = abs(math.sin(yaw))
    if lift is not None: lift = lift * (1 - LIFT_FB * fb)
    fx, fz = math.cos(yaw), math.sin(yaw)
    lx, lz = -math.sin(yaw), math.cos(yaw)
    hip_x = HIP_C[0] + side * (HIP_W * lx + SIDE_SPREAD * math.cos(yaw))
    hip_z = side * HIP_W * lz
    hip_y = HIP_C[1] + bob
    a = math.radians(ang)
    low = max(y for _, y in rot(BOOT, a))
    drop = (G - low - (lift or 0)) - hip_y
    out = side * min(1.0, fb * 1.4) * (FOOT_OUT + SWING_OUT * (lift or 0) / 40.0)
    d = math.hypot(dx, drop)
    dd = min(d, L1 + L2 - 0.01)
    t = math.atan2(drop, dx)
    b = math.acos(max(-1, min(1, (L1 ** 2 + dd ** 2 - L2 ** 2) / (2 * L1 * dd))))
    ku, kv = L1 * math.cos(t - b), L1 * math.sin(t - b)
    def proj(u, v, l=0.0):
        z = hip_z + fz * u + lz * l
        return (hip_x + fx * u + lx * l, hip_y + v + z * DEPTH_Y)
    hip, knee, ank = proj(0, 0), proj(ku, kv, out * 0.5), proj(dx, drop, out)
    to = math.radians(side * TOE_OUT * fb)
    boot_pts = []
    for (px, py) in rot(BOOT, a):
        wv = (BOOT_W + 4.0 * fb) * (0.6 + 0.4 * max(0.0, min(1.0, (py + 10) / 35.0)))
        for lb in (-wv, wv):
            u = dx + px * math.cos(to) - lb * math.sin(to)
            l = out + px * math.sin(to) + lb * math.cos(to)
            boot_pts.append(proj(u, drop + py, l))
    return dict(hip=hip, knee=knee, ank=ank, boot=convex_hull(boot_pts), ang=a, ground=lift is None, reach=d,
                depth=hip_z + fz * dx * 0.5)

def mix(a, b, t):
    return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))

def draw_leg(img, P, pal):
    sc = lambda p: (p[0] * S4, p[1] * S4)
    dr = ImageDraw.Draw(img)
    hip, knee, ank = P['hip'], P['knee'], P['ank']
    boot = [sc(p) for p in P['boot']]
    shin_dir = math.atan2(ank[1] - knee[1], ank[0] - knee[0]) - math.pi / 2
    band = [sc(p) for p in rot(BAND, shin_dir, ank)]
    band_ink = [sc(p) for p in rot(BAND_INK, shin_dir, ank)]
    wt, ws = 30.0, 25.0
    capsule(dr, hip, knee, wt + 2 * OL, INK)
    capsule(dr, knee, ank, ws + 2 * OL, INK)
    dr.line(boot + [boot[0]], fill=INK, width=int(2 * OL * S4), joint='curve')
    dr.polygon(boot, fill=INK)
    capsule(dr, hip, knee, wt, pal['pants'])
    capsule(dr, knee, ank, ws, pal['pants'])
    off = (1.8, -1.8)
    capsule(dr, (hip[0] + off[0], hip[1] + off[1]), (knee[0] + off[0], knee[1] + off[1]), wt * 0.55, pal['pants_hi'])
    capsule(dr, (knee[0] + off[0], knee[1] + off[1]), (ank[0] + off[0] - 2, ank[1] + off[1] - 8), ws * 0.5, pal['pants_hi'])
    dr.polygon(boot, fill=pal['boot'])
    mask = Image.new('L', img.size, 0); ImageDraw.Draw(mask).polygon(boot, fill=255)
    m2 = Image.new('L', img.size, 0); ImageDraw.Draw(m2).polygon([(x, y - 6 * S4) for x, y in boot], fill=255)
    solem = Image.fromarray(np.where((np.asarray(mask) > 0) & (np.asarray(m2) == 0), 255, 0).astype(np.uint8))
    img.paste(Image.new('RGBA', img.size, pal['sole'] + (255,)), (0, 0), solem)
    cx = sum(p[0] for p in P['boot']) / len(P['boot']); cy = sum(p[1] for p in P['boot']) / len(P['boot'])
    r1, r2 = 8 * S4, 4.5 * S4
    dr.ellipse([cx * S4 - r1, (cy - 3) * S4 - r2, cx * S4 + r1, (cy - 3) * S4 + r2], fill=pal['boot_hi'])
    dr.polygon(band_ink, fill=INK)
    dr.polygon(band, fill=pal['band'])

def legs_layer(keys, bob, yaw, palette):
    big = Image.new('RGBA', (CW * S4, CH * S4), (0, 0, 0, 0))
    legs = [leg3(keys[0], 1, bob, yaw), leg3(keys[1], -1, bob, yaw)]
    near = {k: tuple(v) for k, v in palette['near'].items()}
    far = {k: tuple(v) for k, v in palette['far'].items()}
    shade = abs(math.cos(yaw))
    far_pal = {k: mix(near[k], far[k], shade) for k in near}
    for P, side in sorted(zip(legs, (1, -1)), key=lambda t: t[0]['depth']):
        draw_leg(big, P, near if side > 0 else far_pal)
    small = np.asarray(big.resize((CW, CH), Image.LANCZOS)).astype(np.float32) / 255.0
    small[..., :3] *= small[..., 3:4]
    return small, legs[0], legs[1]

# ---- 動作（全キャラ共通） --------------------------------------------------------------------
# 走行の脚表（片脚8相）：(腰からのdx, 接地ならNone/空中なら持上げ, 靴角度)
STRIDE = 22.0
LEG = [(14, None, -4), (14 - STRIDE, None, 28), (-44, 24, 62), (-22, 44, 78),
       (6, 40, 20), (30, 26, -10), (40, 12, -18), (30, 3, -10)]
RUN = dict(bob=[7, 0, -6, -3], lean_base=8.0, lean=[1.5, -0.5, -0.8, 0.0],
           squash=[(1.02, 0.972), (0.99, 1.014), (0.998, 1.008), (1.0, 1.0)], gun_follow=0.35, spring_gain=0.85)
# 揺れの基準角を求める減衰ばね：固有角速度(rad/コマ)、減衰比、入力倍率、常時のなびき(度)
SPRINGS = dict(ponytail=(1.25, 0.35, 0.55, -2.0), hair_back=(1.45, 0.40, 0.45, -1.0), scarf=(1.05, 0.30, 0.60, -5.0))
IDLE_PERIOD = 2.6
DODGE_TIMES = [0.04, 0.10, 0.20, 0.26, 0.32]
DODGE_LIFT = 6.0

def expand(half):
    return list(half) + list(half)

def spring_angles(head_y, gain):
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
                    dom = -w * w * th - 2 * z * w * om + g * gain * a
                    om += dom / sub; th += om / sub
                res[f] = th
        out[name] = [round(rest * gain + v, 3) for v in res]
    return out

def run_specs(head_ref):
    bob = expand(RUN['bob'])
    lean = [RUN['lean_base'] + d for d in expand(RUN['lean'])]
    sq = expand(RUN['squash'])
    head_y = [body_point(head_ref, lean[f], sq[f][0], sq[f][1], bob[f], SPRING_HIP)[1] for f in range(8)]
    bends = spring_angles(head_y, RUN['spring_gain'])
    return [dict(bob=bob[f], lean=lean[f], sq=sq[f], legs=(LEG[f], LEG[(f + 4) % 8]),
                 bends={k: v[f] for k, v in bends.items()}, hands=('gun', RUN['gun_follow'] * bob[(f - 1) % 8]))
            for f in range(8)]

def idle_specs(head_ref=None):
    out = []
    for f in range(8):
        s = math.sin(2 * math.pi * f / 8)
        lag1, lag2 = math.sin(2 * math.pi * (f - 1) / 8), math.sin(2 * math.pi * (f - 2) / 8)
        out.append(dict(bob=-2.0 * s, lean=3.0, sq=(1 - 0.006 * s, 1 + 0.014 * s),
                        legs=((20, None, -2), (-14, None, 6)),
                        bends=dict(ponytail=-2.0 + 3.0 * lag1, hair_back=1.5 * lag1, scarf=-6.0 + 4.0 * lag2),
                        hands=('gun', -1.0 * lag1)))
    return out

def dodge_specs(head_ref=None):
    return [
        dict(bob=14, lean=18, sq=(1.06, 0.90), legs=((14, None, -4), (-18, None, 30)),
             bends=dict(ponytail=-6, hair_back=-3, scarf=-8), hands=('free', 12, 0)),        # 踏み込み
        dict(bob=4, lean=42, sq=(0.97, 1.05), legs=((-20, 8, 40), (-36, 3, 55)),
             bends=dict(ponytail=-12, hair_back=-5, scarf=-14), hands=('free', 34, 16)),     # 踏み切り
        dict(bob=6, lean=72, sq=(0.98, 1.03), legs=((-70, 46, 85), (-62, 36, 88)),
             bends=dict(ponytail=-18, hair_back=-8, scarf=-22), hands=('free', 44, 22)),     # 飛び込み
        dict(bob=0, lean=40, sq=(1.0, 1.0), legs=((22, 18, -6), (4, 26, 10)),
             bends=dict(ponytail=-8, hair_back=-4, scarf=-16), hands=('free', 30, 10)),      # 着地前
        dict(bob=16, lean=20, sq=(1.07, 0.88), legs=((20, None, -4), (-10, None, 20)),
             bends=dict(ponytail=6, hair_back=3, scarf=-2), hands=('free', 20, 0)),          # 着地
        dict(bob=6, lean=10, sq=(1.02, 0.96), legs=((12, None, 0), (-10, None, 8)),
             bends=dict(ponytail=2, hair_back=1, scarf=-4), hands=('gun', 0.0)),             # 立ち直り
    ]

# 近接（ナイフ）：押した瞬間に当たるので、1コマ目から振り抜きの途中。踏み込み→振り抜き→戻り→構え。
# 体と脚だけ。ナイフを持つ腕と斬撃の弧はゲーム側が照準角に合わせて描く（銃は反対の手に持ったまま）。
MELEE_TIMES = [0.05, 0.11, 0.18]   # 各コマの終わり（秒）。全体 MELEE_DURATION
MELEE_DURATION = 0.26
def melee_specs(head_ref=None):
    return [
        dict(bob=6, lean=14, sq=(1.03, 0.96), legs=((24, None, -6), (-18, None, 24)),
             bends=dict(ponytail=-8, hair_back=-4, scarf=-10), hands=('gun', 0.0)),   # 踏み込みながら振る
        dict(bob=8, lean=18, sq=(1.04, 0.95), legs=((26, None, -6), (-20, None, 26)),
             bends=dict(ponytail=-12, hair_back=-6, scarf=-14), hands=('gun', 0.0)),  # 振り抜き
        dict(bob=5, lean=12, sq=(1.02, 0.98), legs=((22, None, -4), (-16, None, 18)),
             bends=dict(ponytail=-6, hair_back=-3, scarf=-8), hands=('gun', 0.0)),    # 戻り
        dict(bob=2, lean=6, sq=(1.0, 1.0), legs=((20, None, -2), (-14, None, 8)),
             bends=dict(ponytail=-2, hair_back=-1, scarf=-5), hands=('gun', 0.0)),    # 構え
    ]

ACTIONS = dict(run=run_specs, idle=idle_specs, dodge=dodge_specs, melee=melee_specs)

# ---- 1向き・1動作を描く ---------------------------------------------------------------------
def render_view(v, loaded, specs, palette):
    parts, roots, yaw, s, place = loaded
    pivot = (HIP_C[0] + SIDE_SPREAD * math.cos(yaw), PIVOT_Y)
    lean_k, dive_k = math.cos(yaw), abs(math.sin(yaw))
    sn_c, sf_c, hand_c = place(v['shoulder_near']), place(v['shoulder_far']), place(v['hand'])
    swings = v.get('swing', [])
    swing_names = [sw['name'] for sw in swings]
    lowers, uppers, meta, previews = [], [], [], []
    for sp in specs:
        # 正面・背面は前傾を回転で見せられないため、体を横へ少し傾けて沈める
        dive = max(0.0, (sp['lean'] - 20.0) / 52.0) * dive_k
        bob = sp['bob'] + 8.0 * dive
        tilt = max(0.0, sp['lean'] - 20.0) * 0.2 * dive_k
        g = (sp['lean'] * lean_k + tilt, sp['sq'][0], sp['sq'][1] * (1 - 0.12 * dive), bob)
        legs, Pn, Pf = legs_layer(sp['legs'], bob, yaw, palette)
        lay = {'legs': legs}
        wl = (roots['warp'], sp['bends'][v['warp']['name']]) if 'warp_w' in parts else None
        for name in ('torso', 'head'):
            if name in parts:
                lay[name] = warp(parts[name], pivot, *g, local=wl, weight=parts.get('warp_w')) if wl else warp(parts[name], pivot, *g)
        for sw in swings:
            lay[sw['name']] = warp(parts[sw['name']], pivot, *g, local=(roots[sw['name']], sp['bends'][sw['channel']] * v['bend']))
        def stack(names):
            acc = np.zeros((CH, CW, 4), np.float32)
            for n in names:
                if n in lay: acc = over(acc, lay[n])
            return to_image(acc)
        # 書き出しは揺れ物を除く（ゲーム側で揺らす）。確認画像は基準角で焼き込む
        lowers.append(stack([n for n in v['lower'] if n not in swing_names])); uppers.append(stack(v['upper']))
        pv = stack(v['lower']); pv.alpha_composite(uppers[-1]); previews.append(pv)
        m = dict(shoulder_near=body_point(sn_c, *g, pivot=pivot), shoulder_far=body_point(sf_c, *g, pivot=pivot),
                 near_ground=Pn['ground'], far_ground=Pf['ground'], reach=max(Pn['reach'], Pf['reach']), lean=g[0],
                 bias={sw['name']: sp['bends'][sw['channel']] * v['bend'] for sw in swings})
        for sw in swings:
            m[sw['name'] + '_root'] = body_point(roots[sw['name']], *g, pivot=pivot)
        if sp['hands'][0] == 'gun':
            # 銃：照準角は保ち、平均の前傾での手の位置に、体の上下の一部だけ追従
            m['hand'] = body_point(hand_c, RUN['lean_base'] * lean_k, 1.0, 1.0, bob - sp['bob'] + sp['hands'][1], pivot)
            m['free'] = False
        else:
            # 銃なし：両手を体の前へ。正面・背面は左右へ開く
            fwd, up = sp['hands'][1], sp['hands'][2]
            spread = 16.0 * dive_k
            near = (hand_c[0] + fwd * lean_k - spread, hand_c[1] - up)
            far = (hand_c[0] + fwd * lean_k + spread + 6.0 * lean_k, hand_c[1] - up - 4.0 * lean_k)
            m['hand'] = body_point(near, *g, pivot=pivot)
            m['hand_far'] = body_point(far, *g, pivot=pivot)
            m['free'] = True
        meta.append(m)
    return lowers, uppers, meta, previews

def export_part(arr, root):
    """揺れ物を切り出し、シート画素の画像・付け根・先端方向・長さを返す。"""
    a = arr[..., 3]
    ys, xs = np.nonzero(a > .02)
    x0, y0, x1, y1 = xs.min() - 2, ys.min() - 2, xs.max() + 3, ys.max() + 3
    img = to_image(arr[y0:y1, x0:x1])
    img = img.resize((max(1, round(img.width * OUT_SCALE)), max(1, round(img.height * OUT_SCALE))), Image.LANCZOS)
    w = a[ys, xs]
    cx, cy = (xs * w).sum() / w.sum(), (ys * w).sum() / w.sum()
    ax, ay = cx - root[0], cy - root[1]
    n = math.hypot(ax, ay) or 1.0
    ax, ay = ax / n, ay / n
    length = max(((xs - root[0]) * ax + (ys - root[1]) * ay).max(), 1.0)
    return img, dict(root=[round((root[0] - x0) * OUT_SCALE, 2), round((root[1] - y0) * OUT_SCALE, 2)],
                     axis=[round(ax, 4), round(ay, 4)], length=round(length * OUT_SCALE, 2))

def sheet(frames):
    w, h = int(CW * OUT_SCALE), int(CH * OUT_SCALE)
    out = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        out.alpha_composite(fr.resize((w, h), Image.LANCZOS), (i * w, 0))
    return out

def export_arm_parts(cfg, out_dir):
    """腕・手袋の生成画像を行ごとに切り出す（左が付け根、右が先）。寸法は手袋の幅 glove_w（ゲーム画素）基準。"""
    rgba = remove_white(np.asarray(Image.open(os.path.join(GEN, cfg['file'] + '.png')).convert('RGB')))
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
    keys = cfg['rows']
    assert [len(r) for r in rows] == [len(k) for k in keys], ([len(r) for r in rows], keys)
    glove_row = next(i for i, k in enumerate(keys) if any(x.startswith('grip') for x in k))
    k = cfg['glove_w'] / np.mean([c['x1'] - c['x0'] for c in rows[glove_row]])
    info = {}
    for row, names in zip(rows, keys):
        for c, key in zip(sorted(row, key=lambda c: c['cx']), names):
            p = rgba[c['y0'] - 2:c['y1'] + 2, c['x0'] - 2:c['x1'] + 2].copy()
            m = ndi.binary_dilation(c['m'], iterations=2)[c['y0'] - 2:c['y1'] + 2, c['x0'] - 2:c['x1'] + 2]
            p[..., 3] = np.where(m, p[..., 3], 0)
            im = Image.fromarray(p)
            s = 64 / im.height
            im.resize((max(1, round(im.width * s)), 64), Image.LANCZOS).save(os.path.join(out_dir, f'arm-{key}.png'))
            info[key] = dict(size=[round(im.width * k, 3), round(im.height * k, 3)])
    return info

def export_melee_weapon(cfg, out_dir):
    """近接武器（横向き、左が握り）を切り出す。length はゲーム画素の全長、grip_u は握りの位置（左端0〜右端1）。"""
    rgba = remove_white(np.asarray(Image.open(os.path.join(GEN, cfg['file'] + '.png')).convert('RGB')))
    ys, xs = np.nonzero(rgba[..., 3] > 0)
    p = rgba[ys.min() - 2:ys.max() + 3, xs.min() - 2:xs.max() + 3]
    im = Image.fromarray(p)
    s = 48 / im.height
    im.resize((max(1, round(im.width * s)), 48), Image.LANCZOS).save(os.path.join(out_dir, 'melee.png'))
    k = cfg['length'] / im.width
    return dict(size=[cfg['length'], round(im.height * k, 3)], grip_u=cfg['grip_u'])

# ---- 全体 ------------------------------------------------------------------------------------
def build(cfg):
    out_dir = os.path.join(ROOT, cfg['out_dir'])
    world = lambda p: [round((p[0] * OUT_SCALE - ORIGIN[0]) * WORLD_K, 3), round((p[1] * OUT_SCALE - ORIGIN[1]) * WORLD_K + FOOT_Y, 3)]
    if os.path.isdir(out_dir):
        for f in os.listdir(out_dir):
            if f.endswith('.png') or f.endswith('.png.import'): os.remove(os.path.join(out_dir, f))
    os.makedirs(out_dir, exist_ok=True)
    comps = {key: components(src) for key, src in cfg['sources'].items()}
    ref = cfg['spring_head_ref']
    _, _, ref_place = view_geometry(cfg['views'][ref['view']])
    head_ref = ref_place(ref['at'])
    specs = {name: fn(head_ref) for name, fn in ACTIONS.items()}
    views_meta, preview = {}, {}
    for key, v in cfg['views'].items():
        loaded = load_view(v, comps[v['src']])
        parts, roots = loaded[0], loaded[1]
        views_meta[key] = dict(yaw=v['yaw'], arms=v['arms'], upper=bool(v['upper']), actions={}, parts={},
                               elbow=v.get('elbow', 'down'))
        for sw in v.get('swing', []):
            img, info = export_part(parts[sw['name']], roots[sw['name']])
            img.save(os.path.join(out_dir, f"{key}-{sw['name']}.png"))
            info['layer'] = 'front' if v['lower'].index(sw['name']) > v['lower'].index('torso') else 'behind'
            info['type'] = sw['type']
            views_meta[key]['parts'][sw['name']] = info
        for action, sp in specs.items():
            lowers, uppers, meta, previews = render_view(v, loaded, sp, cfg['legs'])
            over_ = [i for i, m in enumerate(meta) if m['reach'] > L1 + L2]
            if over_: raise SystemExit(f'{key}/{action}: 脚が届かないコマ {over_}')
            sheet(lowers).save(os.path.join(out_dir, f'{key}-{action}-lower.png'))
            if v['upper']: sheet(uppers).save(os.path.join(out_dir, f'{key}-{action}-upper.png'))
            frames = []
            for m in meta:
                fm = dict(hand=world(m['hand']), shoulder_near=world(m['shoulder_near']), shoulder_far=world(m['shoulder_far']),
                          near_ground=m['near_ground'], far_ground=m['far_ground'], free=m['free'])
                if m['free']: fm['hand_far'] = world(m['hand_far'])
                fm['lean'] = round(m['lean'], 3)
                fm['bias'] = {n: round(b, 3) for n, b in m['bias'].items()}
                for sw in v.get('swing', []):
                    fm[sw['name'] + '_root'] = world(m[sw['name'] + '_root'])
                frames.append(fm)
            views_meta[key]['actions'][action] = frames
            preview.setdefault(action, []).append(previews)
    arm = {n: (round(val * WORLD_K, 3) if n in ('upper', 'lower', 'sleeve_w', 'glove_r', 'cuff_w', 'outline') else val)
           for n, val in cfg['arm'].items()}
    rig = dict(source='tools/character_rig/characters/' + cfg['name'] + '.json', id=cfg['id'], name=cfg['name'],
               cell=[int(CW * OUT_SCALE), int(CH * OUT_SCALE)], scale=round(WORLD_K, 6), origin=list(ORIGIN), foot_y=FOOT_Y,
               idle_period=IDLE_PERIOD, dodge_times=DODGE_TIMES, dodge_lift=DODGE_LIFT, arm=arm, views=views_meta, mirror=MIRROR)
    rig['arm_parts'] = export_arm_parts(cfg['arm_parts'], out_dir)
    rig['melee_times'] = MELEE_TIMES
    rig['melee_duration'] = MELEE_DURATION
    if cfg.get('melee_weapon'):
        rig['melee_weapon'] = export_melee_weapon(cfg['melee_weapon'], out_dir)
    json.dump(rig, open(os.path.join(out_dir, 'rig.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    if cfg.get('preview_dir'):
        w, h = int(CW * OUT_SCALE), int(CH * OUT_SCALE)
        for action, rows in preview.items():
            n = len(rows[0])
            pv = Image.new('RGBA', (w * n, h * len(rows)), (111, 106, 98, 255))
            for r, pr in enumerate(rows):
                for f in range(n):
                    pv.alpha_composite(pr[f].resize((w, h), Image.LANCZOS), (f * w, r * h))
            pv.save(os.path.join(ROOT, cfg['preview_dir'], f"{cfg.get('preview_prefix', '')}{action}-views.png"))
    return rig
