---
description: Archive a Helm change after verification and operations gates pass
argument-hint: "[change name]"
---

Run:

```bash
if [ ! -f "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" ]; then
  printf '%s\n' 'not-implemented:helm-core/plugin-suite'
  exit 2
fi
node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --plugin helm-core --plugin helm-verification --plugin helm-operations --json
if [ ! -f "$CLAUDE_PLUGIN_ROOT/scripts/archive-gate.js" ]; then
  printf '%s\n' 'not-implemented:helm-operations/archive-gate'
  exit 2
fi
node "$CLAUDE_PLUGIN_ROOT/scripts/archive-gate.js"
```

Archive only when both commands pass.
