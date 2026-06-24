---
name: rollback
description: Prepare rollback operations
allowed-tools:
  - Read
  - Bash
  - Write
---

# Rollback

Use this for any release target with deploy risk. If rollback is impossible, operations is blocked until the user explicitly accepts the risk in `operations/signoff.yaml`.

Write:

- `operations/rollback-plan.md`

Include rollback triggers, exact rollback command or manual step, data recovery or migration reversal notes, and rollback verification.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```
