"""Build a conservative, read-only graphics reference inventory (no third-party deps).

References are textual evidence, not proof of execution or user acceptance.
Directory references are deliberately retained as dynamic-load candidates.
"""
from pathlib import Path
from collections import Counter, defaultdict
import argparse
import fnmatch
import hashlib
import json
import os
import re

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'assets/graphics_inventory.json'
PAGE = ROOT / 'assets/graphics_inventory.html'
SKIP = {'.git', '.godot', '.local', '.claude', '.codex', 'node_modules', '.venv', 'venv', '__pycache__', 'web-build', 'export_templates'}
IMAGES = {'.png', '.jpg', '.jpeg', '.webp', '.svg', '.gif', '.bmp'}
TEXT = {'.gd', '.tscn', '.tres', '.json', '.py', '.html', '.js', '.ts', '.md', '.txt', '.godot', '.cfg', '.css'}
LABELS = {
    'runtime_reference': 'ゲーム側に画像参照あり',
    'dynamic_candidate': 'ゲーム側の動的読込候補',
    'development_reference': 'ツール・テスト・試作から参照',
    'generated_original': '生成原画（保管）',
    'archive': '旧素材・履歴（保管）',
    'documentation': '設定・比較・制作資料',
    'legacy_web': '旧Web版',
    'unresolved': 'ゲーム側参照未検出・要確認',
}


def scan_files():
    for base, dirs, names in os.walk(ROOT):
        dirs[:] = sorted(d for d in dirs if d not in SKIP)
        for name in sorted(names):
            yield Path(base) / name


def rel(path):
    return path.relative_to(ROOT).as_posix()


def build():
    files = list(scan_files())
    images = {p.resolve(): p for p in files if p.suffix.lower() in IMAGES}
    refs = defaultdict(set)
    dynamic = defaultdict(set)
    dependencies = defaultdict(set)
    # Only explicit path literals/Markdown destinations are used; basename matches
    # would incorrectly mark many unrelated body.png or preview.png files as used.
    pattern = re.compile(r'''["']([^"'\r\n]{1,700})["']|\]\(<?([^\s)>]+)>?\)''')
    for source in files:
        if source.suffix.lower() not in TEXT or source in (OUTPUT, PAGE, Path(__file__).resolve()):
            continue
        text = source.read_text(encoding='utf-8-sig', errors='replace')
        for match in pattern.finditer(text):
            value = (match.group(1) or match.group(2)).split('#', 1)[0]
            if not value or 'data:image' in value:
                continue
            suffix = value.rsplit('.', 1)[-1].lower()
            if '.' + suffix not in IMAGES | {'.json', '.tres'} and not (value.startswith('res://') and value.endswith('/')):
                continue
            if value.startswith('res://'):
                if re.search(r'%[-+0-9.]*[sd]|\{[^}]*\}', value):
                    glob = re.sub(r'%[-+0-9.]*[sd]|\{[^}]*\}', '*', value[6:])
                    candidates = list(ROOT.glob(glob))
                    for candidate in candidates:
                        if candidate.resolve() in images:
                            dynamic[candidate.resolve()].add(rel(source))
                    candidates = [p for p in candidates if p.suffix not in IMAGES]
                else:
                    candidates = [ROOT / value[6:]]
            elif value.startswith(('http:', 'https:', 'uid:')):
                continue
            else:
                candidates = [source.parent / value, ROOT / value]
            for candidate in candidates:
                try:
                    target = candidate.resolve()
                    if target in images:
                        refs[target].add(rel(source))
                    elif target.is_relative_to(ROOT) and target.is_file() and target.suffix in {'.json', '.tres'}:
                        dependencies[rel(source)].add(rel(target))
                    elif value.startswith('res://assets/') and value != 'res://assets/' and value.endswith('/') and target.is_dir():
                        for image in images:
                            if image.is_relative_to(target):
                                dynamic[image].add(rel(source))
                except (OSError, ValueError):
                    continue
    runtime_sources = {rel(p) for p in files if rel(p).startswith(('scripts/', 'scenes/', 'data/')) or rel(p) == 'project.godot'}
    pending = list(runtime_sources)
    while pending:
        for dependency in dependencies[pending.pop()]:
            if dependency not in runtime_sources:
                runtime_sources.add(dependency)
                pending.append(dependency)
    presets = (ROOT / 'export_presets.cfg').read_text(encoding='utf-8')
    excludes = re.search(r'^exclude_filter="(.*)"', presets, re.M).group(1).split(',')
    rows = []
    hashes = defaultdict(list)
    for path, original in sorted(images.items(), key=lambda item: rel(item[1])):
        name = rel(original)
        users = sorted(refs[path])
        runtime = [u for u in users if u in runtime_sources]
        candidates = sorted(u for u in dynamic[path] if u in runtime_sources)
        dev_dynamic = sorted(u for u in dynamic[path] if u.startswith(('tools/', 'tests/')))
        dev = [u for u in users if u.startswith(('tools/', 'tests/')) or (u.startswith('docs/') and not u.endswith('.md'))]
        if runtime:
            status = 'runtime_reference'
        elif candidates:
            status = 'dynamic_candidate'
        elif name.startswith('assets/generated/'):
            status = 'generated_original'
        elif name.startswith(('docs/archive/', 'assets/reference/')):
            status = 'archive'
        elif dev or dev_dynamic:
            status = 'development_reference'
        elif name.startswith('docs/'):
            status = 'documentation'
        elif name.startswith('legacy-web/'):
            status = 'legacy_web'
        else:
            status = 'unresolved'
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        hashes[digest].append(name)
        ignored = any((parent / '.gdignore').exists() for parent in [path.parent, *path.parents] if parent.is_relative_to(ROOT))
        rows.append(dict(path=name, category=status, bytes=path.stat().st_size, sha256=digest,
                         references=users, runtime_references=runtime, dynamic_candidates=candidates,
                         development_dynamic_candidates=dev_dynamic,
                         web_excluded=any(fnmatch.fnmatchcase(name, p) for p in excludes),
                         godot_ignored=ignored))
    duplicates = [names for names in hashes.values() if len(names) > 1]
    return dict(schema=1, method='textual references; not execution reachability; no automatic deletion',
                excluded_directories=sorted(SKIP), counts=dict(Counter(r['category'] for r in rows)),
                duplicate_groups=duplicates, images=rows)


