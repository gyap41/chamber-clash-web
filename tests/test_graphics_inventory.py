import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('graphics_inventory', Path(__file__).resolve().parents[1] / 'tools/graphics_inventory.py')
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)


class InventoryTests(unittest.TestCase):
    def test_dynamic_resources_and_preserved_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixtures = {
                'export_presets.cfg': 'exclude_filter="assets/generated/*"',
                'scripts/main.gd': 'const ROOT = "res://"\nconst PROP = "res://assets/props/%s.tres"\nconst ACTOR = "res://assets/actor/"\nconst UI = "res://assets/ui/skin.json"',
                'assets/props/desk.tres': 'atlas = "res://assets/props/atlas.png"',
                'assets/ui/skin.json': '{"fallback":"res://assets/ui/fallback.svg"}',
                'assets/props/atlas.png': 'image',
                'assets/actor/front.png': 'image',
                'assets/ui/fallback.svg': 'svg',
                'assets/old.png': 'old',
                'assets/generated/raw.png': 'raw',
                'assets/generated/.gdignore': '',
                '.local/cache.png': 'cache',
            }
            for name, text in fixtures.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding='utf-8')
            with patch.object(inventory, 'ROOT', root):
                data = inventory.build()
            rows = {r['path']: r for r in data['images']}
            self.assertEqual(len(rows), 5)
            self.assertEqual(rows['assets/props/atlas.png']['category'], 'runtime_reference')
            self.assertEqual(rows['assets/ui/fallback.svg']['category'], 'runtime_reference')
            self.assertEqual(rows['assets/actor/front.png']['category'], 'dynamic_candidate')
            self.assertEqual(rows['assets/old.png']['category'], 'unresolved')
            self.assertEqual(rows['assets/generated/raw.png']['category'], 'generated_original')
            self.assertTrue(rows['assets/generated/raw.png']['godot_ignored'])
            self.assertTrue(rows['assets/generated/raw.png']['web_excluded'])
            self.assertEqual(len(data['duplicate_groups']), 1)
            for name, text in fixtures.items():
                self.assertEqual((root / name).read_text(encoding='utf-8'), text)


if __name__ == '__main__':
    unittest.main()
