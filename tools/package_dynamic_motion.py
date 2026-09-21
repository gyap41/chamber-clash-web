"""Package normal-size Godot frames using Pillow, without resizing."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / ".local/dynamic-motion-frames"
OUT = ROOT / "docs/art/reviews/dynamic-motion-2026-09-21"
frames = [Image.open(RAW / f"{i:03d}.png").convert("RGB") for i in range(0, 150, 2)]
palette = frames[0].quantize(colors=192)
frames = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
frames[0].save(OUT / "battle.gif", save_all=True, append_images=frames[1:],
               duration=[60, 70, 70] * 25, loop=0, optimize=False)
print("Saved normal-size battle.gif (1120 x 800)")
