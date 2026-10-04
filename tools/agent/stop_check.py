"""Stop: syntax-check every .gd that differs from HEAD (modified or untracked), and confirm the Claude Code /
Codex agent settings still match tools/agent/agents.toml (sync_agents.check()).

Catches scripts edited through Bash/sed/PowerShell, which the PostToolUse Edit hook never sees.
Blocks once (exit 2) with the errors. Claude sends stop_hook_active on the retry; Codex does not, so an
identical error set is reported only once per session (common.already_reported). A broken file can
therefore never trap the session in a loop.
"""
import subprocess
import sys

from common import ROOT, already_reported, check_scripts, emit_utf8, read_input
import sync_agents

MAX_FILES = 60


def changed_gd():
    out = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all"], cwd=str(ROOT),
                         capture_output=True, timeout=30).stdout.decode("utf-8", "replace")
    paths = []
    for line in out.splitlines():
        if len(line) < 4 or line[:2].strip() == "D":
            continue
        path = line[3:].split(" -> ")[-1].strip().strip('"')
        if path.endswith(".gd") and not path.startswith((".local/", ".claude/")):
            paths.append(path)
    return paths


def main():
    data = read_input()
    if data.get("stop_hook_active"):
        return 0
    sections = []
    paths = changed_gd()
    if paths:
        godot, errors = check_scripts(paths[:MAX_FILES])
        if godot is not None and errors:
            body = "\n".join(f"{res}:\n  " + "\n  ".join(lines[:12]) for res, lines in errors.items())
            sections.append(f"{len(errors)} changed .gd file(s) fail godot --check-only:\n" + body)
    problems = sync_agents.check()
    if problems:
        sections.append("Agent settings (Claude Code / Codex) out of sync or missing a safety rule. Edit "
                        "tools/agent/agents.toml and run `python tools/agent/sync_agents.py`:\n  " + "\n  ".join(problems[:15]))
    if not sections:
        return 0
    report = "\n\n".join(sections)
    if already_reported(data.get("session_id"), report):
        return 0
    emit_utf8("Fix these, or report them to the user as unresolved, before finishing:\n" + report + "\n", sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
