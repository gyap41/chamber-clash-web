"""v6レビューHTMLと確認GIFを生成する。

体（脚＋上体）はシート、銃と腕はここで別レイヤーとして合成する：
  銃: data/weapon_visuals.json の body.texture / grip / muzzle / scale を本編(player.gd update_weapon_art)と同じ
      大きさの規則（40×30の枠に収める倍率×scale、ゲーム画素）で置き、grip を近側の手に合わせる。照準角は0°。
  腕: 遠側は肩→支持点（拳銃は grip の下、長い武器は銃身の下）を2関節で、近側は袖口→grip を手袋で描く。
HTML側（run-cycle-v6-review.template.html）も同じ規則のJSで描き、38種の武器を切り替えられる。

再現: python build_run_cycle_v6_review.py （このフォルダーで実行。先に build_run_cycle_v6.py）
"""
import base64, io, json, math, os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
meta = json.load(open(os.path.join(HERE, 'run-cycle-v6-meta.json'), encoding='utf-8'))
visuals = json.load(open(os.path.join(ROOT, 'data', 'weapon_visuals.json'), encoding='utf-8'))

# 本編の武器表示枠（scripts/combat/player.gd weapon_display_size）
WEAPON_BOX = (40.0, 30.0)
# 腕の寸法・色（シート画素＝セル画素×0.5）。JSへもこの値を渡す。
ARM = dict(upper=25.0, lower=25.0, sleeve_w=12.0, glove_r=8.0, cuff_w=12.5, outline=2.2,
           near_glove=[128, 80, 62], near_glove_hi=[160, 104, 82], far_glove=[88, 56, 44],
           far_sleeve=[196, 184, 160], ink=[20, 14, 12],
           long_min=26.0, support_max=16.0)
# 拳銃の手の添え方（ゲーム画素）。grip から少し下・前。
PISTOL_SUPPORT = (1.5, 2.0)
GOGGLE = (270.0, 140.0)  # 頭の上下を測る点（ゴーグルのレンズ中心、セル座標）。輪郭の最上点はポニーテールの揺れを含むため別に記録する

def weapon_profile(key):
    b = visuals['weapons'][key]['body']
    tex = b['texture'].replace('res://', '')
    im = Image.open(os.path.join(ROOT, tex)).convert('RGBA')
    if 'grip' in b:
        ratio = min(WEAPON_BOX[0] / im.width, WEAPON_BOX[1] / im.height) * float(b.get('scale', 1.0))
        grip, muzzle, note = b['grip'], b['muzzle'], ''
    else:
        # grip未定義（fixed_width方式）：本編の幅を使い、握りは画像から目視した近似値
        ratio = float(b['fixed_width']) / im.width
        grip, muzzle, note = [0.3, 0.72], [0.98, 0.3], 'grip未定義のため近似'
    return dict(key=key, image=im, ratio=ratio, grip=grip, muzzle=muzzle, note=note, tex=tex)

def rig(fm, prof, px):
    """1コマ分の銃と腕の配置（シート画素）。px = 1ゲーム画素あたりのシート画素。"""
    w, h = prof['image'].width * prof['ratio'] * px, prof['image'].height * prof['ratio'] * px
    hx, hy = fm['hand']
    gx, gy = hx - prof['grip'][0] * w, hy - prof['grip'][1] * h
    mx, my = gx + prof['muzzle'][0] * w, gy + prof['muzzle'][1] * h
    reach = (mx - hx) / px
    if reach >= ARM['long_min']:
        # 長い武器：銃身の下へ前の手を添える（腕が届く範囲まで）
        sx = hx + min(ARM['support_max'], reach * 0.4) * px
        sy = my + 0.12 * (hy - my) + ARM['glove_r'] * 0.6
        kind = 'long'
    else:
        sx, sy = hx + PISTOL_SUPPORT[0] * px, hy + PISTOL_SUPPORT[1] * px
        kind = 'short'
    sh = fm['shoulder_far']
    L1, L2 = ARM['upper'], ARM['lower']
    dx, dy = sx - sh[0], sy - sh[1]
    d = math.hypot(dx, dy)
    if d > L1 + L2 - 0.01:   # 届かない場合は肩→支持点の線上で手を止める（腕を伸ばしきる）
        k = (L1 + L2 - 0.01) / d
        sx, sy = sh[0] + dx * k, sh[1] + dy * k
        d = L1 + L2 - 0.01
    a = math.atan2(dy, dx)
    b = math.acos(max(-1, min(1, (L1 * L1 + d * d - L2 * L2) / (2 * L1 * d))))
    elbow = (sh[0] + L1 * math.cos(a + b), sh[1] + L1 * math.sin(a + b))  # 肘は下側
    return dict(gun=(gx, gy, w, h), muzzle=(mx, my), support=(sx, sy), elbow=elbow, kind=kind)

