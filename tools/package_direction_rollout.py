"""Create review artifacts from actual game-renderer frames."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/art/reviews/character-directions-2026-09-12'
RAW=ROOT/'docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/character-directions-2026-09-12'
frames=[Image.open(RAW/f'motion-{i:03d}.png').convert('RGB') for i in range(128)]
# GIF supports centisecond delays: alternate 20/30ms to retain 25ms average.
frames[0].save(OUT/'motion.gif',save_all=True,append_images=frames[1:],duration=[20,30]*64,loop=0)
for n,name in enumerate(['front','back','right','left']):
    frames[n*32+10].save(OUT/f'{name}.png')
print('Packaged four-direction game-renderer comparison.')
