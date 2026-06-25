---
description: Initialize OpenSpec for the current project and unblock Helm lifecycle work
argument-hint: "[optional project path]"
---

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
node "$HELM_CORE_ROOT/scripts/helm-bootstrap.js" --json
```

If it exits non-zero, report the emitted blockers and exit status explicitly. Do not run requirements, implementation, verification, or operations commands until bootstrap reports `ok: true`.

After successful bootstrap, tell the user the next legal calls:

- `/helm-status`
- `/helm-requirements`
