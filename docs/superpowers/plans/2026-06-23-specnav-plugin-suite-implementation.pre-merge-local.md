# SpecNav Plugin Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build SpecNav as a Claude Code marketplace repository containing several lifecycle plugins, not as one monolithic plugin.

**Architecture:** The marketplace root owns `.claude-plugin/marketplace.json`; each lifecycle phase is an individual plugin under `plugins/<plugin-name>/`. `specnav-core` is the required runtime and governance plugin; stage plugins own their own commands, skills, prompts, and stage contracts. Cross-plugin calls go through `specnav-core/scripts/plugin-suite.js`, which resolves plugin roots from marketplace metadata and fails explicitly when a required plugin is missing.

**Tech Stack:** Claude Code plugin marketplace metadata, Node.js CommonJS scripts with built-in modules only, Bash fixture tests with `jq`, OpenSpec project artifacts under `openspec/`, one plugin per SpecNav lifecycle phase.

---

## Scope Check

The full SpecNav development process is intentionally split into multiple plugins. Each plugin must be independently understandable, testable, installable from the same marketplace repository, and blocked when `specnav-core` is missing.

This is the plugin boundary:

| Plugin | Required | Owns | Does Not Own |
| --- | --- | --- | --- |
| `specnav-core` | yes | bootstrap, router, status, doctor, hooks, suite resolution, state machine, shared event/journal helpers | stage-specific requirements/prototype/development/verification/operations decisions |
| `specnav-requirements` | yes for requirements work | foundation specs, requirements questioning, acceptance criteria, spec maps, component impact maps | prototype or production implementation |
| `specnav-prototype` | yes for prototype work | isolated prototype artifacts, prototype verification, prototype decision and handoff | production code |
| `specnav-development` | yes for implementation work | scope lock, task slicing, prototype promotion, implementation ledger, review loop, development handoff | six-domain verification |
| `specnav-verification` | yes for release/archive | six verification domains, evidence index, traceability, receipt, aggregate report | deployment or branch finish |
| `specnav-operations` | yes for release/archive | readiness, release plan, install/update policy, compatibility, deploy, rollback, monitor, branch finish, postmortem, archive gate | requirements or implementation |

The six verification domains are dedicated skills inside `specnav-verification`, not separate plugins in this plan. If later we want marketplace-level optional verification packs, split `specnav-verification` into `specnav-verify-facticity`, `specnav-verify-static`, `specnav-verify-unit`, `specnav-verify-redteam`, `specnav-verify-e2e`, and `specnav-verify-sensory` after the suite contract is stable.

## Target Repository Structure

```text
specnav-claude-plugin/
  .claude-plugin/
    marketplace.json
  plugins/
    specnav-core/
      .claude-plugin/plugin.json
      specnav-stage.json
      commands/
        specnav.md
        specnav-status.md
        specnav-doctor.md
      hooks/
        hooks.json
      skills/
        using-specnav/SKILL.md
        specnav-router/SKILL.md
        status/SKILL.md
        doctor/SKILL.md
        debug/SKILL.md
        break-loop/SKILL.md
      scripts/
        plugin-suite.js
        workflow-state.js
        affordances.js
        specnav-lib.js
        specnav-guard.js
        specnav-session-start.js
        specnav-post-tool.js
        specnav-doctor.js
        override.js
    specnav-requirements/
      .claude-plugin/plugin.json
      specnav-stage.json
      commands/specnav-requirements.md
      skills/foundation-spec/SKILL.md
      skills/requirements/SKILL.md
      scripts/foundation-specs.js
      scripts/requirements-contract.js
    specnav-prototype/
      .claude-plugin/plugin.json
      specnav-stage.json
      commands/specnav-prototype.md
      skills/prototype/SKILL.md
      skills/prototype-verify/SKILL.md
      skills/prototype-handoff/SKILL.md
      scripts/prototype-contract.js
    specnav-development/
      .claude-plugin/plugin.json
      specnav-stage.json
      commands/specnav-implement.md
      skills/before-dev/SKILL.md
      skills/scope-lock/SKILL.md
      skills/vertical-slice-tasking/SKILL.md
      scripts/development-contract.js
    specnav-verification/
      .claude-plugin/plugin.json
      specnav-stage.json
      commands/specnav-verify.md
      skills/verify-plan/SKILL.md
      skills/verify-facticity/SKILL.md
      skills/verify-static/SKILL.md
      skills/verify-unit/SKILL.md
      skills/verify-redteam/SKILL.md
      skills/verify-e2e/SKILL.md
      skills/verify-sensory/SKILL.md
      scripts/verify-domains.js
    specnav-operations/
      .claude-plugin/plugin.json
      specnav-stage.json
      commands/specnav-release.md
      commands/specnav-archive.md
      skills/ops-readiness/SKILL.md
      skills/release-plan/SKILL.md
      skills/install-verify/SKILL.md
      skills/update-policy/SKILL.md
      skills/compatibility-matrix/SKILL.md
      skills/branch-finish/SKILL.md
      skills/deploy/SKILL.md
      skills/rollback/SKILL.md
      skills/monitor/SKILL.md
      skills/postmortem/SKILL.md
      skills/update-spec/SKILL.md
      scripts/operations-gate.js
      scripts/archive-gate.js
  tests/
  docs/
```

## Cross-Plugin Rules

- `specnav-core` is the only plugin allowed to install hooks.
- Stage plugins never mutate another plugin's files.
- Stage plugins expose machine contracts through `specnav-stage.json`.
- `specnav-core` resolves all plugin roots from `.claude-plugin/marketplace.json`; it never assumes sibling paths without verifying metadata.
- If a required plugin is absent, the relevant action is blocked with a `missing-plugin:<name>` blocker.
- Stage commands may call their own local scripts, but cross-stage orchestration must go through `specnav-core/scripts/plugin-suite.js`.
- Project runtime state remains under the target project `openspec/.specnav/`; plugin repository state stays under the plugin marketplace repository.

---

### Task 1: Convert Repository To Multi-Plugin Marketplace

**Files:**
- Modify: `.claude-plugin/marketplace.json`
- Move: `.claude-plugin/plugin.json` to `plugins/specnav-core/.claude-plugin/plugin.json`
- Move: `commands/` to `plugins/specnav-core/commands/`
- Move: `hooks/` to `plugins/specnav-core/hooks/`
- Move: `skills/` to `plugins/specnav-core/skills/`
- Move: `scripts/` to `plugins/specnav-core/scripts/`
- Move: `agents/` to `plugins/specnav-core/agents/`
- Create: `plugins/specnav-core/specnav-stage.json`
- Create: stage plugin directories and metadata
- Test: `tests/run-plugin-suite-layout-fixtures.sh`

- [ ] **Step 1: Write the failing layout fixture**

