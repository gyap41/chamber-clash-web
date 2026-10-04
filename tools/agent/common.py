"""Shared helpers for the agent hooks used by both Claude Code (.claude/settings.json) and Codex
(.codex/hooks.json). Standard library only. See tools/agent/README.md."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR") or Path(__file__).resolve().parents[2]).resolve()
# Claude Code exports CLAUDE_PROJECT_DIR to its hooks; Codex does not.
IS_CLAUDE = "CLAUDE_PROJECT_DIR" in os.environ
PATCH_FILE = re.compile(r"^\*\*\* (?:Add|Update|Delete) File: (.+?)\s*$|^\*\*\* Move to: (.+?)\s*$", re.M)
# Godot prints these when a script fails to parse/compile; everything else is engine noise.
ERROR_MARKERS = ("SCRIPT ERROR", "Parse Error", "ERROR:", "   at: ")


def read_input():
    try:
        return json.loads(sys.stdin.buffer.read().decode("utf-8") or "{}")
    except ValueError:
        return {}


def find_godot():
    """Same priority as run_tests.ps1, preferring the _console build whose output can be captured."""
    candidates = [os.environ.get("GODOT_PATH", ""),
                  str(ROOT / ".local/tools/Godot_v4.7.2-stable_win64.exe"),
                  str(ROOT.parent / "Godot_v4.7.2-stable_win64.exe")]
    for c in candidates:
        if c and Path(c).is_file():
            console = Path(c[:-4] + "_console.exe") if c.endswith(".exe") else None
            return str(console) if console and console.is_file() else c
    return None


def res_path(path):
    p = Path(path)
    if not p.is_absolute():
        p = ROOT / p
    try:
        return "res://" + p.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return None


def check_script(godot, path):
    """Return (res_path, error_lines). Uses --check-only with --quit-after and a hard timeout."""
    res = res_path(path)
    if res is None or not Path(path if Path(path).is_absolute() else ROOT / path).is_file():
        return res or str(path), []
    try:
        proc = subprocess.run([godot, "--headless", "--path", str(ROOT), "--check-only", "--script", res,
                               "--quit-after", "60"], capture_output=True, timeout=60, cwd=str(ROOT))
    except subprocess.TimeoutExpired:
        return res, ["timeout: Godot did not finish the syntax check within 60 s"]
    text = (proc.stdout + proc.stderr).decode("utf-8", "replace")
    lines = [line.rstrip() for line in text.splitlines() if line.startswith(ERROR_MARKERS)]
    if proc.returncode != 0 and not lines:
        lines = [f"Godot exited with {proc.returncode}"] + text.splitlines()[-5:]
    return res, lines


def check_scripts(paths):
    godot = find_godot()
    if not godot:
        return None, {}
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda p: check_script(godot, p), paths))
    return godot, {res: lines for res, lines in results if lines}


def edited_paths(data):
    """Files touched by an edit tool: Claude's file_path/notebook_path, or the file headers of a
    Codex apply_patch (searched in every string of tool_input, since the field name may vary)."""
    ti = data.get("tool_input") or {}
    if isinstance(ti, str):
        ti = {"input": ti}
    paths = [ti[k] for k in ("file_path", "notebook_path") if isinstance(ti.get(k), str)]
    for value in ti.values():
        if isinstance(value, str) and "*** " in value:
            for m in PATCH_FILE.finditer(value):
                paths.append((m.group(1) or m.group(2)).strip())
    return paths


def already_reported(session_id, signature):
    """Stop-hook loop guard for agents that do not send stop_hook_active (Codex): block only once
    per identical set of errors in a session."""
    state = ROOT / ".local/agent-hooks"
    state.mkdir(parents=True, exist_ok=True)
    key = hashlib.sha1(str(session_id or "no-session").encode()).hexdigest()[:16]
    marker = state / f"stop-{key}.txt"
    digest = hashlib.sha1(signature.encode("utf-8")).hexdigest()
    if marker.is_file() and marker.read_text(encoding="utf-8").strip() == digest:
        return True
    marker.write_text(digest, encoding="utf-8")
    return False


def emit_utf8(text, stream):
    stream.buffer.write(text.encode("utf-8"))
    stream.flush()
