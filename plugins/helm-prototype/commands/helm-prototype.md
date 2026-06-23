---
description: Run the Helm prototype plugin
argument-hint: "[prototype question]"
---

You are using the `helm-prototype` plugin.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --plugin helm-core --plugin helm-requirements --plugin helm-prototype --json
```

If the suite check passes, load the `prototype` skill.
