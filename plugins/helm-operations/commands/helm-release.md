---
description: Run the Helm operations plugin
argument-hint: "[release target]"
---

You are using the `helm-operations` plugin.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --plugin helm-core --plugin helm-verification --plugin helm-operations --json
```

If the suite check passes, load the operations skill matching the current blocker.
