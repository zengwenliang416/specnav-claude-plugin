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
SPECNAV_PLUGIN_NAME=specnav-development
SPECNAV_DEVELOPMENT_ROOT="$(specnav_plugin_root)"
SPECNAV_MARKETPLACE_ROOT="$(dirname "$(dirname "$SPECNAV_DEVELOPMENT_ROOT")")"
node "$SPECNAV_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$SPECNAV_MARKETPLACE_ROOT" --plugin specnav-core --plugin specnav-requirements --plugin specnav-prototype --plugin specnav-development --json
```

If the suite check exits non-zero, report the emitted blockers and stop. If it passes, run the development contract before any production edit:

```bash
node "$SPECNAV_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode entry --json
```

Entry mode proves that upstream requirements, prototype approval, scope, task
packets, and standard checkbox syntax exist. It does not require all `tasks.md`
checkboxes to be complete; unchecked vertical slices are expected before their
implementation evidence exists.

If the entry contract is blocked, read the exact owning skill path and repair
only the allowed development artifacts:

- `$SPECNAV_DEVELOPMENT_ROOT/skills/specnav-development-entry/SKILL.md`
- `$SPECNAV_DEVELOPMENT_ROOT/skills/specnav-scope-lock/SKILL.md`
- `$SPECNAV_DEVELOPMENT_ROOT/skills/specnav-vertical-slices/SKILL.md`

Choose the skill according to the exact blocker. Do not infer a
`.claude-plugin/skills/...` path, do not load similarly named skills from another
plugin, do not fallback to a different change, infer missing upstream decisions,
bypass prototype approval, or continue with production edits while the entry
contract is blocked. Start production edits only after the entry gate returns
`"ok": true`.

Before handoff to verification, run the handoff gate:

```bash
node "$SPECNAV_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode handoff --json
```

Handoff mode requires every completed slice to have real task reports, spec
review, quality review, ledger entries, drift checks, validation logs, and
`tasks.md` completion evidence. Any `<decision-required>`, "Replace this
scaffold", scaffold source marker, unchecked checkbox, blocking drift, failed
review, or missing validation pass is a blocker. Handoff to verification only
after this handoff gate returns `"ok": true`.
