# Multica CLI Skill

> Built for [Multica](https://github.com/multica-ai/multica) — an open-source platform for running and managing coding agents with reusable skills.

A portable skill that teaches any local coding agent — Claude Code, Codex, Cursor,
and others — how to operate [Multica](https://github.com/multica-ai/multica)
through the authenticated `multica` CLI: read and triage issues, reply to
comments safely, manage metadata, and handle mention/status side effects.

English | [简体中文](./README.zh.md)

## What it does not do

This repository does **not** grant Multica access by itself. Permissions come
only from the user's local CLI login, selected profile, active workspace, and
explicit approval for any commands the agent runs. The skill teaches *how* to
drive Multica safely; it never bypasses workspace permissions or stores secrets.

## What it covers

- Checking CLI auth, profile, and workspace state (and how to log in)
- Reading issues, comments, metadata, labels, custom properties, subscribers,
  projects, agents, squads, runtimes, repos, skills, autopilots, and attachments
- Searching issues across titles, descriptions, and comment bodies
- Reading comment history cheaply — thread scans, `--compact`, and resolved-thread folding
- Writing safe issue comments with `--content-file`, including the
  working-directory restriction on file arguments
- Creating or updating issues and high-signal metadata
- Handling mention, status, assignment, rerun, and sub-issue side effects, and
  suppressing unwanted agent runs with `--no-start`
- Inspecting run history and token usage; cancelling a run when asked
- Linking pull requests back to Multica issues
- Saying so plainly when the CLI cannot do something, instead of faking it

## Install

The skill lives at `skills/multica-cli/`. Pick the path for your tool.

### Claude Code (plugin marketplace)

```text
/plugin marketplace add bitstrum/multica-cli
/plugin install multica-cli@multica-cli
```

The skill follows each Multica release, so let Claude Code pull updates: in
`/plugin` → Marketplaces, enable auto-update for `multica-cli`, or declare it in
`~/.claude/settings.json`:

```json
"extraKnownMarketplaces": {
  "multica-cli": {
    "source": { "source": "github", "repo": "bitstrum/multica-cli" },
    "autoUpdate": true
  }
}
```

### Codex (skill installer)

```bash
install-skill-from-github.py --repo bitstrum/multica-cli --path skills/multica-cli
```

Restart Codex after installing new skills.

### Cursor

Copy the skill into your personal Cursor skills directory:

```bash
mkdir -p ~/.cursor/skills/multica-cli
cp -R skills/multica-cli/* ~/.cursor/skills/multica-cli/
```

Or drop the project rule [`.cursor/rules/multica-cli.mdc`](.cursor/rules/multica-cli.mdc)
into a project's `.cursor/rules/` directory. See [CURSOR.md](./CURSOR.md) for details.

### Any other agent

Copy [`skills/multica-cli/SKILL.md`](skills/multica-cli/SKILL.md) into wherever
your tool loads skills or instructions from.

## Requirements

- The `multica` CLI is installed locally, and both it and the Multica server are
  at **v0.6.0 or newer**. The skill always describes the newest release, and marks
  everything added after v0.6.0 with the release that introduced it, such as
  `(v0.10.0+)`. The agent checks the CLI (`multica version`) and the server (its
  public `/api/config`; Multica Cloud always runs the latest), then uses only what
  the older of the two supports and tells you what an upgrade would unlock.
- The user has run `multica login` (or `multica setup`) to authenticate.
- The intended workspace/profile is selected, or passed explicitly with
  `--workspace-id` and `--profile`.

## Usage

Ask your agent to work with Multica once the skill is installed, for example:

```text
Read MUL-123 with the multica CLI and draft a reply for me to review.
```

For write operations (comments, status changes, mentions, new issues), the agent
should ask before making state changes unless you have already clearly
authorized that exact action. See [EXAMPLES.md](./EXAMPLES.md) for more.

## Contributing

This skill is only useful while it matches the CLI it describes, so the docs are
linted against real `multica` binaries:

```bash
scripts/lint-skill-commands.py              # against the multica on PATH; --verbose shows every check
scripts/lint-skill-commands.py --versions   # the floor and every release a marker names
```

It fails when a documented command or flag is missing from the release its marker
(or the floor) names, and when the newest CLI has a command `SKILL.md` never
mentions. Document new surface with a marker, `(vX.Y.Z+)` in prose or
`# vX.Y.Z+` in a code block, rather than raising the floor; deliberate omissions
go in `UNDOCUMENTED_OK` in that script, with a reason.

CI runs the lint against the floor, every marked release and the latest release
on every push and pull request. A daily run checks the latest release; when a new
release adds or changes commands, it opens or updates one `cli-drift` issue
instead of failing.

Pull requests from an agent merge themselves once the lint is green, so a PR from
anyone but the repository owner also has to pass `scripts/check-pr-scope.py`: docs,
manifests and the `UNDOCUMENTED_OK` region of the lint script only (never CI,
tests, evals or the floor); no marker above the latest release; no SKILL.md
heading removed; plugin version bumped.

Two checks need Claude, so they run on the contributor's own login and never in
CI (this public repository holds no secrets):

- `scripts/check-claims.sh <base> <head>`: an LLM check that every behaviour claim
  a change adds is backed by the CLI's `--help`.
- `scripts/run-evals.sh`: behaviour evals in `evals/` (`claude plugin eval`
  against a stub `multica`, so no server is touched), such as "reading the inbox
  changes nothing" and "a delete never passes `--yes` unasked". On Linux the eval
  sandbox needs `bubblewrap` and `socat`.

## License

[MIT](./LICENSE)
