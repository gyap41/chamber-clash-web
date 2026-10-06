"""Rebuild local gate timing/gain derivatives; never calls a provider."""
from pathlib import Path
import hashlib
import json
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parent
close, rate = sf.read(ROOT / "fw_gate_close_01.mp3", always_2d=True)
opening, open_rate = sf.read(ROOT / "fw_gate_open_01.mp3", always_2d=True)
assert rate == open_rate == 44100
peak = int(np.argmax(np.max(np.abs(close), axis=1)))
offset = round(.35 * rate) - peak
assert offset > 0
mixed = np.zeros((offset + len(close), 2))
slide = opening[:offset].copy()
fade = min(882, offset // 2)
slide[:fade] *= np.linspace(0, 1, fade)[:, None]
slide[-fade:] *= np.linspace(1, 0, fade)[:, None]
mixed[:offset] += slide * 10 ** (-3 / 20)
mixed[offset:] += close
mixed[-441:] *= np.linspace(1, 0, 441)[:, None]
outputs = {
    "fw_gate_close_aligned_01.wav": mixed,
    "gate-close-preview.wav": mixed * 10 ** (-20 / 20),
    "gate-open-preview.wav": opening * 10 ** (-19 / 20),
}
recipe = json.loads((ROOT / "recipe.json").read_text(encoding="utf-8"))
for entry in recipe["sources"]:
    assert hashlib.sha256((ROOT / entry["path"]).read_bytes()).hexdigest() == entry["sha256"]
for name, data in outputs.items():
    sf.write(ROOT / name, data, rate, subtype="PCM_16")
    expected = next(x["sha256"] for x in recipe["outputs"] if x["path"] == name)
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == expected
print("PASS: gate PCM derivatives reproduce recorded hashes; no API calls")
