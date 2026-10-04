"""Mechanical checks for a generated sprite sheet or single image (no API calls, no file changes outside --out).

Measures what can be measured without taste: transparency, cropping, empty frames, ground-line drift,
body-size drift, luminance/edge contrast against the floor (same formulas as tools/capture_style_comparison.gd),
and how much consecutive frames actually differ. Writes report.json plus contact sheets that show every frame
at in-game display scale on the floor and at 3x nearest-neighbour, for the art reviewer and the user.

Example (fire-pouch lizard v3: 4 direction columns x 8 pose rows, cells 344x256, feet at y=230, scale .24):
  .local/audio-venv/Scripts/python.exe tools/asset_check/check_image.py assets/first-workshop/enemies/lizard-sheet-v3.png
      --grid 4x8 --directions columns --direction-names front,back,right,left
      --groups walk:0-3:loop,windup:4,spit:5,idle:6,death:7 --ground 230 --display-scale 0.24
      --kind actor --out .local/asset-check/lizard-v3
"""
import argparse
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_FLOOR = ROOT / "assets/stages/ashen-foundry-v2/floor.png"  # current exploration floor

# Provisional thresholds (2026-10-04). Hard failures stop the pipeline before review; warnings go to the reviewer.
ALPHA_SOLID = 128            # alpha above this counts as the drawn body
EDGE_MARGIN = 1              # opaque pixels this close to the cell border = cropped / touching the neighbour
MAGENTA_RATIO_FAIL = 0.002   # leftover chroma-key pixels among visible pixels
GROUND_DRIFT_FAIL = 2.0      # display px: feet must stay on the ground line within a group
SIZE_DRIFT_WARN = 0.12       # relative bbox height change within a direction (excluding death/attack groups is up to the reviewer)
STATIC_DIFF_WARN = 1.0       # mean luma difference (0-100) between consecutive frames below this = frames look identical
LOOP_SEAM_WARN = 3.0         # loop seam (last->first) much larger than the average step
# Compared with a reference asset measured by this same tool (--baseline report.json). The absolute targets in
# VISUAL_STYLE_GUIDE 3.5 come from full in-game screenshots (lighting, shadows) and cannot be reproduced here.
BASELINE_RATIO_WARN = 0.8    # luma_mean / luma_std / edge_contrast below 80% of the baseline median


def luma(rgb):
    return (0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]) / 255.0 * 100.0


def saturation(rgb):
    mx = rgb.max(axis=-1).astype(float)
    mn = rgb.min(axis=-1).astype(float)
    return np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0.0)


def parse_groups(text, count):
    if not text:
        return [{"name": "all", "frames": list(range(count)), "loop": False}]
    groups = []
    for part in text.split(","):
        bits = part.split(":")
        name, span = bits[0], bits[1]
        first, _, last = span.partition("-")
        frames = list(range(int(first), int(last or first) + 1))
        if frames[-1] >= count:
            raise SystemExit(f"group {name} uses frame {frames[-1]} but the sheet has {count} frames per direction")
        groups.append({"name": name, "frames": frames, "loop": len(bits) > 2 and bits[2] == "loop"})
    return groups


def cells(image, cols, rows, directions_axis):
    """Return frames[direction][frame] as RGBA uint8 arrays."""
    w, h = image.size
    if w % cols or h % rows:
        raise SystemExit(f"image {w}x{h} is not divisible into a {cols}x{rows} grid")
    cw, ch = w // cols, h // rows
    data = np.asarray(image.convert("RGBA"))
    grid = [[data[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw] for c in range(cols)] for r in range(rows)]
    if directions_axis == "columns":
        grid = [list(col) for col in zip(*grid)]
    return grid, (cw, ch)


def to_display(cell, scale):
    img = Image.fromarray(cell, "RGBA")
    size = (max(1, round(img.width * scale)), max(1, round(img.height * scale)))
    return img.resize(size, Image.Resampling.BILINEAR)


