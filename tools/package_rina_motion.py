"""Package actual Godot captures into review GIFs; no generated artwork edits."""
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/art/reviews/rina-dodge-2026-09-12'
RAW=ROOT/'docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12'
frames=[Image.open(RAW/f'motion-{i:02d}.png').convert('RGB') for i in range(64)]
frames[0].save(OUT/'motion.gif',save_all=True,append_images=frames[1:],duration=25,loop=0)
# Dodge-only crop: 24 poses over .38 seconds, with eight rest frames.
# Exclude the walking row because it was sampled at a different rate.
# GIF centisecond delays approximate .38 seconds with 16 alternating delays.
frames=[im.crop((0,450,im.width,im.height)) for im in frames]
frames[0].save(OUT/'motion-realtime.gif',save_all=True,append_images=frames[1:],
    duration=([20,10]*10+[20]*4+[20]*8)*2,loop=0)
print('Saved slow review and approximately real-time motion GIFs.')
