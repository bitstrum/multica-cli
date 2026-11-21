#!/usr/bin/env bash
# resolve-cli-version.sh min|server|latest — print the multica CLI tag to lint against.
#   min     the floor the docs declare (MIN_CLI_VERSION in lint-skill-commands.py)
#   server  the release a Multica server runs: its /health commit, matched to a release
#           tag. The URL comes from MULTICA_SERVER_URL (a repository secret, so the
#           server's address stays out of this public repo). Unset -> latest.
#   latest  upstream's newest release
set -euo pipefail
api() { curl -fsSL ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} "https://api.github.com/repos/multica-ai/multica/$1"; }
case "${1:?min|server|latest}" in
  min) echo "v$(python3 -c 'import re,pathlib; print(re.search(r"MIN_CLI_VERSION = \"([^\"]+)\"", pathlib.Path("scripts/lint-skill-commands.py").read_text()).group(1))')" ;;
  latest) api releases/latest | jq -r .tag_name ;;
  server)
    if [ -z "${MULTICA_SERVER_URL:-}" ]; then echo "MULTICA_SERVER_URL unset; using latest" >&2; exec "$0" latest; fi
    commit=$(curl -fsS -m 20 "${MULTICA_SERVER_URL%/}/health" | jq -r .commit)
    tag=$(api 'tags?per_page=100' | jq -r --arg c "$commit" 'first(.[] | select(.commit.sha == $c) | .name) // empty')
    [ -n "$tag" ] || { echo "server commit $commit is not a multica-ai/multica release tag" >&2; exit 1; }
    echo "$tag" ;;
  *) echo "usage: $0 min|server|latest" >&2; exit 2 ;;
esac
