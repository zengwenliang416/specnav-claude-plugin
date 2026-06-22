---
name: tasks
description: "Create Helm tasks.md and acceptance contract"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Helm Tasks

Write `openspec/changes/<change>/tasks.md`.

Tasks must map to requirements or scenarios where possible.

After acceptance tests are authored under `tests/acceptance/`, treat them as frozen. Contract changes go through `design`/`tasks` refinement, not silent edits during implementation.

Refresh state:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --write-snapshot --markdown
```
