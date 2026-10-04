"""Numeric checks for generated SE/BGM (no listening, no API calls, no file changes outside --out).

Turns audio into numbers and pictures an LLM reviewer can reason about: duration and active length, decoded
leading silence (start latency), attack/decay, peak/clipping/headroom, RMS and approximate integrated loudness
(BS.1770 K-weighting with gating), DC offset, number of separate hits, spectral balance (centroid, rolloff,
flatness, band energy), harmonicity, stereo correlation and loop seam. Optional reference files (adopted
sounds of the same category) are measured the same way and compared. Taste is out of scope: anything that
needs ears stays "unconfirmed" for the user.

Example:
  .local/audio-venv/Scripts/python.exe tools/asset_check/check_audio.py assets/candidates/lizard_spit/v1/fw_lizard_spit_04.mp3
      --category attack --reference assets/audio/se/fw_lizard_spit_03.mp3 --reference assets/audio/se/fw_sentry_swing_01.mp3
      --out assets/candidates/lizard_spit/v1/check
"""
import argparse
import json
from pathlib import Path
import sys

import numpy as np
import soundfile as sf
from PIL import Image, ImageDraw, ImageFont

# Active-length ranges per AUDIO_BIBLE "SE・環境音" (seconds the sound is audible, not the file length:
# ElevenLabs returns at least 0.5 s, so short sounds should end in a quiet tail).
CATEGORIES = {
    "shot": (0.08, 0.25), "heavy": (0.2, 0.6), "attack": (0.08, 0.6), "hit": (0.1, 0.3),
    "ui": (0.05, 0.2), "skill": (0.1, 1.5), "system": (0.1, 1.5), "defeat": (0.2, 1.2), "bgm": (1.0, 600.0),
}
SILENCE_DB = -50.0          # below this (dBFS, 5 ms RMS) counts as silence
ACTIVE_BELOW_PEAK_DB = 40.0  # active length ends when the envelope stays 40 dB under its peak
HEADROOM_WARN_DB = -0.3     # sample peak above this = no headroom (AUDIO_BIBLE asks ~3 dB at the master)
CLIP_LEVEL = 0.999
# Generated MP3s often overshoot by a few samples after decoding (25 of 100 existing SEs on 2026-10-04); the game
# plays SE well below 0 dB, so only sustained clipping is a hard failure.
CLIP_FAIL_SAMPLES = 50
LEAD_SILENCE_WARN_MS = 25.0  # decoded start latency that would be audible against a muzzle flash
HIT_GAP_MS = 60.0           # onsets closer than this are one hit (sound.gd also merges 60 ms repeats)


def db(x):
    return 20.0 * np.log10(np.maximum(np.asarray(x, dtype=float), 1e-12))


def envelope(mono, sr, window_ms=5.0):
    hop = max(1, int(sr * window_ms / 1000))
    frames = len(mono) // hop
    if frames == 0:
        return np.array([db(np.sqrt(np.mean(mono ** 2)))]), hop
    blocks = mono[:frames * hop].reshape(frames, hop)
    return db(np.sqrt(np.mean(blocks ** 2, axis=1))), hop


