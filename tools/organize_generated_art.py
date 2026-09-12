"""One-time, reversible art organization. Default is a read-only plan; no deletion/API."""
from pathlib import Path
import argparse, hashlib, json, os, re
from urllib.parse import unquote

ROOT=Path(__file__).resolve().parents[1]
ARCHIVE='docs/archive/2026-09-12/art-organization'
UNUSED=ARCHIVE+'/unused-candidates'
DIRECTORIES={
    'docs/design/character-settings-2026-09-12':'docs/art/settings/character-settings-2026-09-12',
    'docs/design/character-revision-2026-09-12':'docs/art/settings/character-revision-2026-09-12',
    'docs/design/concepts':'docs/art/settings/concepts',
    'docs/design/character-prompts':'docs/art/production/character-prompts',
    'assets/first-workshop/prompts':'docs/art/production/first-workshop-prompts',
    'assets/first-workshop/characters':UNUSED+'/superseded-assets/characters',
    'assets/first-workshop/chibi':UNUSED+'/superseded-assets/chibi',
    'assets/first-workshop/twohead':'tests/fixtures/art/legacy-rina-twohead',
}
for name in ['character-directions-2026-09-12','rina-directions-2026-09-12','rina-dodge-2026-09-12']:
    DIRECTORIES['docs/design/'+name]='docs/art/reviews/'+name
LEGACY=['rina','idle','move','move-corrected','roll','pose-guide','roll-guide']
TEXT_SUFFIXES={'.md','.gd','.py','.json','.tscn','.tres','.godot','.ps1','.txt','.import'}

def safe(relative):
    p=(ROOT/relative).resolve()
    if not p.is_relative_to(ROOT) or p==ROOT: raise ValueError('Outside workspace: '+relative)
    return p

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--apply',action='store_true');args=parser.parse_args()
    if (ROOT/ARCHIVE/'relocations.json').exists(): raise SystemExit('Already organized; use saved relocation ledger.')
    exact={}
    for name in LEGACY:
        for suffix in ['.png','.png.import']:
            old='assets/first-workshop/'+name+suffix
            if safe(old).exists(): exact[old]=UNUSED+'/superseded-assets/first-workshop/'+name+suffix
    for p in (ROOT/'assets/generated').glob('*.import'):
        exact[p.relative_to(ROOT).as_posix()]=UNUSED+'/import-sidecars/'+p.name
    for base in ['docs/design/character-directions-2026-09-12','docs/design/rina-directions-2026-09-12',
                 'docs/design/rina-dodge-2026-09-12','docs/archive/2026-09-12/character-integration']:
        for p in safe(base).glob('motion-*.png'):
            if re.fullmatch(r'motion-\d+\.png',p.name):
                exact[p.relative_to(ROOT).as_posix()]=UNUSED+'/raw-frames/'+Path(base).name+'/'+p.name
    dirs={old:new for old,new in DIRECTORIES.items() if safe(old).exists()}
    def relocated(path):
        if path in exact:return exact[path]
        for old,new in dirs.items():
            if path==old or path.startswith(old+'/'):return new+path[len(old):]
        return path
    files=[]
    for parent in ['assets','docs','scripts','scenes','tests','tools','data']:
        for p in (ROOT/parent).rglob('*'):
            if p.is_file() and '__pycache__' not in p.parts: files.append(p)
    for name in ['README.md','project.godot','export_presets.cfg']:
        if (ROOT/name).exists():files.append(ROOT/name)
    records=[];updates=[]
    mappings=sorted({**dirs,**exact}.items(),key=lambda x:len(x[0]),reverse=True)
    for p in files:
        old=p.relative_to(ROOT).as_posix();new=relocated(old)
        if old!=new:
            records.append(dict(old=old,new=new,bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
        # Generation receipts/ledger are immutable historical records; the mapping
        # resolves their original paths without changing prompts or usage records.
        if old.startswith('assets/generated/') or p.suffix not in TEXT_SUFFIXES or p==Path(__file__).resolve():continue
        try: before=p.read_text(encoding='utf-8-sig')
        except UnicodeError:continue
        after=before
        if p.suffix=='.md':
            def link(match):
                value=match.group(1);angled=value.startswith('<') and value.endswith('>')
                raw=value[1:-1] if angled else value
                if re.match(r'^[a-zA-Z]+:',raw) or raw.startswith('#'):return match.group(0)
                target,sep,anchor=raw.partition('#')
                resolved=(p.parent/unquote(target)).resolve()
                if not resolved.is_relative_to(ROOT) or not resolved.exists():return match.group(0)
                final=safe(relocated(resolved.relative_to(ROOT).as_posix()))
                dest=os.path.relpath(final,safe(new).parent).replace('\\','/')+(sep+anchor if sep else '')
                return ']('+('<'+dest+'>' if angled or ' ' in dest else dest)+')'
            after=re.sub(r'\]\(([^\n)]+)\)',link,after)
        for src,dst in mappings:
            after=after.replace(src,dst)
            after=after.replace(src.replace('/','\\\\'),dst.replace('/','\\\\'))
            after=after.replace(src.replace('/','\\'),dst.replace('/','\\'))
        if after!=before:updates.append((new,after))
    # Preflight every source/destination before any directory rename. No overwrite.
    for old,new in list(exact.items())+list(dirs.items()):
        safe(old);target=safe(new)
        if target.exists():raise ValueError('Destination already exists: '+new)
    print(json.dumps(dict(files_moved=len(records),bytes=sum(r['bytes'] for r in records),
        text_updates=len(updates),directories=dirs,loose_files=len(exact)),indent=2))
    if not args.apply:return
    # All paths were resolved above; one process performs workspace-only renames.
    for old,new in exact.items():
        target=safe(new);target.parent.mkdir(parents=True,exist_ok=True);safe(old).rename(target)
    for old,new in dirs.items():
        target=safe(new);target.parent.mkdir(parents=True,exist_ok=True);safe(old).rename(target)
    for new,content in updates:safe(new).write_bytes(content.encode('utf-8'))
    ledger=safe(ARCHIVE+'/relocations.json');ledger.parent.mkdir(parents=True,exist_ok=True)
    for record in records:record['organized_sha256']=hashlib.sha256(safe(record['new']).read_bytes()).hexdigest()
    ledger.write_text(json.dumps(dict(no_deletions=True,files=records,updated_text_files=[p for p,_ in updates]),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Moved files and updated references. No files deleted; original generation records untouched.')

if __name__=='__main__':main()
