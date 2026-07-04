# Compatibility Matrix

This file records the supported host surfaces for the SpecNav Claude Code plugin
suite. Do not claim fresh support for a host or channel without a recent smoke
run.

| Host | Support level | Verification command | Expected result | Reload required |
| --- | --- | --- | --- | --- |
| Claude Code plugin marketplace | supported | `bash tests/run-plugin-validate-fixtures.sh` | marketplace and six plugins validate | new session after install/update |
| Installed cache runtime | supported | `bash tests/run-installed-cache-runtime-fixtures.sh` | cross-plugin runtime resolves from installed cache | new session after install/update |
| Source checkout fixtures | supported | `for test_script in tests/run-*.sh; do bash "$test_script"; done` | all fixture suites pass | no |

## Support Levels

- `supported`: tested by current fixtures and expected to work.
- `experimental`: known path exists, but fresh smoke evidence is missing.
- `unsupported`: not expected to work; SpecNav must report exact blockers.

## Current Requirements

- OpenSpec CLI must be available for SpecNav-managed projects.
- All six plugins must be installed and enabled.
- After changing commands, skills, hooks, agents, or plugin metadata, start a new
  Claude Code session.
- Installed-cache runtime must not rely on `CLAUDE_PLUGIN_ROOT`.


## Hook adoption policy

Adopted hook events (deterministic, non-experimental): `SessionStart`,
`PreToolUse`, `PostToolUse`, `PreCompact`, `PostToolUseFailure` (Bash failure
classification into `verify/blocker-classification.jsonl`), and `Stop`
(unaccounted-edit ledger check with `stop_hook_active` loop safety).

Deliberately NOT adopted:

- **agent-type hooks** — marked experimental by the host; subject to breaking
  changes. Revisit when the host stabilizes them.
- **UserPromptSubmit context injection** — injecting affordances on every
  prompt is a per-turn context tax; the SessionStart ritual plus on-demand
  `/specnav-status` covers the same need.


## Plugin manifest policy

- Every plugin sets `defaultEnabled: true` in `plugin.json`; `strict: true`
  is set per entry in `marketplace.json` (the manifest is the single source
  of truth for components).
- The `dependencies` field of `plugin.json` is NOT used: as of mid-2026 it is
  not yet stable in Claude Code (open host issues). Co-install requirements
  are enforced at runtime instead by `plugin-suite.js` (`missing-plugin:<name>`
  blockers) and documented in each plugin README. Revisit when the host
  stabilizes the field.
