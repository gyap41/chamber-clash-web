"""リナ走行 v8：8方向（描き分け5向き：側面・斜め前・正面・斜め後ろ・背面、左向きは反転）。弾みは「強」のみ。

素材（gpt-image-2、各1回）:
  assets/generated/rina-side-body-parts-v1.png   側面の 頭＋胴・ポニーテール・スカーフの垂れ（v7と同じ）
  assets/generated/rina-front-back-parts-v1.png  正面の 頭＋胴・ポニーテール／背面の 頭＋胴・ポニーテール・（スカーフの垂れ：未使用）
  assets/generated/rina-diagonal-parts-v1.png    斜め前・斜め後ろの 頭＋胴・ポニーテール・スカーフの垂れ
方式（v7レビュー後の合意「制作時に1回だけ投影して下書き、ゲーム中はコマ再生」）:
  - 脚：v6の側面の脚表（前後のずれ・持上げ・靴角度）を3次元の足の軌跡とみなし、向き（ヨー角）ごとに画面へ投影して描く。
    膝は脚の前後面内で曲げ、靴は側面の輪郭を左右に厚みを付けて投影する。側面は v7 と同じ見た目になる。
  - 上体：向きごとの生成パーツを、髪留め〜裾の長さで倍率を合わせ、裾の中央を腰の上に置く。前傾は側面成分（cos）だけ、
    弾み・縮みは全向き共通。ポニーテールとスカーフは付け根まわりに減衰ばねの角度で回す（正面・背面は控えめ）。
  - 重なり順は向きごとの表（VIEWS）。銃と腕はゲーム側（scripts/visuals/rina_run_rig.gd）がコードで描く。
動作: run（走行8コマ）、idle（待機の呼吸8コマ、2.6秒周期）、dodge（回避6コマ：踏み込み→踏み切り→飛び込み→着地前→着地→立ち直り）。
      回避中は銃を隠し、両腕を前へ伸ばす（手の位置を free として記録）。正面・背面の倒れ込みは縦に潰して下げる。
出力: assets/first-workshop/rina-run-8dir/<view>-<action>-lower.png / -upper.png と rig.json（ゲーム座標）。
      確認用の一覧 run-cycle-v8-<action>-views.png をこのフォルダーへ。
再現: python build_run_cycle_v8.py （このフォルダーで実行。Pillow/numpy/scipy が必要）
"""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
import build_run_cycle_v6 as V6
import build_run_cycle_v7 as V7

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
GEN = os.path.join(ROOT, 'assets', 'generated')
OUT = os.path.join(ROOT, 'assets', 'first-workshop', 'rina-run-8dir')
# 回避で体を大きく倒すと頭が前へ出るため、v7のセル（443）より右へ80広げる（左端・原点は同じ）
V7.CW = 443 + 80
PAD, CW, CH = V7.PAD, V7.CW, V7.CH
G = 428 + PAD
HIP_C = (191.0, 336.0 + PAD)      # 左右の腰の中央（側面では近側198・遠側184）
PIVOT_Y = 338.0 + PAD             # 前傾・縮みの支点の高さ
HIP_W = 18.0                      # 腰の左右の半幅（正面で左右の脚の間隔になる）
DEPTH_Y = 2.0 / 18.0              # 奥行き（手前が＋）を画面の下方向へ写す比率
SIDE_SPREAD = 7.0                 # 側面で近側/遠側の腰を前後へずらす量（v7の見た目を保つ）
BOOT_W = 12.0                     # 靴の左右の半幅
RING_TO_HEM = 608.0 * V7.S        # 側面の髪留め〜裾（セル画素）。全向きをこの長さにそろえる
VARIANT = 'strong'

