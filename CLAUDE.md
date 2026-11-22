# multica-cli skill: working rules

Current status and next step → README.md#status; read it before starting.

Public Claude Code plugin that teaches local agents to drive the `multica` CLI. The contract is `skills/multica-cli/SKILL.md`; `.cursor/rules/multica-cli.mdc` is a standalone copy of its core rules; README.md, README.zh.md, CURSOR.md and EXAMPLES.md are linted too.

## Rules
- The skill always describes the newest CLI release. Surface newer than the floor (`MIN_CLI_VERSION` in `scripts/lint-skill-commands.py`) gets a release marker instead of a floor raise: `(vX.Y.Z+)` in prose or a heading, `# vX.Y.Z+` in code (on a comment-only line it covers the block up to the next blank line).
- Set each marker to the first release where the line works, measured by running the lint (`--validity-only`) against historical CLI binaries with a PATH override, not guessed.
- Show marker syntax in docs as `vX.Y.Z+`: any real version written with a `+` in a linted file becomes a marker and a CI matrix entry.
- This public repo and its Actions settings hold no secrets. Claude-backed checks (`scripts/check-claims.sh`, `scripts/run-evals.sh`) run on the contributor's own Claude login, never in CI.
- A change to SKILL.md bumps the version in both `.claude-plugin/*.json`; installed copies refresh only then.
- `main` is protected (required checks `Lint OK`, `Scope guard`); work on a branch and merge through a PR.
- `bitstrum` is the owner (admin). The agents' login `maacarbo` has write only; its PRs, like anyone's but the owner's, must pass the scope guard: docs, manifests and the `UNDOCUMENTED_OK` region only, floor unchanged, no marker above the latest release.
- The only HTTP call the skill tells agents to make is the public `<server_url>/api/config` version check; an unknown server version is never treated as the latest.
- Before deleting a branch, check `gh pr list -R multica-ai/multica-cli`: fork branches can back open upstream PRs.

## Gotchas
- `scripts/install-cli.sh` installs into `~/.local/bin`, which can shadow a `multica` wrapper on a dev machine; install historical CLIs into a scratch dir and use a PATH override instead.
- Under `pipefail`, `cmd | head` can fail with exit 141 (SIGPIPE); use `sed -n 1p`.
- At a release where a parent command is a leaf, the lint reads a newer sub-subcommand as a positional argument (e.g. `issue pull-requests link` before v0.10.0), so it cannot catch a marker set too low there; check the full command path per release.
- `claude plugin eval` cannot read `$HOME` (run-evals.sh copies the stub to /tmp); the macOS sandbox blocks executing the stub; Linux needs `bubblewrap` and `socat`. Every eval case must grant `Bash(curl *)` for the version check.
- Branch protection requires the aggregate `Lint OK`, because the matrix job names change whenever the set of markers changes.
- The scheduled lint opens or updates one `cli-drift` issue instead of failing; keep it that way, or every upstream release sends a failure email.

## Verify
- `scripts/test-lint.py` and `scripts/lint-skill-commands.py --verbose` with a `multica` CLI on PATH; `scripts/lint-skill-commands.py --versions` lists what CI lints.