Create `tests/run-plugin-suite-layout-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

jq -e '.plugins | length == 6' "$ROOT/.claude-plugin/marketplace.json" >/dev/null
jq -e '.plugins[].name' "$ROOT/.claude-plugin/marketplace.json" >/tmp/specnav-plugin-names.txt
grep -q '"specnav-core"' /tmp/specnav-plugin-names.txt
grep -q '"specnav-requirements"' /tmp/specnav-plugin-names.txt
grep -q '"specnav-prototype"' /tmp/specnav-plugin-names.txt
grep -q '"specnav-development"' /tmp/specnav-plugin-names.txt
grep -q '"specnav-verification"' /tmp/specnav-plugin-names.txt
grep -q '"specnav-operations"' /tmp/specnav-plugin-names.txt

for plugin in specnav-core specnav-requirements specnav-prototype specnav-development specnav-verification specnav-operations; do
  test -f "$ROOT/plugins/$plugin/.claude-plugin/plugin.json"
  test -f "$ROOT/plugins/$plugin/specnav-stage.json"
  jq -e '.name == "'"$plugin"'"' "$ROOT/plugins/$plugin/.claude-plugin/plugin.json" >/dev/null
  jq -e '.plugin == "'"$plugin"'"' "$ROOT/plugins/$plugin/specnav-stage.json" >/dev/null
done

test -f "$ROOT/plugins/specnav-core/hooks/hooks.json"
test -f "$ROOT/plugins/specnav-core/scripts/specnav-lib.js"
test -f "$ROOT/plugins/specnav-core/commands/specnav.md"
test -f "$ROOT/plugins/specnav-requirements/commands/specnav-requirements.md"
test -f "$ROOT/plugins/specnav-prototype/commands/specnav-prototype.md"
test -f "$ROOT/plugins/specnav-development/commands/specnav-implement.md"
test -f "$ROOT/plugins/specnav-verification/commands/specnav-verify.md"
test -f "$ROOT/plugins/specnav-operations/commands/specnav-release.md"
test -f "$ROOT/plugins/specnav-operations/commands/specnav-archive.md"

echo "specnav plugin suite layout fixtures ok"
```

- [ ] **Step 2: Run the layout fixture and verify it fails**

Run:

```bash
bash tests/run-plugin-suite-layout-fixtures.sh
```

Expected: FAIL because `plugins/specnav-core/` and stage plugin directories do not exist.

- [ ] **Step 3: Move the current monolithic plugin into `specnav-core`**

Run:

```bash
mkdir -p plugins/specnav-core/.claude-plugin
git mv .claude-plugin/plugin.json plugins/specnav-core/.claude-plugin/plugin.json
git mv commands plugins/specnav-core/commands
git mv hooks plugins/specnav-core/hooks
git mv skills plugins/specnav-core/skills
git mv scripts plugins/specnav-core/scripts
git mv agents plugins/specnav-core/agents
mkdir -p plugins/specnav-requirements/.claude-plugin plugins/specnav-requirements/commands plugins/specnav-requirements/skills plugins/specnav-requirements/scripts
mkdir -p plugins/specnav-prototype/.claude-plugin plugins/specnav-prototype/commands plugins/specnav-prototype/skills plugins/specnav-prototype/scripts
mkdir -p plugins/specnav-development/.claude-plugin plugins/specnav-development/commands plugins/specnav-development/skills plugins/specnav-development/scripts
mkdir -p plugins/specnav-verification/.claude-plugin plugins/specnav-verification/commands plugins/specnav-verification/skills plugins/specnav-verification/scripts
mkdir -p plugins/specnav-operations/.claude-plugin plugins/specnav-operations/commands plugins/specnav-operations/skills plugins/specnav-operations/scripts
```

- [ ] **Step 4: Replace marketplace metadata**

Write `.claude-plugin/marketplace.json`:

```json
{
  "name": "specnav-marketplace",
  "description": "Local marketplace for the SpecNav Claude Code lifecycle plugin suite.",
  "owner": {
    "name": "Wenliang Zeng"
  },
  "plugins": [
    {
      "name": "specnav-core",
      "source": "plugins/specnav-core",
      "description": "SpecNav core runtime: router, hooks, state machine, doctor, and suite governance.",
      "version": "0.3.0",
      "category": "productivity"
    },
    {
      "name": "specnav-requirements",
      "source": "plugins/specnav-requirements",
      "description": "SpecNav requirements stage: foundation specs, requirements questioning, acceptance, and maps.",
      "version": "0.3.0",
      "category": "productivity"
    },
    {
      "name": "specnav-prototype",
      "source": "plugins/specnav-prototype",
      "description": "SpecNav prototype stage: isolated prototype code, review, verification, and handoff.",
      "version": "0.3.0",
      "category": "productivity"
    },
    {
      "name": "specnav-development",
      "source": "plugins/specnav-development",
      "description": "SpecNav development stage: scope lock, vertical slices, task ledger, and development handoff.",
      "version": "0.3.0",
      "category": "productivity"
    },
    {
      "name": "specnav-verification",
      "source": "plugins/specnav-verification",
      "description": "SpecNav verification stage: six-domain evidence, traceability, receipt, and aggregate report.",
      "version": "0.3.0",
      "category": "productivity"
    },
    {
      "name": "specnav-operations",
      "source": "plugins/specnav-operations",
      "description": "SpecNav operations stage: release, install/update policy, deploy, rollback, monitor, and archive.",
      "version": "0.3.0",
      "category": "productivity"
    }
  ]
}
```

- [ ] **Step 5: Write plugin metadata**

Write `plugins/specnav-core/.claude-plugin/plugin.json`:

```json
{
  "name": "specnav-core",
  "version": "0.3.0",
  "description": "Core runtime for the SpecNav OpenSpec lifecycle plugin suite.",
  "author": {
    "name": "Wenliang Zeng"
  },
  "homepage": "https://github.com/zengwenliang416/specnav",
  "license": "MIT",
  "keywords": ["claude-code", "openspec", "workflow", "guardrails", "verification"],
  "skills": "./skills/"
}
```

Write `plugins/specnav-requirements/.claude-plugin/plugin.json`:

```json
{
  "name": "specnav-requirements",
  "version": "0.3.0",
  "description": "Requirements stage plugin for the SpecNav OpenSpec lifecycle suite.",
  "author": {
    "name": "Wenliang Zeng"
  },
  "homepage": "https://github.com/zengwenliang416/specnav",
  "license": "MIT",
  "keywords": ["claude-code", "openspec", "requirements", "specs"],
  "skills": "./skills/"
}
```

Write `plugins/specnav-prototype/.claude-plugin/plugin.json`:

```json
{
  "name": "specnav-prototype",
  "version": "0.3.0",
  "description": "Prototype stage plugin for the SpecNav OpenSpec lifecycle suite.",
  "author": {
    "name": "Wenliang Zeng"
  },
  "homepage": "https://github.com/zengwenliang416/specnav",
  "license": "MIT",
  "keywords": ["claude-code", "openspec", "prototype", "ux"],
  "skills": "./skills/"
}
```

Write `plugins/specnav-development/.claude-plugin/plugin.json`:

```json
{
  "name": "specnav-development",
  "version": "0.3.0",
  "description": "Development stage plugin for the SpecNav OpenSpec lifecycle suite.",
  "author": {
    "name": "Wenliang Zeng"
  },
  "homepage": "https://github.com/zengwenliang416/specnav",
  "license": "MIT",
  "keywords": ["claude-code", "openspec", "implementation", "tdd"],
  "skills": "./skills/"
}
```

Write `plugins/specnav-verification/.claude-plugin/plugin.json`:

```json
{
  "name": "specnav-verification",
  "version": "0.3.0",
  "description": "Six-domain verification plugin for the SpecNav OpenSpec lifecycle suite.",
  "author": {
    "name": "Wenliang Zeng"
  },
  "homepage": "https://github.com/zengwenliang416/specnav",
  "license": "MIT",
  "keywords": ["claude-code", "openspec", "verification", "testing"],
  "skills": "./skills/"
}
```

Write `plugins/specnav-operations/.claude-plugin/plugin.json`:

