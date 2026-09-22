"""Rebuild the Markdown catalog, or check catalog freshness and local inline links.

No network access. Code fences, external URLs and heading fragments are not checked.
Reference-style links and bare paths are outside this check.
"""
from pathlib import Path
import argparse
import os
import re
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'docs/CATALOG.md'
EXCLUDED = {'.git', '.godot', '.local', 'node_modules', '.venv', 'venv', '__pycache__', 'web-build', 'export_templates'}
GROUPS = ['入口・運用', '現行仕様', '計画・提案', '実装・検証手順', '美術・音響の共通基準', '制作・採用・設定の記録', '一時メモ', '素材・ツールの説明', '過去の計画・履歴', '旧Web・テスト資料', '未分類（要整理）']
HISTORICAL_PLANS = {'ASSET_PRODUCTION_PLAN.md', 'AUDIO_ASSET_INVENTORY_2026-09-13.md', 'PURCHASE_ECONOMY_PROPOSAL.md'}

def files():
    result = []
    for base, dirs, names in os.walk(ROOT):
        dirs[:] = sorted(d for d in dirs if d not in EXCLUDED)
        result.extend(Path(base) / name for name in names if name.lower().endswith('.md'))
    return sorted(result, key=lambda p: p.relative_to(ROOT).as_posix())


def category(path):
    name = path.relative_to(ROOT).as_posix()
    if name in {'AGENTS.md', 'README.md', 'docs/README.md', 'docs/DOCUMENTATION_GUIDE.md', 'docs/CATALOG.md'} or name in {'docs/design/README.md', 'docs/planning/README.md', 'docs/development/README.md', 'docs/art/README.md', 'docs/archive/README.md'}:
        return GROUPS[0]
    if name.startswith('docs/archive/') or (name.startswith('docs/planning/') and (path.name in HISTORICAL_PLANS or '/se16-' in name or '/se34-' in name)):
        return GROUPS[8]
    if name.startswith('docs/design/'): return GROUPS[1]
    if name.startswith('docs/planning/'): return GROUPS[2]
    if name.startswith('docs/development/'): return GROUPS[3]
    if name.startswith(('docs/art/production/', 'docs/art/reviews/', 'docs/art/settings/')): return GROUPS[5]
    if name.startswith('docs/art/') or name == 'docs/AUDIO_BIBLE.md': return GROUPS[4]
    if name.startswith('docs/notes/'): return GROUPS[6]
    if name.startswith(('assets/', 'tools/')): return GROUPS[7]
    if name.startswith(('legacy-web/', 'tests/')): return GROUPS[9]
    return GROUPS[10]


def read(path):
    return path.read_text(encoding='utf-8-sig')


def render(paths):
    lines = ['# 全Markdown索引', '', '[総合索引](README.md) / [更新先の判断](DOCUMENTATION_GUIDE.md)', '',
             '自動生成: `python tools/docs_index.py`。表題は本文の最初の見出しから取得。分類は役割の案内で、内容の検証完了や採用を示しません。過去計画は元のパスを維持して履歴に分類しています。', '',
             f'対象 {len(paths)} 件。キャッシュ・依存パッケージ・配布生成物は除外。依頼ごとの正本は総合索引と各分野のREADMEを参照してください。', '']
    for group in GROUPS:
        members = [p for p in paths if category(p) == group]
        if not members: continue
        lines += [f'## {group}', '', '|ファイル|表題・内容の手掛かり|', '|---|---|']
        for path in members:
            title = re.search(r'^#{1,6}\s+(.+)$', read(path), re.M)
            title = title.group(1).strip().replace('|', '／') if title else '見出しなし（本文参照）'
            rel = os.path.relpath(path, OUTPUT.parent).replace('\\', '/')
            label = path.relative_to(ROOT).as_posix()
            lines.append(f'|[{label}](<{rel}>)|{title}|')
        lines.append('')
    return '\n'.join(lines)


def check_links(paths):
    missing = []
    count = 0
    for path in paths:
        content = re.sub(r'(?ms)^\s*(`{3,}|~{3,})[^\n]*\n.*?^\s*\1\s*$', '', read(path))
        for match in re.finditer(r'\[[^\]]*\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+"[^"]*")?\s*\)', content):
            ref = match.group(1).strip('<>')
            if re.match(r'^[a-zA-Z][\w+.-]*:|^//', ref): continue
            target = unquote(ref.split('#', 1)[0])
            if not target: continue
            count += 1
            if not (path.parent / target).exists():
                missing.append(f'{path.relative_to(ROOT).as_posix()}: {ref}')
    return count, missing


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    paths = files()
    if OUTPUT not in paths: paths = sorted(paths + [OUTPUT], key=lambda p: p.relative_to(ROOT).as_posix())
    # The catalog has a fixed title; allow first-time creation before scanning headings.
    if not OUTPUT.exists():
        if args.check:
            print('Catalog missing; run python tools/docs_index.py')
            return 1
        OUTPUT.write_text('# 全Markdown索引\n', encoding='utf-8')
    expected = render(paths)
    if not args.check:
        OUTPUT.write_text(expected, encoding='utf-8', newline='\n')
        print(f'Catalog updated: {len(paths)} Markdown files')
    elif read(OUTPUT) != expected:
        print('Catalog stale; run python tools/docs_index.py')
        return 1
    count, missing = check_links(paths)
    print(f'Checked {len(paths)} Markdown files, {count} local inline file links; missing: {len(missing)}')
    for item in missing: print(item)
    return int(bool(missing))


if __name__ == '__main__':
    raise SystemExit(main())
