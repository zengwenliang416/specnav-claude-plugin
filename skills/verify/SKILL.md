---
name: verify
description: "Run Helm verification and emit verify-report.md"
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Task
---

# Helm Verify

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/verify.js"
```

If deeper judgment is needed, invoke the `verifier` agent after the script report exists. Keep the implementer and verifier reasoning separate.

Archive is blocked unless `verify-report.json` is green and not stale.