```json
{
  "name": "specnav-operations",
  "version": "0.3.0",
  "description": "Operations and archive plugin for the SpecNav OpenSpec lifecycle suite.",
  "author": {
    "name": "Wenliang Zeng"
  },
  "homepage": "https://github.com/zengwenliang416/specnav",
  "license": "MIT",
  "keywords": ["claude-code", "openspec", "release", "operations"],
  "skills": "./skills/"
}
```

- [ ] **Step 6: Write stage manifests**

Write `plugins/specnav-core/specnav-stage.json`:

```json
{
  "schema": "specnav.stagePlugin.v1",
  "plugin": "specnav-core",
  "stage": "core",
  "required": true,
  "commands": ["specnav", "specnav-status", "specnav-doctor"],
  "skills": ["using-specnav", "specnav-router", "status", "doctor", "debug", "break-loop"],
  "contracts": {
    "suite": "scripts/plugin-suite.js",
    "state": "scripts/workflow-state.js",
    "doctor": "scripts/specnav-doctor.js",
    "guard": "scripts/specnav-guard.js"
  },
  "state_outputs": ["openspec/.specnav/workflow-state.json", "openspec/.specnav/affordances.json"]
}
```

Write `plugins/specnav-requirements/specnav-stage.json`:

```json
{
  "schema": "specnav.stagePlugin.v1",
  "plugin": "specnav-requirements",
  "stage": "requirements",
  "required": true,
  "depends_on": ["specnav-core"],
  "commands": ["specnav-requirements"],
  "skills": ["foundation-spec", "requirements"],
  "contracts": {
    "foundation": "scripts/foundation-specs.js",
    "requirements": "scripts/requirements-contract.js"
  },
  "state_outputs": [
    "openspec/specs/ui-design/design.md",
    "openspec/specs/system-architecture/design.md",
    "openspec/specs/frontend-backend-data-flow/design.md",
    "openspec/specs/component-architecture/design.md",
    "openspec/changes/<change>/requirements.md",
    "openspec/changes/<change>/acceptance.md",
    "openspec/changes/<change>/spec-map.json",
    "openspec/changes/<change>/component-impact-map.json"
  ]
}
```

Write `plugins/specnav-prototype/specnav-stage.json`:

```json
{
  "schema": "specnav.stagePlugin.v1",
  "plugin": "specnav-prototype",
  "stage": "prototype",
  "required": true,
  "depends_on": ["specnav-core", "specnav-requirements"],
  "commands": ["specnav-prototype"],
  "skills": ["prototype", "prototype-verify", "prototype-handoff"],
  "contracts": {
    "prototype": "scripts/prototype-contract.js"
  },
  "state_outputs": ["openspec/changes/<change>/prototype/"]
}
```

Write `plugins/specnav-development/specnav-stage.json`:

```json
{
  "schema": "specnav.stagePlugin.v1",
  "plugin": "specnav-development",
  "stage": "development",
  "required": true,
  "depends_on": ["specnav-core", "specnav-requirements", "specnav-prototype"],
  "commands": ["specnav-implement"],
  "skills": ["before-dev", "scope-lock", "vertical-slice-tasking"],
  "contracts": {
    "development": "scripts/development-contract.js"
  },
  "state_outputs": ["openspec/changes/<change>/development/"]
}
```

Write `plugins/specnav-verification/specnav-stage.json`:

```json
{
  "schema": "specnav.stagePlugin.v1",
  "plugin": "specnav-verification",
  "stage": "verification",
  "required": true,
  "depends_on": ["specnav-core", "specnav-development"],
  "commands": ["specnav-verify"],
  "skills": [
    "verify-plan",
    "verify-facticity",
    "verify-static",
    "verify-unit",
    "verify-redteam",
    "verify-e2e",
    "verify-sensory"
  ],
  "contracts": {
    "verification": "scripts/verify-domains.js"
  },
  "state_outputs": ["openspec/changes/<change>/verify/"]
}
```

Write `plugins/specnav-operations/specnav-stage.json`:

```json
{
  "schema": "specnav.stagePlugin.v1",
  "plugin": "specnav-operations",
  "stage": "operations",
  "required": true,
  "depends_on": ["specnav-core", "specnav-verification"],
  "commands": ["specnav-release", "specnav-archive"],
  "skills": [
    "ops-readiness",
    "release-plan",
    "install-verify",
    "update-policy",
    "compatibility-matrix",
    "branch-finish",
    "deploy",
    "rollback",
    "monitor",
    "postmortem",
    "update-spec"
  ],
  "contracts": {
    "operations": "scripts/operations-gate.js",
    "archive": "scripts/archive-gate.js"
  },
  "state_outputs": ["openspec/changes/<change>/operations/"]
}
```

- [ ] **Step 7: Create stage command stubs**

Write `plugins/specnav-requirements/commands/specnav-requirements.md`:

```markdown
---
description: Run the SpecNav requirements plugin
argument-hint: "[change intent]"
---

You are using the `specnav-requirements` plugin.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/../specnav-core/scripts/plugin-suite.js" require --plugin specnav-core --plugin specnav-requirements --json
```

If the suite check passes, load the `requirements` skill.
```

Write `plugins/specnav-prototype/commands/specnav-prototype.md`:

```markdown
---
description: Run the SpecNav prototype plugin
argument-hint: "[prototype question]"
---

You are using the `specnav-prototype` plugin.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/../specnav-core/scripts/plugin-suite.js" require --plugin specnav-core --plugin specnav-requirements --plugin specnav-prototype --json
```

If the suite check passes, load the `prototype` skill.
```

Write `plugins/specnav-development/commands/specnav-implement.md`:

```markdown
---
description: Run the SpecNav development plugin
argument-hint: "[task or slice]"
---

You are using the `specnav-development` plugin.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/../specnav-core/scripts/plugin-suite.js" require --plugin specnav-core --plugin specnav-requirements --plugin specnav-prototype --plugin specnav-development --json
```

If the suite check passes, load `before-dev`, `scope-lock`, or `vertical-slice-tasking` according to the blocker.
```

Write `plugins/specnav-verification/commands/specnav-verify.md`:

```markdown
---
description: Run the SpecNav verification plugin
argument-hint: "[verification target]"
---

You are using the `specnav-verification` plugin.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/../specnav-core/scripts/plugin-suite.js" require --plugin specnav-core --plugin specnav-development --plugin specnav-verification --json
```

If the suite check passes, load `verify-plan` and then the six verification domain skills.
```

Write `plugins/specnav-operations/commands/specnav-release.md`:

```markdown
---
description: Run the SpecNav operations plugin
argument-hint: "[release target]"
---

You are using the `specnav-operations` plugin.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/../specnav-core/scripts/plugin-suite.js" require --plugin specnav-core --plugin specnav-verification --plugin specnav-operations --json
```

If the suite check passes, load the operations skill matching the current blocker.
```

Write `plugins/specnav-operations/commands/specnav-archive.md`:

```markdown
---
description: Archive a SpecNav change after verification and operations gates pass
argument-hint: "[change name]"
---

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/../specnav-core/scripts/plugin-suite.js" require --plugin specnav-core --plugin specnav-verification --plugin specnav-operations --json
node "$CLAUDE_PLUGIN_ROOT/scripts/archive-gate.js"
```

Archive only when both commands pass.
```

- [ ] **Step 8: Run the layout fixture**

Run:

```bash
chmod +x tests/run-plugin-suite-layout-fixtures.sh
bash tests/run-plugin-suite-layout-fixtures.sh
```

Expected:

```text
specnav plugin suite layout fixtures ok
```

- [ ] **Step 9: Commit**

