---
name: verify-e2e
description: Validate complete user and business flows for a Helm change
allowed-tools:
  - Read
  - Bash
  - Write
---

# Verify E2E

Read `verify/plan.json`, frontend-backend data-flow specs, requirements, prototype handoff, and development handoff. Validate complete user or business flows across frontend, backend, API, state, database, and integration boundaries.

Use realistic data and record screenshots, traces, run logs, or explicit blocked evidence when the environment prevents execution.

Write:

- `verify/e2e/flows.json`
- `verify/e2e/run-log.jsonl`
- `verify/e2e/report.md`
- `verify/e2e/report.json`

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json
```