def k_weighted(x, sr):
    """BS.1770 K-weighting (high shelf + RLB high-pass) applied in the frequency domain."""
    n = len(x)
    spec = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(n, 1.0 / sr)
    w = 2 * np.pi * f / sr
    z = np.exp(-1j * w)

    def biquad(b, a):
        return (b[0] + b[1] * z + b[2] * z ** 2) / (a[0] + a[1] * z + a[2] * z ** 2)

    # Coefficients from ITU-R BS.1770-4 (defined for 48 kHz; re-derived for other rates via bilinear transform).
    def shelf():
        f0, g, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
        k = np.tan(np.pi * f0 / sr)
        vh = 10 ** (g / 20)
        vb = vh ** 0.4996667741545416
        a0 = 1 + k / q + k * k
        return [(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0], \
               [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]

    def highpass():
        f0, q = 38.13547087602444, 0.5003270373238773
        k = np.tan(np.pi * f0 / sr)
        a0 = 1 + k / q + k * k
        return [1, -2, 1], [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]

    h = biquad(*shelf()) * biquad(*highpass())
    return np.fft.irfft(spec * (h[:, None] if spec.ndim == 2 else h), n=n, axis=0)


def loudness_lufs(data, sr):
    y = k_weighted(data, sr)
    block, step = int(0.4 * sr), int(0.1 * sr)
    power = np.sum(y ** 2, axis=1) if y.ndim == 2 else y ** 2
    if len(power) < block:  # short SE: one ungated block over the whole file
        return round(float(-0.691 + 10 * np.log10(max(power.mean(), 1e-12))), 1)
    starts = range(0, len(power) - block + 1, step)
    z = np.array([power[s:s + block].mean() for s in starts])
    lk = -0.691 + 10 * np.log10(np.maximum(z, 1e-12))
    z = z[lk > -70]
    if not len(z):
        return -70.0
    rel = -0.691 + 10 * np.log10(z.mean()) - 10
    z = z[(-0.691 + 10 * np.log10(z)) > rel]
    return round(float(-0.691 + 10 * np.log10(z.mean())), 1)


def analyse(path, category=None, loop=False, loop_end=None):
    data, sr = sf.read(str(path), always_2d=True, dtype="float64")
    if loop_end:
        data = data[:int(loop_end * sr)]  # music.gd loops at a code-defined point, not at the file end
    mono = data.mean(axis=1)
    n = len(mono)
    duration = n / sr
    env, hop = envelope(mono, sr)
    peak_db_env = float(env.max())
    audible = np.nonzero(env > max(SILENCE_DB, peak_db_env - 60))[0]
    first = int(audible[0]) if len(audible) else 0
    peak_idx = int(np.argmax(env))
    above = np.nonzero(env > peak_db_env - ACTIVE_BELOW_PEAK_DB)[0]
    active_end = int(above[-1]) + 1 if len(above) else 0
    tail_audible = np.nonzero(env > SILENCE_DB)[0]
    last_audible = int(tail_audible[-1]) + 1 if len(tail_audible) else 0
    ms = lambda frames: round(frames * hop / sr * 1000, 1)

    # Separate hits: rises of >= 12 dB within 20 ms that start from at least 10 dB under the running peak.
    onsets, last_onset = [], -10 ** 9
    look = max(1, int(20 / (hop / sr * 1000)))
    for i in range(look, len(env)):
        if env[i] - env[i - look] >= 12 and env[i] > peak_db_env - 30 and (i - last_onset) * hop / sr * 1000 >= HIT_GAP_MS:
            onsets.append(i)
            last_onset = i
    # A sound that starts at full level in the first frame has no rise to detect; its start is still a hit.
    if len(audible) and (not onsets or (onsets[0] - first) * hop / sr * 1000 >= HIT_GAP_MS):
        onsets.insert(0, first)

    # Spectrum of the active part.
    seg = mono[first * hop:max(active_end * hop, first * hop + 256)]
    centred = seg - seg.mean()  # DC would otherwise dominate the low band and the centroid
    mag = np.abs(np.fft.rfft(centred * np.hanning(len(centred))))
    mag[0] = 0.0
    spec = mag ** 2
    freqs = np.fft.rfftfreq(len(seg), 1.0 / sr)
    total = spec.sum() + 1e-20
    # Power-weighted: a magnitude-weighted centroid is pulled up by the broadband noise floor of quiet tails.
    centroid = float((freqs * spec).sum() / total)
    rolloff = float(freqs[min(len(freqs) - 1, np.searchsorted(np.cumsum(spec), 0.85 * total))])
    flatness = float(np.exp(np.mean(np.log(spec[1:] + 1e-20))) / (spec[1:].mean() + 1e-20))
    bands = {"sub_<120": (0, 120), "low_120-500": (120, 500), "mid_500-2k": (500, 2000),
             "presence_2k-6k": (2000, 6000), "air_>6k": (6000, sr / 2)}
    band_share = {k: round(float(spec[(freqs >= lo) & (freqs < hi)].sum() / total), 3) for k, (lo, hi) in bands.items()}

    # Harmonicity: normalised autocorrelation peak (60-1000 Hz) over the loudest 100 ms.
    win = min(n, int(0.1 * sr))
    centre = min(max(peak_idx * hop, win // 2), n - win // 2)
    chunk = mono[max(0, centre - win // 2):max(0, centre - win // 2) + win]
    chunk = chunk - chunk.mean()
    ac = np.correlate(chunk, chunk, "full")[len(chunk) - 1:]
    lo, hi = int(sr / 1000), min(len(ac) - 1, int(sr / 60))
    # Search only after the autocorrelation first goes negative; before that a low-pass signal simply decays
    # from lag 0 and the "peak" would sit at the search bound.
    negative = np.nonzero(ac[1:hi] < 0)[0]
    lo = max(lo, int(negative[0]) + 1) if len(negative) else hi
    harmonicity = float(max(0.0, ac[lo:hi].max() / ac[0])) if ac[0] > 0 and hi > lo else 0.0
    pitch = float(sr / (lo + int(np.argmax(ac[lo:hi])))) if harmonicity > 0.5 else None

    peak = float(np.abs(data).max())
    result = {
        "file": str(path), "sample_rate": sr, "channels": data.shape[1],
        "file_duration_s": round(duration, 3),
        "leading_silence_ms": ms(first),
        "attack_ms": ms(max(0, peak_idx - first)),
        "active_length_s": round((active_end - first) * hop / sr, 3),
        "audible_until_s": round(last_audible * hop / sr, 3),
        "trailing_silence_ms": round((n - last_audible * hop) / sr * 1000, 1),
        "peak_dbfs": round(float(db(peak)), 2),
        "clipped_samples": int((np.abs(data) >= CLIP_LEVEL).sum()),
        "rms_dbfs_active": round(float(db(np.sqrt(np.mean(seg ** 2)))), 1),
        "loudness_lufs_approx": loudness_lufs(data, sr),
        "dc_offset": round(float(mono.mean()), 5),
        "hits": len(onsets), "hit_times_ms": [ms(i) for i in onsets],
        "spectral_centroid_hz": round(centroid), "rolloff85_hz": round(rolloff),
        "spectral_flatness": round(flatness, 3), "band_energy_share": band_share,
        "harmonicity": round(harmonicity, 2), "pitch_hz": round(pitch, 1) if pitch else None,
        "stereo_correlation": round(float(np.corrcoef(data[:, 0], data[:, 1])[0, 1]), 3) if data.shape[1] == 2 and np.std(data[:, 0]) > 0 and np.std(data[:, 1]) > 0 else None,
    }
    if loop:
        k = max(1, int(0.05 * sr))
        result["loop_seam"] = {
            "sample_jump": round(float(abs(mono[-1] - mono[0])), 4),
            "level_jump_db": round(float(db(np.sqrt(np.mean(mono[-k:] ** 2))) - db(np.sqrt(np.mean(mono[:k] ** 2)))), 1),
        }
    return result, mono, sr, env, hop


def judge(r, category, loop):
    failures, warnings = [], []
    if r["clipped_samples"] > CLIP_FAIL_SAMPLES:
        failures.append(f"{r['clipped_samples']} clipped samples (sustained clipping, audible distortion likely)")
    elif r["clipped_samples"]:
        warnings.append(f"{r['clipped_samples']} clipped samples (short MP3 overshoot)")
    if r["peak_dbfs"] > HEADROOM_WARN_DB:
        warnings.append(f"peak {r['peak_dbfs']} dBFS leaves no headroom")
    if r["active_length_s"] <= 0:
        failures.append("silent file")
    if category:
        lo, hi = CATEGORIES[category]
        if not lo * 0.8 <= r["active_length_s"] <= hi * 1.25:
            warnings.append(f"active length {r['active_length_s']} s outside the {category} range {lo}-{hi} s (AUDIO_BIBLE)")
        if category != "bgm":
            if r["leading_silence_ms"] > LEAD_SILENCE_WARN_MS:
                warnings.append(f"{r['leading_silence_ms']} ms of silence before the sound starts (late against the visual)")
            if r["trailing_silence_ms"] < 5 and r["file_duration_s"] > r["active_length_s"] + 0.05:
                warnings.append("tail is cut off at the file end (no fade to silence)")
    if abs(r["dc_offset"]) > 0.01:
        warnings.append(f"DC offset {r['dc_offset']}")
    if loop and r.get("loop_seam"):
        seam = r["loop_seam"]
        if seam["sample_jump"] > 0.05 or abs(seam["level_jump_db"]) > 3:
            warnings.append(f"loop seam jump (sample {seam['sample_jump']}, level {seam['level_jump_db']} dB) - likely audible click or swell")
    return failures, warnings


def compare(r, refs):
    if not refs:
        return {}
    keys = ["loudness_lufs_approx", "active_length_s", "spectral_centroid_hz", "attack_ms", "leading_silence_ms"]
    out = {}
    for k in keys:
        vals = [x[k] for x in refs if x.get(k) is not None]
        if vals:
            med = float(np.median(vals))
            out[k] = {"candidate": r[k], "reference_median": round(med, 2), "difference": round(r[k] - med, 2)}
    return out


def draw(entries, path):
    """One row per file: dB envelope (top) and log-frequency spectrogram (bottom), same time scale."""
    width, env_h, spec_h, pad = 900, 90, 140, 18
    longest = max(len(m) / sr for _, m, sr, _, _ in entries)
    img = Image.new("RGB", (width + 60, (env_h + spec_h + pad * 2) * len(entries)), (20, 20, 24))
    d = ImageDraw.Draw(img)
    font = ImageFont.load_default()
    for row, (label, mono, sr, env, hop) in enumerate(entries):
        y0 = row * (env_h + spec_h + pad * 2)
        d.text((4, y0 + 2), label, fill=(230, 230, 230), font=font)
        y0 += pad
        px_per_s = width / longest
        # envelope, -60..0 dBFS
        for level in (-12, -24, -36, -48):
            yy = y0 + int(-level / 60 * env_h)
            d.line([(60, yy), (60 + width, yy)], fill=(45, 45, 55))
            d.text((4, yy - 6), f"{level}dB", fill=(120, 120, 130), font=font)
        pts = [(60 + i * hop / sr * px_per_s, y0 + int(min(60, max(0, -v)) / 60 * env_h)) for i, v in enumerate(env)]
        if len(pts) > 1:
            d.line(pts, fill=(255, 200, 80), width=1)
        # spectrogram
        sy = y0 + env_h + 4
        nfft = 1024
        step = max(1, int((len(mono) / sr) * sr / max(1, int((len(mono) / sr) * px_per_s))))
        cols = []
        for s in range(0, max(1, len(mono) - nfft), step):
            frame = mono[s:s + nfft]
            if len(frame) < nfft:
                frame = np.pad(frame, (0, nfft - len(frame)))
            cols.append(db(np.abs(np.fft.rfft(frame * np.hanning(nfft)))))
        if cols:
            spec = np.array(cols).T
            freqs = np.fft.rfftfreq(nfft, 1.0 / sr)
            rows = np.geomspace(40, sr / 2, spec_h)[::-1]
            idx = np.clip(np.searchsorted(freqs, rows), 0, len(freqs) - 1)
            grid = spec[idx]
            top = grid.max()
            norm = np.clip((grid - (top - 80)) / 80, 0, 1)
            rgb = np.stack([norm ** 0.6 * 255, norm ** 1.5 * 220, (1 - norm) * norm * 4 * 160], axis=-1).astype(np.uint8)
            pic = Image.fromarray(rgb, "RGB").resize((max(1, int(len(mono) / sr * px_per_s)), spec_h), Image.Resampling.NEAREST)
            img.paste(pic, (60, sy))
            for f in (100, 1000, 5000):
                yy = sy + int(np.searchsorted(-rows, -f))
                d.text((4, yy - 6), f"{f}Hz" if f < 1000 else f"{f // 1000}kHz", fill=(150, 150, 160), font=font)
        for t in np.arange(0, longest + 1e-9, 0.1 if longest <= 2 else (1 if longest <= 20 else 10)):
            xx = 60 + int(t * px_per_s)
            d.line([(xx, sy + spec_h), (xx, sy + spec_h + 3)], fill=(150, 150, 160))
            d.text((xx + 1, sy + spec_h + 2), f"{t:g}s", fill=(150, 150, 160), font=font)
    img.save(path)


def main(argv=None):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # Windows consoles default to cp932
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("audio", type=Path)
    p.add_argument("--category", choices=sorted(CATEGORIES))
    p.add_argument("--loop", action="store_true")
    p.add_argument("--loop-end", type=float, help="loop point in seconds when the game loops before the file end (music.gd LOOP_SECONDS)")
    p.add_argument("--reference", type=Path, action="append", default=[], help="adopted sound(s) of the same role")
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args(argv)

    result, mono, sr, env, hop = analyse(args.audio, args.category, args.loop or bool(args.loop_end), args.loop_end)
    entries = [("candidate: " + args.audio.name, mono, sr, env, hop)]
    refs = []
    for ref in args.reference:
        r, m, rsr, renv, rhop = analyse(ref, args.category, False)
        refs.append(r)
        entries.append(("reference: " + ref.name, m, rsr, renv, rhop))
    failures, warnings = judge(result, args.category, args.loop or bool(args.loop_end))
    comparison = compare(result, refs)
    lufs = comparison.get("loudness_lufs_approx")
    if lufs and abs(lufs["difference"]) > 6:
        warnings.append(f"{lufs['difference']:+} LU louder/quieter than the references (set volume_db or regenerate)")
    report = {"candidate": result, "category": args.category, "references": refs, "comparison": comparison,
              "hard_failures": failures, "warnings": warnings,
              "verdict": "FAIL" if failures else ("WARN" if warnings else "PASS"),
              "not_measurable": "timbre quality, fit with the visual, mix in real play, loop musicality: user listening required"}
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    draw(entries, args.out / "waveform_spectrogram.png")
    print(f"{report['verdict']}: {len(failures)} hard failure(s), {len(warnings)} warning(s) -> {args.out}")
    for line in failures:
        print("  FAIL  " + line)
    for line in warnings:
        print("  WARN  " + line)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