```bash
git add .claude-plugin/marketplace.json plugins tests/run-plugin-suite-layout-fixtures.sh
git commit -m "feat: split specnav into plugin suite"
```

---

### Task 2: Suite Resolver In SpecNav Core

**Files:**
- Create: `plugins/specnav-core/scripts/plugin-suite.js`
- Test: `tests/run-plugin-suite-resolver-fixtures.sh`

- [ ] **Step 1: Write the failing resolver fixture**

Create `tests/run-plugin-suite-resolver-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

node "$ROOT/plugins/specnav-core/scripts/plugin-suite.js" list --marketplace-root "$ROOT" --json >/tmp/specnav-suite-list.json
jq -e '.ok == true' /tmp/specnav-suite-list.json >/dev/null
jq -e '.plugins | length == 6' /tmp/specnav-suite-list.json >/dev/null
jq -e '.plugins[] | select(.name == "specnav-core" and .stage == "core")' /tmp/specnav-suite-list.json >/dev/null
jq -e '.plugins[] | select(.name == "specnav-verification" and .stage == "verification")' /tmp/specnav-suite-list.json >/dev/null

node "$ROOT/plugins/specnav-core/scripts/plugin-suite.js" resolve --marketplace-root "$ROOT" --plugin specnav-requirements --json >/tmp/specnav-suite-requirements.json
jq -e '.ok == true' /tmp/specnav-suite-requirements.json >/dev/null
jq -e '.plugin.name == "specnav-requirements"' /tmp/specnav-suite-requirements.json >/dev/null
jq -e '.plugin.stage == "requirements"' /tmp/specnav-suite-requirements.json >/dev/null

node "$ROOT/plugins/specnav-core/scripts/plugin-suite.js" require --marketplace-root "$ROOT" --plugin specnav-core --plugin specnav-requirements --json >/tmp/specnav-suite-require.json
jq -e '.ok == true' /tmp/specnav-suite-require.json >/dev/null

set +e
node "$ROOT/plugins/specnav-core/scripts/plugin-suite.js" require --marketplace-root "$ROOT" --plugin specnav-missing --json >/tmp/specnav-suite-missing.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.ok == false' /tmp/specnav-suite-missing.json >/dev/null
jq -e '.blockers[] | select(. == "missing-plugin:specnav-missing")' /tmp/specnav-suite-missing.json >/dev/null

echo "specnav plugin suite resolver fixtures ok"
```

- [ ] **Step 2: Run the resolver fixture and verify it fails**

Run:

```bash
bash tests/run-plugin-suite-resolver-fixtures.sh
```

Expected: FAIL because `plugins/specnav-core/scripts/plugin-suite.js` does not exist.

- [ ] **Step 3: Create `plugins/specnav-core/scripts/plugin-suite.js`**

```js
#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

function readJson(file, fallback = null) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
}

function argValues(args, name) {
  const values = [];
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === name && args[i + 1]) values.push(args[i + 1]);
  }
  return values;
}

function argValue(args, name, fallback = null) {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : fallback;
}

function findMarketplaceRoot(start) {
  let current = path.resolve(start);
  while (true) {
    if (fs.existsSync(path.join(current, '.claude-plugin', 'marketplace.json'))) return current;
    const parent = path.dirname(current);
    if (parent === current) return null;
    current = parent;
  }
}

function loadMarketplace(root) {
  const marketplaceRoot = path.resolve(root || findMarketplaceRoot(process.cwd()) || process.cwd());
  const marketplaceFile = path.join(marketplaceRoot, '.claude-plugin', 'marketplace.json');
  const marketplace = readJson(marketplaceFile, null);
  if (!marketplace || !Array.isArray(marketplace.plugins)) {
    return { ok: false, marketplaceRoot, blockers: ['marketplace-json'] };
  }
  return { ok: true, marketplaceRoot, marketplace };
}

function pluginRecord(marketplaceRoot, entry) {
  const source = entry.source || './';
  const root = path.resolve(marketplaceRoot, source);
  const pluginJson = readJson(path.join(root, '.claude-plugin', 'plugin.json'), null);
  const stage = readJson(path.join(root, 'specnav-stage.json'), null);
  return {
    name: entry.name,
    source,
    root,
    version: entry.version || (pluginJson && pluginJson.version) || null,
    stage: stage && stage.stage,
    required: !!(stage && stage.required),
    commands: stage && stage.commands || [],
    skills: stage && stage.skills || [],
    contracts: stage && stage.contracts || {},
    ok: !!pluginJson && !!stage,
    blockers: [
      pluginJson ? null : `missing-plugin-json:${entry.name}`,
      stage ? null : `missing-stage-manifest:${entry.name}`
    ].filter(Boolean)
  };
}

function listPlugins(options = {}) {
  const loaded = loadMarketplace(options.marketplaceRoot);
  if (!loaded.ok) return { ok: false, blockers: loaded.blockers, marketplace_root: loaded.marketplaceRoot, plugins: [] };
  const plugins = loaded.marketplace.plugins.map((entry) => pluginRecord(loaded.marketplaceRoot, entry));
  const blockers = plugins.flatMap((plugin) => plugin.blockers);
  return {
    ok: blockers.length === 0,
    marketplace_root: loaded.marketplaceRoot,
    marketplace_name: loaded.marketplace.name || null,
    blockers,
    plugins
  };
}

function resolvePlugin(options = {}) {
  const suite = listPlugins(options);
  if (!suite.ok && !suite.plugins.length) return suite;
  const plugin = suite.plugins.find((item) => item.name === options.plugin);
  if (!plugin) {
    return {
      ok: false,
      marketplace_root: suite.marketplace_root,
      blockers: [`missing-plugin:${options.plugin}`],
      plugin: null
    };
  }
  return {
    ok: plugin.ok,
    marketplace_root: suite.marketplace_root,
    blockers: plugin.blockers,
    plugin
  };
}

function requirePlugins(options = {}) {
  const suite = listPlugins(options);
  const required = options.plugins || [];
  const blockers = [...suite.blockers];
  for (const name of required) {
    const plugin = suite.plugins.find((item) => item.name === name);
    if (!plugin) blockers.push(`missing-plugin:${name}`);
    else blockers.push(...plugin.blockers);
  }
  return {
    ok: blockers.length === 0,
    marketplace_root: suite.marketplace_root,
    blockers,
    required,
    plugins: suite.plugins.filter((item) => required.includes(item.name))
  };
}

function main() {
  const args = process.argv.slice(2);
  const command = args[0] || 'list';
  const marketplaceRoot = argValue(args, '--marketplace-root');
  let result;
  if (command === 'resolve') {
    result = resolvePlugin({ marketplaceRoot, plugin: argValue(args, '--plugin') });
  } else if (command === 'require') {
    result = requirePlugins({ marketplaceRoot, plugins: argValues(args, '--plugin') });
  } else {
    result = listPlugins({ marketplaceRoot });
  }
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = {
  findMarketplaceRoot,
  listPlugins,
  resolvePlugin,
  requirePlugins
};
```

- [ ] **Step 4: Run resolver fixture**

Run:

```bash
chmod +x tests/run-plugin-suite-resolver-fixtures.sh
bash tests/run-plugin-suite-resolver-fixtures.sh
```

Expected:

```text
specnav plugin suite resolver fixtures ok
```

- [ ] **Step 5: Commit**

```bash
git add plugins/specnav-core/scripts/plugin-suite.js tests/run-plugin-suite-resolver-fixtures.sh
git commit -m "feat: add specnav plugin suite resolver"
```

