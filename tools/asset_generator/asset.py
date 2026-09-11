"""One command generates exactly one asset. API credentials never enter metadata."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import re
import sys
import wave

from config import ROOT, AUDIO, STATE, KEY_NAMES, load_keys, reject_secrets
from providers import PROVIDERS
from transport import generate, GenerationError


def now():
    return datetime.now(timezone.utc).isoformat()


def atomic_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2, allow_nan=False)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)


@contextmanager
def exclusive(path):
    try:
        handle = path.open("x", encoding="utf-8")
    except FileExistsError:
        raise ValueError("Generator is locked. See README recovery steps; no API call made.") from None
    try:
        with handle:
            handle.write(str(os.getpid()))
        yield
    finally:
        path.unlink()


def inspect_audio(data, extension):
    if extension == "wav":
        try:
            with wave.open(io.BytesIO(data), "rb") as stream:
                duration = stream.getnframes() / stream.getframerate()
                expected = stream.getnframes() * stream.getnchannels() * stream.getsampwidth()
                if duration <= 0 or len(stream.readframes(stream.getnframes())) != expected:
                    raise ValueError("Incomplete WAV response.")
                return duration
        except (wave.Error, EOFError):
            raise ValueError("Unsupported or invalid WAV response; raw result retained locally.") from None
    from mutagen.mp3 import MP3
    try:
        stream = MP3(io.BytesIO(data))
        if stream.info.length <= 0:
            raise ValueError()
        return stream.info.length
    except Exception:
        raise ValueError("Invalid MP3 response; raw result retained locally.") from None


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    sub = result.add_subparsers(dest="type", required=True)
    sub.add_parser("check-keys", help="Existence check only; no network")
    for kind in PROVIDERS:
        command = sub.add_parser(kind)
        command.add_argument("--prompt", required=True)
        command.add_argument("--name", required=True, help="Unique lowercase asset name")
        command.add_argument("--purpose", default="")
        command.add_argument("--duration", type=float)
        command.add_argument("--loop", action="store_true", help="Loop intent; requires listening/import review")
        command.add_argument("--seed", type=int)
        command.add_argument("--prompt-influence", type=float)
        command.add_argument("--timeout", type=float, default=180, help="Socket timeout and download deadline, seconds")
        command.add_argument("--dry-run", action="store_true")
        command.add_argument("--allow-repeat", action="store_true", help="Explicitly permit previously attempted conditions; new name required")
    return result


def run(argv=None):
    keys = load_keys()
    # Check raw arguments before argparse could echo them in errors.
    argv = sys.argv[1:] if argv is None else argv
    reject_secrets(" ".join(argv), keys)
    args = parser().parse_args(argv)
    if args.type == "check-keys":
        for name in KEY_NAMES:
            print(name + (": configured" if keys[name] else ": missing"))
        return 0
    if not re.fullmatch(r"[a-z][a-z0-9_-]{0,63}", args.name) or args.name in {"con", "prn", "aux", "nul", *[f"com{i}" for i in range(10)], *[f"lpt{i}" for i in range(10)]}:
        raise ValueError("Name must be 1..64 lowercase letters/digits/_/-; no Windows reserved names.")
    if not args.prompt.strip() or len(args.prompt) > 10000:
        raise ValueError("Prompt must contain 1..10000 characters.")
    if not 5 <= args.timeout <= 600:
        raise ValueError("Timeout must be 5..600 seconds.")
    if not (ROOT / "docs/AUDIO_BIBLE.md").is_file():
        raise ValueError("Read/create docs/AUDIO_BIBLE.md before generation.")
    provider = PROVIDERS[args.type]
    params = provider.parameters(args)
    target = AUDIO / args.type / (args.name + "." + provider.EXTENSION)
    plan = {"asset_id": args.type + ":" + args.name, "type": args.type, "provider": provider.NAME,
            "file_path": "res://" + target.relative_to(ROOT).as_posix(), "purpose": args.purpose,
            "prompt": args.prompt, "loop": args.loop, "generation_parameters": params}
    fingerprint = hashlib.sha256(json.dumps({"type": args.type, "prompt": args.prompt,
        "parameters": params, "loop": args.loop}, sort_keys=True).encode()).hexdigest()
    if args.dry_run:
        print(json.dumps({**plan, "endpoint": provider.ENDPOINT, "api_calls": 0,
                          "candidates": 1, "retries": 0, "timeout_seconds": args.timeout,
                          "allow_repeat": args.allow_repeat, "output_exists": target.exists()}, ensure_ascii=False, indent=2))
        return 0
    if not keys[provider.KEY]:
        raise ValueError(provider.KEY + ": missing. No API call made.")
    # Validate dependencies before any paid request (including BGM).
    try:
        import mutagen.mp3  # noqa: F401
    except ImportError:
        raise ValueError("Install requirements.txt before generation. No API call made.") from None
    STATE.mkdir(parents=True, exist_ok=True)
    AUDIO.mkdir(parents=True, exist_ok=True)
    with exclusive(STATE / "generator.lock"):
        manifest_path = AUDIO / "asset_manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if manifest.get("schema_version") != 1 or not isinstance(manifest.get("assets"), list):
            raise ValueError("Invalid manifest. No API call made.")
        attempts_path = STATE / "attempts.json"
        attempts = json.loads(attempts_path.read_text(encoding="utf-8")) if attempts_path.exists() else []
        if target.exists() or any(a["asset_id"] == plan["asset_id"] for a in manifest["assets"] + attempts):
            raise ValueError("Asset name already used/reserved. No API call made.")
        if not args.allow_repeat and any(a.get("fingerprint") == fingerprint for a in attempts + manifest["assets"]):
            raise ValueError("These conditions were already attempted. Review history before --allow-repeat with a NEW name.")
        target.parent.mkdir(parents=True, exist_ok=True)
        attempt = {**plan, "fingerprint": fingerprint, "attempted_at": now(),
                   "status": "pending", "api_post_attempts": 1, "timeout_seconds": args.timeout}
        attempts.append(attempt)
        atomic_json(attempts_path, attempts)  # Persist BEFORE POST; survives timeout/process termination.
        print("Submitting one generation request; automatic retries: 0.", flush=True)
        try:
            data = generate(*provider.request(args.prompt, params, args.loop, keys[provider.KEY]), args.timeout)
            recovery = STATE / (args.type + "_" + args.name + "." + provider.EXTENSION)
            with recovery.open("xb") as handle:
                handle.write(data)  # Retain successful bytes if validation/manifest writing fails.
            duration = inspect_audio(data, provider.EXTENSION)
            with target.open("xb") as handle:
                handle.write(data)
            entry = {**plan, "duration": duration, "duration_source": "audio_header",
                     "generated_at": now(), "fingerprint": fingerprint,
                     "sha256": hashlib.sha256(data).hexdigest(), "loop_verified": False}
            manifest["assets"].append(entry)
            atomic_json(manifest_path, manifest)
            attempt["status"] = "succeeded"
            atomic_json(attempts_path, attempts)
            recovery.unlink()
            print("Saved " + plan["file_path"] + "; manifest updated.")
        except BaseException:
            attempt["status"] = "failed_or_uncertain"
            atomic_json(attempts_path, attempts)
            raise
    return 0


if __name__ == "__main__":
    try:
        sys.exit(run())
    except (ValueError, GenerationError) as exc:
        # Only our controlled ValueErrors; JSON/decoder details are not displayed.
        message = str(exc) if type(exc) in (ValueError, GenerationError) else "Invalid local data; details hidden."
        print("Error: " + message, file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("Interrupted. Review attempt history before generating again.", file=sys.stderr)
        sys.exit(130)
    except Exception:
        print("Local or transport failure (details hidden). Review recovery instructions; do not retry blindly.", file=sys.stderr)
        sys.exit(1)