def draw_capsule(dr, a, b, width, col, s):
    dr.line([(a[0] * s, a[1] * s), (b[0] * s, b[1] * s)], fill=col, width=max(1, int(width * s)))
    for p in (a, b):
        r = width * s / 2
        dr.ellipse([p[0] * s - r, p[1] * s - r, p[0] * s + r, p[1] * s + r], fill=col)

def draw_disc(dr, p, r, col, s):
    dr.ellipse([(p[0] - r) * s, (p[1] - r) * s, (p[0] + r) * s, (p[1] + r) * s], fill=col)

def composite(sheet, fm, f, prof, px, cell, ss=4):
    """PIL合成（GIF用）。順序：遠側の腕 → 体 → 銃 → 近側の手袋。"""
    R = rig(fm, prof, px)
    ink = tuple(ARM['ink']) + (255,)
    o = ARM['outline']
    CW = cell * 2  # 銃が前へはみ出すので横2セル分の画面に合成する
    far = Image.new('RGBA', (CW * ss, cell * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(far)
    sh, el, sp = fm['shoulder_far'], R['elbow'], R['support']
    draw_capsule(d, sh, el, ARM['sleeve_w'] + 2 * o, ink, ss)
    draw_capsule(d, el, sp, ARM['cuff_w'] + 2 * o, ink, ss)
    draw_capsule(d, sh, el, ARM['sleeve_w'], tuple(ARM['far_sleeve']) + (255,), ss)
    draw_capsule(d, el, sp, ARM['cuff_w'], tuple(ARM['far_glove']) + (255,), ss)
    out = far.resize((CW, cell), Image.LANCZOS)
    out.alpha_composite(sheet.crop((f * cell, 0, (f + 1) * cell, cell)), (0, 0))
    gx, gy, w, h = R['gun']
    big = Image.new('RGBA', (CW * ss, cell * ss), (0, 0, 0, 0))
    g = prof['image'].resize((max(1, round(w * ss)), max(1, round(h * ss))), Image.LANCZOS)
    big.paste(g, (round(gx * ss), round(gy * ss)))  # 空のレイヤーなので paste で可（負の座標も扱える）
    d = ImageDraw.Draw(big)
    # 遠側の手は銃の上に描く（銃身・握りを下から支える指が見える）
    draw_disc(d, sp, ARM['glove_r'] + o, ink, ss)
    draw_disc(d, sp, ARM['glove_r'], tuple(ARM['far_glove']) + (255,), ss)
    wr, hd = fm['wrist_near'], fm['hand']
    draw_capsule(d, wr, hd, ARM['cuff_w'] + 2 * o, ink, ss)
    draw_disc(d, hd, ARM['glove_r'] + o, ink, ss)
    draw_capsule(d, wr, hd, ARM['cuff_w'], tuple(ARM['near_glove']) + (255,), ss)
    draw_disc(d, hd, ARM['glove_r'], tuple(ARM['near_glove']) + (255,), ss)
    draw_disc(d, (hd[0] - 2, hd[1] - 2.5), ARM['glove_r'] * 0.45, tuple(ARM['near_glove_hi']) + (255,), ss)
    out.alpha_composite(big.resize((CW, cell), Image.LANCZOS))
    return out, R

def gif(variant, weapons, path):
    cell = meta['cell']
    sheet = Image.open(os.path.join(HERE, f'run-cycle-v6-{variant}-sheet.png')).convert('RGBA')
    px = meta['nominal_height'] / 56.0
    s56 = 56.0 / meta['nominal_height']
    W, Hh = 240, 70 * len(weapons)
    frames = []
    scroll = 0.0
    for loop in range(3):
        for f in range(8):
            canvas = Image.new('RGBA', (W, Hh), (111, 106, 98, 255))
            d = ImageDraw.Draw(canvas)
            for row, key in enumerate(weapons):
                prof = weapon_profile(key)
                img, _ = composite(sheet, meta[variant]['frames_meta'][f], f, prof, px, cell)
                small = img.resize((round(img.width * s56), round(img.height * s56)), Image.LANCZOS)
                gy = 60 + row * 70
                off = (scroll * s56) % 24
                d.line([(0, gy), (W, gy)], fill=(133, 124, 112, 255))
                for x in range(-24, W + 24, 24):
                    d.line([(x - off, gy), (x - off - 6, gy + 10)], fill=(90, 82, 74, 255))
                canvas.alpha_composite(small, (round(80 - meta['origin_x'] * s56), round(gy - meta['ground_y'] * s56)))
            frames.append(canvas.convert('P', palette=Image.ADAPTIVE))
            scroll += meta['stride_per_frame']
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=62, loop=0, disposal=2)

if __name__ == '__main__':
    cell = meta['cell']
    for variant in ('medium', 'strong'):
        im = Image.open(os.path.join(HERE, f'run-cycle-v6-{variant}-sheet.png'))
        meta[variant]['sheet'] = base64.b64encode(open(os.path.join(HERE, f'run-cycle-v6-{variant}-sheet.png'), 'rb').read()).decode()
    # 56px表示での数値（体シートの画素と、拳銃00の銃口）。美術品質の判定ではない。
    s56 = 56.0 / meta['nominal_height']
    px = meta['nominal_height'] / 56.0
    import numpy as np
    for variant in ('medium', 'strong'):
        a = np.asarray(Image.open(os.path.join(HERE, f'run-cycle-v6-{variant}-sheet.png')))[..., 3]
        tops, bots = [], []
        for f in range(8):
            ys = np.nonzero(a[:, f * cell:(f + 1) * cell].max(1) > 40)[0]
            tops.append(int(ys.min())); bots.append(int(ys.max()))
        ground = max(bots)
        prof = weapon_profile('0')
        muz = [rig(fm, prof, px)['muzzle'][1] for fm in meta[variant]['frames_meta']]
        hand = [fm['hand'][1] for fm in meta[variant]['frames_meta']]
        import build_run_cycle_v6 as B
        gog = [B.body_point(GOGGLE, fm['lean'], fm['squash'][0], fm['squash'][1], fm['bob'])[1] * B.OUT_SCALE
               for fm in meta[variant]['frames_meta']]
        meta[variant]['measure'] = dict(
            head_px=[round((g - gog[0]) * s56, 2) for g in gog],
            head_range_px=round((max(gog) - min(gog)) * s56, 2),
            outline_top_px=[round((t - tops[0]) * s56, 2) for t in tops],
            outline_top_range_px=round((max(tops) - min(tops)) * s56, 2),
            foot_lift_px=[round((ground - b) * s56, 2) for b in bots],
            muzzle_range_px=round((max(muz) - min(muz)) * s56, 2),
            hand_range_px=round((max(hand) - min(hand)) * s56, 2),
            airborne_frames=sum(1 for fm in meta[variant]['frames_meta'] if not fm['near']['ground'] and not fm['far']['ground']))
        print(variant, meta[variant]['measure'])
    guns = []
    for key in visuals['weapons']:
        prof = weapon_profile(key)
        buf = open(os.path.join(ROOT, prof['tex']), 'rb').read()
        guns.append(dict(key=key, family=visuals['weapons'][key].get('family', ''), ratio=prof['ratio'],
                         w=prof['image'].width, h=prof['image'].height, grip=prof['grip'], muzzle=prof['muzzle'],
                         note=prof['note'], src='data:image/png;base64,' + base64.b64encode(buf).decode()))
    html = open(os.path.join(HERE, 'run-cycle-v6-review.template.html'), encoding='utf-8').read()
    html = html.replace('__META__', json.dumps(meta, ensure_ascii=False))
    html = html.replace('__GUNS__', json.dumps(guns, ensure_ascii=False))
    html = html.replace('__ARM__', json.dumps(dict(ARM, pistol_support=PISTOL_SUPPORT), ensure_ascii=False))
    open(os.path.join(HERE, 'run-cycle-v6-review.html'), 'w', encoding='utf-8').write(html)
    for variant in ('medium', 'strong'):
        gif(variant, ['0', '19'], os.path.join(HERE, f'run-cycle-v6-{variant}.gif'))
    print('ok')
