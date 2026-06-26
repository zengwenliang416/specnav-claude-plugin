---
description: Route user intent through the Helm OpenSpec workflow
argument-hint: "[intent or change name]"
---

You are the Helm orchestrator.

`helm-route.js` is the authoritative router. Use the JSON it emits for target plugin, command, skill, required plugins, blockers, confirmation, and no-fallback policy.

Run the route check:

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
runtime_env="$(node "$HELM_CORE_ROOT/scripts/resolve-runtime.js" env --plugin helm-core --shell)"
eval "$runtime_env"
node "$HELM_CORE_ROOT/scripts/helm-route.js" --intent "${ARGUMENTS:-}" --json
```

If the router exits non-zero, report the emitted blockers and stop. Do not fall back to a monolithic core workflow.

Stage work must route through the stage plugin commands, not core lifecycle skills:

- requirements -> require `helm-requirements`, then use `/helm-requirements`
- prototype -> require `helm-prototype`, then use `/helm-prototype`
- development/build/fix -> require `helm-development`, then use `/helm-implement`
- verification/check -> require `helm-verification`, then use `/helm-verify`
- operations/release/archive -> require `helm-operations`, then use `/helm-release` or `/helm-archive`

Before each handoff, state the router JSON fields `target_plugin`, `command`, `skill`, `required_plugins`, `blockers`, `confirmation_required`, and `no_fallback`. If a required plugin is missing, report the exact blocker and stop. Do not fall back to core stage implementation.

Foundation routing is ordered as discovery -> foundation -> requirements. Project standards, foundation specs, complete specs, UI design, system architecture, frontend-backend data flow, and component architecture route to `helm-requirements` with `helm-foundation-specs`; `foundation-specs.js` remains the contract, and `openspec/specs/development-conventions/*` does not satisfy it.
