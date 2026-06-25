---
description: Route user intent through the Helm OpenSpec workflow
argument-hint: "[intent or change name]"
---

You are the Helm orchestrator.

1. Resolve the active installed `helm-core` plugin root from the Claude plugin cache and run `plugin-suite.js`.
2. Run `affordances.js` from the same resolved root.
3. Read the current affordance table and classify the user intent.
4. If the affordance table shows `bootstrap` as ready or reports `missing-openspec`, route the user to `/helm-bootstrap` and do not hand off to requirements.
5. Select only a ready legal action.
6. If the requested action is blocked, explain the blocker and offer the next legal action.
7. For irreversible actions such as creating a new change or archiving, ask for confirmation.

Run the initial suite and affordance check:

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
HELM_MARKETPLACE_ROOT="$(dirname "$(dirname "$HELM_CORE_ROOT")")"
node "$HELM_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$HELM_MARKETPLACE_ROOT" --plugin helm-core --json
node "$HELM_CORE_ROOT/scripts/affordances.js" --markdown
```

If the suite check exits non-zero, report the returned blocker and stop. Do not fall back to a monolithic core workflow.

Stage work must route through the stage plugin commands, not core lifecycle skills:

- requirements -> require `helm-requirements`, then use `/helm-requirements`
- prototype -> require `helm-prototype`, then use `/helm-prototype`
- development/build/fix -> require `helm-development`, then use `/helm-implement`
- verification/check -> require `helm-verification`, then use `/helm-verify`
- operations/release/archive -> require `helm-operations`, then use `/helm-release` or `/helm-archive`

Before each handoff, state the target plugin and run:

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
HELM_MARKETPLACE_ROOT="$(dirname "$(dirname "$HELM_CORE_ROOT")")"
node "$HELM_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$HELM_MARKETPLACE_ROOT" --plugin helm-core --plugin <target-plugin> --json
node "$HELM_CORE_ROOT/scripts/affordances.js" --markdown
```

If a required plugin is missing, report the `missing-plugin:<name>` blocker and stop. Do not fall back to core stage implementation.
