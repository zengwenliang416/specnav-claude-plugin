---
name: release-plan
description: Select and document the Helm release target
allowed-tools:
  - Read
  - Bash
  - Write
---

# Release Plan

Read verification output, user intent, repository shape, and distribution surface. Select exactly one primary release target: `local-only`, `plugin-marketplace`, `package`, `host-compatibility`, or `project-deploy`.

Write:

- `operations/release-plan.md`
- `operations/release-checklist.json`

The checklist must include every required artifact for the chosen target and all required checks must pass before release.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```
