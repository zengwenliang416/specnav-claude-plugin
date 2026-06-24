---
description: Run the Helm development plugin
argument-hint: "[task or slice]"
---

You are using the `helm-development` plugin.

The suite check is required before loading skills. If the suite tool itself is unavailable, report blocker `not-implemented:helm-core/plugin-suite` and stop.

Run this suite check:

```bash
if [ ! -f "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" ]; then
  printf '%s\n' 'not-implemented:helm-core/plugin-suite'
  exit 2
fi
node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --plugin helm-requirements --plugin helm-prototype --plugin helm-development --json
```

If the suite check exits non-zero, report the emitted blockers and stop. If it passes, run the development contract before any production edit:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --mode entry --json
```

If the contract is blocked, load `before-dev`, `scope-lock`, or `vertical-slice-tasking` according to the exact blocker and repair only the allowed development artifacts. Do not fallback to a different change, infer missing upstream decisions, bypass prototype approval, or continue with production edits while the contract is blocked.

Before handoff to verification, run the handoff gate:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --mode handoff --json
```

Proceed only when it returns `"ok": true`.
