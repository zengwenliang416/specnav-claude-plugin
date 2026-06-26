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
