#!/usr/bin/env bash
# check-claims.sh <base> <head> — LLM review that every behaviour claim a self-merging PR
# adds to the docs is backed by the installed CLI's --help. The lint proves commands and
# flags exist; it cannot tell whether "this starts an agent run" or "this is read-only" is
# true. That prose is this skill's whole value, so an agent PR that adds such a sentence
# without support in --help fails here and waits for a human.
# Needs `claude` (CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY) and `multica` on PATH.
set -euo pipefail
base=${1:?base}; head=${2:?head}
docs=(skills README.md README.zh.md CURSOR.md .cursor EXAMPLES.md)
diff=$(git diff --unified=3 "$base...$head" -- "${docs[@]}")
[ -n "$diff" ] || { echo "no doc changes"; exit 0; }

# --help for every namespace the added lines mention and all of its subcommands, plus
# any deeper path they name. Prose often says "restore" without "multica project", so
# the judge gets the whole namespace rather than only the exact paths.
mentioned=$(printf '%s\n' "$diff" | grep '^+' | grep -oE 'multica( [a-z][a-z0-9-]*){1,3}' | sort -u || true)
resolves() { grep -qE "^  multica $1( |$)" <<< "$2"; }
subcommands() { awk '/COMMANDS$/{f=1;next} f&&/^[^ ]/{f=0} f&&match($0,/^  +[a-z][a-z0-9-]*:/){print substr($0,RSTART,RLENGTH)}' <<< "$1" | tr -d ' :'; }
declare -A done=()
add() { # add <path...>
  local args="$*" out
  [ -z "${done[$args]:-}" ] || return 0
  # shellcheck disable=SC2086
  out=$(multica $args --help 2>/dev/null < /dev/null) && resolves "$args" "$out" || return 1
  done[$args]=1; help+=$'\n\n### multica '"$args"$'\n'"$out"
}
help=""
while read -r p; do
  [ -n "$p" ] || continue
  # shellcheck disable=SC2086
  set -- ${p#multica }
  ns=$1
  if add "$ns"; then
    for sub in $(subcommands "$(multica "$ns" --help 2>/dev/null < /dev/null)"); do add "$ns" "$sub" || true; done
  fi
  [ $# -ge 3 ] && { add "$1" "$2" "$3" || true; }
done <<< "$mentioned"

schema='{"type":"object","properties":{"verdict":{"type":"string","enum":["pass","fail"]},"unsupported":{"type":"array","items":{"type":"object","properties":{"claim":{"type":"string"},"why":{"type":"string"}},"required":["claim","why"]}}},"required":["verdict","unsupported"]}'
prompt=$(cat <<EOF
You review a pull request to a skill that teaches coding agents to use the multica CLI.
Below are the documentation diff and the --help text of every command it mentions, from
the CLI version the docs target ($(multica version | head -1)).

Find every ADDED line (starting with +) that states how a command BEHAVES: whether it
starts agent runs, notifies or affects people, is read-only, is permanent or reversible,
who may run it, what it changes. For each, decide whether the --help text supports it.
Flag a claim only when --help contradicts it, or when it asserts a side effect or a
safety property that --help does not state at all. Advice to the reader ("ask the user
first", "run --dry-run first") is not a claim about the CLI: do not flag it. Unchanged
context lines are not under review.

verdict = "fail" if anything is flagged, else "pass".

=== DIFF ===
$diff

=== --help ===
$help
EOF
)
out=$(claude -p "$prompt" < /dev/null --model sonnet --tools "" --no-session-persistence --output-format json --json-schema "$schema")
result=$(printf '%s' "$out" | jq -c '.structured_output // (.result | fromjson? ) // empty')
[ -n "$result" ] || { echo "judge returned no structured output:" >&2; printf '%s\n' "$out" | head -c 2000 >&2; exit 1; }
printf '%s' "$result" | jq -r '.unsupported[] | "  - \(.claim)\n      why: \(.why)"'
[ "$(printf '%s' "$result" | jq -r .verdict)" = pass ] && echo "claims check: pass" || { echo "claims check: FAIL (unsupported claims above)" >&2; exit 1; }