# 向きごとの設定（生成画像上の座標）。yaw: 0=右向き側面、+90=正面（手前向き）、-90=背面。
VIEWS = {
    'side': dict(yaw=0, src='rina-side-body-parts-v1', ring=(336, 236), hem=(348, 844),
                 torso='A', pony=('pony', (850, 322), False), scarf=('scarf', (893, 748), (262, 668), False),
                 cut=None, shoulder_near=(303, 723), shoulder_far=None, hand=None,
                 lower=['scarf', 'pony', 'legs', 'torso'], upper=['head'], arms='side', gun='between', bend=1.0),
    'diag_front': dict(yaw=45, src='rina-diagonal-parts-v1', ring=(372, 272), hem=(376, 656),
                       torso='D1', pony=('D2', (132, 417), False), scarf=('D3', (182, 555), (318, 520), False),
                       cut=506, shoulder_near=(307, 555), shoulder_far=(442, 545), hand=(462, 598),
                       lower=['scarf', 'pony', 'legs', 'torso'], upper=['head'], arms='side', gun='between', bend=.85),
    'front': dict(yaw=90, src='rina-front-back-parts-v1', ring=(279, 283), hem=(272, 738),
                  torso='F1', pony=('F2', (278, 203), False), scarf=None,
                  cut=568, shoulder_near=(177, 622), shoulder_far=(356, 622), hand=(252, 652),
                  lower=['pony', 'legs', 'torso'], upper=['head'], arms='front', gun='between', bend=.8),
    'diag_back': dict(yaw=-45, src='rina-diagonal-parts-v1', ring=(685, 272), hem=(672, 656),
                      torso='E1', pony=('E2', (872, 420), True), scarf=('E3', (827, 570), (640, 525), True),
                      cut=None, shoulder_near=(717, 545), shoulder_far=(607, 550), hand=(815, 530),
                      lower=['legs', 'torso', 'scarf', 'pony'], upper=[], arms='side', gun='between', bend=.85),
    'back': dict(yaw=-90, src='rina-front-back-parts-v1', ring=(752, 289), hem=(752, 742),
                 torso='B1', pony=('B2', (752, 203), False), scarf=('B3', (705, 812), (745, 598), False),
                 cut=None, shoulder_near=(835, 635), shoulder_far=(677, 635), hand=(790, 470),
                 lower=['legs', 'torso', 'scarf', 'pony'], upper=[], arms='behind', gun='behind', bend=.8, elbow='out'),
}

def components(name):
    """生成画像の背景を除去し、連結成分をラベル（A/pony/scarf、F1…E3）で返す。"""
    rgba = V7.remove_white(np.asarray(Image.open(os.path.join(GEN, name + '.png')).convert('RGB')))
    lab, n = ndi.label(rgba[..., 3] > 0)
    comps = []
    for i in range(1, n + 1):
        m = lab == i
        s = int(m.sum())
        if s < 2000: continue
        ys, xs = np.nonzero(m)
        p = rgba.copy()
        p[..., 3] = np.where(ndi.binary_dilation(m, iterations=2), rgba[..., 3], 0)
        comps.append(dict(img=p, size=s, cx=xs.mean(), cy=ys.mean()))
    comps.sort(key=lambda c: -c['size'])
    out = {}
    if name == 'rina-side-body-parts-v1':
        out['A'] = comps[0]['img']
        small = sorted(comps[1:3], key=lambda c: c['cy'])
        out['pony'], out['scarf'] = small[0]['img'], small[1]['img']
    elif name == 'rina-front-back-parts-v1':
        big = sorted(comps[:2], key=lambda c: c['cx'])
        out['F1'], out['B1'] = big[0]['img'], big[1]['img']
        for c in comps[2:]:
            key = ('F2' if c['cx'] < 512 else 'B2') if c['cy'] < 260 else 'B3'
            out[key] = c['img']
    else:
        big = sorted(comps[:2], key=lambda c: c['cx'])
        out['D1'], out['E1'] = big[0]['img'], big[1]['img']
        for c in comps[2:]:
            out[('D' if c['cx'] < 512 else 'E') + ('2' if c['cy'] < 480 else '3')] = c['img']
    return out

def view_geometry(v):
    yaw = math.radians(v['yaw'])
    s = RING_TO_HEM / (v['hem'][1] - v['ring'][1])
    hem_cell = (HIP_C[0] + 24.0 * math.cos(yaw), 350.0 + PAD)
    place = lambda p: ((p[0] - v['hem'][0]) * s + hem_cell[0], (p[1] - v['hem'][1]) * s + hem_cell[1])
    return yaw, s, place

def to_cell(part, s, place, offset=(0.0, 0.0), flip_about=None):
    """生成画像のパーツを倍率sでセルへ置く（premultiplied）。flip_about=x なら生成画像上のxを軸に左右反転。"""
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

