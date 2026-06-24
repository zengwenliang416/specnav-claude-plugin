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
node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --plugin helm-verification --plugin helm-operations --json
node "$CLAUDE_PLUGIN_ROOT/scripts/archive-gate.js" --json
```

Archive only when both commands pass and `operations/archive-gate.json.verdict` is `green`.
