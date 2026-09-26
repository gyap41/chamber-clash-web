"""Package the generated chroma-key atlas into the offline Canvas rig preview."""
import base64
from pathlib import Path
p=Path(__file__).resolve().parent
s=(p/'run-review.template.html').read_text(encoding='utf-8')
s=s.replace('__ATLAS__','data:image/png;base64,'+base64.b64encode((p/'run-parts-key.png').read_bytes()).decode())
(p/'run-review.html').write_text(s,encoding='utf-8')
