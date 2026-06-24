---
name: update-policy
description: Record Helm installation update policy
allowed-tools:
  - Read
  - Bash
  - Write
---

# Update Policy

Document how installed plugin surfaces are updated and re-verified. Default updates are current-host scoped; all-host updates require explicit user request.

Write:

- `operations/update-policy.json`

Record every known installation, host, plugin root, discovery root, discovery shape, tracked ref, and reload hint.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```
