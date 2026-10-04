"""Write the Claude Code and Codex agent settings from tools/agent/agents.toml (standard library only).

  python tools/agent/sync_agents.py          write the generated files, then report safety-rule problems
  python tools/agent/sync_agents.py --check  write nothing; report drift from the manifest and safety problems

Exit code 1 when anything is out of sync or a safety rule is missing. The edit and stop hooks call check().
Generated: .claude/skills/*/SKILL.md, the frontmatter of .agents/skills/*/SKILL.md (bodies stay hand-written),
.agents/skills/*/agents/openai.yaml, .claude/agents/*.md, .codex/agents/*.toml, the "hooks" key of
.claude/settings.json and .codex/hooks.json. Safety rules (Claude permissions, .codex/config.toml,
.codex/rules/project.rules, guard.py) are hand-written and only checked against [safety].
"""
import json
from pathlib import Path
import re
import sys
import tomllib

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "tools/agent/agents.toml"
GENERATED_NOTE = "自動生成: tools/agent/sync_agents.py（台帳: tools/agent/agents.toml）。直接編集せず、台帳を直して同期する。"
CLAUDE_SETTINGS = ROOT / ".claude/settings.json"
CODEX_HOOKS = ROOT / ".codex/hooks.json"
CODEX_CONFIG = ROOT / ".codex/config.toml"
CODEX_RULES = ROOT / ".codex/rules/project.rules"
GUARD = ROOT / "tools/agent/guard.py"


def q(text):
    """A YAML/TOML-safe double-quoted string (JSON escapes are valid in both)."""
    return json.dumps(text, ensure_ascii=False)


def load():
    return tomllib.loads(MANIFEST.read_text(encoding="utf-8"))


# ------------------------------------------------------------------ generators: path -> expected text

def claude_skill(s):
    lines = ["---", f"name: {s['name']}", f"description: {q(s.get('claude_description', s['description']))}"]
    if s.get("explicit_only"):
        lines.append("disable-model-invocation: true")
    if s.get("claude_argument_hint"):
        lines.append(f"argument-hint: {q(s['claude_argument_hint'])}")
    lines += ["---", "", f"<!-- {GENERATED_NOTE} -->", ""]
    if s.get("claude_argument_hint"):
        lines += ["対象: $ARGUMENTS", ""]
    lines.append(f"手順の正本は `.agents/skills/{s['name']}/SKILL.md`（Codexと共通）。最初にそれを読み、そのとおりに進める。")
    if s.get("claude_notes"):
        lines += ["", "Claude Code固有の補足:"] + [f"- {n}" for n in s["claude_notes"]]
    return "\n".join(lines) + "\n"


def split_frontmatter(text):
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end >= 0:
            return text[4:end], text[end + 5:]
    return None, text


def codex_skill(s, current):
    front = "\n".join([f"# name/description は {GENERATED_NOTE}", f"name: {s['name']}",
                       f"description: {q(s.get('codex_description', s['description']))}"])
    _, body = split_frontmatter(current) if current else (None, "\n本文（手順）をここに書く。\n")
    return f"---\n{front}\n---\n{body}"


def openai_yaml(s):
    return (f"# {GENERATED_NOTE}\n# 有料などの理由で、プロンプトの内容から自動では起動させない（${s['name']} で明示的に呼んだときだけ）。\n"
            "policy:\n  allow_implicit_invocation: false\n")


def claude_agent(r):
    return "\n".join([
        "---", f"name: {r['claude_name']}", f"description: {q(r['description'])}", "tools: Read, Glob, Grep",
        f"model: {r['claude_model']}", "---", "", f"<!-- {GENERATED_NOTE} -->", "",
        f"最初に `{r['instructions']}` を読み、その指示に厳密に従って判定してください（Codexの `{r['codex_name']}` と共通の正本）。"
        + r.get("claude_view_note", ""), ""])


