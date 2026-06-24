---
name: verify-facticity
description: Audit Helm specs and implementation claims against actual repo state
allowed-tools:
  - Read
  - Bash
  - Write
---

# Verify Facticity

Read `verify/plan.json`, `verify/traceability-matrix.json`, requirements, foundation specs, prototype handoff, and development handoff.

Audit claims about APIs, dependencies, routes, config, database effects, generated artifacts, and changed files against actual repository evidence. Treat controller summaries and implementer reports as claims, not proof.

Write:

- `verify/facticity/claims.jsonl`
- `verify/facticity/repo-inventory.json`
- `verify/facticity/report.md`
- `verify/facticity/report.json`

`report.json` must use schema version `1`, domain `facticity`, and verdict `green`, `red`, or `blocked`. Unmapped changes, invented facts, stale specs, or undocumented behavior make this domain red.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json
```
