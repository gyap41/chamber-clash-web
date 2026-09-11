"""Local-only OpenAI Image API utility. Python 3.10+, no dependencies."""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "generated"
TEST_PROMPT = (
    "Create one test game asset sprite for Chamber Clash, a 2D arena combat game. "
    "A single closed sci-fi loot chest, dark steel with gold trim and a cyan latch. "
    "Three-quarter top-down view, crisp pixel-art style, chunky readable silhouette, "
    "centered with generous padding. Flat solid white background, no ground shadow, "
    "no scene, no text, no watermark, no sprite sheet."
)


def load_key():
    # Read only the required entry; never evaluate .env as shell code.
    key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not key and (ROOT / ".env").exists():
        for line in (ROOT / ".env").read_text(encoding="utf-8-sig").splitlines():
            match = re.match(r"^\s*(?:export\s+)?OPENAI_API_KEY\s*=\s*(.*)$", line)
            if match:
                value = match.group(1).strip()
                if value.startswith(("'", '"')):
                    end = value.find(value[0], 1)
                    if end < 0:
                        raise ValueError("Invalid quoted OPENAI_API_KEY in .env.")
                    key = value[1:end]
                else:
                    key = re.split(r"\s+#", value, maxsplit=1)[0].strip()
                break
    if not key or any(c.isspace() for c in key):
        raise ValueError("Set a valid OPENAI_API_KEY in the project .env or environment.")
    return key


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None  # Never forward credentials to a redirect destination.


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prompt", default=TEST_PROMPT)
    parser.add_argument("--name", default="test-loot-chest", help="New filename stem (no extension)")
    parser.add_argument("--model", default="gpt-image-2")
    parser.add_argument("--quality", choices=["low", "medium", "high", "auto"], default="low")
    parser.add_argument("--check", action="store_true", help="Validate locally without an API call")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}", args.name):
        raise ValueError("Use 1-80 letters, numbers, underscores or hyphens for --name.")
    if not args.prompt.strip():
        raise ValueError("Prompt must not be empty.")
    key = load_key()
    # Avoid accidentally writing the credential via user-supplied metadata.
    if key in args.prompt or key in args.model or key in args.name:
        raise ValueError("Do not include credentials in generation arguments.")
    target = OUTPUT / (args.name + ".png")
    metadata = target.with_suffix(".json")
    if target.exists() or metadata.exists():
        raise ValueError("Output already exists. Choose a new --name.")
    if args.check:
        print("Local configuration OK. No API call made; key not displayed.")
        return 0
    payload = dict(model=args.model, prompt=args.prompt, n=1, size="1024x1024",
                   quality=args.quality, output_format="png")
    request = urllib.request.Request(
        "https://api.openai.com/v1/images/generations",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
        method="POST",
    )
    print("Generating one image via OpenAI Image API...", flush=True)
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=300) as response:
            result = json.load(response)
    except urllib.error.HTTPError as error:
        # API error bodies can contain credential fragments; never print them.
        hints = {401: "Check the API key.", 403: "Check model access / organization verification.",
                 429: "Check API quota, billing and rate limits.", 400: "Check model and request parameters."}
        print(f"OpenAI HTTP {error.code}. " + hints.get(error.code, "Request failed."), file=sys.stderr)
        return 1
    except (urllib.error.URLError, TimeoutError):
        print("Network error or timeout. No automatic retry; check before retrying to avoid duplicate charges.", file=sys.stderr)
        return 2
    raw = base64.b64decode(result["data"][0]["b64_json"], validate=True)
    if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("API response was not a PNG.")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with target.open("xb") as stream:
        stream.write(raw)
    with metadata.open("x", encoding="utf-8") as stream:
        json.dump(payload, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print("Saved: " + str(target))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ValueError:
        print("Validation failed. Check configuration, arguments and output filename; existing files are not overwritten.", file=sys.stderr)
        sys.exit(1)
    except Exception:
        # Suppress exception bodies/tracebacks to keep credentials out of logs.
        print("Generation failed. Check local files or API response format. Details suppressed for credential safety.", file=sys.stderr)
        sys.exit(1)
