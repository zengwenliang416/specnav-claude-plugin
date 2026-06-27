---
description: Run the SpecNav verification plugin
argument-hint: "[verification target]"
---

You are using the `specnav-verification` plugin.

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
SPECNAV_PLUGIN_NAME=specnav-development
SPECNAV_DEVELOPMENT_ROOT="$(specnav_plugin_root)"
SPECNAV_PLUGIN_NAME=specnav-verification
SPECNAV_VERIFICATION_ROOT="$(specnav_plugin_root)"
SPECNAV_MARKETPLACE_ROOT="$(dirname "$(dirname "$SPECNAV_VERIFICATION_ROOT")")"
node "$SPECNAV_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$SPECNAV_MARKETPLACE_ROOT" --plugin specnav-core --plugin specnav-development --plugin specnav-verification --json
```

If the suite check passes, run the development handoff gate:

```bash
node "$SPECNAV_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode handoff --json
```

If development is blocked, report the exact blockers and stop. Do not fabricate verification evidence.

If development passes, read and follow these exact installed-cache skill files:

- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-plan/SKILL.md`
- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-facticity/SKILL.md`
- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-static/SKILL.md`
- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-unit/SKILL.md`
- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-redteam/SKILL.md`
- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-e2e/SKILL.md`
- `$SPECNAV_VERIFICATION_ROOT/skills/specnav-verify-sensory/SKILL.md`

Do not infer `.claude-plugin/skills/...` paths and do not treat the six domains
as labels only. Each domain must create or update its `verify/<domain>/report.*`
artifacts with commands, evidence, findings, required fixes, and residual risk.

After the domain artifacts exist, run:

```bash
node "$SPECNAV_VERIFICATION_ROOT/scripts/verify-domains.js" aggregate --json
```

The aggregate command must write machine and human review artifacts:

- `openspec/changes/<change>/verify/aggregate-report.json`
- `openspec/changes/<change>/verify/aggregate-report.md`
- `openspec/changes/<change>/verify/aggregate-report.html`
- `openspec/changes/<change>/verify-report.json`
- `openspec/changes/<change>/verify-report.md`
- `openspec/changes/<change>/verify-report.html`

Proceed to operations only when `verify/aggregate-report.json.verdict` is
`green`. If the user needs to review with stakeholders, open or provide the
`verify-report.html` path first.
