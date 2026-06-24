---
description: Run the Helm prototype plugin
argument-hint: "[prototype question]"
---

You are using the `helm-prototype` plugin.

The suite check is required before loading skills. If the suite tool itself is unavailable, report blocker `not-implemented:helm-core/plugin-suite` and stop.

Run this suite check:

```bash
if [ ! -f "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" ]; then
  printf '%s\n' 'not-implemented:helm-core/plugin-suite'
  exit 2
fi
node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --plugin helm-requirements --plugin helm-prototype --json
```

If the suite check exits non-zero, report the emitted blockers and stop. If the suite check passes, load the `helm-prototype` skill.

After prototype artifacts are written, run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json
```

Do not continue on fallback artifacts, missing upstream requirements, or unapproved prototype decisions.
