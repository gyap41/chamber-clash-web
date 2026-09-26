"""v7レビューHTMLと確認GIFを生成する。

体シート（後ろ髪・スカーフ・脚・胴＋頭）と頭シートの間に、本編の銃画像と腕を合成する。
  描画順（既定）: 遠側の腕 → 体 → 銃 → 頭 → 遠側の手 → 近側の腕（肩→肘→手）
  比較用（本編と同じ）: 遠側の腕 → 体 → 頭 → 銃 → 遠側の手 → 近側の腕
銃の大きさ・grip・muzzle の規則は v6 と同じ（本編 player.gd update_weapon_art と同じ 40×30 枠×scale）。
HTML側（run-cycle-v7-review.template.html）も同じ規則のJSで描き、38種の武器を切り替えられる。

再現: python build_run_cycle_v7_review.py （このフォルダーで実行。先に build_run_cycle_v7.py）
"""
import base64, json, math, os
import numpy as np
from PIL import Image, ImageDraw
from build_run_cycle_v6_review import weapon_profile, draw_capsule, draw_disc, visuals, ROOT

HERE = os.path.dirname(os.path.abspath(__file__))
meta = json.load(open(os.path.join(HERE, 'run-cycle-v7-meta.json'), encoding='utf-8'))

# 腕の寸法・色（シート画素）。JSへもこの値を渡す。
ARM = dict(upper=23.0, lower=23.0, sleeve_w=13.0, glove_r=8.5, cuff_w=12.0, outline=2.2,
           near_sleeve=[246, 230, 198], near_sleeve_hi=[252, 242, 220], far_sleeve=[204, 186, 156],
           near_glove=[128, 80, 62], near_glove_hi=[160, 104, 82], far_glove=[88, 56, 44], ink=[20, 14, 12],
           long_min=26.0, support_max=16.0, pistol_support=[1.5, 2.0])

def ik(a, b, L1, L2):
    """a→b の2関節。届かなければ伸ばしきった位置で止める。肘は下側。戻り値 (肘, 手)。"""
    dx, dy = b[0] - a[0], b[1] - a[1]
    d = math.hypot(dx, dy)
    if d > L1 + L2 - 0.01:
        k = (L1 + L2 - 0.01) / d
        b = (a[0] + dx * k, a[1] + dy * k)
        d = L1 + L2 - 0.01
    t = math.atan2(dy, dx)
    c = math.acos(max(-1, min(1, (L1 * L1 + d * d - L2 * L2) / (2 * L1 * max(d, 1e-3)))))
    return (a[0] + L1 * math.cos(t + c), a[1] + L1 * math.sin(t + c)), b

def rig(fm, prof, px):
    w, h = prof['image'].width * prof['ratio'] * px, prof['image'].height * prof['ratio'] * px
    hx, hy = fm['hand']
    gx, gy = hx - prof['grip'][0] * w, hy - prof['grip'][1] * h
    mx, my = gx + prof['muzzle'][0] * w, gy + prof['muzzle'][1] * h
    reach = (mx - hx) / px
    if reach >= ARM['long_min']:
        sp = (hx + min(ARM['support_max'], reach * 0.4) * px, my + 0.12 * (hy - my) + ARM['glove_r'] * 0.6)
        kind = 'long'
    else:
        sp = (hx + ARM['pistol_support'][0] * px, hy + ARM['pistol_support'][1] * px)
        kind = 'short'
    far_elbow, sp = ik(fm['shoulder_far'], sp, ARM['upper'], ARM['lower'])
    near_elbow, near_hand = ik(fm['shoulder_near'], (hx, hy), ARM['upper'], ARM['lower'])
    return dict(gun=(gx, gy, w, h), muzzle=(mx, my), support=sp, far_elbow=far_elbow,
                near_elbow=near_elbow, near_hand=near_hand, kind=kind)

def composite(body, head, fm, f, prof, px, gun_behind_head=True, ss=4):
    cw, ch = meta['cell_w'], meta['cell_h']
    W = cw * 2
    R = rig(fm, prof, px)
    ink = tuple(ARM['ink']) + (255,)
    o = ARM['outline']
    col = lambda k: tuple(ARM[k]) + (255,)

    def layer():
        im = Image.new('RGBA', (W * ss, ch * ss), (0, 0, 0, 0))
        return im, ImageDraw.Draw(im)

    far, d = layer()
    sh, el, sp = fm['shoulder_far'], R['far_elbow'], R['support']
    draw_capsule(d, sh, el, ARM['sleeve_w'] + 2 * o, ink, ss)
    draw_capsule(d, el, sp, ARM['cuff_w'] + 2 * o, ink, ss)
    draw_capsule(d, sh, el, ARM['sleeve_w'], col('far_sleeve'), ss)
    draw_capsule(d, el, sp, ARM['cuff_w'], col('far_sleeve'), ss)
    gun, _ = layer()
    gx, gy, w, h = R['gun']
    gun.paste(prof['image'].resize((max(1, round(w * ss)), max(1, round(h * ss))), Image.LANCZOS), (round(gx * ss), round(gy * ss)))
    hands, d = layer()
    draw_disc(d, sp, ARM['glove_r'] + o, ink, ss)
    draw_disc(d, sp, ARM['glove_r'], col('far_glove'), ss)
    sn, en, hn = fm['shoulder_near'], R['near_elbow'], R['near_hand']
    draw_capsule(d, sn, en, ARM['sleeve_w'] + 2 * o, ink, ss)
    draw_capsule(d, en, hn, ARM['cuff_w'] + 2 * o, ink, ss)
    draw_disc(d, hn, ARM['glove_r'] + o, ink, ss)
    draw_capsule(d, sn, en, ARM['sleeve_w'], col('near_sleeve'), ss)
    draw_capsule(d, en, hn, ARM['cuff_w'], col('near_sleeve'), ss)
    draw_disc(d, (sn[0] + 1.5, sn[1] - 2), ARM['sleeve_w'] * 0.28, col('near_sleeve_hi'), ss)
    draw_disc(d, hn, ARM['glove_r'], col('near_glove'), ss)
    draw_disc(d, (hn[0] - 2, hn[1] - 2.5), ARM['glove_r'] * 0.45, col('near_glove_hi'), ss)
    small = lambda im: im.resize((W, ch), Image.LANCZOS)
    out = small(far)
    out.alpha_composite(body.crop((f * cw, 0, (f + 1) * cw, ch)), (0, 0))
    hd = head.crop((f * cw, 0, (f + 1) * cw, ch))
    if gun_behind_head:
        out.alpha_composite(small(gun)); out.alpha_composite(hd, (0, 0))
    else:
        out.alpha_composite(hd, (0, 0)); out.alpha_composite(small(gun))
    out.alpha_composite(small(hands))
    return out, R