---

### Task 3: Core Plugin Runtime After Split

**Files:**
- Modify: `plugins/specnav-core/hooks/hooks.json`
- Modify: `plugins/specnav-core/commands/specnav.md`
- Modify: `plugins/specnav-core/commands/specnav-status.md`
- Modify: `plugins/specnav-core/commands/specnav-doctor.md`
- Modify: `plugins/specnav-core/skills/specnav-router/SKILL.md`
- Modify: `plugins/specnav-core/skills/status/SKILL.md`
- Modify: `plugins/specnav-core/skills/doctor/SKILL.md`
- Modify: `tests/run-smoke.sh`
- Modify: `tests/run-hook-fixtures.sh`

- [ ] **Step 1: Write the core runtime fixture**

Create `tests/run-core-runtime-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
PROJECT="$ROOT/tests/fixtures/simple-project"

grep -q 'specnav-core/scripts/specnav-session-start.js\\|CLAUDE_PLUGIN_ROOT/scripts/specnav-session-start.js' "$CORE/hooks/hooks.json"
grep -q 'plugin-suite.js' "$CORE/commands/specnav.md"
grep -q 'workflow-state.js' "$CORE/commands/specnav-status.md"
grep -q 'specnav-doctor.js' "$CORE/commands/specnav-doctor.md"
grep -q 'specnav-requirements' "$CORE/skills/specnav-router/SKILL.md"
grep -q 'specnav-verification' "$CORE/skills/specnav-router/SKILL.md"
grep -q 'specnav-operations' "$CORE/skills/specnav-router/SKILL.md"

PROJECT_DIR="$PROJECT" node "$CORE/scripts/affordances.js" --json >/tmp/specnav-core-affordances.json
jq -e '.active_change == "add-dark-mode"' /tmp/specnav-core-affordances.json >/dev/null

echo "specnav core runtime fixtures ok"
```

- [ ] **Step 2: Run the core runtime fixture**

Run:

```bash
bash tests/run-core-runtime-fixtures.sh
```

Expected: FAIL until root paths in tests and command text are changed to `plugins/specnav-core`.

- [ ] **Step 3: Update core router text**

In `plugins/specnav-core/commands/specnav.md`, replace the workflow instruction with:

```markdown
1. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --plugin specnav-core --json`.
2. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --markdown`.
3. Route by plugin:
   - requirements -> require `specnav-requirements`, then use `/specnav-requirements`
   - prototype -> require `specnav-prototype`, then use `/specnav-prototype`
   - development -> require `specnav-development`, then use `/specnav-implement`
   - verification -> require `specnav-verification`, then use `/specnav-verify`
   - operations/archive -> require `specnav-operations`, then use `/specnav-release` or `/specnav-archive`
4. If a required plugin is missing, report the `missing-plugin:<name>` blocker.
```

In `plugins/specnav-core/skills/specnav-router/SKILL.md`, replace the routing block with:

```markdown
## Plugin Routing

- INVESTIGATE / STATUS -> stay in `specnav-core`.
- DEFINE -> require `specnav-requirements`, then route to `/specnav-requirements`.
- PROTOTYPE -> require `specnav-prototype`, then route to `/specnav-prototype`.
- BUILD -> require `specnav-development`, then route to `/specnav-implement`.
- CHECK -> require `specnav-verification`, then route to `/specnav-verify`.
- FINISH / RELEASE / ARCHIVE -> require `specnav-operations`, then route to `/specnav-release` or `/specnav-archive`.

Run the suite check before handing off:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --plugin specnav-core --plugin <target-plugin> --json
```
```

- [ ] **Step 4: Update test paths**

In `tests/run-smoke.sh`, set:

```bash
CORE="$ROOT/plugins/specnav-core"
```

Replace script calls:

```bash
node "$CORE/scripts/affordances.js" --json "$FIXTURE" >/tmp/specnav-affordances.json
node "$CORE/scripts/risk-tier.js" --paths src/ui/theme.ts >/tmp/specnav-risk.json
PROJECT_DIR="$FIXTURE" node "$CORE/scripts/verify.js" >/tmp/specnav-verify.md
PROJECT_DIR="$FIXTURE" node "$CORE/scripts/archive-gate.js" >/tmp/specnav-archive.txt
PROJECT_DIR="$FIXTURE" node "$CORE/scripts/specnav-guard.js"
```

In `tests/run-hook-fixtures.sh`, set:

```bash
CORE="$ROOT/plugins/specnav-core"
```

Replace:

```bash
PROJECT_DIR="$project" node "$CORE/scripts/specnav-guard.js" <"$payload" >"$out" 2>"$err"
```

- [ ] **Step 5: Run fixtures**

Run:

```bash
chmod +x tests/run-core-runtime-fixtures.sh
bash tests/run-core-runtime-fixtures.sh
bash tests/run-smoke.sh
bash tests/run-hook-fixtures.sh
```

Expected:

```text
specnav core runtime fixtures ok
specnav smoke ok
specnav hook fixtures ok
```

- [ ] **Step 6: Commit**

```bash
git add plugins/specnav-core tests/run-core-runtime-fixtures.sh tests/run-smoke.sh tests/run-hook-fixtures.sh
git commit -m "feat: update core runtime for plugin suite"
```

---

### Task 4: Requirements Plugin

**Files:**
- Create: `plugins/specnav-requirements/scripts/foundation-specs.js`
- Create: `plugins/specnav-requirements/scripts/requirements-contract.js`
- Create: `plugins/specnav-requirements/skills/foundation-spec/SKILL.md`
- Create: `plugins/specnav-requirements/skills/requirements/SKILL.md`
- Modify: `plugins/specnav-requirements/commands/specnav-requirements.md`
- Test: `tests/run-requirements-plugin-fixtures.sh`

- [ ] **Step 1: Write the requirements plugin fixture**

Create `tests/run-requirements-plugin-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REQ="$ROOT/plugins/specnav-requirements"
PROJECT="$ROOT/tests/fixtures/simple-project"

test -f "$REQ/scripts/foundation-specs.js"
test -f "$REQ/scripts/requirements-contract.js"
test -f "$REQ/skills/foundation-spec/SKILL.md"
test -f "$REQ/skills/requirements/SKILL.md"
grep -q 'specnav-requirements' "$REQ/commands/specnav-requirements.md"

set +e
PROJECT_DIR="$PROJECT" node "$REQ/scripts/requirements-contract.js" --json >/tmp/specnav-req-contract.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.ok == false' /tmp/specnav-req-contract.json >/dev/null

echo "specnav requirements plugin fixtures ok"
```

- [ ] **Step 2: Run the fixture and verify it fails**

Run:

```bash
bash tests/run-requirements-plugin-fixtures.sh
```

Expected: FAIL because requirements plugin scripts and skills are not yet present.

- [ ] **Step 3: Move or create requirements scripts**

Create `plugins/specnav-requirements/scripts/requirements-contract.js` with the complete implementation from the prior requirements contract plan. It must export:

```js
module.exports = { validateRequirements };
```

Create `plugins/specnav-requirements/scripts/foundation-specs.js` with the complete implementation from the foundation spec gate plan. It must export:

```js
module.exports = { validateFoundationSpecs, validateOne, markdown };
```

When these scripts need shared helpers, import them from core through an explicit path:

```js
const coreLib = require('../../specnav-core/scripts/specnav-lib');
const contracts = require('../../specnav-core/scripts/contracts');
```

- [ ] **Step 4: Create requirements skills**

Write `plugins/specnav-requirements/skills/foundation-spec/SKILL.md`:

```markdown
---
name: foundation-spec
description: Create or repair SpecNav project-level foundation specs before requirements work
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# Foundation Spec

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/foundation-specs.js" --json
```

If a required spec is missing, create that exact spec. If a required spec is invalid, repair only the missing sections or frontmatter keys reported by the validator.
```

