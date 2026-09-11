"""ElevenLabs Sound Effects v2 API, verified 2026-09-11."""
import json

NAME = "elevenlabs"
KEY = "ELEVENLABS_API_KEY"
ENDPOINT = "https://api.elevenlabs.io/v1/sound-generation"
EXTENSION = "mp3"


def parameters(args):
    duration = 0.5 if args.duration is None else args.duration
    if not 0.5 <= duration <= 30:
        raise ValueError("SE duration must be 0.5..30 seconds.")
    if args.seed is not None:
        raise ValueError("SE API does not expose a seed parameter.")
    influence = 0.3 if args.prompt_influence is None else args.prompt_influence
    if not 0 <= influence <= 1:
        raise ValueError("Prompt influence must be 0..1.")
    return {"model_id": "eleven_text_to_sound_v2", "duration_seconds": duration,
            "prompt_influence": influence, "loop": args.loop, "output_format": "mp3_44100_128"}


def request(prompt, params, loop, key):
    body = {k: v for k, v in params.items() if k != "output_format"}
    body["text"] = prompt
    return (ENDPOINT + "?output_format=" + params["output_format"],
            {"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"},
            json.dumps(body).encode("utf-8"))
