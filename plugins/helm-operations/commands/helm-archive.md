---
description: Archive a Helm change after verification and operations gates pass
argument-hint: "[change name]"
---

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --plugin helm-core --plugin helm-verification --plugin helm-operations --json
node "$CLAUDE_PLUGIN_ROOT/scripts/archive-gate.js"
```

Archive only when both commands pass.
