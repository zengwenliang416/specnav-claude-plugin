---
name: verify-redteam
description: Run destructive and adversarial verification for a Helm change
allowed-tools:
  - Read
  - Bash
  - Write
---

# Verify Redteam

Read `verify/plan.json`, requirements, architecture specs, data-flow specs, and development handoff. Probe destructive, adversarial, injection, boundary, permission, abuse, and resilience cases appropriate to the risk tier.

If a probe fails, classify root cause in `verify/root-cause-checks.jsonl` before routing fixes.

Write:

- `verify/redteam/threat-model.md`
- `verify/redteam/probes.jsonl`
- `verify/redteam/report.md`
- `verify/redteam/report.json`

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json
```