def load_view(key, cache):
    v = VIEWS[key]
    if v['src'] not in cache:
        cache[v['src']] = components(v['src'])
    comps = cache[v['src']]
    yaw, s, place = view_geometry(v)
    parts = {}
    if key == 'side':
        side = V7.load_parts()   # v7と同じ組立（後ろ髪のワープ重みを含む）
        parts.update(torso=side['torso'], head=side['head'], pony=side['pony'], scarf=side['scarf'], hair_back_w=side['hair_back_w'])
        roots = dict(pony=V7.place(V7.RING_HEAD), scarf=V7.place(V7.SCARF_ROOT_AT), hair_back=V7.place(V7.HAIR_BACK_ROOT))
    else:
        body = comps[v['torso']]
        parts['torso'] = to_cell(body, s, place)
        if v['cut']:
            head = body.copy(); head[v['cut']:, :, 3] = 0
            parts['head'] = to_cell(head, s, place)
        pk, pring, pflip = v['pony']
        pimg = comps[pk]
        if pflip:
            parts['pony'] = to_cell(pimg, s, place, (v['ring'][0] - pring[0], v['ring'][1] - pring[1]), flip_about=pring[0])
        else:
            parts['pony'] = to_cell(pimg, s, place, (v['ring'][0] - pring[0], v['ring'][1] - pring[1]))
        roots = dict(pony=place(v['ring']))
        if v['scarf']:
            sk, sroot, sat, sflip = v['scarf']
            off = (sat[0] - sroot[0], sat[1] - sroot[1])
            parts['scarf'] = to_cell(comps[sk], s, place, off, flip_about=sroot[0] if sflip else None)
            roots['scarf'] = place(sat)
    apply_pony_style(key, parts, roots, place)
    return parts, roots, yaw, s, place

# ---- ポニーテールの位置（2026-09-26 ユーザー指摘「位置が少し高い」への比較案） ----------------------
# 頭頂の髪留めの範囲（生成画像上の座標）。付け根を動かすときは頭側の髪留めを消し、頭の輪郭を補う。
RING_BOX = dict(side=(292, 210, 386, 262), diag_front=(338, 248, 414, 296), front=(236, 260, 322, 306),
                diag_back=(648, 248, 728, 298), back=(712, 266, 794, 310))
# move: 付け根の移動（セル画素、+x右 +y下）/ tilt: 毛束を後ろへ倒す角度（度、負＝反時計回り）/ squash: 正面・背面で毛束の縦を縮める
PONY_STYLES = {
    'current': {},
    'A': dict(side=dict(move=(-12, 14)), diag_front=dict(move=(-9, 14)), front=dict(move=(0, 16)),
              diag_back=dict(move=(-8, 14)), back=dict(move=(0, 22))),
    'B': dict(side=dict(tilt=-22), diag_front=dict(tilt=-18), front=dict(squash=.78),
              diag_back=dict(tilt=-18), back=dict(squash=.78)),
}
PONY_STYLES['C'] = {k: dict(PONY_STYLES['A'][k], **PONY_STYLES['B'][k]) for k in PONY_STYLES['A']}
PONY_STYLE = 'C'   # 2026-09-26 ユーザー選択（付け根を後頭部寄りに下げ、毛束を後ろへ倒す）
SWING_PARTS = ('pony', 'scarf')  # ゲーム側で毎フレーム揺らすパーツ（体のシートには焼き込まない）

def transform_part(arr, root, move=(0.0, 0.0), tilt=0.0, squash=1.0):
    """premultiplied のパーツを、付け根まわりに回転・縦縮みし、平行移動する（逆写像）。"""
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
    """頭頂の髪留めを消す：箱の左右の頭の輪郭から放物線で輪郭を補い、その上を透明に、線上を輪郭色に、
    線より下に残る金色・髪留めの縁取りを髪の色で塗る。arr は premultiplied（セル座標）。"""
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
    # 髪留めの縁取り（暗い線）は金色から少し離れて残るため、広めに拾う
    dark = (rgb.max(-1) < .32) & (out[..., 3] > .3)
    ring_ink = dark & ndi.binary_dilation(gold, iterations=9) & inbox
    ink = np.array([20, 14, 12], np.float32) / 255
    yc_mid = np.polyval(coef, (x0 + x1) / 2)
    ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    sample = (ys > yc_mid + 10) & (ys < yc_mid + 30) & (xs >= x0) & (xs <= x1) & (out[..., 3] > .95) & ~near_gold
    hair = np.median(rgb[sample], axis=0) if sample.sum() > 10 else np.array([.45, .29, .2], np.float32)
    OL = 4
    for x in range(x0, x1 + 1):
        yc = int(round(np.polyval(coef, x)))
        for y in range(max(0, y0 - 10), y1 + 1):
            if y < yc:
                out[y, x] = 0
            elif y < yc + OL:
                out[y, x, :3] = ink; out[y, x, 3] = 1
            elif near_gold[y, x] or ring_ink[y, x]:
                out[y, x, :3] = hair; out[y, x, 3] = 1
    return out