def frame_stats(cell, scale, floor_rgb):
    alpha = cell[..., 3]
    solid = alpha > ALPHA_SOLID
    visible = alpha > 8
    h, w = alpha.shape
    result = {"empty": not solid.any()}
    if result["empty"]:
        return result
    ys, xs = np.nonzero(solid)
    result["bbox"] = [int(xs.min()), int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)]
    result["feet_y"] = int(ys.max())
    result["touches_edge"] = bool(xs.min() < EDGE_MARGIN or ys.min() < EDGE_MARGIN
                                  or xs.max() >= w - EDGE_MARGIN or ys.max() >= h - EDGE_MARGIN)
    rgb = cell[..., :3].astype(int)
    magenta = visible & (rgb[..., 0] > 200) & (rgb[..., 2] > 200) & (rgb[..., 1] < 80)
    result["magenta_ratio"] = round(float(magenta.sum() / max(1, visible.sum())), 4)
    result["semi_transparent_ratio"] = round(float(((alpha > 8) & (alpha < 248)).sum() / max(1, visible.sum())), 3)
    # Colour statistics at display scale composited on the floor, like the in-game camera shows it.
    disp = np.asarray(to_display(cell, scale)).astype(float)
    dh, dw = disp.shape[:2]
    floor = floor_rgb[:dh, :dw].astype(float)
    a = disp[..., 3:4] / 255.0
    comp = disp[..., :3] * a + floor * (1 - a)
    body = disp[..., 3] > ALPHA_SOLID
    if body.sum() < 4:
        return result
    l_comp, l_floor = luma(comp), luma(floor)
    inner = body.copy()
    inner[1:, :] &= body[:-1, :]
    inner[:-1, :] &= body[1:, :]
    inner[:, 1:] &= body[:, :-1]
    inner[:, :-1] &= body[:, 1:]
    edge = body & ~inner
    gx = np.abs(np.roll(l_comp, -1, 1) - np.roll(l_comp, 1, 1))
    gy = np.abs(np.roll(l_comp, -1, 0) - np.roll(l_comp, 1, 0))
    detail = ((gx + gy) * 0.25)[inner]
    result.update({
        "display_size": [int(body.any(axis=0).sum()), int(body.any(axis=1).sum())],
        "luma_mean": round(float(l_comp[body].mean()), 1),
        "luma_std": round(float(l_comp[body].std()), 1),
        "saturation_mean": round(float(saturation(comp.astype(np.uint8))[body].mean() * 100), 1),
        "detail": round(float(detail.mean()) if detail.size else 0.0, 2),
        "edge_contrast": round(float(np.abs(l_comp[edge] - l_floor[edge]).mean()), 1),
    })
    return result


def frame_difference(a, b, scale):
    """Mean luma change (0-100) between two frames at display scale, with alpha as coverage."""
    da = np.asarray(to_display(a, scale)).astype(float)
    db = np.asarray(to_display(b, scale)).astype(float)
    la = luma(da[..., :3]) * da[..., 3] / 255.0
    lb = luma(db[..., :3]) * db[..., 3] / 255.0
    cover = (da[..., 3] > 8) | (db[..., 3] > 8)
    if not cover.any():
        return 0.0, 1.0
    sa, sb = da[..., 3] > ALPHA_SOLID, db[..., 3] > ALPHA_SOLID
    union = (sa | sb).sum()
    return round(float(np.abs(la - lb)[cover].mean()), 2), round(float((sa & sb).sum() / max(1, union)), 3)


def contact_sheet(frames, names, groups, scale, floor_img, ground, zoom):
    """Rows = directions, columns = frames in order; each loop group repeats its first frame after the last."""
    order = []
    for g in groups:
        order += [(g["name"], i, False) for i in g["frames"]]
        if g["loop"]:
            order.append((g["name"], g["frames"][0], True))
    sample = to_display(frames[0][0], scale)
    cw, ch = sample.width * zoom, sample.height * zoom
    label_h, label_w = 14, 64
    sheet = Image.new("RGB", (label_w + cw * len(order), label_h * 2 + ch * len(frames)), (24, 24, 28))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for col, (gname, index, seam) in enumerate(order):
        draw.text((label_w + col * cw + 2, 0), gname[:8], fill=(200, 200, 200), font=font)
        draw.text((label_w + col * cw + 2, label_h), ("=" if seam else "") + str(index), fill=(255, 210, 80) if seam else (230, 230, 230), font=font)
    tile = floor_img.resize((floor_img.width * zoom, floor_img.height * zoom), Image.Resampling.NEAREST) if zoom > 1 else floor_img
    for row, direction in enumerate(frames):
        y0 = label_h * 2 + row * ch
        draw.text((2, y0 + 2), names[row][:10], fill=(230, 230, 230), font=font)
        for col, (_, index, _) in enumerate(order):
            x0 = label_w + col * cw
            sprite = to_display(direction[index], scale)
            if zoom > 1:
                sprite = sprite.resize((sprite.width * zoom, sprite.height * zoom), Image.Resampling.NEAREST)
            cell = tile.crop((0, 0, cw, ch)).convert("RGBA")
            cell.alpha_composite(sprite)
            sheet.paste(cell.convert("RGB"), (x0, y0))
            if ground is not None:
                gy = y0 + round(ground * scale) * zoom
                draw.line([(x0, gy), (x0 + cw - 1, gy)], fill=(255, 64, 64), width=1)
            draw.rectangle([x0, y0, x0 + cw - 1, y0 + ch - 1], outline=(60, 60, 70))
    return sheet


