"""Rebuild the audition mix; no API calls, preserve both original MP3s."""
from pathlib import Path
import hashlib
import json
import numpy as np
import soundfile as sf
base = Path(__file__).resolve().parent
sources = [(base.parent / "v1/fw_workshop_open_01.mp3", 0.0, -12.0), (base / "fw_workshop_energy_01.mp3", 0.35, -10.0)]
layers = []
recipe = []
rate = 44100
for path, start, gain_db in sources:
    samples, sample_rate = sf.read(path, dtype="float64", always_2d=True)
    assert sample_rate == rate and samples.shape[1] == 2
    samples *= 10 ** (gain_db / 20)
    attack, release = int(rate * .004), int(rate * .025)
    samples[:attack] *= np.linspace(0, 1, attack)[:, None]
    samples[-release:] *= np.linspace(1, 0, release)[:, None]
    layers.append((int(round(start * rate)), samples))
    recipe.append({"file": str(path.relative_to(base.parent)), "start_s": start, "gain_db": gain_db, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
mix = np.zeros((max(start + len(samples) for start, samples in layers), 2))
for start, samples in layers:
    mix[start:start + len(samples)] += samples
assert np.max(np.abs(mix)) < .9
sf.write(base / "workshop-open-energy-preview.wav", mix, rate, subtype="PCM_16")
(base / "mix-recipe.json").write_text(json.dumps({"sources": recipe, "fade_in_ms": 4, "fade_out_ms": 25, "sample_rate": rate, "duration_s": len(mix) / rate, "status": "candidate", "listening_verified": False}, indent=2), encoding="utf-8")
print("Mixed mechanical opening at 0ms + energy at 350ms; %.3fs" % (len(mix) / rate))
