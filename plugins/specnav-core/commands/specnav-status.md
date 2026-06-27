---
description: Show SpecNav workflow status for the active OpenSpec change
argument-hint: "[optional project path]"
---

Run:

```bash
set -euo pipefail

specnav_plugin_root() {
  local plugin_name="${SPECNAV_PLUGIN_NAME:?missing SPECNAV_PLUGIN_NAME}"
  SPECNAV_PLUGIN_NAME="$plugin_name" node - <<'NODE'
const fs = require('fs');
const os = require('os');
const path = require('path');
const plugin = process.env.SPECNAV_PLUGIN_NAME;
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

SPECNAV_PLUGIN_NAME=specnav-core
SPECNAV_CORE_ROOT="$(specnav_plugin_root)"
node "$SPECNAV_CORE_ROOT/scripts/workflow-state.js" --json
```

If `workflow-state.js` exits non-zero or returns `not-implemented:specnav-core/workflow-state`, report that blocker and the exit status explicitly. Do not hide the placeholder exit 2 and do not infer cross-plugin state.

Then run the affordance surface for current legal actions:

```bash
node "$SPECNAV_CORE_ROOT/scripts/affordances.js" --markdown
```

Summarize active change, risk tier, verify status, stale report state, ready actions, and blockers. If workflow state is blocked, label the affordance output as affordances only, not a full workflow-state fallback.
