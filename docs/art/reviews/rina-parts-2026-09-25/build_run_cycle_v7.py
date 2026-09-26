"""リナ側面走行サイクル v7：生成した胴体パーツ（腕・銃なし）＋本編の銃＋コード描画の両腕。

素材: assets/generated/rina-side-body-parts-v1.png（gpt-image-2、2026-09-26、1回生成。白背景に
      A=頭＋胴、B=ポニーテール、C=スカーフの垂れ の3パーツ）。プロンプトと参照は同名JSONに記録。
v6からの変更:
  - 仮胴体（v4原画から銃と手を消したもの）を生成パーツに差し替え。近側の腕も肩からコードで描く。
  - 頭を別レイヤーに出力し、レビュー側で「胴 → 銃 → 頭 → 手」の順に描けるようにした（銃は頬の後ろを通る）。
  - ポニーテールとスカーフの垂れは独立パーツとして付け根まわりに回す（切れ目なし）。後ろ髪の房だけワープで揺らす。
  - 脚・弾み（中/強）・減衰ばねは v6 と同じ（build_run_cycle_v6 を読み込む）。
出力: run-cycle-v7-<variant>-body.png（後ろ髪・スカーフ・脚・胴＋頭）、run-cycle-v7-<variant>-head.png（頭のみ）、
      run-cycle-v7-meta.json。各シートは8コマ横並び、1コマ 221×241（上に余白を足した縦長）。
再現: python build_run_cycle_v7.py （このフォルダーで実行。Pillow/numpy/scipy が必要）
"""
import json, math, os
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
import build_run_cycle_v6 as V6

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
PARTS_SRC = os.path.join(ROOT, 'assets', 'generated', 'rina-side-body-parts-v1.png')
PAD = 40                         # ポニーテールが揺れても切れないよう上に足す余白（セル画素）
CW, CH = 443, 443 + PAD
OUT_SCALE = 0.5
S = 0.44                         # 生成画像→セル画素の倍率（頭頂〜裾の高さをv4に合わせた）
HEM_SRC = (348.0, 844.0)         # 生成画像の裾の中央下端
HEM_CELL = (215.0, 350.0 + PAD)  # それを置くセル座標（脚の腰の少し前）
# 脚は v6 と同じ設計を余白ぶん下げて使う
V6.G = 428 + PAD
V6.HIP = (198.0, 338.0 + PAD)
V6.HIP_FAR = (184.0, 334.0 + PAD)
HIP = V6.HIP

def place(p):
    return ((p[0] - HEM_SRC[0]) * S + HEM_CELL[0], (p[1] - HEM_SRC[1]) * S + HEM_CELL[1])

# 生成画像上の基準点（目視と金色部分の検出で決めた値）
RING_HEAD = (336.0, 236.0)       # 頭頂の髪留め
RING_PONY = (850.0, 322.0)       # ポニーテール側の髪留め
SCARF_ROOT_SRC = (893.0, 748.0)  # スカーフの垂れの付け根（右端）
SCARF_ROOT_AT = (262.0, 668.0)   # それを付ける首の後ろ（生成画像のA上の位置）
SHOULDER_NEAR_SRC = (303.0, 723.0)
TORSO_FRONT_SRC = (445.0, 760.0)
HAIR_BACK_POLY = [(88, 420), (150, 380), (240, 420), (250, 520), (200, 600), (120, 560), (88, 470)]
HAIR_BACK_ROOT = (250.0, 470.0)

SHOULDER_NEAR = place(SHOULDER_NEAR_SRC)
SHOULDER_FAR = (SHOULDER_NEAR[0] + 8.0, SHOULDER_NEAR[1] - 4.0)
_front = place(TORSO_FRONT_SRC)
HAND_BASE = (_front[0] + 16.0, _front[1] + 6.0)
GOGGLE = place((470.0, 327.0))
HEAD_REF = place((400.0, 450.0))  # 揺れの入力に使う頭の代表点

def remove_white(rgb):
    """外周とつながる白背景を透明にし、輪郭の白混じりを白から分離（アンミックス）する。"""
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

def split_components(rgba):
    lab, n = ndi.label(rgba[..., 3] > 0)
    sizes = ndi.sum(np.ones(lab.shape), lab, range(1, n + 1))
    order = np.argsort(sizes)[::-1][:3] + 1
    parts = []
    for i in order:
        p = rgba.copy()
        p[..., 3] = np.where(ndi.binary_dilation(lab == i, iterations=2), rgba[..., 3], 0)
        ys, xs = np.nonzero(lab == i)
        parts.append((p, xs.mean(), ys.mean()))
    body = parts[0][0]
    rest = sorted(parts[1:], key=lambda t: t[2])  # 上＝ポニーテール、下＝スカーフ
    return body, rest[0][0], rest[1][0]

