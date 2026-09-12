"""Read-only validation of relocated artwork and current art documentation."""
from pathlib import Path
import hashlib,json,re
from urllib.parse import unquote
ROOT=Path(__file__).resolve().parents[1]
base=ROOT/'docs/archive/2026-09-12/art-organization'
ledger=json.loads((base/'relocations.json').read_text(encoding='utf-8'))
errors=[];binary_count=0
for entry in ledger['files']:
    path=ROOT/entry['new']
    if not path.exists():errors.append('Missing relocated file: '+entry['new']);continue
    if path.suffix.lower() in ['.png','.gif','.jpg','.jpeg','.webp']:
        binary_count+=1
        if hashlib.sha256(path.read_bytes()).hexdigest()!=entry['sha256']:errors.append('Changed artwork: '+entry['new'])
for path in (ROOT/'docs/art').rglob('*.md'):
    for value in re.findall(r'\]\(([^\n)]+)\)',path.read_text(encoding='utf-8-sig')):
        value=value.strip('<>')
        if re.match(r'^[a-zA-Z]+:',value) or value.startswith('#') or '*' in value:continue
        target=(path.parent/unquote(value.split('#')[0])).resolve()
        if not target.exists():errors.append(path.relative_to(ROOT).as_posix()+': '+value)
usage=json.loads((ROOT/'assets/generated/first-workshop-usage.json').read_text(encoding='utf-8'))
print(json.dumps(dict(relocations=len(ledger['files']),unchanged_artwork=binary_count,
    generation_attempts=len(usage),errors=errors),ensure_ascii=False,indent=2))
raise SystemExit(bool(errors))
