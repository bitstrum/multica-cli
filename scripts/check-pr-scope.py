#!/usr/bin/env python3
"""Scope guard for pull requests that merge themselves.

The skill-update agent's PRs auto-merge once CI is green, so CI has to stop the ways a
green lint can still be a bad merge. A PR from anyone but the repository owner may only:

  - touch the docs, the plugin manifests and two marked regions of the lint script
    (MIN_CLI_VERSION with its comment, and UNDOCUMENTED_OK) — never CI, tests or evals,
    which would let it grade itself
  - raise the floor no higher than the CLI the server runs (--server-version)
  - keep every heading of SKILL.md and its frontmatter name, so safety sections cannot
    quietly disappear
  - bump the plugin version in both manifests when the skill changes, so installed
    copies refresh
  - stay under --max-lines changed lines in SKILL.md

Usage: check-pr-scope.py --base <sha> --head <sha> --author <login> --owner <login>
                         --server-version vX.Y.Z [--max-lines N]
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys

ALLOWED = {
    "skills/multica-cli/SKILL.md",
    "skills/multica-cli/agents/openai.yaml",
    "README.md",
    "README.zh.md",
    "CURSOR.md",
    ".cursor/rules/multica-cli.mdc",
    "EXAMPLES.md",
    ".claude-plugin/plugin.json",
    ".claude-plugin/marketplace.json",
    "scripts/lint-skill-commands.py",
}
LINT = "scripts/lint-skill-commands.py"
SKILL = "skills/multica-cli/SKILL.md"
MANIFESTS = (".claude-plugin/plugin.json", ".claude-plugin/marketplace.json")


def git(*args: str) -> str:
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def show(rev: str, path: str) -> str:
    try:
        return git("show", f"{rev}:{path}")
    except subprocess.CalledProcessError:
        return ""


def ver(s: str) -> tuple[int, ...]:
    return tuple(int(x) for x in re.findall(r"\d+", s)[:3])


def lint_outside_regions(text: str) -> str:
    """The lint script with the two regions an agent may edit cut out."""
    text = re.sub(r"(?ms)^# The oldest CLI every documented command works on\..*?^MIN_CLI_VERSION = \"[^\"]+\"\n", "<MIN>\n", text)
    text = re.sub(r"(?ms)^UNDOCUMENTED_OK = \{\n.*?^\}\n", "<UNDOCUMENTED_OK>\n", text)
    return text


def plugin_versions(rev: str) -> list[str]:
    out = []
    for path in MANIFESTS:
        data = json.loads(show(rev, path) or "{}")
        out.append(data.get("version") or data.get("metadata", {}).get("version", ""))
        out.extend(p.get("version", "") for p in data.get("plugins", []))
    return out


def main() -> int:
    p = argparse.ArgumentParser()
    for flag in ("--base", "--head", "--author", "--owner", "--server-version"):
        p.add_argument(flag, required=True)
    p.add_argument("--max-lines", type=int, default=300)
    a = p.parse_args()

    if a.author == a.owner:
        print(f"PR by the owner ({a.owner}): scope guard does not apply.")
        return 0

    errors: list[str] = []
    changed = [f for f in git("diff", "--name-only", f"{a.base}...{a.head}").split() if f]
    for f in changed:
        if f not in ALLOWED:
            errors.append(f"{f}: outside what a self-merging PR may change")

    if LINT in changed and lint_outside_regions(show(a.base, LINT)) != lint_outside_regions(show(a.head, LINT)):
        errors.append(f"{LINT}: changed outside MIN_CLI_VERSION and UNDOCUMENTED_OK")

    m = re.search(r'MIN_CLI_VERSION = "([^"]+)"', show(a.head, LINT))
    if not m:
        errors.append(f"{LINT}: MIN_CLI_VERSION not found")
    elif ver(m.group(1)) > ver(a.server_version):
        errors.append(f"MIN_CLI_VERSION {m.group(1)} is above the server's CLI {a.server_version}")

    base_skill, head_skill = show(a.base, SKILL), show(a.head, SKILL)
    heading = re.compile(r"^#{1,4} .+$", re.M)
    prose = lambda t: re.sub(r"(?ms)^```.*?^```", "", t)  # `# comments` in code blocks are not headings
    for h in sorted(set(heading.findall(prose(base_skill))) - set(heading.findall(prose(head_skill)))):
        errors.append(f"{SKILL}: heading removed or renamed: {h!r}")
    name = re.compile(r"^name: .+$", re.M)
    if name.findall(base_skill)[:1] != name.findall(head_skill)[:1]:
        errors.append(f"{SKILL}: frontmatter name changed")

    if SKILL in changed:
        old, new = plugin_versions(a.base), plugin_versions(a.head)
        if len(set(new)) != 1:
            errors.append(f"plugin versions differ between manifests: {new}")
        elif ver(new[0]) <= ver(max(old, key=ver)):
            errors.append(f"plugin version not bumped ({old[0]} -> {new[0]}): installed copies would not refresh")
        n = sum(int(x) for x in re.findall(r"^(\d+)\t(\d+)", git("diff", "--numstat", f"{a.base}...{a.head}", "--", SKILL), re.M)[0]) if base_skill else 0
        if n > a.max_lines:
            errors.append(f"{SKILL}: {n} lines changed, more than {a.max_lines}; needs a human")

    if errors:
        print("Scope guard failed:\n" + "\n".join(f"  - {e}" for e in errors), file=sys.stderr)
        return 1
    print(f"Scope guard OK: {len(changed)} file(s), all within scope.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
