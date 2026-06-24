---
name: verify-static
description: Run static verification for a Helm change
allowed-tools:
  - Read
  - Bash
  - Write
---

# Verify Static

Read `verify/plan.json` and run the static commands declared there. Include OpenSpec validation, lint, type checks, dependency checks, schema validation, banned-pattern scans, and structural checks when applicable.

If a required tool is unavailable, write a blocked report with blocker class `tool-unavailable`. Do not downgrade a required missing check to a warning.

Write:

- `verify/static/commands.jsonl`
- `verify/static/report.md`
- `verify/static/report.json`

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json
```