def apply_pony_style(key, parts, roots, place):
    st = PONY_STYLES[PONY_STYLE].get(key, {})
    if not st: return
    move = st.get('move', (0.0, 0.0))
    if move != (0.0, 0.0) and move != (0, 0):
        bx = RING_BOX[key]
        (cx0, cy0), (cx1, cy1) = place((bx[0], bx[1])), place((bx[2], bx[3]))
        for name in ('torso', 'head'):
            if name in parts: parts[name] = erase_ring(parts[name], (cx0, cy0, cx1, cy1))
    parts['pony'] = transform_part(parts['pony'], roots['pony'], move, st.get('tilt', 0.0), st.get('squash', 1.0))
    roots['pony'] = (roots['pony'][0] + move[0], roots['pony'][1] + move[1])

# ---- 脚の投影 ------------------------------------------------------------------------
# 正面・背面の足（2026-09-26、参考動画との比較で「両足がくっつく」「足踏みに見える」を修正）：
# 足先を裾の左右の端まで外へ開き（ハの字）、つま先を外へ向ける。持ち上げは控えめにし、上げた足は少し外へ振る。
# いずれも |sin(yaw)|（正面・背面らしさ）で効かせるので、側面は従来と同じ。
FOOT_OUT = 16.0      # 足首を腰より外へ出す量（セル画素、正面・背面）
SWING_OUT = 8.0      # 持ち上げた足を外へ振る量（持上げ40あたり）
TOE_OUT = 18.0       # つま先を外へ向ける角（度）
LIFT_FB = 0.35       # 正面・背面で持ち上げを弱める割合

def leg3(key, side, bob, yaw):
    """key=(前後のずれ, 接地ならNone/空中なら持上げ, 靴角度)。side=+1 近側/-1 遠側。
    画面上の腰・膝・足首、靴の多角形（セル画素）と奥行きを返す。"""
    dx, lift, ang = key
    fb = abs(math.sin(yaw))
    if lift is not None: lift = lift * (1 - LIFT_FB * fb)
    fx, fz = math.cos(yaw), math.sin(yaw)           # 前方向（画面x, 手前z）
    lx, lz = -math.sin(yaw), math.cos(yaw)          # 近側方向
    hip_x = HIP_C[0] + side * (HIP_W * lx + SIDE_SPREAD * math.cos(yaw))
    hip_z = side * HIP_W * lz
    hip_y = HIP_C[1] + bob                          # 奥行き補正前の高さ
    a = math.radians(ang)
    low = max(y for _, y in V6.rot(V6.BOOT, a))
    drop = (G - low - (lift or 0)) - hip_y          # 腰から足首までの縦の落差
    out = side * min(1.0, fb * 1.4) * (FOOT_OUT + SWING_OUT * (lift or 0) / 40.0)   # 足首を外へ出す量（近側方向）。斜めでも2本が離れて見えるよう強めに効かせる
    # 前後面内の2関節（膝は前）
    d = math.hypot(dx, drop)
    dd = min(d, V6.L1 + V6.L2 - 0.01)
    t = math.atan2(drop, dx)
    b = math.acos(max(-1, min(1, (V6.L1 ** 2 + dd ** 2 - V6.L2 ** 2) / (2 * V6.L1 * dd))))
    ku, kv = V6.L1 * math.cos(t - b), V6.L1 * math.sin(t - b)
    def proj(u, v, l=0.0):
        z = hip_z + fz * u + lz * l
        return (hip_x + fx * u + lx * l, hip_y + v + z * DEPTH_Y)
    hip, knee, ank = proj(0, 0), proj(ku, kv, out * 0.5), proj(dx, drop, out)
    to = math.radians(side * TOE_OUT * fb)
    boot_pts = []
    for (px, py) in V6.rot(V6.BOOT, a):
        # 靴の左右の厚み：底ほど広く、上ほど狭い。正面・背面は少し幅広
        wv = (BOOT_W + 4.0 * fb) * (0.6 + 0.4 * max(0.0, min(1.0, (py + 10) / 35.0)))
        for lb in (-wv, wv):
            u = dx + px * math.cos(to) - lb * math.sin(to)
            l = out + px * math.sin(to) + lb * math.cos(to)
            boot_pts.append(proj(u, drop + py, l))
    hull = convex_hull(boot_pts)
    depth = hip_z + fz * dx * 0.5
    return dict(hip=hip, knee=knee, ank=ank, boot=hull, ang=a, ground=lift is None, reach=d, depth=depth)

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