def codex_agent(r):
    instructions = "\n".join([
        f"最初に {r['instructions']} を読み、その指示に厳密に従ってください。",
        r.get("codex_view_note", ""),
        "ファイルの変更・生成はしません。結果は docs/art/ART_BIBLE.md の7節の書式で、日本語で返します。あなたの合格はユーザー採用ではありません。",
    ])
    return "\n".join([
        f"# {GENERATED_NOTE}", f"# 指示の本文: {r['instructions']}（Claude Codeの {r['claude_name']} と共通）",
        f"name = {q(r['codex_name'])}", f"description = {q(r['description'])}", f"model = {q(r['codex_model'])}",
        f"model_reasoning_effort = {q(r.get('codex_reasoning_effort', 'high'))}", 'sandbox_mode = "read-only"',
        f'developer_instructions = """\n{instructions}\n"""', ""])


def claude_command(script):
    # A missing script must not become "exit 2 = block every tool" (happened on 2026-10-04).
    return f'f="$CLAUDE_PROJECT_DIR/tools/agent/{script}"; [ -f "$f" ] || exit 0; python "$f"'


def codex_command(python, script):
    # Resolve the repo root with git so a session started in a subfolder still finds the script.
    code = ("import os,subprocess,sys,runpy;"
            "r=subprocess.run(['git','rev-parse','--show-toplevel'],capture_output=True,text=True).stdout.strip() or '.';"
            f"d=os.path.join(r,'tools','agent');f=os.path.join(d,'{script}');"
            "os.path.isfile(f) or sys.exit(0);sys.path.insert(0,d);sys.argv=[f];runpy.run_path(f,run_name='__main__')")
    return f'{python} -c "{code}"'


def claude_hooks(m):
    out = {}
    for h in m["hooks"]:
        hook = {"type": "command", "command": claude_command(h["script"]), "timeout": h["timeout"]}
        if h.get("claude_status"):
            hook["statusMessage"] = h["claude_status"]
        group = {"matcher": h["claude_matcher"]} if h.get("claude_matcher") else {}
        group["hooks"] = [hook]
        out.setdefault(h["event"], []).append(group)
    return out


def codex_hooks(m):
    out = {}
    for h in m["hooks"]:
        hook = {"type": "command", "command": codex_command("python3", h["script"]),
                "commandWindows": codex_command("python", h["script"]), "timeout": h["timeout"]}
        if h.get("codex_status"):
            hook["statusMessage"] = h["codex_status"]
        group = {"matcher": h["codex_matcher"]} if h.get("codex_matcher") else {}
        group["hooks"] = [hook]
        out.setdefault(h["event"], []).append(group)
    return {"hooks": out}


def dump_json(value):
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def expected_files(m):
    """Files written whole (path -> text). settings.json is handled separately (only its hooks key)."""
    files = {}
    for s in m.get("skills", []):
        files[ROOT / f".claude/skills/{s['name']}/SKILL.md"] = claude_skill(s)
        canon = ROOT / f".agents/skills/{s['name']}/SKILL.md"
        files[canon] = codex_skill(s, read(canon))
        yaml_path = ROOT / f".agents/skills/{s['name']}/agents/openai.yaml"
        files[yaml_path] = openai_yaml(s) if s.get("explicit_only") else None  # None = must not exist
    for r in m.get("reviewers", []):
        files[ROOT / f".claude/agents/{r['claude_name']}.md"] = claude_agent(r)
        files[ROOT / f".codex/agents/{r['codex_name']}.toml"] = codex_agent(r)
    files[CODEX_HOOKS] = dump_json(codex_hooks(m))
    return files


def read(path):
    return path.read_bytes().decode("utf-8").replace("\r\n", "\n") if path.is_file() else None


def rel(path):
    return path.relative_to(ROOT).as_posix()


def managed_paths(m=None):
    """Every file the sync owns or checks; the edit hook re-checks when one of these changes."""
    m = m or load()
    paths = {rel(p) for p in expected_files(m)}
    paths |= {rel(p) for p in (MANIFEST, CLAUDE_SETTINGS, CODEX_CONFIG, CODEX_RULES, GUARD)}
    return paths


# ------------------------------------------------------------------ drift and safety

