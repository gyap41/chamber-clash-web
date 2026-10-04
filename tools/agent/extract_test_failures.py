"""Summarise a run_tests.ps1 log without reading the whole file into Claude's context.

Usage: python tools/agent/extract_test_failures.py [path/to/run_tests-*.log]
       (default: newest .local/logs/run_tests-*.log)

Prints the totals line, every FAIL / NO-PASS test, the first error lines of each FAIL block, and groups
FAILs that share the same first error location (one broken script usually fails many tests that preload it).
"""
from collections import defaultdict
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
ERROR = re.compile(r"SCRIPT ERROR|Parse Error|Assertion failed|^ERROR:|FAIL:")
LEAK = re.compile(r"^ERROR: \d+ resources still in use at exit")
# run_tests.ps1 captures stderr with 2>&1, so PowerShell wraps Godot's lines as NativeCommandError records:
# "<exe> : SCRIPT ERROR: ..." (wrapped at the console width) followed by "At ...run_tests.ps1", "+ ..." noise.
EXE_PREFIX = re.compile(r"^\S+\.exe : ")
PS_NOISE = re.compile(r"^(At \S*run_tests\.ps1|\s*\+ |\s*~+\s*$|\s*$)")
LOCATION = re.compile(r"\((res://[^)]+:\d+)\)|(res://[\w/.-]+\.gd:\d+)")


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if len(sys.argv) > 1:
        log = Path(sys.argv[1])
    else:
        logs = sorted((ROOT / ".local/logs").glob("run_tests-*.log"))
        if not logs:
            print("No run_tests log found under .local/logs.")
            return 1
        log = logs[-1]
    lines = log.read_text(encoding="utf-8-sig", errors="replace").splitlines()
    blocks, current = defaultdict(list), None
    results = {}
    in_summary = False
    for line in lines:
        m = re.match(r"^=== (.+) ===$", line)
        if m:
            current = m.group(1)
            continue
        if line.startswith("----- summary -----"):
            in_summary, current = True, None
            continue
        if in_summary:
            row = line.split()
            if len(row) >= 2 and row[1] in ("PASS", "FAIL", "NO-PASS"):
                results[row[0]] = row[1]
            continue
        if current:
            blocks[current].append(line)
    totals = next((l for l in reversed(lines) if l.startswith("PASS ") and "/ FAIL" in l), "totals line missing (run interrupted?)")
    print(f"log: {log}")
    print(totals)
    fails = [t for t, r in results.items() if r == "FAIL"]
    nopass = [t for t, r in results.items() if r == "NO-PASS"]
    if not results:
        print("No summary table: the run did not finish. Tests with a block in the log: " + ", ".join(blocks))
    print("NO-PASS (not failures): " + (", ".join(nopass) or "none"))
    print("FAIL: " + (", ".join(fails) or "none"))
    by_location = defaultdict(list)
    for test in fails:
        raw = blocks.get(test, [])
        body = []
        for line in raw:
            if PS_NOISE.match(line):
                continue
            if EXE_PREFIX.match(line):
                body.append(EXE_PREFIX.sub("", line))  # keep the trailing space PowerShell leaves at a wrap
            elif (body and body[-1].startswith(("SCRIPT ERROR", "ERROR:")) and not line.startswith((" ", "\t"))
                    and not ERROR.search(line) and not line.startswith(("PASS", "Godot Engine"))):
                body[-1] = (body[-1] + line).rstrip()  # console-width wrap of the previous error line
            else:
                body.append(line.rstrip())
        hits = []
        for i, line in enumerate(body):
            if ERROR.search(line) and not LEAK.match(line):
                hits.append(line)
                for nxt in body[i + 1:i + 3]:
                    if nxt.lstrip().startswith("at:"):
                        hits.append(nxt)
                        break
        first_loc = None
        for h in hits:
            m = LOCATION.search(h)
            if m:
                first_loc = m.group(1) or m.group(2)
                break
        by_location[first_loc or "(no res:// location)"].append(test)
        print(f"\n=== {test} === ({len(raw)} lines in log block)")
        for h in hits[:14]:
            print("  " + h)
        if not hits:
            print("  (no error line matched; last lines:)")
            for l in body[-6:]:
                print("  " + l)
    if fails:
        print("\nFAILs grouped by first error location (fix the top of each group first):")
        for loc, tests in sorted(by_location.items(), key=lambda kv: -len(kv[1])):
            print(f"  {loc}: {len(tests)} test(s) - {', '.join(tests)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