def render(data):
    payload = json.dumps(data, ensure_ascii=False).replace('<', '\\u003c')
    labels = json.dumps(LABELS, ensure_ascii=False)
    return '''<!doctype html><html lang="ja"><meta charset="utf-8"><title>グラフィック素材の使用状況</title>
<style>body{background:#172029;color:#e8eef2;font:15px system-ui;margin:24px}h1{font-size:26px}p{max-width:1100px;line-height:1.7}input,select,button{padding:10px;margin:5px;background:#fff;color:#172029;border:0;border-radius:5px}#grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px}article{background:#263440;padding:12px;border-radius:9px;overflow-wrap:anywhere}img{width:100%;height:170px;object-fit:contain;background:repeating-conic-gradient(#abb3ba 0% 25%,#d5dce0 0% 50%) 50%/18px 18px}a{color:#87d5ff}small{display:block;margin:8px 0}summary{cursor:pointer}li{font-size:12px}</style>
<h1>グラフィック素材の使用状況</h1><p>コード・データの参照を調べた一覧です。「ゲーム側に参照あり」は実際の表示や採用を保証しません。動的読込候補はフォルダー単位の保守的な判定です。原画と実行用画像の同一内容コピーは必要な場合があります。参照未検出だけで削除しないでください。キャッシュ・.local・配布生成物は対象外です。</p>
<input id="q" placeholder="パス・参照元を検索"><select id="category"><option value="">全分類</option></select><label><input type="checkbox" id="duplicate">同一内容の重複のみ</label><label><input type="checkbox" id="excluded">Web配布除外のみ</label><p id="summary"></p><button id="prev">前へ</button><span id="page"></span><button id="next">次へ</button><div id="grid"></div>
<script>const data=PAYLOAD,labels=LABELS;let page=0;const size=60;const dup=new Set(data.duplicate_groups.flat());
const $=id=>document.getElementById(id);for(const [key,label] of Object.entries(labels)){const o=document.createElement('option');o.value=key;o.textContent=label+' ('+(data.counts[key]||0)+')';$('category').append(o)}
function el(tag,text){const e=document.createElement(tag);e.textContent=text;return e}
function fileUrl(p){return '../'+p.split('/').map(encodeURIComponent).join('/')}
function draw(){const q=$('q').value.toLowerCase();const rows=data.images.filter(r=>(!$('category').value||r.category===$('category').value)&&(!q||(r.path+' '+r.references.join(' ')).toLowerCase().includes(q))&&(!$('duplicate').checked||dup.has(r.path))&&(!$('excluded').checked||r.web_excluded));page=Math.max(0,Math.min(page,Math.ceil(rows.length/size)-1));$('summary').textContent=rows.length+' 件 / '+(rows.reduce((n,r)=>n+r.bytes,0)/1048576).toFixed(1)+' MiB（全 '+data.images.length+' 件）';$('page').textContent=(page+1)+' / '+Math.max(1,Math.ceil(rows.length/size));$('grid').replaceChildren();for(const r of rows.slice(page*size,(page+1)*size)){const card=el('article','');const a=el('a','');a.href=fileUrl(r.path);a.target='_blank';const img=document.createElement('img');img.loading='lazy';img.src=a.href;img.alt=r.path;a.append(img);card.append(a,el('small',labels[r.category]),el('strong',r.path),el('small',(r.bytes/1024).toFixed(1)+' KiB'+(r.web_excluded?' / Web除外':'')+(r.godot_ignored?' / Godot対象外':'')+(dup.has(r.path)?' / 同一内容コピーあり':'')));const details=el('details','');details.append(el('summary','参照元・動的読込候補'));const list=el('ul','');for(const ref of [...r.references,...r.dynamic_candidates.map(x=>'動的候補: '+x),...r.development_dynamic_candidates.map(x=>'開発用動的候補: '+x)])list.append(el('li',ref));details.append(list);card.append(details);$('grid').append(card)}}
for(const id of ['q','category','duplicate','excluded'])$(id).addEventListener('input',()=>{page=0;draw()});$('prev').onclick=()=>{page--;draw()};$('next').onclick=()=>{page++;draw()};draw();</script></html>'''.replace('PAYLOAD', payload).replace('LABELS', labels)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify generated inventory is current')
    args = parser.parse_args()
    data = build()
    outputs = {OUTPUT: json.dumps(data, ensure_ascii=False, indent=2) + '\n', PAGE: render(data)}
    for path, content in outputs.items():
        if args.check:
            if not path.exists() or path.read_text(encoding='utf-8') != content:
                raise SystemExit(f'Stale inventory: {rel(path)}')
        else:
            path.write_text(content, encoding='utf-8', newline='\n')
    print(json.dumps(dict(images=len(data['images']), counts=data['counts'], duplicate_groups=len(data['duplicate_groups'])), ensure_ascii=False))


if __name__ == '__main__':
    main()
