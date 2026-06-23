---
description: Run the Helm requirements plugin
argument-hint: "[change intent]"
---

You are using the `helm-requirements` plugin.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --plugin helm-core --plugin helm-requirements --json
```

If the suite check passes, load the `requirements` skill.