def mix(a, b, t):
    return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))

def draw_leg(img, P, pal):
    S4 = V6.S
    sc = lambda p: (p[0] * S4, p[1] * S4)
    dr = ImageDraw.Draw(img)
    hip, knee, ank = P['hip'], P['knee'], P['ank']
    boot = [sc(p) for p in P['boot']]
    shin_dir = math.atan2(ank[1] - knee[1], ank[0] - knee[0]) - math.pi / 2
    band = [sc(p) for p in V6.rot(V6.BAND, shin_dir, ank)]
    band_ink = [sc(p) for p in V6.rot(V6.BAND_INK, shin_dir, ank)]
    wt, ws, OL, INK = 30.0, 25.0, V6.OL, V6.INK
    V6.capsule(dr, hip, knee, wt + 2 * OL, INK)
    V6.capsule(dr, knee, ank, ws + 2 * OL, INK)
    dr.line(boot + [boot[0]], fill=INK, width=int(2 * OL * S4), joint='curve')
    dr.polygon(boot, fill=INK)
    V6.capsule(dr, hip, knee, wt, pal['pants'])
    V6.capsule(dr, knee, ank, ws, pal['pants'])
    off = (1.8, -1.8)
    V6.capsule(dr, (hip[0] + off[0], hip[1] + off[1]), (knee[0] + off[0], knee[1] + off[1]), wt * 0.55, pal['pants_hi'])
    V6.capsule(dr, (knee[0] + off[0], knee[1] + off[1]), (ank[0] + off[0] - 2, ank[1] + off[1] - 8), ws * 0.5, pal['pants_hi'])
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

def legs_layer(keys, bob, yaw):
    S4 = V6.S
    big = Image.new('RGBA', (CW * S4, CH * S4), (0, 0, 0, 0))
    legs = [leg3(keys[0], 1, bob, yaw), leg3(keys[1], -1, bob, yaw)]
    shade = abs(math.cos(yaw))
    far_pal = {k: mix(V6.NEAR[k], V6.FAR[k], shade) for k in V6.NEAR}
    for P, side in sorted(zip(legs, (1, -1)), key=lambda t: t[0]['depth']):
        draw_leg(big, P, V6.NEAR if side > 0 else far_pal)
    small = np.asarray(big.resize((CW, CH), Image.LANCZOS)).astype(np.float32) / 255.0
    small[..., :3] *= small[..., 3:4]
    return small, legs[0], legs[1]

# ---- 動作ごとのコマ（全向き共通の仕様） --------------------------------------------------
# bob: 腰の上下(+下, セル画素) / lean: 側面での前傾(度) / sq: (横, 縦)の縮み / legs: (近側, 遠側) の脚キー /
# bends: 揺れ角(度) / hands: ('gun', 銃の上下追従) または ('free', 前へ伸ばす量, 上げる量)（回避中、銃なしで両腕を前へ）
def run_specs():
    V = V6.VARIANTS[VARIANT]
    bob = V6.expand(V['bob'])
    lean = [V['lean_base'] + d for d in V6.expand(V['lean'])]
    sq = V6.expand(V['squash'])
    V7.HIP = V7.V6.HIP
    head_y = [V7.body_point(V7.HEAD_REF, lean[f], sq[f][0], sq[f][1], bob[f])[1] for f in range(8)]
    bends = V6.spring_angles(head_y, V['spring_gain'])
    return [dict(bob=bob[f], lean=lean[f], sq=sq[f], legs=(V6.LEG[f], V6.LEG[(f + 4) % 8]),
                 bends={k: v[f] for k, v in bends.items()}, hands=('gun', V['gun_follow'] * bob[(f - 1) % 8]))
            for f in range(8)]

