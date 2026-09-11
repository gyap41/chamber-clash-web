"""Project-relative paths and read-only secret loading. No shell evaluation."""
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "assets/audio"
STATE = ROOT / ".local/asset_generator"
KEY_NAMES = ("STABILITY_API_KEY", "ELEVENLABS_API_KEY")


def load_keys(root=ROOT):
    keys = {name: os.environ.get(name, "").strip() for name in KEY_NAMES}
    env = root / ".env"
    if env.is_file():
        for line in env.read_text(encoding="utf-8-sig").splitlines():
            match = re.match(r"^\s*(?:export\s+)?(STABILITY_API_KEY|ELEVENLABS_API_KEY)\s*=\s*(.*)$", line)
            if not match or keys[match[1]]:
                continue
            value = match[2].strip()
            if value.startswith(("'", '"')):
                end = value.find(value[0], 1)
                if end < 0:
                    raise ValueError("Invalid quoted credential in .env (value hidden).")
                value = value[1:end]
            else:
                value = re.split(r"\s+#", value, maxsplit=1)[0].strip()
            keys[match[1]] = value
    if any(any(c.isspace() for c in value) for value in keys.values()):
        raise ValueError("Credential contains whitespace (value hidden).")
    return keys


def reject_secrets(value, keys):
    if any(key and key in value for key in keys.values()):
        raise ValueError("Credential found in arguments; refusing to display or save them.")
