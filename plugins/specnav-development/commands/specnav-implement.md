---
description: Run the SpecNav development plugin
argument-hint: "[task or slice]"
---

You are using the `specnav-development` plugin.

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
SPECNAV_DEVELOPMENT_ROOT="$(specnav_plugin_root specnav-development)"
SPECNAV_MARKETPLACE_ROOT="$(dirname "$(dirname "$SPECNAV_DEVELOPMENT_ROOT")")"
node "$SPECNAV_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$SPECNAV_MARKETPLACE_ROOT" --plugin specnav-core --plugin specnav-requirements --plugin specnav-prototype --plugin specnav-development --json
```

If the suite check exits non-zero, report the emitted blockers and stop. If it passes, run the development contract before any production edit:

```bash
node "$SPECNAV_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode entry --json
```

If the entry contract is blocked, load `specnav-development-entry`, `specnav-scope-lock`, or `specnav-vertical-slices` according to the exact blocker and repair only the allowed development artifacts. Do not fallback to a different change, infer missing upstream decisions, bypass prototype approval, or continue with production edits while the entry contract is blocked. Start production edits only after the entry gate returns `"ok": true`.

Before handoff to verification, run the handoff gate:

```bash
node "$SPECNAV_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode handoff --json
```

Handoff to verification only after this handoff gate returns `"ok": true`.