def idle_specs():
    # 2.6秒周期の呼吸（本編の待機と同じ周期）。両足接地、上体だけ上下・伸縮、髪とスカーフはゆっくり遅れて揺れる。
    out = []
    for f in range(8):
        s = math.sin(2 * math.pi * f / 8)
        lag1, lag2 = math.sin(2 * math.pi * (f - 1) / 8), math.sin(2 * math.pi * (f - 2) / 8)
        out.append(dict(bob=-2.0 * s, lean=3.0, sq=(1 - 0.006 * s, 1 + 0.014 * s),
                        legs=((20, None, -2), (-14, None, 6)),   # 前後に開いて左右非対称、膝の曲げを浅く
                        bends=dict(ponytail=-2.0 + 3.0 * lag1, hair_back=1.5 * lag1, scarf=-6.0 + 4.0 * lag2),
                        hands=('gun', -1.0 * lag1)))
    return out

DODGE_TIMES = [0.04, 0.10, 0.20, 0.26, 0.32]   # 回避0.38秒のうち各コマの終わり（秒）。0〜0.04踏み込み、〜0.26飛び込み、以降着地
def dodge_specs():
    return [
        dict(bob=14, lean=18, sq=(1.06, 0.90), legs=((14, None, -4), (-18, None, 30)),
             bends=dict(ponytail=-6, hair_back=-3, scarf=-8), hands=('free', 12, 0)),        # 踏み込み（沈む）
        dict(bob=4, lean=42, sq=(0.97, 1.05), legs=((-20, 8, 40), (-36, 3, 55)),
             bends=dict(ponytail=-12, hair_back=-5, scarf=-14), hands=('free', 34, 16)),     # 踏み切り
        dict(bob=6, lean=72, sq=(0.98, 1.03), legs=((-70, 46, 85), (-62, 36, 88)),
             bends=dict(ponytail=-18, hair_back=-8, scarf=-22), hands=('free', 44, 22)),     # 飛び込み（体をほぼ水平に）
        dict(bob=0, lean=40, sq=(1.0, 1.0), legs=((22, 18, -6), (4, 26, 10)),
             bends=dict(ponytail=-8, hair_back=-4, scarf=-16), hands=('free', 30, 10)),      # 着地前（脚を前へ）
        dict(bob=16, lean=20, sq=(1.07, 0.88), legs=((20, None, -4), (-10, None, 20)),
             bends=dict(ponytail=6, hair_back=3, scarf=-2), hands=('free', 20, 0)),          # 着地（縮み）
        dict(bob=6, lean=10, sq=(1.02, 0.96), legs=((12, None, 0), (-10, None, 8)),
             bends=dict(ponytail=2, hair_back=1, scarf=-4), hands=('gun', 0.0)),             # 立ち直り（銃を再表示）
    ]

ACTIONS = dict(run=run_specs, idle=idle_specs, dodge=dodge_specs)

# ---- 1向き・1動作を描く ------------------------------------------------------------------
def body_point(p, lean, sx, sy, bob, pivot):
    hx, hy = pivot
    x, y = (p[0] - hx) * sx, (p[1] - hy) * sy
    a = math.radians(lean)
    return (hx + x * math.cos(a) - y * math.sin(a), hy + x * math.sin(a) + y * math.cos(a) + bob)

