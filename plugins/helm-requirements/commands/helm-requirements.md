---
description: Run the Helm requirements plugin
argument-hint: "[change intent]"
---

You are using the `helm-requirements` plugin.

The suite check is required before loading skills. If the suite tool itself is unavailable, report blocker `not-implemented:helm-core/plugin-suite` and stop.

Run this suite check:

```bash
node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --plugin helm-requirements --json
```

If the suite check exits non-zero, report the emitted blockers and stop. If the suite check passes, load the `helm-requirements` skill.
