---
description: Run the SpecNav requirements plugin
argument-hint: "[change intent]"
---

You are using the `specnav-requirements` plugin.

The suite check is required before loading skills. If the suite tool itself is unavailable, report blocker `not-implemented:specnav-core/plugin-suite` and stop.

Run this suite check:

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
SPECNAV_REQUIREMENTS_ROOT="$(specnav_plugin_root specnav-requirements)"
SPECNAV_MARKETPLACE_ROOT="$(dirname "$(dirname "$SPECNAV_REQUIREMENTS_ROOT")")"
node "$SPECNAV_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$SPECNAV_MARKETPLACE_ROOT" --plugin specnav-core --plugin specnav-requirements --json
```

If the suite check exits non-zero, report the emitted blockers and stop. If the suite check passes, load the `specnav-requirements` skill.