def head_only(body):
    """頭（髪・顔）だけ：首の線より上。顎の先は少し下まで含める。"""
    h = body.copy()
    yy, xx = np.mgrid[0:h.shape[0], 0:h.shape[1]]
    cut = np.where(xx < 400, 652, 662)
    h[..., 3] = np.where(yy < cut, h[..., 3], 0)
    return h

def to_cell(part, offset=(0.0, 0.0)):
    """生成画像のパーツを倍率Sでセル座標へ置いた premultiplied float 配列（offsetは生成画像上の平行移動）。"""
    im = Image.fromarray(part)
    w, h = round(im.width * S), round(im.height * S)
    small = np.asarray(im.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255.0
    small[..., :3] *= small[..., 3:4]
    out = np.zeros((CH, CW, 4), np.float32)
    x0, y0 = place((0.0 + offset[0], 0.0 + offset[1]))
    x0, y0 = int(round(x0)), int(round(y0))
    sx0, sy0 = max(0, -x0), max(0, -y0)
    dx0, dy0 = max(0, x0), max(0, y0)
    ww, hh = min(w - sx0, CW - dx0), min(h - sy0, CH - dy0)
    if ww > 0 and hh > 0:
        out[dy0:dy0 + hh, dx0:dx0 + ww] = small[sy0:sy0 + hh, sx0:sx0 + ww]
    return out

def load_parts():
    rgba = remove_white(np.asarray(Image.open(PARTS_SRC).convert('RGB')))
    body, pony, scarf = split_components(rgba)
    head = head_only(body)
    pony_off = (RING_HEAD[0] - RING_PONY[0], RING_HEAD[1] - RING_PONY[1])
    scarf_off = (SCARF_ROOT_AT[0] - SCARF_ROOT_SRC[0], SCARF_ROOT_AT[1] - SCARF_ROOT_SRC[1])
    hb = np.zeros(rgba.shape[:2], np.float32)
    from PIL import ImageDraw
    m = Image.new('L', (rgba.shape[1], rgba.shape[0]), 0)
    ImageDraw.Draw(m).polygon(HAIR_BACK_POLY, fill=255)
    hb = np.asarray(m, np.float32) / 255.0
    hb_cell = to_cell(np.dstack([np.zeros(hb.shape + (3,), np.uint8), (hb * 255).astype(np.uint8)]))[..., 3]
    hb_cell = ndi.gaussian_filter(hb_cell, 5)
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    r = place(HAIR_BACK_ROOT)
    ramp = np.clip(np.hypot(xx - r[0], yy - r[1]) / 60.0, 0, 1)
    hb_w = hb_cell * ramp * ramp * (3 - 2 * ramp)
    return dict(torso=to_cell(body), head=to_cell(head), pony=to_cell(pony, pony_off),
                scarf=to_cell(scarf, scarf_off), hair_back_w=hb_w)

def warp(src, lean, sx, sy, bob, local=None, weight=None):
    """出力→元の逆写像。全体：腰中心の拡縮→前傾→上下。local=(根本, 角度)：weight（無ければ全体）で根本まわりに回す。"""
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    hx, hy = HIP
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

def over(dst, src):
    return src + dst * (1.0 - src[..., 3:4])

def to_image(pm):
    al = np.clip(pm[..., 3:4], 1e-6, 1)
    rgb = np.where(pm[..., 3:4] > 1e-4, pm[..., :3] / al, 0)
    return Image.fromarray((np.dstack([np.clip(rgb, 0, 1), np.clip(pm[..., 3:4], 0, 1)]) * 255 + 0.5).astype(np.uint8))

def body_point(p, lean, sx, sy, bob):
    hx, hy = HIP
    x, y = (p[0] - hx) * sx, (p[1] - hy) * sy
    a = math.radians(lean)
    return (hx + x * math.cos(a) - y * math.sin(a), hy + x * math.sin(a) + y * math.cos(a) + bob)

def frame_params(V):
    bob = V6.expand(V['bob'])
    lean = [V['lean_base'] + d for d in V6.expand(V['lean'])]
    sq = V6.expand(V['squash'])
    head_y = [body_point(HEAD_REF, lean[f], sq[f][0], sq[f][1], bob[f])[1] for f in range(8)]
    bends = V6.spring_angles(head_y, V['spring_gain'])
    return bob, lean, sq, bends

def legs_layer(f, bob):
    S4 = V6.S
    big = Image.new('RGBA', (CW * S4, CH * S4), (0, 0, 0, 0))
    Pf = V6.leg_pose(f, far=True, bob=bob)
    Pn = V6.leg_pose(f, far=False, bob=bob)
    V6.draw_leg(big, Pf, V6.FAR)
    V6.draw_leg(big, Pn, V6.NEAR)
    small = np.asarray(big.resize((CW, CH), Image.LANCZOS)).astype(np.float32) / 255.0
    small[..., :3] *= small[..., 3:4]
    return small, Pn, Pf

def render_variant(parts, variant):
    V = V6.VARIANTS[variant]
    bob, lean, sq, bends = frame_params(V)
    pony_root, scarf_root = place(RING_HEAD), place(SCARF_ROOT_AT)
    hb_root = place(HAIR_BACK_ROOT)
    bodies, heads, meta = [], [], []
    for f in range(8):
        g = (lean[f], sq[f][0], sq[f][1], bob[f])
        legs, Pn, Pf = legs_layer(f, bob)
        scarf = warp(parts['scarf'], *g, local=(scarf_root, bends['scarf'][f]))
        pony = warp(parts['pony'], *g, local=(pony_root, bends['ponytail'][f]))
        torso = warp(parts['torso'], *g, local=(hb_root, bends['hair_back'][f]), weight=parts['hair_back_w'])
        head = warp(parts['head'], *g, local=(hb_root, bends['hair_back'][f]), weight=parts['hair_back_w'])
        body = np.zeros_like(torso)
        for layer in (scarf, pony, legs, torso):
            body = over(body, layer)
        bodies.append(to_image(body)); heads.append(to_image(head))
        gb = V['gun_follow'] * bob[(f - 1) % 8]
        hand = body_point(HAND_BASE, V['lean_base'], 1.0, 1.0, gb)
        sn = body_point(SHOULDER_NEAR, *g)
        sf = body_point(SHOULDER_FAR, *g)
        o = OUT_SCALE
        P = lambda p: [round(p[0] * o, 2), round(p[1] * o, 2)]
        meta.append(dict(frame=f, bob=bob[f], lean=round(lean[f], 2), squash=[sq[f][0], sq[f][1]],
                         bend={k: round(v[f], 2) for k, v in bends.items()},
                         hand=P(hand), shoulder_near=P(sn), shoulder_far=P(sf),
                         goggle=P(body_point(GOGGLE, *g)),
                         near=dict(key=Pn['key'], ground=Pn['ground'], reach=round(Pn['reach'], 2)),
                         far=dict(key=Pf['key'], ground=Pf['ground'], reach=round(Pf['reach'], 2))))
    return bodies, heads, meta

def sheet(frames):
    w, h = int(CW * OUT_SCALE), int(CH * OUT_SCALE)
    out = Image.new('RGBA', (w * 8, h), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        out.alpha_composite(fr.resize((w, h), Image.LANCZOS), (i * w, 0))
    return out

if __name__ == '__main__':
    parts = load_parts()
    result = {}
    for variant in ('medium', 'strong'):
        bodies, heads, meta = render_variant(parts, variant)
        sheet(bodies).save(os.path.join(HERE, f'run-cycle-v7-{variant}-body.png'))
        sheet(heads).save(os.path.join(HERE, f'run-cycle-v7-{variant}-head.png'))
        over_reach = [(m['frame'], s) for m in meta for s in ('near', 'far') if m[s]['reach'] > V6.L1 + V6.L2]
        if over_reach:
            raise SystemExit(f'{variant}: 脚が届かないコマ {over_reach}')
        result[variant] = dict(frames_meta=meta)
    o = OUT_SCALE
    result.update(cell_w=int(CW * o), cell_h=int(CH * o), frames=8, ground_y=V6.G * o, origin_x=HIP[0] * o,
                  nominal_height=None, stride_per_frame=V6.STRIDE * o,
                  source='assets/generated/rina-side-body-parts-v1.png (head+torso, ponytail, scarf tail; generated 2026-09-26). '
                         'Guns from assets/first-workshop/equipment/guns via data/weapon_visuals.json; arms drawn in code.')
    # 表示倍率の基準：コマ0の体シートの最上点（ポニーテール込み）〜床。レビューでこれを56pxにする。
    b0 = np.asarray(Image.open(os.path.join(HERE, 'run-cycle-v7-strong-body.png')))[..., 3][:, :result['cell_w']]
    ys = np.nonzero(b0.max(1) > 40)[0]
    result['nominal_height'] = float(result['ground_y'] - ys.min())
    json.dump(result, open(os.path.join(HERE, 'run-cycle-v7-meta.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('ok nominal_height', result['nominal_height'])