def main(argv=None):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # Windows consoles default to cp932
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("image", type=Path)
    p.add_argument("--grid", default="1x1", help="COLSxROWS of equal cells")
    p.add_argument("--directions", choices=["rows", "columns"], default="rows", help="which axis holds directions")
    p.add_argument("--direction-names", default="", help="comma separated, e.g. front,back,right,left")
    p.add_argument("--groups", default="", help="name:first-last[:loop],... frame index ranges per direction")
    p.add_argument("--ground", type=float, help="feet line y inside each cell (source px)")
    p.add_argument("--display-scale", type=float, default=None, help="in-game scale of the source cell (before camera zoom)")
    p.add_argument("--camera-zoom", type=float, default=1.2, help="exploration camera zoom; 1.2 matches VISUAL_STYLE_GUIDE measurements")
    p.add_argument("--baseline", type=Path, help="report.json of an adopted reference asset measured with the same options")
    p.add_argument("--display-height", type=float, default=None, help="alternative: tallest body height on screen in px (character ~56)")
    p.add_argument("--kind", choices=["actor", "prop", "vfx", "floor"], default="actor")
    p.add_argument("--floor", type=Path, default=DEFAULT_FLOOR)
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args(argv)

    image = Image.open(args.image)
    cols, rows = (int(v) for v in args.grid.lower().split("x"))
    frames, cell_size = cells(image, cols, rows, args.directions)
    per_direction = len(frames[0])
    names = args.direction_names.split(",") if args.direction_names else [f"dir{i}" for i in range(len(frames))]
    if len(names) != len(frames):
        raise SystemExit(f"{len(names)} direction names for {len(frames)} directions")
    groups = parse_groups(args.groups, per_direction)

    scale = args.display_scale
    if scale is None:
        tallest = max((frame_stats(f, 1.0, np.zeros((cell_size[1], cell_size[0], 3)))
                       .get("bbox", [0, 0, 0, 1])[3] for d in frames for f in d), default=1)
        scale = (args.display_height / tallest) if args.display_height else 1.0
    else:
        scale *= args.camera_zoom
    floor_img = Image.open(args.floor).convert("RGB")
    floor_rgb = np.asarray(floor_img)

    failures, warnings = [], []
    has_alpha = image.mode in ("RGBA", "LA") or (image.mode == "P" and "transparency" in image.info)
    if not has_alpha:
        failures.append("no alpha channel: background is not transparent")
    elif np.asarray(image.convert("RGBA"))[..., 3].min() > 8:
        failures.append("alpha channel present but nothing is transparent")

    if failures:
        # Without transparency every frame metric is meaningless; stop here and send it back to generation.
        args.out.mkdir(parents=True, exist_ok=True)
        (args.out / "report.json").write_text(json.dumps({"image": str(args.image), "hard_failures": failures,
            "warnings": [], "verdict": "FAIL"}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"FAIL: {failures[0]} -> {args.out}")
        return 1

    report = {"image": str(args.image), "size": list(image.size), "grid": [cols, rows], "cell": list(cell_size),
              "display_scale": round(scale, 4), "camera_zoom": args.camera_zoom, "kind": args.kind, "directions": {}, "thresholds_note":
              "provisional 2026-10-04; colour metrics use a floor composite without lighting/shadows, so compare them "
              "with a baseline measured by this tool, not with the absolute VISUAL_STYLE_GUIDE 3.5 numbers"}
    for d, direction in enumerate(frames):
        stats = [frame_stats(f, scale, floor_rgb) for f in direction]
        entry = {"frames": stats, "groups": {}}
        for i, s in enumerate(stats):
            tag = f"{names[d]} frame {i}"
            if s["empty"]:
                failures.append(f"{tag}: empty frame")
                continue
            if s["touches_edge"]:
                failures.append(f"{tag}: body touches the cell border (cropped or bleeding into the neighbour)")
            if s["magenta_ratio"] > MAGENTA_RATIO_FAIL:
                failures.append(f"{tag}: chroma-key magenta left on {s['magenta_ratio']:.1%} of visible pixels")
        for g in groups:
            gs = [stats[i] for i in g["frames"] if not stats[i]["empty"]]
            if not gs:
                continue
            ginfo = {}
            if args.ground is not None:
                drift = [round((s["feet_y"] - args.ground) * scale, 2) for s in gs]
                ginfo["feet_offset_display_px"] = drift
                if g["name"] not in ("death",) and max(abs(v) for v in drift) > GROUND_DRIFT_FAIL:
                    failures.append(f"{names[d]} {g['name']}: feet leave the ground line by up to {max(abs(v) for v in drift)} display px")
            heights = [s["bbox"][3] for s in gs]
            ginfo["height_variation"] = round((max(heights) - min(heights)) / max(heights), 3)
            if len(gs) > 1 and ginfo["height_variation"] > SIZE_DRIFT_WARN and g["loop"]:
                warnings.append(f"{names[d]} {g['name']}: body height varies {ginfo['height_variation']:.0%} inside a loop (scale drift?)")
            steps = []
            for a, b in zip(g["frames"], g["frames"][1:]):
                steps.append(frame_difference(direction[a], direction[b], scale))
            if steps:
                ginfo["step_luma_diff"] = [s[0] for s in steps]
                ginfo["step_silhouette_iou"] = [s[1] for s in steps]
                for (a, b), (diff, _) in zip(zip(g["frames"], g["frames"][1:]), steps):
                    if diff < STATIC_DIFF_WARN:
                        warnings.append(f"{names[d]} {g['name']}: frames {a}->{b} are almost identical (diff {diff})")
            if g["loop"] and len(g["frames"]) > 1:
                seam = frame_difference(direction[g["frames"][-1]], direction[g["frames"][0]], scale)
                ginfo["loop_seam"] = {"luma_diff": seam[0], "silhouette_iou": seam[1]}
                avg = sum(ginfo["step_luma_diff"]) / len(ginfo["step_luma_diff"])
                if seam[0] > avg * LOOP_SEAM_WARN and seam[0] > 2.0:
                    warnings.append(f"{names[d]} {g['name']}: loop seam jump {seam[0]} vs average step {avg:.2f}")
            entry["groups"][g["name"]] = ginfo
        report["directions"][names[d]] = entry

    measured = [s for d in report["directions"].values() for s in d["frames"] if "luma_mean" in s]
    if measured:
        summary = {k: round(float(np.median([s[k] for s in measured])), 1)
                   for k in ("luma_mean", "luma_std", "saturation_mean", "detail", "edge_contrast")}
        summary["display_height_px_max"] = max(s["display_size"][1] for s in measured)
        report["summary_median"] = summary
        if args.baseline:
            base = json.loads(args.baseline.read_text(encoding="utf-8")).get("summary_median", {})
            report["baseline"] = {"report": str(args.baseline), "summary_median": base}
            for key in ("luma_mean", "luma_std", "edge_contrast"):
                if key in base and summary[key] < base[key] * BASELINE_RATIO_WARN:
                    warnings.append(f"{key} {summary[key]} is below 80% of the baseline {base[key]} (darker / weaker outline than the reference)")

    report["hard_failures"] = failures
    report["warnings"] = warnings
    report["verdict"] = "FAIL" if failures else ("WARN" if warnings else "PASS")
    args.out.mkdir(parents=True, exist_ok=True)
    contact_sheet(frames, names, groups, scale, floor_img, args.ground, 1).save(args.out / "contact_display.png")
    contact_sheet(frames, names, groups, scale, floor_img, args.ground, 3).save(args.out / "contact_zoom3.png")
    (args.out / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{report['verdict']}: {len(failures)} hard failure(s), {len(warnings)} warning(s) -> {args.out}")
    for line in failures:
        print("  FAIL  " + line)
    for line in warnings[:20]:
        print("  WARN  " + line)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
