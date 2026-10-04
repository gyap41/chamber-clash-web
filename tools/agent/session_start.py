"""SessionStart: print a short status block (stdout is added to Claude's context).

git branch/status, the newest run_tests log summary and this month's image budget, so a new session
does not spend several tool calls rediscovering them. Read-only; never touches the network or keys.
"""
import json
from pathlib import Path
import subprocess
import sys

from common import ROOT, emit_utf8


def git(*args):
    try:
        return subprocess.run(["git", *args], cwd=str(ROOT), capture_output=True, timeout=15).stdout.decode("utf-8", "replace").rstrip()
    except Exception:
        return ""


def last_test_summary():
    logs = sorted((ROOT / ".local/logs").glob("run_tests-*.log"))
    if not logs:
        return "no run_tests log yet"
    text = logs[-1].read_text(encoding="utf-8-sig", errors="replace").splitlines()
    picked = [l.strip() for l in text if (l.startswith("PASS ") and "/ FAIL" in l) or l.startswith(("FAILED:", "NO-PASS (", "ALL TESTS"))]
    return f"{logs[-1].name}: " + (" | ".join(picked[-3:]) or "summary not found (run interrupted?)")


def image_budget():
    try:
        sys.path.insert(0, str(ROOT / "tools"))
        from image_budget import budget_status, describe, load_config
        ledger = ROOT / "assets/generated/first-workshop-usage.json"
        history = json.loads(ledger.read_text(encoding="utf-8")) if ledger.exists() else []
        return describe(budget_status(history, load_config()))
    except Exception as exc:  # budget display is informational only
        return f"unavailable ({type(exc).__name__})"


def main():
    status = git("status", "--short")
    lines = status.splitlines()
    shown = "\n".join(lines[:25]) + (f"\n... {len(lines) - 25} more" if len(lines) > 25 else "")
    candidates = sorted(p.parent.relative_to(ROOT / "assets/candidates").as_posix()
                        for p in (ROOT / "assets/candidates").glob("*/*/preview.json"))
    out = [
        "## Project status (SessionStart hook)",
        f"branch: {git('rev-parse', '--abbrev-ref', 'HEAD')} / last commit: {git('log', '-1', '--format=%h %s')}",
        "git status --short:" + ("\n" + shown if shown else " clean"),
        "latest tests: " + last_test_summary(),
        "image budget: " + image_budget(),
        "candidates awaiting user review: " + (", ".join(candidates) if candidates else "none"),
    ]
    emit_utf8("\n".join(out) + "\n", sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