def gif(variant, weapons, path):
    body = Image.open(os.path.join(HERE, f'run-cycle-v7-{variant}-body.png')).convert('RGBA')
    head = Image.open(os.path.join(HERE, f'run-cycle-v7-{variant}-head.png')).convert('RGBA')
    px = meta['nominal_height'] / 56.0
    s56 = 56.0 / meta['nominal_height']
    W, Hh = 240, 76 * len(weapons)
    profs = [weapon_profile(k) for k in weapons]
    frames, scroll = [], 0.0
    for loop in range(3):
        for f in range(8):
            canvas = Image.new('RGBA', (W, Hh), (111, 106, 98, 255))
            d = ImageDraw.Draw(canvas)
            for row, prof in enumerate(profs):
                img, _ = composite(body, head, meta[variant]['frames_meta'][f], f, prof, px)
                small = img.resize((round(img.width * s56), round(img.height * s56)), Image.LANCZOS)
                gy = 66 + row * 76
                off = (scroll * s56) % 24
                d.line([(0, gy), (W, gy)], fill=(133, 124, 112, 255))
                for x in range(-24, W + 24, 24):
                    d.line([(x - off, gy), (x - off - 6, gy + 10)], fill=(90, 82, 74, 255))
                canvas.alpha_composite(small, (round(80 - meta['origin_x'] * s56), round(gy - meta['ground_y'] * s56)))
            frames.append(canvas.convert('P', palette=Image.ADAPTIVE))
            scroll += meta['stride_per_frame']
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=62, loop=0, disposal=2)

if __name__ == '__main__':
    cw = meta['cell_w']
    s56 = 56.0 / meta['nominal_height']
    px = meta['nominal_height'] / 56.0
    for variant in ('medium', 'strong'):
        for part in ('body', 'head'):
            meta[variant][part] = base64.b64encode(open(os.path.join(HERE, f'run-cycle-v7-{variant}-{part}.png'), 'rb').read()).decode()
        # 56px表示での数値（拳銃00）。美術品質の判定ではない。
        a = np.asarray(Image.open(os.path.join(HERE, f'run-cycle-v7-{variant}-body.png')))[..., 3]
        tops, bots = [], []
        for f in range(8):
            ys = np.nonzero(a[:, f * cw:(f + 1) * cw].max(1) > 40)[0]
            tops.append(int(ys.min())); bots.append(int(ys.max()))
        ground = max(bots)
        fms = meta[variant]['frames_meta']
        prof = weapon_profile('0')
        muz = [rig(fm, prof, px)['muzzle'][1] for fm in fms]
        gog = [fm['goggle'][1] for fm in fms]
        meta[variant]['measure'] = dict(
            head_px=[round((g - gog[0]) * s56, 2) for g in gog],
            head_range_px=round((max(gog) - min(gog)) * s56, 2),
            outline_top_range_px=round((max(tops) - min(tops)) * s56, 2),
            foot_lift_px=[round((ground - b) * s56, 2) for b in bots],
            muzzle_range_px=round((max(muz) - min(muz)) * s56, 2),
            airborne_frames=sum(1 for fm in fms if not fm['near']['ground'] and not fm['far']['ground']))
        print(variant, meta[variant]['measure'])
    guns = []
    for key in visuals['weapons']:
        prof = weapon_profile(key)
        buf = open(os.path.join(ROOT, prof['tex']), 'rb').read()
        guns.append(dict(key=key, family=visuals['weapons'][key].get('family', ''), ratio=prof['ratio'],
                         w=prof['image'].width, h=prof['image'].height, grip=prof['grip'], muzzle=prof['muzzle'],
                         note=prof['note'], src='data:image/png;base64,' + base64.b64encode(buf).decode()))
    html = open(os.path.join(HERE, 'run-cycle-v7-review.template.html'), encoding='utf-8').read()
    html = html.replace('__META__', json.dumps(meta, ensure_ascii=False))
    html = html.replace('__GUNS__', json.dumps(guns, ensure_ascii=False))
    html = html.replace('__ARM__', json.dumps(ARM, ensure_ascii=False))
    open(os.path.join(HERE, 'run-cycle-v7-review.html'), 'w', encoding='utf-8').write(html)
    for variant in ('medium', 'strong'):
        gif(variant, ['0', '19'], os.path.join(HERE, f'run-cycle-v7-{variant}.gif'))
    print('ok')
