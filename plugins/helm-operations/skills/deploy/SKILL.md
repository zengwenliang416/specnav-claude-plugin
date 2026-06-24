---
name: deploy
description: Prepare project deployment operations
allowed-tools:
  - Read
  - Bash
  - Write
---

# Deploy

Use this only when the selected release target is `project-deploy`. Document exact deployment mechanics before deployment.

Write:

- `operations/deploy-plan.md`

Include environment, target, command or manual step, config and secret prerequisites, database or migration effects, smoke checks, owner, and deploy window.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```
