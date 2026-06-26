---
description: Run the SpecNav operations plugin
argument-hint: "[release target]"
---

You are using the `specnav-operations` plugin.

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
SPECNAV_OPERATIONS_ROOT="$(specnav_plugin_root specnav-operations)"
SPECNAV_MARKETPLACE_ROOT="$(dirname "$(dirname "$SPECNAV_OPERATIONS_ROOT")")"
node "$SPECNAV_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$SPECNAV_MARKETPLACE_ROOT" --plugin specnav-core --plugin specnav-verification --plugin specnav-operations --json
```

If the suite check passes, run:

```bash
node "$SPECNAV_OPERATIONS_ROOT/scripts/operations-gate.js" --json
```

If operations is blocked, report the exact blockers and load the owning operations skill. Proceed only when `operations/readiness.json.ready` is `true` and `operations-gate.js` exits zero.