def drift(m):
    problems = []
    for path, text in expected_files(m).items():
        current = read(path)
        if text is None and current is not None:
            problems.append(f"{rel(path)}: should not exist (skill is not explicit_only)")
        elif text is not None and current != text:
            problems.append(f"{rel(path)}: differs from the manifest" if current is not None else f"{rel(path)}: missing")
    settings = json.loads(read(CLAUDE_SETTINGS) or "{}")
    if settings.get("hooks") != claude_hooks(m):
        problems.append(f"{rel(CLAUDE_SETTINGS)}: \"hooks\" differs from the manifest")
    for s in m.get("skills", []):
        body = split_frontmatter(read(ROOT / f".agents/skills/{s['name']}/SKILL.md") or "")[1]
        if "本文（手順）をここに書く" in body:
            problems.append(f".agents/skills/{s['name']}/SKILL.md: body not written yet")
    for r in m.get("reviewers", []):
        if not (ROOT / r["instructions"]).is_file():
            problems.append(f"{r['instructions']}: reviewer instructions missing")
    return problems


def safety(m):
    rules, problems = m.get("safety", {}), []
    settings = json.loads(read(CLAUDE_SETTINGS) or "{}")
    deny = settings.get("permissions", {}).get("deny", [])
    for rule in rules.get("claude_deny", []):
        if rule not in deny:
            problems.append(f"safety: {rel(CLAUDE_SETTINGS)} permissions.deny lacks {rule}")
    try:
        config = tomllib.loads(read(CODEX_CONFIG) or "")
    except tomllib.TOMLDecodeError as exc:
        config = {}
        problems.append(f"safety: {rel(CODEX_CONFIG)} is not valid TOML ({exc})")
    if "codex_network_access" in rules and \
            config.get("sandbox_workspace_write", {}).get("network_access") != rules["codex_network_access"]:
        problems.append(f"safety: {rel(CODEX_CONFIG)} sandbox_workspace_write.network_access must be "
                        f"{str(rules['codex_network_access']).lower()}")
    exclude = config.get("shell_environment_policy", {}).get("exclude", [])
    for pattern in rules.get("codex_env_exclude", []):
        if pattern not in exclude:
            problems.append(f"safety: {rel(CODEX_CONFIG)} shell_environment_policy.exclude lacks {pattern}")
    blocks = re.findall(r"prefix_rule\((.*?)\n\)", read(CODEX_RULES) or "", re.S)
    for need in rules.get("codex_rules", []):
        if not any(need["contains"] in b and re.search(r'decision\s*=\s*"%s"' % need["decision"], b) for b in blocks):
            problems.append(f"safety: {rel(CODEX_RULES)} has no prefix_rule containing {need['contains']!r} "
                            f"with decision \"{need['decision']}\"")
    guard = read(GUARD) or ""
    for text in rules.get("guard_contains", []):
        if text not in guard:
            problems.append(f"safety: {rel(GUARD)} no longer contains {text!r}")
    codex = json.loads(read(CODEX_HOOKS) or "{}").get("hooks", {})
    for label, hooks in (("Claude", settings.get("hooks", {})), ("Codex", codex)):
        if not any("guard.py" in h.get("command", "") for g in hooks.get("PreToolUse", []) for h in g.get("hooks", [])):
            problems.append(f"safety: guard.py is not registered as a {label} PreToolUse hook")
    return problems


def check():
    m = load()
    return drift(m) + safety(m)


def write():
    m = load()
    changed = []
    for path, text in expected_files(m).items():
        if text is None:
            if path.is_file():
                path.unlink()
                changed.append(f"removed {rel(path)}")
        elif read(path) != text:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(text.encode("utf-8"))
            changed.append(f"wrote {rel(path)}")
    settings = json.loads(read(CLAUDE_SETTINGS) or "{}")
    hooks = claude_hooks(m)
    if settings.get("hooks") != hooks:
        settings["hooks"] = hooks
        CLAUDE_SETTINGS.write_bytes(dump_json(settings).encode("utf-8"))
        changed.append(f"updated hooks in {rel(CLAUDE_SETTINGS)}")
    return changed, safety(m)


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if "--check" in sys.argv[1:]:
        problems = check()
        for p in problems:
            print("NG  " + p)
        print("agent settings in sync, safety rules present" if not problems else
              f"{len(problems)} problem(s). Fix tools/agent/agents.toml (or the hand-written safety files), "
              "then run: python tools/agent/sync_agents.py")
        return 1 if problems else 0
    changed, problems = write()
    for c in changed:
        print(c)
    for p in problems:
        print("NG  " + p)
    print(f"{len(changed)} file(s) updated; " + ("safety rules present" if not problems else f"{len(problems)} safety problem(s)"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
