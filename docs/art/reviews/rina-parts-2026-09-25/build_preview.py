"""Package the original atlas and existing Rina sprite into an offline HTML preview.
No image transformations or network requests; cropping and rigging use Canvas in HTML.
"""
import base64
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
text = (HERE / 'preview.template.html').read_text(encoding='utf-8')
for key, path in [('ATLAS', HERE / 'atlas.png'), ('OLD', ROOT / 'assets/first-workshop/rina-directions/front.png')]:
    text = text.replace('__' + key + '__', 'data:image/png;base64,' + base64.b64encode(path.read_bytes()).decode())
(HERE / 'preview.html').write_text(text, encoding='utf-8')
print('Built offline preview.html')