def render_view(key, loaded, specs):
    v = VIEWS[key]
    parts, roots, yaw, s, place = loaded
    pivot = (HIP_C[0] + SIDE_SPREAD * math.cos(yaw), PIVOT_Y)
    V7.HIP = pivot   # V7.warp の支点
    lean_k, dive_k = math.cos(yaw), abs(math.sin(yaw))
    if key == 'side':
        sn_c, sf_c, hand_c = V7.SHOULDER_NEAR, V7.SHOULDER_FAR, V7.HAND_BASE
    else:
        sn_c, sf_c, hand_c = place(v['shoulder_near']), place(v['shoulder_far']), place(v['hand'])
    base_lean = V6.VARIANTS[VARIANT]['lean_base']
    lowers, uppers, meta, previews = [], [], [], []
    for sp in specs:
        # 正面・背面では前傾を回転で見せられないため、体を横へ傾けて少し沈める（横へ飛び込む見え方）。
        # 2026-09-26：縦に潰すだけではしゃがんで見えたため、傾きを主にした。
        dive = max(0.0, (sp['lean'] - 20.0) / 52.0) * dive_k
        bob = sp['bob'] + 8.0 * dive
        tilt = max(0.0, sp['lean'] - 20.0) * 0.2 * dive_k   # 2026-09-26 参考動画に合わせ弱めた（横に転がって見えたため）
        g = (sp['lean'] * lean_k + tilt, sp['sq'][0], sp['sq'][1] * (1 - 0.12 * dive), bob)
        legs, Pn, Pf = legs_layer(sp['legs'], bob, yaw)
        lay = {'legs': legs}
        hb = (roots.get('hair_back'), sp['bends']['hair_back']) if 'hair_back_w' in parts else None
        lay['torso'] = V7.warp(parts['torso'], *g, local=hb, weight=parts.get('hair_back_w')) if hb else V7.warp(parts['torso'], *g)
        if 'head' in parts:
            lay['head'] = V7.warp(parts['head'], *g, local=hb, weight=parts.get('hair_back_w')) if hb else V7.warp(parts['head'], *g)
        lay['pony'] = V7.warp(parts['pony'], *g, local=(roots['pony'], sp['bends']['ponytail'] * v['bend']))
        if 'scarf' in parts:
            lay['scarf'] = V7.warp(parts['scarf'], *g, local=(roots['scarf'], sp['bends']['scarf'] * v['bend']))
        def stack(names):
            acc = np.zeros((CH, CW, 4), np.float32)
            for n in names:
                if n in lay: acc = V7.over(acc, lay[n])
            return V7.to_image(acc)
        # 書き出し用はポニーテール・スカーフを除く（ゲーム側で揺らす）。確認画像用は揺れの基準角で焼き込む
        lowers.append(stack([n for n in v['lower'] if n not in SWING_PARTS])); uppers.append(stack(v['upper']))
        pv = stack(v['lower']); pv.alpha_composite(uppers[-1]); previews.append(pv)
        m = dict(shoulder_near=body_point(sn_c, *g, pivot=pivot), shoulder_far=body_point(sf_c, *g, pivot=pivot),
                 near_ground=Pn['ground'], far_ground=Pf['ground'], reach=max(Pn['reach'], Pf['reach']),
                 lean=g[0], bias=dict(pony=sp['bends']['ponytail'] * v['bend'], scarf=sp['bends']['scarf'] * v['bend']))
        for n in SWING_PARTS:
            if n in parts: m[n + '_root'] = body_point(roots[n], *g, pivot=pivot)
        if sp['hands'][0] == 'gun':
            # 銃：照準角は保ち、平均の前傾での手の位置に、体の上下の一部だけ追従
            m['hand'] = body_point(hand_c, base_lean * lean_k, 1.0, 1.0, bob - sp['bob'] + sp['hands'][1], pivot)
            m['free'] = False
        else:
            # 銃なし：両手を体の前へ（体と一緒に回る）。正面・背面は左右へ開く
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
    """揺らすパーツ（セル座標の premultiplied）を切り出し、シート画素の画像・付け根・毛先方向・長さを返す。"""
    a = arr[..., 3]
    ys, xs = np.nonzero(a > .02)
    x0, y0, x1, y1 = xs.min() - 2, ys.min() - 2, xs.max() + 3, ys.max() + 3
    img = V7.to_image(arr[y0:y1, x0:x1])
    o = V7.OUT_SCALE
    img = img.resize((max(1, round(img.width * o)), max(1, round(img.height * o))), Image.LANCZOS)
    w = a[ys, xs]
    cx, cy = (xs * w).sum() / w.sum(), (ys * w).sum() / w.sum()
    ax, ay = cx - root[0], cy - root[1]
    n = math.hypot(ax, ay) or 1.0
    ax, ay = ax / n, ay / n
    length = max(((xs - root[0]) * ax + (ys - root[1]) * ay).max(), 1.0)
    return img, dict(root=[round((root[0] - x0) * o, 2), round((root[1] - y0) * o, 2)],
                     axis=[round(ax, 4), round(ay, 4)], length=round(length * o, 2))

def sheet(frames):
    w, h = int(CW * V7.OUT_SCALE), int(CH * V7.OUT_SCALE)
    out = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        out.alpha_composite(fr.resize((w, h), Image.LANCZOS), (i * w, 0))
    return out

