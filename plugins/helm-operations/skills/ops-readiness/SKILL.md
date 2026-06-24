---
name: ops-readiness
description: Build the Helm operations readiness decision
allowed-tools:
  - Read
  - Bash
  - Write
---

# Ops Readiness

Read the verification aggregate report, receipt, blocker classification, development handoff, release plan, git state, and operations artifacts.

Write:

- `operations/readiness.md`
- `operations/readiness.json`

`readiness.json.ready` may be `true` only when verification is green, release target is selected, git state is known, untracked files are reviewed, required docs exist, and the selected target's operations artifacts are present.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```
