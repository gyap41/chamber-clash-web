"""Register new audio providers here; keep transport and persistence shared."""
from . import stable_audio, elevenlabs

PROVIDERS = {"bgm": stable_audio, "se": elevenlabs}
