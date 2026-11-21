#!/usr/bin/env bash
# run-evals.sh [extra `claude plugin eval` flags] — run the skill's behaviour evals
# (evals/<case>/) against a stand-in `multica` (evals/stub/multica): no server is touched.
# The eval sandbox cannot read the home directory, where both a local checkout and the
# CI workspace live, so the stub is copied to a temp dir outside it and put first on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."
stub=$(mktemp -d /tmp/multica-eval-stub.XXXXXX); trap 'rm -rf "$stub"' EXIT
install -m 755 evals/stub/multica "$stub/multica"
PATH="$stub:$PATH" claude plugin eval . --trust-plugin --no-publish --ablation none \
  --allow-tools "Bash(multica *)" Write Read --model sonnet "$@"
