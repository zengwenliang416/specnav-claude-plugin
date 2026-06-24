---
name: update-spec
description: Record operations learning writeback to OpenSpec
allowed-tools:
  - Read
  - Bash
  - Write
---

# Update Spec

Review operations, verification, release, deploy, rollback, monitor, and postmortem outputs for learning that belongs in requirements, acceptance, UI design, architecture, data-flow, component architecture, operational runbook, or known limitations.

Write:

- `operations/update-spec.json`

Use status `no_writeback_needed`, `written_back`, or `deferred`. Any unresolved learning item blocks archive.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```
