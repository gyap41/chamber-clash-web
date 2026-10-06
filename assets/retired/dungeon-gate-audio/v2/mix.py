"""Deterministic heavy iron derivatives. Local processing only, no provider calls."""
from pathlib import Path
import hashlib
import json
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parent
RATE = 44100

def read(name):
    data, rate = sf.read(ROOT / name, always_2d=True)
    assert rate == RATE and data.shape[1] == 2
    return data - np.mean(data, axis=0)

def darken(data, cutoff):
    # Padded, zero-phase low-pass: keep the iron detail, suppress the bright ringing.
    size = 2 ** int(np.ceil(np.log2(len(data) * 4)))
    freq = np.fft.rfftfreq(size, 1 / RATE)
    response = 1 / np.sqrt(1 + (freq / cutoff) ** 8)
    padded = np.pad(data, ((len(data), size - 2 * len(data)), (0, 0)))
    result = np.fft.irfft(np.fft.rfft(padded, axis=0) * response[:, None], n=size, axis=0)
    return result[len(data):2 * len(data)]

def fade(data, ms=10):
    data = data.copy()
    n = round(ms / 1000 * RATE)
    data[:n] *= np.linspace(0, 1, n)[:, None]
    data[-n:] *= np.linspace(1, 0, n)[:, None]
    return data

def normalize(data, peak_db):
    return data * 10 ** (peak_db / 20) / np.max(np.abs(data))

close_source = read('fw_gate_close_02.mp3')
open_source = read('fw_gate_open_02.mp3')
opening = fade(darken(open_source, 2400))
opening = normalize(opening, -4)
impact = darken(close_source, 1500)
impact = normalize(impact, -8)
# Existing project practice: damped low metal modes provide body without another paid generation.
t = np.arange(len(impact)) / RATE
body = sum(gain * np.sin(2 * np.pi * hz * t) * np.exp(-t / decay)
           for hz, gain, decay in [(95, .34, .075), (173, .20, .10), (271, .13, .085), (437, .07, .055)])
body *= np.minimum(t / .004, 1)
impact = fade(impact + body[:, None], 4)
peak = int(np.argmax(np.max(np.abs(impact), axis=1)))
offset = round(.35 * RATE) - peak
assert offset > 0
closing = np.zeros((offset + len(impact), 2))
closing[:offset] += fade(opening[:offset], 20) * 10 ** (-12 / 20)
closing[offset:] += impact
closing = normalize(fade(closing), -1.5)
assert abs(np.argmax(np.max(np.abs(closing), axis=1)) / RATE - .35) < 1 / RATE

outputs = {
    'fw_gate_close_heavy_02.wav': closing,
    'fw_gate_open_heavy_02.wav': opening,
    'gate-close-preview.wav': closing * 10 ** (-20 / 20),
    'gate-open-preview.wav': opening * 10 ** (-19 / 20),
}
sources = [{'path': name, 'sha256': hashlib.sha256((ROOT / name).read_bytes()).hexdigest()}
           for name in ['fw_gate_close_02.mp3', 'fw_gate_open_02.mp3']]
old = json.loads((ROOT / 'recipe.json').read_text(encoding='utf-8')) if (ROOT / 'recipe.json').exists() else None
if old:
    assert sources == old['sources'], 'Source changed'
records = []
for name, data in outputs.items():
    assert np.max(np.abs(data)) < 1
    sf.write(ROOT / name, data, RATE, subtype='PCM_16')
    records.append({'path': name, 'sha256': hashlib.sha256((ROOT / name).read_bytes()).hexdigest(), 'duration': len(data) / RATE})
if old:
    assert records == old['outputs'], 'Derived audio changed'
else:
    recipe = {
        'method': 'mix.py: DC removal; zero-phase low-pass close 1500Hz / open 2400Hz; close damped 95/173/271/437Hz body; opening prefix -12dB with 20ms fades; align close maximum to 0.35s; edge fades; normalize close -1.5dBFS / open -4dBFS.',
        'sample_rate': RATE, 'impact_offset_seconds': offset / RATE,
        'runtime_gain_db': {'gate_close': -20, 'gate_open': -19},
        'sources': sources, 'outputs': records, 'listened': False,
    }
    (ROOT / 'recipe.json').write_text(json.dumps(recipe, indent=2) + '\n', encoding='utf-8')
print('PASS: heavy gate PCM derivatives, source hashes and output hashes verified; no API calls')
