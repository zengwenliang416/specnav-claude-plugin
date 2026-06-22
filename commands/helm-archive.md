---
description: Check whether the active OpenSpec change can be archived
argument-hint: "[optional change name]"
---

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/archive-gate.js"
```

If the gate passes, archive through OpenSpec. If it fails, report blockers and route to `fix`, `verify`, or sign-off.