Write `plugins/specnav-requirements/skills/requirements/SKILL.md`:

```markdown
---
name: requirements
description: Discover SpecNav requirements after foundation specs pass
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Requirements

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/foundation-specs.js" --json
```

Read all four foundation specs before asking product questions. Ask one focused question at a time. Write `requirements.md`, `acceptance.md`, `spec-map.json`, and `component-impact-map.json`.

Then run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/requirements-contract.js" --json
```
```

- [ ] **Step 5: Run requirements plugin fixture**

Run:

```bash
chmod +x tests/run-requirements-plugin-fixtures.sh
bash tests/run-requirements-plugin-fixtures.sh
```

Expected:

```text
specnav requirements plugin fixtures ok
```

- [ ] **Step 6: Commit**

```bash
git add plugins/specnav-requirements tests/run-requirements-plugin-fixtures.sh
git commit -m "feat: add requirements stage plugin"
```

---

### Task 5: Prototype Plugin

**Files:**
- Create: `plugins/specnav-prototype/scripts/prototype-contract.js`
- Create: `plugins/specnav-prototype/skills/prototype/SKILL.md`
- Create: `plugins/specnav-prototype/skills/prototype-verify/SKILL.md`
- Create: `plugins/specnav-prototype/skills/prototype-handoff/SKILL.md`
- Modify: `plugins/specnav-prototype/commands/specnav-prototype.md`
- Test: `tests/run-prototype-plugin-fixtures.sh`

- [ ] **Step 1: Write the prototype plugin fixture**

Create `tests/run-prototype-plugin-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROTO="$ROOT/plugins/specnav-prototype"
PROJECT="$ROOT/tests/fixtures/simple-project"

test -f "$PROTO/scripts/prototype-contract.js"
test -f "$PROTO/skills/prototype/SKILL.md"
test -f "$PROTO/skills/prototype-verify/SKILL.md"
test -f "$PROTO/skills/prototype-handoff/SKILL.md"
grep -q 'specnav-prototype' "$PROTO/commands/specnav-prototype.md"

set +e
PROJECT_DIR="$PROJECT" node "$PROTO/scripts/prototype-contract.js" --json >/tmp/specnav-prototype-contract.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.ok == false' /tmp/specnav-prototype-contract.json >/dev/null

echo "specnav prototype plugin fixtures ok"
```

- [ ] **Step 2: Run fixture and verify it fails**

Run:

```bash
bash tests/run-prototype-plugin-fixtures.sh
```

Expected: FAIL until prototype plugin scripts and skills are present.

- [ ] **Step 3: Create prototype contract**

Create `plugins/specnav-prototype/scripts/prototype-contract.js` with the complete prototype contract implementation. It must import shared helpers through:

```js
const lib = require('../../specnav-core/scripts/specnav-lib');
const contracts = require('../../specnav-core/scripts/contracts');
```

It must export:

```js
module.exports = { validatePrototype };
```

- [ ] **Step 4: Create prototype skills**

Write `plugins/specnav-prototype/skills/prototype/SKILL.md`, `plugins/specnav-prototype/skills/prototype-verify/SKILL.md`, and `plugins/specnav-prototype/skills/prototype-handoff/SKILL.md` using the prototype stage contract from `docs/design.md`. Each skill must run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json
```

- [ ] **Step 5: Run prototype fixture**

Run:

```bash
chmod +x tests/run-prototype-plugin-fixtures.sh
bash tests/run-prototype-plugin-fixtures.sh
```

Expected:

```text
specnav prototype plugin fixtures ok
```

- [ ] **Step 6: Commit**

```bash
git add plugins/specnav-prototype tests/run-prototype-plugin-fixtures.sh
git commit -m "feat: add prototype stage plugin"
```

---

### Task 6: Development Plugin

**Files:**
- Create: `plugins/specnav-development/scripts/development-contract.js`
- Create: `plugins/specnav-development/skills/before-dev/SKILL.md`
- Create: `plugins/specnav-development/skills/scope-lock/SKILL.md`
- Create: `plugins/specnav-development/skills/vertical-slice-tasking/SKILL.md`
- Modify: `plugins/specnav-development/commands/specnav-implement.md`
- Test: `tests/run-development-plugin-fixtures.sh`

- [ ] **Step 1: Write development plugin fixture**

Create `tests/run-development-plugin-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEV="$ROOT/plugins/specnav-development"
PROJECT="$ROOT/tests/fixtures/simple-project"

test -f "$DEV/scripts/development-contract.js"
test -f "$DEV/skills/before-dev/SKILL.md"
test -f "$DEV/skills/scope-lock/SKILL.md"
test -f "$DEV/skills/vertical-slice-tasking/SKILL.md"
grep -q 'specnav-development' "$DEV/commands/specnav-implement.md"

set +e
PROJECT_DIR="$PROJECT" node "$DEV/scripts/development-contract.js" --json >/tmp/specnav-development-contract.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.ok == false' /tmp/specnav-development-contract.json >/dev/null

echo "specnav development plugin fixtures ok"
```

- [ ] **Step 2: Run fixture and verify it fails**

Run:

```bash
bash tests/run-development-plugin-fixtures.sh
```

Expected: FAIL until development plugin files are present.

- [ ] **Step 3: Create development contract**

Create `plugins/specnav-development/scripts/development-contract.js` with the development contract implementation from the design. It must import shared helpers through:

```js
const lib = require('../../specnav-core/scripts/specnav-lib');
const contracts = require('../../specnav-core/scripts/contracts');
```

It must export:

```js
module.exports = { validateDevelopment };
```

- [ ] **Step 4: Create development skills**

Write:

- `plugins/specnav-development/skills/before-dev/SKILL.md`
- `plugins/specnav-development/skills/scope-lock/SKILL.md`
- `plugins/specnav-development/skills/vertical-slice-tasking/SKILL.md`

Each skill must run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --json
```

- [ ] **Step 5: Run development fixture**

Run:

```bash
chmod +x tests/run-development-plugin-fixtures.sh
bash tests/run-development-plugin-fixtures.sh
```

Expected:

```text
specnav development plugin fixtures ok
```

- [ ] **Step 6: Commit**

```bash
git add plugins/specnav-development tests/run-development-plugin-fixtures.sh
git commit -m "feat: add development stage plugin"
```

---

### Task 7: Verification Plugin

**Files:**
- Create: `plugins/specnav-verification/scripts/verify-domains.js`
- Create seven verification skills under `plugins/specnav-verification/skills/`
- Modify: `plugins/specnav-verification/commands/specnav-verify.md`
- Test: `tests/run-verification-plugin-fixtures.sh`

- [ ] **Step 1: Write verification plugin fixture**

Create `tests/run-verification-plugin-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERIFY="$ROOT/plugins/specnav-verification"
PROJECT="$ROOT/tests/fixtures/simple-project"

test -f "$VERIFY/scripts/verify-domains.js"
for skill in verify-plan verify-facticity verify-static verify-unit verify-redteam verify-e2e verify-sensory; do
  test -f "$VERIFY/skills/$skill/SKILL.md"
  grep -q "name: $skill" "$VERIFY/skills/$skill/SKILL.md"
done
grep -q 'specnav-verification' "$VERIFY/commands/specnav-verify.md"

set +e
PROJECT_DIR="$PROJECT" node "$VERIFY/scripts/verify-domains.js" validate --json >/tmp/specnav-verification-contract.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.ok == false' /tmp/specnav-verification-contract.json >/dev/null

echo "specnav verification plugin fixtures ok"
```

