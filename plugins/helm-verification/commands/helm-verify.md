---
description: Run the Helm verification plugin
argument-hint: "[verification target]"
---

You are using the `helm-verification` plugin.

Run:

```bash
set -euo pipefail

helm_plugin_root() {
  node - "$1" <<'NODE'
const fs = require('fs');
const os = require('os');
const path = require('path');
const plugin = process.argv[2];
const base = path.join(os.homedir(), '.claude', 'plugins', 'cache', 'helm-marketplace', plugin);
function block(reason) {
  console.error(`${reason}:${plugin}`);
  process.exit(2);
}
if (!/^[a-z0-9-]+$/.test(plugin)) block('invalid-plugin-name');
if (!fs.existsSync(base)) block('missing-installed-plugin');
const collator = new Intl.Collator(undefined, { numeric: true, sensitivity: 'base' });
const candidates = fs.readdirSync(base, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => ({ version: entry.name, root: path.join(base, entry.name) }))
  .filter((candidate) => fs.existsSync(path.join(candidate.root, '.claude-plugin', 'plugin.json'))
    && !fs.existsSync(path.join(candidate.root, '.orphaned_at')))
  .sort((a, b) => collator.compare(b.version, a.version));
if (!candidates.length) block('missing-active-installed-plugin');
process.stdout.write(candidates[0].root);
NODE
}

HELM_CORE_ROOT="$(helm_plugin_root helm-core)"
HELM_DEVELOPMENT_ROOT="$(helm_plugin_root helm-development)"
HELM_VERIFICATION_ROOT="$(helm_plugin_root helm-verification)"
HELM_MARKETPLACE_ROOT="$(dirname "$(dirname "$HELM_VERIFICATION_ROOT")")"
node "$HELM_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$HELM_MARKETPLACE_ROOT" --plugin helm-core --plugin helm-development --plugin helm-verification --json
```

If the suite check passes, run the development handoff gate:

```bash
node "$HELM_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode handoff --json
```

If development is blocked, report the exact blockers and stop. Do not fabricate verification evidence.

If development passes, load `helm-verify-plan`, then run all six domain skills: `helm-verify-facticity`, `helm-verify-static`, `helm-verify-unit`, `helm-verify-redteam`, `helm-verify-e2e`, and `helm-verify-sensory`.

After the domain artifacts exist, run:

```bash
node "$HELM_VERIFICATION_ROOT/scripts/verify-domains.js" aggregate --json
```

Proceed to operations only when `verify/aggregate-report.json.verdict` is `green`.
