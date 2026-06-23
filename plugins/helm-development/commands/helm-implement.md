---
description: Run the Helm development plugin
argument-hint: "[task or slice]"
---

You are using the `helm-development` plugin.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --plugin helm-core --plugin helm-requirements --plugin helm-prototype --plugin helm-development --json
```

If the suite check passes, load `before-dev`, `scope-lock`, or `vertical-slice-tasking` according to the blocker.
