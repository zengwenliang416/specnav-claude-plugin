---
description: Run the Helm operations plugin
argument-hint: "[release target]"
---

You are using the `helm-operations` plugin.

Run:

```bash
if [ ! -f "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" ]; then
  printf '%s\n' 'not-implemented:helm-core/plugin-suite'
  exit 2
fi
node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --plugin helm-verification --plugin helm-operations --json
```

If the suite check passes, run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```

If operations is blocked, report the exact blockers and load the owning operations skill. Proceed only when `operations/readiness.json.ready` is `true` and `operations-gate.js` exits zero.
