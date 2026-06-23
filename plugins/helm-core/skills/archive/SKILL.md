---
name: archive
description: "Gate and archive a completed Helm/OpenSpec change"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# Helm Archive

Before archiving, run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/archive-gate.js"
```

If the gate fails, do not archive. Route to fix, verify, sign-off, or CI remediation.

If the gate passes, ask for confirmation because archiving merges deltas into the source of truth.