- [ ] **Step 2: Run fixture and verify it fails**

Run:

```bash
bash tests/run-verification-plugin-fixtures.sh
```

Expected: FAIL until verification plugin files are present.

- [ ] **Step 3: Create verification contract**

Create `plugins/specnav-verification/scripts/verify-domains.js` with the six-domain contract implementation. It must import shared helpers through:

```js
const lib = require('../../specnav-core/scripts/specnav-lib');
const contracts = require('../../specnav-core/scripts/contracts');
```

It must export:

```js
module.exports = { validateVerify, writeAggregate };
```

- [ ] **Step 4: Create verification skills**

Create these files:

- `plugins/specnav-verification/skills/verify-plan/SKILL.md`
- `plugins/specnav-verification/skills/verify-facticity/SKILL.md`
- `plugins/specnav-verification/skills/verify-static/SKILL.md`
- `plugins/specnav-verification/skills/verify-unit/SKILL.md`
- `plugins/specnav-verification/skills/verify-redteam/SKILL.md`
- `plugins/specnav-verification/skills/verify-e2e/SKILL.md`
- `plugins/specnav-verification/skills/verify-sensory/SKILL.md`

Each domain skill writes exactly one domain report under `openspec/changes/<change>/verify/<domain>/report.json`. `verify-unit` also writes `unit/test-quality-rubric.json`. `verify-sensory` also writes `sensory/reviewer-independence.md`.

- [ ] **Step 5: Run verification fixture**

Run:

```bash
chmod +x tests/run-verification-plugin-fixtures.sh
bash tests/run-verification-plugin-fixtures.sh
```

Expected:

```text
specnav verification plugin fixtures ok
```

- [ ] **Step 6: Commit**

```bash
git add plugins/specnav-verification tests/run-verification-plugin-fixtures.sh
git commit -m "feat: add verification stage plugin"
```

---

### Task 8: Operations Plugin

**Files:**
- Create: `plugins/specnav-operations/scripts/operations-gate.js`
- Create: `plugins/specnav-operations/scripts/archive-gate.js`
- Create ten operations skills under `plugins/specnav-operations/skills/`
- Modify: `plugins/specnav-operations/commands/specnav-release.md`
- Modify: `plugins/specnav-operations/commands/specnav-archive.md`
- Test: `tests/run-operations-plugin-fixtures.sh`

- [ ] **Step 1: Write operations plugin fixture**

Create `tests/run-operations-plugin-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPS="$ROOT/plugins/specnav-operations"
PROJECT="$ROOT/tests/fixtures/simple-project"

test -f "$OPS/scripts/operations-gate.js"
test -f "$OPS/scripts/archive-gate.js"
for skill in ops-readiness release-plan install-verify update-policy compatibility-matrix branch-finish deploy rollback monitor postmortem update-spec; do
  test -f "$OPS/skills/$skill/SKILL.md"
  grep -q "name: $skill" "$OPS/skills/$skill/SKILL.md"
done
grep -q 'specnav-operations' "$OPS/commands/specnav-release.md"
grep -q 'archive-gate.js' "$OPS/commands/specnav-archive.md"

set +e
PROJECT_DIR="$PROJECT" node "$OPS/scripts/operations-gate.js" --json >/tmp/specnav-operations-contract.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.ok == false' /tmp/specnav-operations-contract.json >/dev/null

echo "specnav operations plugin fixtures ok"
```

- [ ] **Step 2: Run fixture and verify it fails**

Run:

```bash
bash tests/run-operations-plugin-fixtures.sh
```

Expected: FAIL until operations plugin files are present.

- [ ] **Step 3: Create operations scripts**

Create `plugins/specnav-operations/scripts/operations-gate.js` with the operations readiness contract. It must import:

```js
const lib = require('../../specnav-core/scripts/specnav-lib');
const contracts = require('../../specnav-core/scripts/contracts');
```

It must export:

```js
module.exports = { validateOperations };
```

Create `plugins/specnav-operations/scripts/archive-gate.js` with archive gating that calls `validateOperations(root)` before archive passes.

- [ ] **Step 4: Create operations skills**

Create:

- `plugins/specnav-operations/skills/ops-readiness/SKILL.md`
- `plugins/specnav-operations/skills/release-plan/SKILL.md`
- `plugins/specnav-operations/skills/install-verify/SKILL.md`
- `plugins/specnav-operations/skills/update-policy/SKILL.md`
- `plugins/specnav-operations/skills/compatibility-matrix/SKILL.md`
- `plugins/specnav-operations/skills/branch-finish/SKILL.md`
- `plugins/specnav-operations/skills/deploy/SKILL.md`
- `plugins/specnav-operations/skills/rollback/SKILL.md`
- `plugins/specnav-operations/skills/monitor/SKILL.md`
- `plugins/specnav-operations/skills/postmortem/SKILL.md`
- `plugins/specnav-operations/skills/update-spec/SKILL.md`

Each skill writes only its own `openspec/changes/<change>/operations/` artifact and then runs:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```

- [ ] **Step 5: Run operations fixture**

Run:

```bash
chmod +x tests/run-operations-plugin-fixtures.sh
bash tests/run-operations-plugin-fixtures.sh
```

Expected:

```text
specnav operations plugin fixtures ok
```

- [ ] **Step 6: Commit**

```bash
git add plugins/specnav-operations tests/run-operations-plugin-fixtures.sh
git commit -m "feat: add operations stage plugin"
```

---

### Task 9: Cross-Plugin Workflow State

**Files:**
- Modify: `plugins/specnav-core/scripts/workflow-state.js`
- Modify: `plugins/specnav-core/scripts/affordances.js`
- Modify: `plugins/specnav-core/scripts/specnav-doctor.js`
- Test: `tests/run-cross-plugin-state-fixtures.sh`

- [ ] **Step 1: Write cross-plugin state fixture**

Create `tests/run-cross-plugin-state-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
PROJECT="$ROOT/tests/fixtures/simple-project"

PROJECT_DIR="$PROJECT" node "$CORE/scripts/workflow-state.js" --write --json >/tmp/specnav-cross-state.json
jq -e '.plugin_suite.ok == true' /tmp/specnav-cross-state.json >/dev/null
jq -e '.plugin_suite.plugins[] | select(.name == "specnav-core")' /tmp/specnav-cross-state.json >/dev/null
jq -e '.plugin_suite.plugins[] | select(.name == "specnav-requirements")' /tmp/specnav-cross-state.json >/dev/null

PROJECT_DIR="$PROJECT" node "$CORE/scripts/affordances.js" --json >/tmp/specnav-cross-affordances.json
jq -e '.required_plugins[] | select(. == "specnav-core")' /tmp/specnav-cross-affordances.json >/dev/null
jq -e '.required_plugins[] | select(. == "specnav-verification")' /tmp/specnav-cross-affordances.json >/dev/null

node "$CORE/scripts/specnav-doctor.js" --marketplace-root "$ROOT" --json >/tmp/specnav-cross-doctor.json
jq -e '.suite.ok == true' /tmp/specnav-cross-doctor.json >/dev/null
jq -e '.suite.plugins | length == 6' /tmp/specnav-cross-doctor.json >/dev/null

