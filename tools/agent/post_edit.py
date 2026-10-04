"""PostToolUse after file edits (Claude: Edit/Write/MultiEdit/NotebookEdit, Codex: apply_patch).

- .gd  -> Godot --check-only on each edited file. A parse/type error exits 2 so the agent sees it and fixes it now.
- .md  -> python tools/docs_index.py --check (AGENTS.md requires it after docs changes; ~1 s).
- agent settings (tools/agent/agents.toml, the files generated from it, the safety files) -> sync_agents.check(),
  so Claude Code and Codex never drift apart whichever agent made the edit.
Anything else is ignored. A missing Godot only warns.
"""
from pathlib import Path
import subprocess
import sys

from common import ROOT, check_scripts, edited_paths, emit_utf8, read_input
import sync_agents


def relative(path):
    p = Path(path)
    try:
        return (p if p.is_absolute() else ROOT / p).resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return None


def main():
    paths = edited_paths(read_input())
    agent_files = {relative(p) for p in paths} & sync_agents.managed_paths()
    if agent_files:
        problems = sync_agents.check()
        if problems:
            emit_utf8("Agent settings out of sync after editing " + ", ".join(sorted(agent_files)) + ":\n  " +
                      "\n  ".join(problems[:15]) + "\nGenerated files are not edited by hand: change "
                      "tools/agent/agents.toml and run `python tools/agent/sync_agents.py` (safety files: "
                      "restore the missing rule).\n", sys.stderr)
            return 2
    gd = [p for p in paths if p.endswith(".gd")]
    if gd:
        godot, errors = check_scripts(gd)
        if godot is None:
            emit_utf8("gd syntax check skipped: Godot executable not found (set GODOT_PATH).\n", sys.stderr)
        elif errors:
            body = "\n".join(f"{res}:\n  " + "\n  ".join(lines[:20]) for res, lines in errors.items())
            emit_utf8("GDScript check failed (godot --check-only). Fix before continuing:\n" + body +
                      "\nReminder: a ternary assigned with := infers Variant and fails; declare the type "
                      "explicitly (var x: float = a if c else b).\n", sys.stderr)
            return 2
    # docs_index.py catalogs every Markdown file, including CLAUDE.md, .claude/ and .agents/.
    if any(p.endswith(".md") for p in paths):
        proc = subprocess.run([sys.executable, "tools/docs_index.py", "--check"], cwd=str(ROOT),
                              capture_output=True, timeout=60)
        if proc.returncode != 0:
            out = (proc.stdout + proc.stderr).decode("utf-8", "replace").strip().splitlines()[-15:]
            emit_utf8("docs index check failed. If you added/moved/deleted Markdown, run "
                      "`python tools/docs_index.py` and update the field README:\n" + "\n".join(out) + "\n", sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
