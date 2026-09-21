"""Package actual Godot review frames; requires Pillow. No generation API calls."""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / ".local/rich-motion-frames"
OUT = ROOT / "docs/art/reviews/character-motion-2026-09-21"


def save_gif(frames, filename):
    # A shared palette prevents frame-to-frame color flicker and reduces size.
    palette = frames[0].quantize(colors=192)
    indexed = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
    indexed[0].save(
        OUT / filename,
        save_all=True,
        append_images=indexed[1:],
        duration=[60, 70, 70] * 35,
        loop=0,
        optimize=False,
    )


def main():
    paths = [RAW / f"{i:03d}.png" for i in range(0, 210, 2)]
    frames = [Image.open(p).convert("RGB") for p in paths]
    save_gif(frames, "before-after.gif")
    closeups = []
    for frame in frames:
        closeup = Image.new("RGB", (576, 274), "#26353e")
        draw = ImageDraw.Draw(closeup)
        draw.text((12, 10), "BEFORE", fill="white")
        draw.text((300, 10), "AFTER", fill="white")
        for x, y in [(0, 78), (288, 250)]:
            crop = frame.crop((0, y, 144, y + 120))
            closeup.paste(crop.resize((288, 240), Image.Resampling.LANCZOS), (x, 30))
        closeups.append(closeup)
    save_gif(closeups, "rina-before-after.gif")
    for name in ["before-after.gif", "rina-before-after.gif"]:
        print(f"{name}: {(OUT / name).stat().st_size} bytes")


if __name__ == "__main__":
    main()