echo "specnav cross-plugin state fixtures ok"
```

- [ ] **Step 2: Run fixture and verify it fails**

Run:

```bash
bash tests/run-cross-plugin-state-fixtures.sh
```

Expected: FAIL until core state and doctor include suite metadata.

- [ ] **Step 3: Include suite metadata in workflow state**

In `plugins/specnav-core/scripts/workflow-state.js`, import:

```js
const suite = require('./plugin-suite');
```

Add to the returned state object:

```js
plugin_suite: suite.listPlugins({ marketplaceRoot: process.env.SPECNAV_MARKETPLACE_ROOT || path.resolve(__dirname, '../../..') })
```

When a legal action requires a missing plugin, add `missing-plugin:<name>` to that action's blockers.

- [ ] **Step 4: Include required plugin list in affordances**

In `plugins/specnav-core/scripts/affordances.js`, add:

```js
required_plugins: ['specnav-core', 'specnav-requirements', 'specnav-prototype', 'specnav-development', 'specnav-verification', 'specnav-operations']
```

Add each action's required plugin:

```js
const actionPlugins = {
  requirements: ['specnav-core', 'specnav-requirements'],
  prototype: ['specnav-core', 'specnav-requirements', 'specnav-prototype'],
  implement: ['specnav-core', 'specnav-development'],
  verify: ['specnav-core', 'specnav-verification'],
  release: ['specnav-core', 'specnav-operations'],
  archive: ['specnav-core', 'specnav-operations']
};
```

- [ ] **Step 5: Include suite metadata in doctor**

In `plugins/specnav-core/scripts/specnav-doctor.js`, add:

```js
const suite = require('./plugin-suite');
```

Add:

```js
const suiteStatus = suite.listPlugins({ marketplaceRoot: options.marketplaceRoot || path.resolve(pluginRoot, '../..') });
checks.push(check('plugin-suite', suiteStatus.ok, suiteStatus.blockers.join(', ')));
```

Add to doctor JSON:

```js
suite: suiteStatus
```

- [ ] **Step 6: Run cross-plugin state fixture**

Run:

```bash
chmod +x tests/run-cross-plugin-state-fixtures.sh
bash tests/run-cross-plugin-state-fixtures.sh
```

Expected:

```text
specnav cross-plugin state fixtures ok
```

- [ ] **Step 7: Commit**

```bash
git add plugins/specnav-core/scripts/workflow-state.js plugins/specnav-core/scripts/affordances.js plugins/specnav-core/scripts/specnav-doctor.js tests/run-cross-plugin-state-fixtures.sh
git commit -m "feat: add cross-plugin suite state"
```

---

### Task 10: Full Suite Test Runner And Documentation

**Files:**
- Create: `tests/run-all.sh`
- Modify: `README.md`
- Create: `README.zh-CN.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/design.md`
- Modify: `docs/specnav-plan-review.html`

- [ ] **Step 1: Create full suite runner**

Create `tests/run-all.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

bash "$ROOT/tests/run-plugin-suite-layout-fixtures.sh"
bash "$ROOT/tests/run-plugin-suite-resolver-fixtures.sh"
bash "$ROOT/tests/run-core-runtime-fixtures.sh"
bash "$ROOT/tests/run-requirements-plugin-fixtures.sh"
bash "$ROOT/tests/run-prototype-plugin-fixtures.sh"
bash "$ROOT/tests/run-development-plugin-fixtures.sh"
bash "$ROOT/tests/run-verification-plugin-fixtures.sh"
bash "$ROOT/tests/run-operations-plugin-fixtures.sh"
bash "$ROOT/tests/run-cross-plugin-state-fixtures.sh"
bash "$ROOT/tests/run-smoke.sh"
bash "$ROOT/tests/run-hook-fixtures.sh"

echo "specnav plugin suite full fixtures ok"
```

- [ ] **Step 2: Run full suite**

Run:

```bash
chmod +x tests/run-all.sh
bash tests/run-all.sh
```

Expected:

```text
specnav plugin suite full fixtures ok
```

- [ ] **Step 3: Document plugin suite installation**

In `README.md`, add:

```markdown
## Plugin Suite

SpecNav is a Claude Code marketplace containing six plugins:

- `specnav-core`
- `specnav-requirements`
- `specnav-prototype`
- `specnav-development`
- `specnav-verification`
- `specnav-operations`

Install from the marketplace root so Claude Code can see every plugin:

```bash
claude plugin marketplace add /path/to/specnav-claude-plugin --scope user
claude plugin install specnav-core@specnav-marketplace --scope user
claude plugin install specnav-requirements@specnav-marketplace --scope user
claude plugin install specnav-prototype@specnav-marketplace --scope user
claude plugin install specnav-development@specnav-marketplace --scope user
claude plugin install specnav-verification@specnav-marketplace --scope user
claude plugin install specnav-operations@specnav-marketplace --scope user
```

`specnav-core` is required. Stage plugins block their own commands if `specnav-core` is missing.
```

In `README.zh-CN.md`, add:

```markdown
## 插件套件

SpecNav 是一个 Claude Code marketplace，内部包含六个插件：

- `specnav-core`
- `specnav-requirements`
- `specnav-prototype`
- `specnav-development`
- `specnav-verification`
- `specnav-operations`

必须从 marketplace 根目录安装，让 Claude Code 能发现所有插件。

`specnav-core` 是必需插件。阶段插件发现 `specnav-core` 缺失时必须阻断，不允许 fallback。
```

- [ ] **Step 4: Update design docs**

In `docs/design.md`, add a section named `Plugin Suite Architecture` and include the six-plugin table from this plan.

In `docs/specnav-plan-review.html`, add a visible review section named `插件套件架构` with the same six plugin boundaries.

- [ ] **Step 5: Run doc and hygiene checks**

Run:

```bash
bash tests/run-all.sh
git diff --check
rg -n "specnav-core|specnav-requirements|specnav-prototype|specnav-development|specnav-verification|specnav-operations" README.md README.zh-CN.md docs/design.md docs/specnav-plan-review.html
```

Expected:

- full suite passes;
- `git diff --check` prints nothing;
- all six plugin names appear in README and design docs.

- [ ] **Step 6: Commit**

```bash
git add tests/run-all.sh README.md README.zh-CN.md CHANGELOG.md docs/design.md docs/specnav-plan-review.html
git commit -m "docs: document specnav plugin suite"
```

---

## Self-Review

### Spec Coverage

- Multi-plugin marketplace repository: Tasks 1 and 2.
- `specnav-core` required runtime and hooks: Tasks 1, 2, 3, and 9.
- Requirements phase as a plugin: Task 4.
- Prototype phase as a plugin: Task 5.
- Development phase as a plugin: Task 6.
- Verification phase as a plugin with six domain skills: Task 7.
- Operations phase as a plugin: Task 8.
- Cross-plugin state, doctor, and blockers: Task 9.
- Suite install docs and review docs: Task 10.

### Placeholder Scan

Checked this plan against the prohibited placeholder patterns from the writing-plans skill. Implementation steps define exact files, commands, expected outputs, and concrete content.

### Type And Name Consistency

Plugin names:

- `specnav-core`
- `specnav-requirements`
- `specnav-prototype`
- `specnav-development`
- `specnav-verification`
- `specnav-operations`

Manifest schema:

- `specnav.stagePlugin.v1`

Core suite APIs:

- `listPlugins(options)`
- `resolvePlugin(options)`
- `requirePlugins(options)`
