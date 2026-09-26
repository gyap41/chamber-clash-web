"""キャラクターの8方向リグを設定ファイルから書き出す。

使い方（リポジトリのルートで）：
  python tools/character_rig/build.py rina
Pillow / numpy / scipy が必要（この環境では .local/video-deps に導入済み。PYTHONPATH に追加して実行）。
設定ファイルは tools/character_rig/characters/<name>.json。書き方は tools/character_rig/README.md。
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_builder

if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise SystemExit('usage: python tools/character_rig/build.py <character name>')
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'characters', sys.argv[1] + '.json')
    cfg = json.load(open(path, encoding='utf-8'))
    rig = rig_builder.build(cfg)
    print('ok', cfg['name'], list(rig['views']), {a: len(v) for a, v in rig['views']['side']['actions'].items()})
