#!/usr/bin/env bash
# resolve-cli-version.sh min|latest — print a multica CLI tag to lint or evaluate against.
#   min     the floor the docs declare (MIN_CLI_VERSION in lint-skill-commands.py)
#   latest  upstream's newest release; the skill always describes it
set -euo pipefail
case "${1:?min|latest}" in
  min) echo "v$(python3 -c 'import re,pathlib; print(re.search(r"MIN_CLI_VERSION = \"([^\"]+)\"", pathlib.Path("scripts/lint-skill-commands.py").read_text()).group(1))')" ;;
  latest) curl -fsSL ${GH_TOKEN:+-H "Authorization: Bearer $GH_TOKEN"} https://api.github.com/repos/multica-ai/multica/releases/latest | jq -r .tag_name ;;
  *) echo "usage: $0 min|latest" >&2; exit 2 ;;
esac
