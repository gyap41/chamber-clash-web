"""PreToolUse guard (Claude Code and Codex).

1. Secrets: block any tool call that would show API keys to the agent (.env files, *_API_KEY variables,
   environment dumps). The generator CLIs read .env themselves and never print values, so they stay allowed.
2. Paid generation (Claude only): tools/generate_image.py without --check/--plan, and
   tools/asset_generator/asset.py se/bgm without --dry-run, always ask the user (allow rules cannot express
   "only --check"). Codex hooks cannot answer "ask"; there the network-disabled sandbox forces an approval
   and .codex/rules/project.rules marks these commands "prompt".
Claude's settings.json deny rules also cover Read/Edit of .env; this hook is the backstop for shells and
the only path guard for Codex.
"""
import json
import re
import sys

from common import IS_CLAUDE, edited_paths, emit_utf8, read_input

SHELL_TOOLS = ("Bash", "PowerShell", "shell", "local_shell", "exec_command")
SECRET_PATTERNS = [
    r"(^|[\s'\"=/\\<>|;&(])\.env(\.[\w-]+)?($|[\s'\"/\\|;&)<>])",   # .env, .env.local as a path/argument
    r"\b[A-Z][A-Z0-9_]*_API_KEY\b",
    r"\b(OPENAI|ELEVENLABS|STABILITY)_[A-Z_]*(KEY|TOKEN|SECRET)\b",
    r"(^|[;&|]\s*)(printenv|env|set|export\s+-p)\s*($|[;&|])",        # bare environment dumps
    r"\b(Get-ChildItem|gci|dir|ls|Get-Item)\s+env:",                   # PowerShell env: drive listing
    r"\$env:[A-Za-z_]*(KEY|TOKEN|SECRET)",
    r"os\.environ(\b|\[|\.get)|process\.env\b|getenv\(",
    r"\[Environment\]::GetEnvironmentVariables?",
]
ENV_PATH = re.compile(r"(^|[\\/])\.env(\.[\w-]+)?$")
PAID_IMAGE = re.compile(r"generate_image\.py\b")
PAID_IMAGE_FREE = re.compile(r"--check\b|--plan\b|--help\b|-h\b")
PAID_AUDIO = re.compile(r"asset_generator[\\/]asset\.py\s+(se|bgm)\b")
PAID_AUDIO_FREE = re.compile(r"--dry-run\b|--help\b|-h\b")


def decide(decision, reason):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": decision,
                                             "permissionDecisionReason": reason}}, ensure_ascii=False))
    return 0


def block(message):
    emit_utf8("Blocked: " + message + "\n", sys.stderr)
    return 2


def main():
    data = read_input()
    tool = data.get("tool_name", "")
    ti = data.get("tool_input") or {}
    if tool in SHELL_TOOLS:
        command = ti.get("command", "") if isinstance(ti, dict) else str(ti)
        if isinstance(command, list):  # Codex may pass argv
            command = " ".join(map(str, command))
        for pattern in SECRET_PATTERNS:
            if re.search(pattern, command):
                return block("this command could reveal API keys (.env / *_API_KEY / environment dump). "
                             "Keys must stay out of the agent's context. Use `asset.py check-keys` or "
                             "`generate_image.py --check` to confirm configuration instead.")
        if not IS_CLAUDE:
            return 0
        if PAID_IMAGE.search(command) and not PAID_IMAGE_FREE.search(command):
            return decide("ask", "Paid image generation (OpenAI). Confirm the count and budget first.")
        if PAID_AUDIO.search(command) and not PAID_AUDIO_FREE.search(command):
            return decide("ask", "Paid audio generation (ElevenLabs/Stability). Confirm after the dry-run.")
        return 0
    paths = edited_paths(data)
    if isinstance(ti, dict):
        paths += [str(ti.get(k, "")) for k in ("path", "pattern", "glob")]
    if any(ENV_PATH.search(p.strip()) for p in paths if p):
        return block(".env files hold API keys and must not be read or edited by an agent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