if __name__ == '__main__':
    specs = {name: fn() for name, fn in ACTIONS.items()}
    v7meta = json.load(open(os.path.join(HERE, 'run-cycle-v7-meta.json'), encoding='utf-8'))
    o = V7.OUT_SCALE
    k = 56.0 / v7meta['nominal_height']            # シート画素→ゲーム画素（v7と同じ全高基準）
    ox, gy = v7meta['origin_x'], v7meta['ground_y']
    world = lambda p: [round((p[0] * o - ox) * k, 3), round((p[1] * o - gy) * k + 15.0, 3)]
    if os.path.isdir(OUT):
        for f in os.listdir(OUT):
            if f.endswith('.png') or f.endswith('.png.import'): os.remove(os.path.join(OUT, f))  # 旧名のシートを残さない
    os.makedirs(OUT, exist_ok=True)
    cache, views_meta, preview = {}, {}, {}
    for key, v in VIEWS.items():
        loaded = load_view(key, cache)
        has_upper = bool(v['upper'])
        views_meta[key] = dict(yaw=v['yaw'], arms=v['arms'], gun=v['gun'], upper=has_upper, actions={}, parts={}, elbow=v.get('elbow', 'down'))
        parts_, roots_ = loaded[0], loaded[1]
        order = [n for n in v['lower']]
        for n in SWING_PARTS:
            if n not in parts_: continue
            img, info = export_part(parts_[n], roots_[n])
            img.save(os.path.join(OUT, f'{key}-{n}.png'))
            # 体（脚・胴）より前に描くか後ろに描くか：lower の並びで torso より後ろなら前面
            info['layer'] = 'front' if order.index(n) > order.index('torso') else 'behind'
            views_meta[key]['parts'][n] = info
        for action, sp in specs.items():
            lowers, uppers, meta, previews = render_view(key, loaded, sp)
            over = [i for i, m in enumerate(meta) if m['reach'] > V6.L1 + V6.L2]
            if over: raise SystemExit(f'{key}/{action}: 脚が届かないコマ {over}')
            sheet(lowers).save(os.path.join(OUT, f'{key}-{action}-lower.png'))
            if has_upper: sheet(uppers).save(os.path.join(OUT, f'{key}-{action}-upper.png'))
            frames = []
            for m in meta:
                fm = dict(hand=world(m['hand']), shoulder_near=world(m['shoulder_near']), shoulder_far=world(m['shoulder_far']),
                          near_ground=m['near_ground'], far_ground=m['far_ground'], free=m['free'])
                if m['free']: fm['hand_far'] = world(m['hand_far'])
                fm['lean'] = round(m['lean'], 3)
                fm['bias'] = {n: round(b, 3) for n, b in m['bias'].items()}
                for n in SWING_PARTS:
                    if n + '_root' in m: fm[n + '_root'] = world(m[n + '_root'])
                frames.append(fm)
            views_meta[key]['actions'][action] = frames
            preview.setdefault(action, []).append(previews)
    from build_run_cycle_v7_review import ARM
    arm = {n: (round(val * k, 3) if n in ('upper', 'lower', 'sleeve_w', 'glove_r', 'cuff_w', 'outline') else val) for n, val in ARM.items()}
    rig = dict(source='docs/art/reviews/rina-parts-2026-09-25 build_run_cycle_v8.py (' + VARIANT + ')',
               cell=[int(CW * o), int(CH * o)], scale=round(k, 6), origin=[ox, gy], foot_y=15.0,
               idle_period=2.6, dodge_times=DODGE_TIMES, dodge_lift=6.0, arm=arm, views=views_meta,
               mirror={'e': ['side', False], 'se': ['diag_front', False], 's': ['front', False], 'sw': ['diag_front', True],
                       'w': ['side', True], 'nw': ['diag_back', True], 'n': ['back', False], 'ne': ['diag_back', False]})
    import build_arm_parts   # 腕・手袋の生成パーツ（2026-09-26、rina-arm-parts-v2）
    rig['arm_parts'] = build_arm_parts.export(OUT)
    json.dump(rig, open(os.path.join(OUT, 'rig.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    # 確認用一覧（銃・腕なし）：動作ごとに1枚、行＝向き、列＝コマ
    w, h = int(CW * o), int(CH * o)
    for action, rows in preview.items():
        n = len(rows[0])
        pv = Image.new('RGBA', (w * n, h * len(rows)), (111, 106, 98, 255))
        for r, previews in enumerate(rows):
            for f in range(n):
                pv.alpha_composite(previews[f].resize((w, h), Image.LANCZOS), (f * w, r * h))
        pv.save(os.path.join(HERE, f'run-cycle-v8-{action}-views.png'))
    print('ok', list(VIEWS), {a: len(s_) for a, s_ in specs.items()})
