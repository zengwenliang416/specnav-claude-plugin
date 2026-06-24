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
node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --plugin helm-development --plugin helm-verification --json
```

If the suite check passes, run the development handoff gate:

```bash
node "$CLAUDE_PLUGIN_ROOT/../helm-development/scripts/development-contract.js" --mode handoff --json
```

If development is blocked, report the exact blockers and stop. Do not fabricate verification evidence.

If development passes, load `helm-verify-plan`, then run all six domain skills: `helm-verify-facticity`, `helm-verify-static`, `helm-verify-unit`, `helm-verify-redteam`, `helm-verify-e2e`, and `helm-verify-sensory`.

After the domain artifacts exist, run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" aggregate --json
```

Proceed to operations only when `verify/aggregate-report.json.verdict` is `green`.
