---
description: Archive a SpecNav change after verification and operations gates pass
argument-hint: "[change name]"
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
SPECNAV_PLUGIN_NAME=specnav-operations
SPECNAV_OPERATIONS_ROOT="$(specnav_plugin_root)"
SPECNAV_MARKETPLACE_ROOT="$(dirname "$(dirname "$SPECNAV_OPERATIONS_ROOT")")"
node "$SPECNAV_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$SPECNAV_MARKETPLACE_ROOT" --plugin specnav-core --plugin specnav-verification --plugin specnav-operations --json
SPECNAV_ARCHIVE_ARGS="${ARGUMENTS:-}" node "$SPECNAV_OPERATIONS_ROOT/scripts/archive-change.js" --json
```

Archive only when the command returns `ok: true`. The command normalizes
`tasks.md`, requires a green operations archive gate, validates the change with
`openspec validate`, executes `openspec archive`, updates SpecNav registry/focus
state, and writes `operations/archive-receipt.json` under the archived change.
If `tasks-md.js normalize` changes the file but exits with
`tasks-md:incomplete-checkboxes`, stop and tell the user the task file has been
converted to standard checkbox syntax and now needs explicit `- [x]` completion
evidence. Do not describe plain bullets as completed tasks. Do not use native
OpenSpec skills; using the `openspec` CLI is allowed.
