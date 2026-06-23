---
name: status
description: "Show active Helm/OpenSpec state and next legal actions"
allowed-tools:
  - Bash
  - Read
---

# Helm Status

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --markdown
```

Report:

- active change
- risk tier
- verify status
- stale report state
- ready actions
- blockers
