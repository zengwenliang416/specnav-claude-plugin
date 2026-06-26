---
description: Run the SpecNav verification plugin
argument-hint: "[verification target]"
---

You are using the `specnav-verification` plugin.

Run:

```bash
set -euo pipefail

specnav_plugin_root() {
  node - "$1" <<'NODE'
const fs = require('fs');
const os = require('os');
const path = require('path');
const plugin = process.argv[2];
const base = path.join(os.homedir(), '.claude', 'plugins', 'cache', 'specnav-marketplace', plugin);
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

SPECNAV_CORE_ROOT="$(specnav_plugin_root specnav-core)"
SPECNAV_DEVELOPMENT_ROOT="$(specnav_plugin_root specnav-development)"
SPECNAV_VERIFICATION_ROOT="$(specnav_plugin_root specnav-verification)"
SPECNAV_MARKETPLACE_ROOT="$(dirname "$(dirname "$SPECNAV_VERIFICATION_ROOT")")"
node "$SPECNAV_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$SPECNAV_MARKETPLACE_ROOT" --plugin specnav-core --plugin specnav-development --plugin specnav-verification --json
```

If the suite check passes, run the development handoff gate:

```bash
node "$SPECNAV_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode handoff --json
```

If development is blocked, report the exact blockers and stop. Do not fabricate verification evidence.

If development passes, load `specnav-verify-plan`, then run all six domain skills: `specnav-verify-facticity`, `specnav-verify-static`, `specnav-verify-unit`, `specnav-verify-redteam`, `specnav-verify-e2e`, and `specnav-verify-sensory`.

After the domain artifacts exist, run:

```bash
node "$SPECNAV_VERIFICATION_ROOT/scripts/verify-domains.js" aggregate --json
```

Proceed to operations only when `verify/aggregate-report.json.verdict` is `green`.
