"""Stable Audio 2.5 synchronous API, verified 2026-09-11."""
from uuid import uuid4

NAME = "stability"
KEY = "STABILITY_API_KEY"
ENDPOINT = "https://api.stability.ai/v2beta/audio/stable-audio-2/text-to-audio"
EXTENSION = "wav"


def parameters(args):
    duration = 20.0 if args.duration is None else args.duration
    if not 1 <= duration <= 190:
        raise ValueError("BGM duration must be 1..190 seconds.")
    if args.prompt_influence is not None:
        raise ValueError("--prompt-influence is only supported for SE.")
    if args.seed is not None and not 0 <= args.seed <= 4294967294:
        raise ValueError("Seed must be 0..4294967294.")
    result = {"model": "stable-audio-2.5", "duration": duration,
              "output_format": "wav", "steps": 8}
    if args.seed is not None:
        result["seed"] = args.seed
    return result


def request(prompt, params, loop, key):
    # Stable Audio has no loop flag. Loop intent belongs in the prompt/manifest.
    boundary = "ChamberAudio" + uuid4().hex
    chunks = []
    for name, value in {"prompt": prompt, **params}.items():
        chunks.append((f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"'
                       f'\r\n\r\n{value}\r\n').encode("utf-8"))
    chunks.append(f"--{boundary}--\r\n".encode())
    return ENDPOINT, {"Authorization": "Bearer " + key, "Accept": "audio/*",
                      "Content-Type": "multipart/form-data; boundary=" + boundary}, b"".join(chunks)
