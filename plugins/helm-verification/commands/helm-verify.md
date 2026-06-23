---
description: Run the Helm verification plugin
argument-hint: "[verification target]"
---

You are using the `helm-verification` plugin.

Run:

```bash
if [ ! -f "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" ]; then
  printf '%s\n' 'not-implemented:helm-core/plugin-suite'
  exit 2
fi
node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --plugin helm-core --plugin helm-development --plugin helm-verification --json
```

If the suite check passes, load `verify-plan` and then the six verification domain skills.
