---
name: monitor
description: Prepare post-release monitoring
allowed-tools:
  - Read
  - Bash
  - Write
---

# Monitor

Use this for deploy or runtime release targets. If monitoring is impossible, operations is blocked until the user explicitly accepts the risk in `operations/signoff.yaml`.

Write:

- `operations/monitor-plan.md`

Include signals, logs, metrics, endpoints, queues, user flows to watch, observation window, owner, expected normal values, and escalation route.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```
