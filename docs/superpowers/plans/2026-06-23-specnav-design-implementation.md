# SpecNav Design Implementation Plan

> Superseded by `docs/superpowers/plans/2026-06-23-specnav-plugin-suite-implementation.md`. This earlier draft treated SpecNav too much like one plugin with multi-plugin repository support. The accepted architecture is a marketplace repository containing multiple SpecNav lifecycle plugins.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the SpecNav Claude Code plugin described in `docs/design.md`: a no-fallback OpenSpec lifecycle plugin covering requirements, prototype, development, six-domain verification, operations, doctor, archive, and bilingual docs.

**Architecture:** Keep the current CommonJS script architecture and grow it through small contract modules under `scripts/`. `scripts/specnav-lib.js` remains the shared filesystem/runtime utility layer; new lifecycle scripts produce machine-readable artifacts, and existing hooks/commands/skills call those contracts instead of inferring state from chat. Plugin installation code must distinguish marketplace repository root from individual plugin root because a Claude Code plugin repository can contain multiple plugins.

**Tech Stack:** Node.js CommonJS scripts using only built-in modules, Bash fixture tests, jq assertions, Claude Code plugin commands/skills/hooks, OpenSpec project files under `openspec/`.

---

## Scope Check

The design document covers multiple subsystems: state machine, hooks, requirements, prototype, development, verification, operations, doctor, skills, commands, README, and tests. This plan keeps them in one master implementation plan because the lifecycle gates depend on each other, but each task below is a separately testable slice with its own files, commands, and commit.

## Plugin Repository Topology

Claude Code plugin distribution has two roots that must not be conflated:

- `marketplace_root`: the repository root that contains `.claude-plugin/marketplace.json`.
- `plugin_root`: the individual plugin source directory referenced by `marketplace.json.plugins[].source`.

This repo currently uses the single-plugin shape:

```text
repo/
  .claude-plugin/
    marketplace.json   # plugins[0].source == "./"
    plugin.json
  commands/
  skills/
  scripts/
```

The implementation must also support a multi-plugin repository:

```text
repo/
  .claude-plugin/
    marketplace.json   # plugins[].source points to each plugin directory
  plugins/
    specnav/
      .claude-plugin/
        plugin.json
      commands/
      skills/
      hooks/
      scripts/
    other-plugin/
      .claude-plugin/
        plugin.json
```

All doctor, install verification, release packaging, and host compatibility checks resolve the plugin root through marketplace metadata. They must not assume the repository root is the SpecNav plugin root.

## File Structure

Create and modify these files:

- `scripts/plugin-repository.js`: resolves marketplace root, plugin name, plugin source, plugin root, and single-plugin compatibility.
- `scripts/contracts.js`: shared lifecycle constants, required artifact paths, JSON read/write assertions, blocker result helpers.
- `scripts/foundation-specs.js`: validates the four project-level foundation specs and emits structured blockers.
- `scripts/workflow-state.js`: builds `openspec/.specnav/workflow-state.json` and legal action tables.
- `scripts/prototype-contract.js`: validates prototype artifacts before development.
- `scripts/development-contract.js`: validates `scope.json`, task artifacts, review loop artifacts, and development handoff.
- `scripts/verify-domains.js`: writes and validates six-domain verification plan/report artifacts.
- `scripts/operations-gate.js`: validates readiness, release, deploy, rollback, monitor, update, branch finish, postmortem, and archive artifacts.
- `scripts/specnav-doctor.js`: verifies plugin install surface, hooks, scripts, OpenSpec, state, context manifests, and JSON health output.
- `scripts/specnav-lib.js`: add path helpers, strict OpenSpec detection, JSONL writer, Markdown section helpers, and git state helper.
- `scripts/affordances.js`: replace filesystem fallback logic with workflow-state driven affordances.
- `scripts/specnav-guard.js`: enforce no-fallback production write blocking through contracts.
- `scripts/specnav-session-start.js`: run lightweight OpenSpec/doctor detection on every session.
- `scripts/verify.js`: orchestrate six-domain verification instead of one flat report.
- `scripts/archive-gate.js`: require verification and operations completion before archive.
- `hooks/hooks.json`: add supported prompt/session checks and route to the stricter scripts.
- `commands/specnav-requirements.md`, `commands/specnav-prototype.md`, `commands/specnav-implement.md`, `commands/specnav-release.md`, `commands/specnav-doctor.md`: new stage commands.
- Existing `commands/specnav.md`, `commands/specnav-status.md`, `commands/specnav-verify.md`, `commands/specnav-archive.md`: update routing and blockers.
- New skills under `skills/`: `using-specnav`, `requirements`, `foundation-spec`, `prototype`, `prototype-verify`, `prototype-handoff`, `before-dev`, `scope-lock`, `vertical-slice-tasking`, `verify-plan`, six `verify-*` skills, `ops-readiness`, `release-plan`, `install-verify`, `update-policy`, `compatibility-matrix`, `branch-finish`, `deploy`, `rollback`, `monitor`, `postmortem`, `update-spec`, `doctor`, `debug`, `break-loop`.
- `README.md`: English README.
- `README.zh-CN.md`: Chinese README.
- `docs/design.md`: keep design aligned only when implementation reveals a contract mismatch.
- `docs/specnav-plan-review.html`: update only when major plan sections change.
- New fixture scripts under `tests/`: one script per contract slice.
- New fixtures under `tests/fixtures/`: focused valid and invalid OpenSpec/SpecNav projects.

## Execution Rules

- Keep every task commit-sized.
- Run the task-specific fixture before committing.
- Run the broader smoke suite after every third task.
- Do not delete user changes or ignored reference repositories.
- Do not assume `repo root == plugin root`; use `scripts/plugin-repository.js` for install, doctor, release, and compatibility checks.
- Do not introduce runtime dependencies unless a task explicitly edits package metadata; this plan uses Node built-ins only.

---

### Task 1: Shared Contract Helpers

**Files:**
- Create: `scripts/contracts.js`
- Modify: `scripts/specnav-lib.js`
- Test: `tests/run-contract-fixtures.sh`

- [ ] **Step 1: Write the failing contract fixture**

Create `tests/run-contract-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/openspec/.specnav"

node - <<'NODE' "$ROOT" "$TMP"
const assert = require('assert');
const path = require('path');
const root = process.argv[3];
const contracts = require(path.join(process.argv[2], 'scripts/contracts'));

assert.deepStrictEqual(contracts.REQUIRED_FOUNDATION_SPECS.map((item) => item.id), [
  'ui-design',
  'system-architecture',
  'frontend-backend-data-flow',
  'component-architecture'
]);

const ok = contracts.pass('sample', { value: 1 });
assert.strictEqual(ok.ok, true);
assert.strictEqual(ok.gate, 'sample');
assert.strictEqual(ok.value, 1);

const blocked = contracts.block('sample', ['missing-a', 'missing-b'], { active_change: 'x' });
assert.strictEqual(blocked.ok, false);
assert.deepStrictEqual(blocked.blockers, ['missing-a', 'missing-b']);
assert.strictEqual(blocked.active_change, 'x');

const contextPath = contracts.contextManifestPath(root, 'verify');
assert.strictEqual(contextPath.endsWith('openspec/.specnav/context/verify-context.jsonl'), true);

console.log('contract helper fixture ok');
NODE
```

- [ ] **Step 2: Run the fixture and verify it fails**

Run:

```bash
bash tests/run-contract-fixtures.sh
```

Expected: FAIL with `Cannot find module` for `scripts/contracts`.

- [ ] **Step 3: Create `scripts/contracts.js`**

```js
#!/usr/bin/env node
'use strict';

const path = require('path');

const REQUIRED_FOUNDATION_SPECS = [
  {
    id: 'ui-design',
    path: 'openspec/specs/ui-design/design.md',
    title: 'UI Design Spec',
    requiredSections: [
      '# ',
      '## Overview',
      '## Colors',
      '## Typography',
      '## Layout',
      '## Elevation & Depth',
      '## Motion',
      '## Shapes',
      '## Components',
      '## Voice & Content',
      "## Do's and Don'ts"
    ],
    requiredFrontmatterKeys: ['version', 'name', 'description', 'colors', 'typography', 'spacing', 'rounded', 'components']
  },
  {
    id: 'system-architecture',
    path: 'openspec/specs/system-architecture/design.md',
    title: 'System Architecture & Database Spec',
    requiredSections: [
      '# System Architecture & Database Spec',
      '## Overview',
      '## Application Topology',
      '## Module Boundaries',
      '## Frontend Architecture',
      '## Backend Architecture',
      '## API Surface',
      '## Database Model',
      '## Permissions & Security',
      '## Integration Boundaries',
      '## Operational Constraints',
      "## Architecture Do's and Don'ts"
    ],
    requiredFrontmatterKeys: []
  },
  {
    id: 'frontend-backend-data-flow',
    path: 'openspec/specs/frontend-backend-data-flow/design.md',
    title: 'Frontend-Backend Data Flow Spec',
    requiredSections: [
      '# Frontend-Backend Data Flow Spec',
      '## Overview',
      '## Flow Index',
      '## Boundary Contracts',
      '## State Ownership',
      '## Validation Ownership',
      '## Error & Empty States',
      '## Loading / Optimistic / Retry Behavior',
      '## End-to-End Flow Details',
      '## Async / Realtime Flows',
      "## Flow Do's and Don'ts"
    ],
    requiredFrontmatterKeys: []
  },
  {
    id: 'component-architecture',
    path: 'openspec/specs/component-architecture/design.md',
    title: 'Component Architecture & Reuse Spec',
    requiredSections: [
      '# Component Architecture & Reuse Spec',
      '## Overview',
      '## Component Taxonomy',
      '## Cohesion Rules',
      '## Coupling Rules',
      '## Shared Component Extraction Rules',
      '## Component Public API Rules',
      '## State Ownership Rules',
      '## Composition Patterns',
      '## File & Naming Conventions',
      '## Testing Expectations',
      '## Refactor Triggers',
      "## Component Do's and Don'ts"
    ],
    requiredFrontmatterKeys: []
  }
];

const LIFECYCLE_STATES = [
  'no_openspec',
  'initialized',
  'requirements',
  'prototype',
  'development',
  'verification',
  'operations',
  'archived'
];

const VERIFY_DOMAINS = ['facticity', 'static', 'unit', 'redteam', 'e2e', 'sensory'];

const RELEASE_TARGETS = ['local-only', 'plugin-marketplace', 'package', 'host-compatibility', 'project-deploy'];

function pass(gate, fields = {}) {
  return { ok: true, gate, blockers: [], ...fields };
}

function block(gate, blockers, fields = {}) {
  const list = Array.isArray(blockers) ? blockers : [String(blockers)];
  return { ok: false, gate, blockers: list.filter(Boolean), ...fields };
}

function changeArtifact(root, change, relativePath) {
  return path.join(root, 'openspec', 'changes', change || '', relativePath);
}

function specnavStatePath(root, relativePath) {
  return path.join(root, 'openspec', '.specnav', relativePath);
}

function contextManifestPath(root, stage) {
  return specnavStatePath(root, path.join('context', `${stage}-context.jsonl`));
}

module.exports = {
  LIFECYCLE_STATES,
  RELEASE_TARGETS,
  REQUIRED_FOUNDATION_SPECS,
  VERIFY_DOMAINS,
  block,
  changeArtifact,
  contextManifestPath,
  specnavStatePath,
  pass
};
```

- [ ] **Step 4: Extend `scripts/specnav-lib.js` with focused helpers**

Add these functions before `module.exports`:

```js
function appendJsonl(file, value) {
  ensureDir(path.dirname(file));
  fs.appendFileSync(file, `${JSON.stringify(value)}\n`);
}

function markdownHasSection(text, heading) {
  if (heading === '# ') return /^#\s+\S+/m.test(text);
  const escaped = heading.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`^${escaped}\\s*$`, 'm').test(text);
}

function parseYamlFrontmatterKeys(text) {
  if (!text.startsWith('---\n')) return [];
  const end = text.indexOf('\n---', 4);
  if (end < 0) return [];
  return text
    .slice(4, end)
    .split(/\r?\n/)
    .map((line) => line.match(/^([A-Za-z0-9_-]+):/))
    .filter(Boolean)
    .map((match) => match[1]);
}

function gitState(root) {
  const branch = runCommand('git branch --show-current', { cwd: root, timeoutMs: 10000 });
  const gitDir = runCommand('git rev-parse --git-dir', { cwd: root, timeoutMs: 10000 });
  const commonDir = runCommand('git rev-parse --git-common-dir', { cwd: root, timeoutMs: 10000 });
  const porcelain = runCommand('git status --porcelain=v1', { cwd: root, timeoutMs: 10000 });
  return {
    ok: branch.ok && gitDir.ok && commonDir.ok && porcelain.ok,
    branch: branch.stdout.trim(),
    detached: branch.stdout.trim() === '',
    git_dir: gitDir.stdout.trim(),
    git_common_dir: commonDir.stdout.trim(),
    linked_worktree: gitDir.stdout.trim() !== commonDir.stdout.trim(),
    dirty: porcelain.stdout.trim().length > 0,
    porcelain: porcelain.stdout.trim().split(/\r?\n/).filter(Boolean)
  };
}
```

Add these names to `module.exports`:

```js
  appendJsonl,
  gitState,
  markdownHasSection,
  parseYamlFrontmatterKeys,
```

- [ ] **Step 5: Run the fixture and verify it passes**

Run:

```bash
chmod +x tests/run-contract-fixtures.sh
bash tests/run-contract-fixtures.sh
```

Expected: PASS with `contract helper fixture ok`.

- [ ] **Step 6: Commit**

```bash
git add scripts/contracts.js scripts/specnav-lib.js tests/run-contract-fixtures.sh
git commit -m "feat: add specnav lifecycle contract helpers"
```

---

### Task 2: Foundation Spec Gate

**Files:**
- Create: `scripts/foundation-specs.js`
- Create: `tests/run-foundation-fixtures.sh`
- Create fixture directories under `tests/fixtures/foundation-specs/`
- Modify: `scripts/affordances.js`
- Modify: `scripts/specnav-guard.js`

- [ ] **Step 1: Write the failing fixture**

Create `tests/run-foundation-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

make_valid_spec_set() {
  local project="$1"
  mkdir -p "$project/openspec/specs/ui-design" \
    "$project/openspec/specs/system-architecture" \
    "$project/openspec/specs/frontend-backend-data-flow" \
    "$project/openspec/specs/component-architecture"

  cat >"$project/openspec/specs/ui-design/design.md" <<'MD'
---
version: alpha
name: Test Design
description: Test UI design system.
colors: {}
typography: {}
spacing: {}
rounded: {}
components: {}
---
# Test Design
## Overview
## Colors
## Typography
## Layout
## Elevation & Depth
## Motion
## Shapes
## Components
## Voice & Content
## Do's and Don'ts
MD

  cat >"$project/openspec/specs/system-architecture/design.md" <<'MD'
# System Architecture & Database Spec
## Overview
## Application Topology
## Module Boundaries
## Frontend Architecture
## Backend Architecture
## API Surface
## Database Model
## Permissions & Security
## Integration Boundaries
## Operational Constraints
## Architecture Do's and Don'ts
MD

  cat >"$project/openspec/specs/frontend-backend-data-flow/design.md" <<'MD'
# Frontend-Backend Data Flow Spec
## Overview
## Flow Index
## Boundary Contracts
## State Ownership
## Validation Ownership
## Error & Empty States
## Loading / Optimistic / Retry Behavior
## End-to-End Flow Details
## Async / Realtime Flows
## Flow Do's and Don'ts
MD

  cat >"$project/openspec/specs/component-architecture/design.md" <<'MD'
# Component Architecture & Reuse Spec
## Overview
## Component Taxonomy
## Cohesion Rules
## Coupling Rules
## Shared Component Extraction Rules
## Component Public API Rules
## State Ownership Rules
## Composition Patterns
## File & Naming Conventions
## Testing Expectations
## Refactor Triggers
## Component Do's and Don'ts
MD
}

VALID="$TMP/valid"
MISSING="$TMP/missing"
INVALID="$TMP/invalid"
mkdir -p "$VALID" "$MISSING" "$INVALID/openspec/specs/ui-design"
make_valid_spec_set "$VALID"

node "$ROOT/scripts/foundation-specs.js" --json "$VALID" >/tmp/specnav-foundation-valid.json
jq -e '.ok == true' /tmp/specnav-foundation-valid.json >/dev/null
jq -e '.specs | length == 4' /tmp/specnav-foundation-valid.json >/dev/null

set +e
node "$ROOT/scripts/foundation-specs.js" --json "$MISSING" >/tmp/specnav-foundation-missing.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.ok == false' /tmp/specnav-foundation-missing.json >/dev/null
jq -e '.blockers[] | select(. == "openspec-missing")' /tmp/specnav-foundation-missing.json >/dev/null

cat >"$INVALID/openspec/specs/ui-design/design.md" <<'MD'
# Broken
## Overview
MD
set +e
node "$ROOT/scripts/foundation-specs.js" --json "$INVALID" >/tmp/specnav-foundation-invalid.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.blockers[] | select(. == "missing-foundation-spec:system-architecture")' /tmp/specnav-foundation-invalid.json >/dev/null
jq -e '.specs[] | select(.id == "ui-design" and .ok == false)' /tmp/specnav-foundation-invalid.json >/dev/null

echo "specnav foundation fixtures ok"
```

- [ ] **Step 2: Run the fixture and verify it fails**

Run:

```bash
bash tests/run-foundation-fixtures.sh
```

Expected: FAIL with `Cannot find module` for `scripts/foundation-specs.js`.

- [ ] **Step 3: Create `scripts/foundation-specs.js`**

```js
#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const lib = require('./specnav-lib');
const contracts = require('./contracts');

function validateOne(root, spec) {
  const file = path.join(root, spec.path);
  const exists = fs.existsSync(file);
  if (!exists) {
    return { id: spec.id, path: spec.path, ok: false, blockers: [`missing-foundation-spec:${spec.id}`], missing_sections: [], missing_frontmatter_keys: spec.requiredFrontmatterKeys };
  }
  const text = lib.readText(file);
  const missingSections = spec.requiredSections.filter((heading) => !lib.markdownHasSection(text, heading));
  const keys = lib.parseYamlFrontmatterKeys(text);
  const missingKeys = spec.requiredFrontmatterKeys.filter((key) => !keys.includes(key));
  const blockers = [];
  if (missingSections.length) blockers.push(`invalid-foundation-spec-sections:${spec.id}`);
  if (missingKeys.length) blockers.push(`invalid-foundation-spec-frontmatter:${spec.id}`);
  return {
    id: spec.id,
    path: spec.path,
    ok: blockers.length === 0,
    blockers,
    missing_sections: missingSections,
    missing_frontmatter_keys: missingKeys
  };
}

function validateFoundationSpecs(root = lib.projectRoot()) {
  if (!fs.existsSync(lib.openspecDir(root))) {
    return contracts.block('foundation-specs', ['openspec-missing'], {
      project_root: root,
      specs: contracts.REQUIRED_FOUNDATION_SPECS.map((spec) => ({
        id: spec.id,
        path: spec.path,
        ok: false,
        blockers: [`missing-foundation-spec:${spec.id}`],
        missing_sections: spec.requiredSections,
        missing_frontmatter_keys: spec.requiredFrontmatterKeys
      }))
    });
  }
  const specs = contracts.REQUIRED_FOUNDATION_SPECS.map((spec) => validateOne(root, spec));
  const blockers = specs.flatMap((spec) => spec.blockers);
  const result = blockers.length
    ? contracts.block('foundation-specs', blockers, { project_root: root, specs })
    : contracts.pass('foundation-specs', { project_root: root, specs });
  if (fs.existsSync(lib.openspecDir(root))) {
    lib.writeJson(path.join(lib.specnavDir(root), 'foundation-specs.json'), result);
    lib.event(root, 'foundation-specs.validate', { ok: result.ok, blockers: result.blockers });
  }
  return result;
}

function markdown(result) {
  const lines = ['# SpecNav Foundation Specs', '', `- ok: ${result.ok}`];
  if (result.blockers.length) lines.push(`- blockers: ${result.blockers.join(', ')}`);
  lines.push('', '| Spec | Status | Missing |', '| --- | --- | --- |');
  for (const spec of result.specs) {
    const missing = spec.missing_sections.concat(spec.missing_frontmatter_keys.map((key) => `frontmatter:${key}`));
    lines.push(`| ${spec.id} | ${spec.ok ? 'pass' : 'blocked'} | ${missing.join('<br>') || '-'} |`);
  }
  return `${lines.join('\n')}\n`;
}

function main() {
  const root = lib.projectRoot();
  const result = validateFoundationSpecs(root);
  process.stdout.write(process.argv.includes('--json') ? `${JSON.stringify(result, null, 2)}\n` : markdown(result));
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = { validateFoundationSpecs, validateOne, markdown };
```

- [ ] **Step 4: Wire foundation status into affordances**

In `scripts/affordances.js`, require the validator:

```js
const foundation = require('./foundation-specs');
```

Inside `buildAffordances`, after `hasOpenSpec`, add:

```js
  const foundationStatus = hasOpenSpec
    ? foundation.validateFoundationSpecs(root)
    : { ok: false, blockers: ['openspec-missing'], specs: [] };
```

Change the requirements-stage actions so requirements/design/prototype/development actions are blocked by missing foundation specs:

```js
  const foundationBlockers = foundationStatus.ok ? [] : foundationStatus.blockers;
  add('requirements', hasOpenSpec && foundationStatus.ok, hasOpenSpec ? foundationBlockers : ['bootstrap']);
  add('propose', hasOpenSpec && foundationStatus.ok, hasOpenSpec ? foundationBlockers : ['bootstrap']);
```

Add this field to the returned object:

```js
    foundation_specs: {
      ok: foundationStatus.ok,
      blockers: foundationStatus.blockers,
      specs: foundationStatus.specs
    },
```

- [ ] **Step 5: Block production writes when foundation specs are missing**

In `scripts/specnav-guard.js`, require the validator:

```js
const foundation = require('./foundation-specs');
```

After the `productionPaths` computation and before `tasks.md` check, add:

```js
  const foundationStatus = foundation.validateFoundationSpecs(root);
  if (!foundationStatus.ok) {
    lib.event(root, 'hook.deny', { reason: 'foundation-specs', blockers: foundationStatus.blockers, paths: productionPaths });
    deny(`production edits require valid foundation specs: ${foundationStatus.blockers.join(', ')}`);
  }
```

- [ ] **Step 6: Run the fixture and smoke suite**

Run:

```bash
chmod +x tests/run-foundation-fixtures.sh
bash tests/run-foundation-fixtures.sh
bash tests/run-smoke.sh
```

Expected:

```text
specnav foundation fixtures ok
specnav smoke ok
```

- [ ] **Step 7: Commit**

```bash
git add scripts/foundation-specs.js scripts/affordances.js scripts/specnav-guard.js tests/run-foundation-fixtures.sh
git commit -m "feat: enforce foundation spec gate"
```

---

### Task 3: Workflow State Machine

**Files:**
- Create: `scripts/workflow-state.js`
- Create: `tests/run-workflow-state-fixtures.sh`
- Modify: `scripts/affordances.js`
- Modify: `commands/specnav-status.md`
- Modify: `skills/status/SKILL.md`

- [ ] **Step 1: Write the failing workflow fixture**

Create `tests/run-workflow-state-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/tests/fixtures/simple-project"
TMP="$(mktemp -d)"
cp -R "$BASE/." "$TMP/"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/openspec/specs/ui-design" \
  "$TMP/openspec/specs/system-architecture" \
  "$TMP/openspec/specs/frontend-backend-data-flow" \
  "$TMP/openspec/specs/component-architecture"

cat >"$TMP/openspec/specs/ui-design/design.md" <<'MD'
---
version: alpha
name: Test
description: Test
colors: {}
typography: {}
spacing: {}
rounded: {}
components: {}
---
# Test
## Overview
## Colors
## Typography
## Layout
## Elevation & Depth
## Motion
## Shapes
## Components
## Voice & Content
## Do's and Don'ts
MD
cat >"$TMP/openspec/specs/system-architecture/design.md" <<'MD'
# System Architecture & Database Spec
## Overview
## Application Topology
## Module Boundaries
## Frontend Architecture
## Backend Architecture
## API Surface
## Database Model
## Permissions & Security
## Integration Boundaries
## Operational Constraints
## Architecture Do's and Don'ts
MD
cat >"$TMP/openspec/specs/frontend-backend-data-flow/design.md" <<'MD'
# Frontend-Backend Data Flow Spec
## Overview
## Flow Index
## Boundary Contracts
## State Ownership
## Validation Ownership
## Error & Empty States
## Loading / Optimistic / Retry Behavior
## End-to-End Flow Details
## Async / Realtime Flows
## Flow Do's and Don'ts
MD
cat >"$TMP/openspec/specs/component-architecture/design.md" <<'MD'
# Component Architecture & Reuse Spec
## Overview
## Component Taxonomy
## Cohesion Rules
## Coupling Rules
## Shared Component Extraction Rules
## Component Public API Rules
## State Ownership Rules
## Composition Patterns
## File & Naming Conventions
## Testing Expectations
## Refactor Triggers
## Component Do's and Don'ts
MD

PROJECT_DIR="$TMP" node "$ROOT/scripts/workflow-state.js" --write --json >/tmp/specnav-workflow-state.json
jq -e '.state == "development"' /tmp/specnav-workflow-state.json >/dev/null
jq -e '.legal_actions[] | select(. == "verify")' /tmp/specnav-workflow-state.json >/dev/null
jq -e '.blocked_actions.implement | length == 0' /tmp/specnav-workflow-state.json >/dev/null
jq -e '.required_artifacts[] | select(. == "openspec/changes/add-dark-mode/tasks.md")' /tmp/specnav-workflow-state.json >/dev/null
jq -e '.state == "development"' "$TMP/openspec/.specnav/workflow-state.json" >/dev/null

echo "specnav workflow state fixtures ok"
```

- [ ] **Step 2: Run the fixture and verify it fails**

Run:

```bash
bash tests/run-workflow-state-fixtures.sh
```

Expected: FAIL with `Cannot find module` for `scripts/workflow-state.js`.

- [ ] **Step 3: Create `scripts/workflow-state.js`**

```js
#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const lib = require('./specnav-lib');
const contracts = require('./contracts');
const foundation = require('./foundation-specs');

function exists(file) {
  return file && fs.existsSync(file);
}

function buildWorkflowState(root = lib.projectRoot()) {
  const hasOpenSpec = exists(lib.openspecDir(root));
  const change = lib.activeChange(root);
  const dir = lib.changeDir(root, change);
  const requiredArtifacts = [];
  const blockedActions = {};
  const legalActions = ['status', 'doctor'];

  if (!hasOpenSpec) {
    return {
      schema_version: 1,
      generated_at: new Date().toISOString(),
      project_root: root,
      state: 'no_openspec',
      active_change: null,
      required_artifacts: ['openspec/'],
      legal_actions: ['bootstrap', 'status', 'doctor'],
      blocked_actions: {
        requirements: ['openspec-missing'],
        prototype: ['openspec-missing'],
        implement: ['openspec-missing'],
        verify: ['openspec-missing'],
        release: ['openspec-missing'],
        archive: ['openspec-missing']
      }
    };
  }

  const foundationStatus = foundation.validateFoundationSpecs(root);
  if (!foundationStatus.ok) {
    return {
      schema_version: 1,
      generated_at: new Date().toISOString(),
      project_root: root,
      state: 'initialized',
      active_change: change,
      required_artifacts: contracts.REQUIRED_FOUNDATION_SPECS.map((spec) => spec.path),
      legal_actions: ['foundation-spec', 'status', 'doctor'],
      blocked_actions: {
        requirements: foundationStatus.blockers,
        prototype: foundationStatus.blockers,
        implement: foundationStatus.blockers,
        verify: foundationStatus.blockers,
        release: foundationStatus.blockers,
        archive: foundationStatus.blockers
      },
      foundation_specs: foundationStatus
    };
  }

  if (!change || !dir || !exists(dir)) {
    return {
      schema_version: 1,
      generated_at: new Date().toISOString(),
      project_root: root,
      state: 'requirements',
      active_change: change,
      required_artifacts: ['openspec/changes/<change>/requirements.md', 'openspec/changes/<change>/acceptance.md'],
      legal_actions: ['requirements', 'status', 'doctor'],
      blocked_actions: {
        prototype: ['active-change-missing'],
        implement: ['active-change-missing'],
        verify: ['active-change-missing'],
        release: ['active-change-missing'],
        archive: ['active-change-missing']
      },
      foundation_specs: foundationStatus
    };
  }

  const artifact = (name) => path.join(dir, name);
  const hasRequirements = exists(artifact('requirements.md')) && exists(artifact('acceptance.md')) && exists(artifact('spec-map.json')) && exists(artifact('component-impact-map.json'));
  const hasPrototypeDecision = exists(artifact('prototype/decision.json')) && exists(artifact('prototype/handoff.md'));
  const hasDevelopment = exists(artifact('development/handoff-to-verify.md'));
  const hasVerify = exists(artifact('verify/aggregate-report.json'));
  const verifyReport = lib.readJson(artifact('verify/aggregate-report.json'), null);
  const hasOperations = exists(artifact('operations/readiness.json'));
  const readiness = lib.readJson(artifact('operations/readiness.json'), null);

  let state = 'requirements';
  if (hasRequirements) state = 'prototype';
  if (hasPrototypeDecision && exists(artifact('scope.json')) && exists(artifact('tasks.md'))) state = 'development';
  if (hasDevelopment) state = 'verification';
  if (hasVerify && verifyReport && verifyReport.verdict === 'green' && !exists(artifact('verify-report.stale'))) state = 'operations';
  if (hasOperations && readiness && readiness.ready === true && exists(artifact('operations/archive-gate.json'))) state = 'archived';

  requiredArtifacts.push(`openspec/changes/${change}/requirements.md`);
  requiredArtifacts.push(`openspec/changes/${change}/acceptance.md`);
  requiredArtifacts.push(`openspec/changes/${change}/spec-map.json`);
  requiredArtifacts.push(`openspec/changes/${change}/component-impact-map.json`);

  if (state === 'requirements') legalActions.push('requirements');
  if (hasRequirements) legalActions.push('prototype');
  else blockedActions.prototype = ['requirements-artifacts'];
  if (hasPrototypeDecision) legalActions.push('implement');
  else blockedActions.implement = ['prototype-decision'];
  if (exists(artifact('tasks.md'))) legalActions.push('verify');
  else blockedActions.verify = ['tasks'];
  if (verifyReport && verifyReport.verdict === 'green') legalActions.push('release');
  else blockedActions.release = ['green-aggregate-verification'];
  if (readiness && readiness.ready === true) legalActions.push('archive');
  else blockedActions.archive = ['operations-readiness'];

  return {
    schema_version: 1,
    generated_at: new Date().toISOString(),
    project_root: root,
    state,
    active_change: change,
    required_artifacts: requiredArtifacts,
    legal_actions: Array.from(new Set(legalActions)),
    blocked_actions: blockedActions,
    foundation_specs: foundationStatus
  };
}

function main() {
  const root = lib.projectRoot();
  const result = buildWorkflowState(root);
  if (process.argv.includes('--write') && fs.existsSync(lib.openspecDir(root))) {
    lib.writeJson(path.join(lib.specnavDir(root), 'workflow-state.json'), result);
    lib.event(root, 'workflow-state.write', { state: result.state, active_change: result.active_change });
  }
  process.stdout.write(process.argv.includes('--json') ? `${JSON.stringify(result, null, 2)}\n` : `${result.state}\n`);
}

if (require.main === module) main();

module.exports = { buildWorkflowState };
```

- [ ] **Step 4: Update `scripts/affordances.js` to read workflow state**

At the top:

```js
const workflow = require('./workflow-state');
```

At the start of `buildAffordances`, after `root` values are available:

```js
  const workflowState = workflow.buildWorkflowState(root);
```

Add these return fields:

```js
    workflow_state: workflowState.state,
    legal_actions: workflowState.legal_actions,
    blocked_actions: workflowState.blocked_actions,
```

For each existing `add(...)` call, use `workflowState.legal_actions.includes(actionName)` where possible so the displayed affordances match `workflow-state.json`.

- [ ] **Step 5: Update status command and skill**

In `commands/specnav-status.md`, make the first command:

```markdown
Run `node "$CLAUDE_PLUGIN_ROOT/scripts/workflow-state.js" --write --json` and then `node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --json`.
```

In `skills/status/SKILL.md`, add:

```markdown
## Required State Source

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/workflow-state.js" --write --json
node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --json
```

Treat `workflow_state`, `legal_actions`, and `blocked_actions` as authoritative. Do not infer next actions from conversation history.
```

- [ ] **Step 6: Run workflow and smoke fixtures**

Run:

```bash
chmod +x tests/run-workflow-state-fixtures.sh
bash tests/run-workflow-state-fixtures.sh
bash tests/run-smoke.sh
```

Expected:

```text
specnav workflow state fixtures ok
specnav smoke ok
```

- [ ] **Step 7: Commit**

```bash
git add scripts/workflow-state.js scripts/affordances.js commands/specnav-status.md skills/status/SKILL.md tests/run-workflow-state-fixtures.sh
git commit -m "feat: add specnav workflow state machine"
```

---

### Task 4: Strict No-Fallback Hook Behavior

**Files:**
- Modify: `scripts/specnav-session-start.js`
- Modify: `scripts/specnav-guard.js`
- Modify: `scripts/affordances.js`
- Modify: `tests/run-hook-fixtures.sh`
- Modify: `tests/run-openspec-fixtures.sh`
- Create: `tests/run-no-fallback-fixtures.sh`

- [ ] **Step 1: Write the no-fallback fixture**

Create `tests/run-no-fallback-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

printf '{"tool_name":"Write","tool_input":{"file_path":"src/app.ts"}}' >"$TMP/write.json"

set +e
PROJECT_DIR="$TMP" node "$ROOT/scripts/specnav-guard.js" <"$TMP/write.json" >/tmp/specnav-no-fallback-write.out 2>/tmp/specnav-no-fallback-write.err
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
grep -q "openspec" /tmp/specnav-no-fallback-write.err

node "$ROOT/scripts/affordances.js" --json "$TMP" >/tmp/specnav-no-fallback-affordances.json
jq -e '.workflow_state == "no_openspec"' /tmp/specnav-no-fallback-affordances.json >/dev/null
jq -e '.actions[] | select(.id == "bootstrap" and .state == "ready")' /tmp/specnav-no-fallback-affordances.json >/dev/null
jq -e '.actions[] | select(.id == "implement" and .state == "blocked")' /tmp/specnav-no-fallback-affordances.json >/dev/null

SPECNAV_DISABLE_OPENSPEC=1 node "$ROOT/scripts/affordances.js" --json "$TMP" >/tmp/specnav-no-fallback-disabled.json
jq -e '.workflow_state == "no_openspec"' /tmp/specnav-no-fallback-disabled.json >/dev/null

PROJECT_DIR="$TMP" node "$ROOT/scripts/specnav-session-start.js" >/tmp/specnav-session-start.out 2>/tmp/specnav-session-start.err
grep -q "SpecNav detected missing openspec" /tmp/specnav-session-start.err

echo "specnav no fallback fixtures ok"
```

- [ ] **Step 2: Run the fixture and verify it fails against current warning behavior**

Run:

```bash
bash tests/run-no-fallback-fixtures.sh
```

Expected: FAIL because the current guard exits with warning code `1` for no active state and session start is silent.

- [ ] **Step 3: Make session start report missing OpenSpec**

Replace `scripts/specnav-session-start.js` with:

```js
#!/usr/bin/env node
'use strict';

const fs = require('fs');
const lib = require('./specnav-lib');

function main() {
  const root = lib.projectRoot();
  if (!fs.existsSync(lib.openspecDir(root))) {
    console.error(`SpecNav detected missing openspec/ in ${root}. Production edits are blocked until OpenSpec is initialized.`);
    process.exit(0);
  }
  lib.event(root, 'session.start', { cwd: root });
  const workflow = require('./workflow-state').buildWorkflowState(root);
  lib.writeJson(require('path').join(lib.specnavDir(root), 'workflow-state.json'), workflow);
}

main();
```

- [ ] **Step 4: Make guard deny production writes without OpenSpec**

In `scripts/specnav-guard.js`, after `const root = lib.projectRoot();`, add:

```js
  if (!fs.existsSync(lib.openspecDir(root))) {
    lib.event(root, 'hook.deny', { reason: 'openspec-missing' });
    deny('production edits require openspec/. Run SpecNav initialization before editing code.');
  }
```

Keep the existing `openspec/` edit allowance below this check by allowing paths under `openspec/` before this guard when the tool path targets `openspec/`. Use this exact order:

```js
  const relPaths = normalized.paths.map((target) => toRelativeProjectPath(root, target));
  const onlyOpenSpecPaths = relPaths.length > 0 && relPaths.every((rel) => rel.startsWith('openspec/'));
  if (onlyOpenSpecPaths) allow(root, 'openspec-edit');

  if (!fs.existsSync(lib.openspecDir(root))) {
    lib.event(root, 'hook.deny', { reason: 'openspec-missing', paths: relPaths });
    deny('production edits require openspec/. Run SpecNav initialization before editing code.');
  }
```

- [ ] **Step 5: Remove OpenSpec CLI fallback assertions**

In `tests/run-openspec-fixtures.sh`, replace the fallback block with:

```bash
SPECNAV_DISABLE_OPENSPEC=1 node "$ROOT/scripts/affordances.js" --json "$PROJECT" >/tmp/specnav-disabled-affordances.json
jq -e '.openspec_status.ok == false' /tmp/specnav-disabled-affordances.json >/dev/null
jq -e '.openspec_status.error == "disabled"' /tmp/specnav-disabled-affordances.json >/dev/null
```

- [ ] **Step 6: Run no-fallback and existing hook fixtures**

Run:

```bash
chmod +x tests/run-no-fallback-fixtures.sh
bash tests/run-no-fallback-fixtures.sh
bash tests/run-hook-fixtures.sh
bash tests/run-openspec-fixtures.sh
```

Expected:

```text
specnav no fallback fixtures ok
specnav hook fixtures ok
specnav openspec fixtures ok
```

- [ ] **Step 7: Commit**

```bash
git add scripts/specnav-session-start.js scripts/specnav-guard.js scripts/affordances.js tests/run-no-fallback-fixtures.sh tests/run-hook-fixtures.sh tests/run-openspec-fixtures.sh
git commit -m "feat: enforce no fallback workflow gates"
```

---

### Task 5: Requirements Stage Contracts

**Files:**
- Create: `commands/specnav-requirements.md`
- Create: `skills/requirements/SKILL.md`
- Create: `skills/foundation-spec/SKILL.md`
- Create: `scripts/requirements-contract.js`
- Create: `tests/run-requirements-fixtures.sh`
- Modify: `commands/specnav.md`
- Modify: `skills/specnav-router/SKILL.md`

- [ ] **Step 1: Write the requirements fixture**

Create `tests/run-requirements-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/tests/fixtures/simple-project"
TMP="$(mktemp -d)"
cp -R "$BASE/." "$TMP/"
trap 'rm -rf "$TMP"' EXIT

CHANGE_DIR="$TMP/openspec/changes/add-dark-mode"

set +e
PROJECT_DIR="$TMP" node "$ROOT/scripts/requirements-contract.js" --json >/tmp/specnav-requirements-missing.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.blockers[] | select(. == "requirements.md")' /tmp/specnav-requirements-missing.json >/dev/null

cat >"$CHANGE_DIR/requirements.md" <<'MD'
# Requirements
## User Goal
Users can switch between light and dark mode.
## Decisions
- The feature uses the existing UI design tokens.
MD
cat >"$CHANGE_DIR/acceptance.md" <<'MD'
# Acceptance
- User can toggle the theme from the settings UI.
- The selected theme persists after reload.
MD
cat >"$CHANGE_DIR/spec-map.json" <<'JSON'
{
  "schema": "specnav.requirements.specMap.v1",
  "foundation_specs": ["ui-design", "system-architecture", "frontend-backend-data-flow", "component-architecture"],
  "touched_ui_rules": ["colors"],
  "touched_modules": ["theme"],
  "touched_flows": ["FLOW-theme-toggle"],
  "unresolved_gaps": []
}
JSON
cat >"$CHANGE_DIR/component-impact-map.json" <<'JSON'
{
  "schema": "specnav.requirements.componentImpact.v1",
  "new_components": [],
  "reused_components": ["ThemeToggle"],
  "extraction_triggers": [],
  "forbidden_dependencies": [],
  "required_component_tests": ["ThemeToggle persists selected theme"],
  "unresolved_gaps": []
}
JSON

PROJECT_DIR="$TMP" node "$ROOT/scripts/requirements-contract.js" --json >/tmp/specnav-requirements-valid.json
jq -e '.ok == true' /tmp/specnav-requirements-valid.json >/dev/null

echo "specnav requirements fixtures ok"
```

- [ ] **Step 2: Run the fixture and verify it fails**

Run:

```bash
bash tests/run-requirements-fixtures.sh
```

Expected: FAIL with `Cannot find module` for `scripts/requirements-contract.js`.

- [ ] **Step 3: Create `scripts/requirements-contract.js`**

```js
#!/usr/bin/env node
'use strict';

const path = require('path');
const lib = require('./specnav-lib');
const contracts = require('./contracts');

function validateRequirements(root = lib.projectRoot()) {
  const change = lib.activeChange(root);
  const dir = lib.changeDir(root, change);
  const blockers = [];
  const requireFile = (name) => {
    if (!lib.fileExists(path.join(dir || '', name))) blockers.push(name);
  };
  if (!change || !dir) blockers.push('active-change');
  for (const name of ['requirements.md', 'acceptance.md', 'spec-map.json', 'component-impact-map.json']) requireFile(name);

  const specMap = lib.readJson(path.join(dir || '', 'spec-map.json'), null);
  if (specMap && Array.isArray(specMap.unresolved_gaps) && specMap.unresolved_gaps.length) blockers.push('spec-map-unresolved-gaps');
  if (specMap && specMap.schema !== 'specnav.requirements.specMap.v1') blockers.push('spec-map-schema');

  const componentMap = lib.readJson(path.join(dir || '', 'component-impact-map.json'), null);
  if (componentMap && Array.isArray(componentMap.unresolved_gaps) && componentMap.unresolved_gaps.length) blockers.push('component-impact-unresolved-gaps');
  if (componentMap && componentMap.schema !== 'specnav.requirements.componentImpact.v1') blockers.push('component-impact-schema');

  return blockers.length
    ? contracts.block('requirements-contract', blockers, { active_change: change })
    : contracts.pass('requirements-contract', { active_change: change });
}

function main() {
  const result = validateRequirements();
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = { validateRequirements };
```

- [ ] **Step 4: Create requirements command and skills**

Create `commands/specnav-requirements.md`:

```markdown
---
description: Run the SpecNav requirements stage after foundation specs are valid
argument-hint: "[change intent]"
---

You are running the SpecNav requirements stage.

1. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/foundation-specs.js" --json`.
2. If foundation specs are blocked, load `foundation-spec` and guide creation or repair of the missing specs.
3. If foundation specs pass, load `requirements`.
4. Write or repair `openspec/changes/<change>/requirements.md`, `acceptance.md`, `spec-map.json`, and `component-impact-map.json`.
5. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/requirements-contract.js" --json`.
6. Do not start prototype or development until the contract passes.
```

Create `skills/foundation-spec/SKILL.md`:

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

Run `node "$CLAUDE_PLUGIN_ROOT/scripts/foundation-specs.js" --json`.

If a required spec is missing, create it at the exact reported path using the section contract from `docs/design.md`.

If a required spec is invalid, repair only the missing sections or frontmatter keys reported by the validator.

After edits, rerun:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/foundation-specs.js" --json
```

Proceed only when `ok` is `true`.
```

Create `skills/requirements/SKILL.md`:

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

First run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/foundation-specs.js" --json
```

Read all four foundation specs before asking the user any product questions.

Ask one focused question at a time. Do not ask for information already present in the foundation specs or current code evidence.

Write these files for the active change:

- `requirements.md`
- `acceptance.md`
- `spec-map.json`
- `component-impact-map.json`

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/requirements-contract.js" --json
```

Stop when the contract is blocked and report the exact blocker.
```

- [ ] **Step 5: Update router**

In `skills/specnav-router/SKILL.md`, change routing:

```markdown
- DEFINE -> `requirements`
- FOUNDATION_SPEC -> `foundation-spec`
```

In `commands/specnav.md`, add:

```markdown
If the user asks to define requirements, first run `/specnav-requirements`.
If foundation specs are blocked, route to `foundation-spec`; do not ask feature questions.
```

- [ ] **Step 6: Run requirements fixtures**

Run:

```bash
chmod +x tests/run-requirements-fixtures.sh
bash tests/run-requirements-fixtures.sh
```

Expected:

```text
specnav requirements fixtures ok
```

- [ ] **Step 7: Commit**

```bash
git add commands/specnav-requirements.md skills/requirements/SKILL.md skills/foundation-spec/SKILL.md scripts/requirements-contract.js tests/run-requirements-fixtures.sh commands/specnav.md skills/specnav-router/SKILL.md
git commit -m "feat: add requirements stage contract"
```

---

### Task 6: Prototype Stage Contracts

**Files:**
- Create: `commands/specnav-prototype.md`
- Create: `skills/prototype/SKILL.md`
- Create: `skills/prototype-verify/SKILL.md`
- Create: `skills/prototype-handoff/SKILL.md`
- Create: `scripts/prototype-contract.js`
- Create: `tests/run-prototype-fixtures.sh`
- Modify: `scripts/workflow-state.js`

- [ ] **Step 1: Write the prototype fixture**

Create `tests/run-prototype-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/tests/fixtures/simple-project"
TMP="$(mktemp -d)"
cp -R "$BASE/." "$TMP/"
trap 'rm -rf "$TMP"' EXIT
CHANGE_DIR="$TMP/openspec/changes/add-dark-mode"

mkdir -p "$CHANGE_DIR/prototype/artifact"

set +e
PROJECT_DIR="$TMP" node "$ROOT/scripts/prototype-contract.js" --json >/tmp/specnav-prototype-missing.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.blockers[] | select(. == "prototype-manifest.json")' /tmp/specnav-prototype-missing.json >/dev/null

cat >"$CHANGE_DIR/prototype/question.md" <<'MD'
# Prototype Question
Can users clearly understand and operate the theme toggle?
MD
cat >"$CHANGE_DIR/prototype/prototype-manifest.json" <<'JSON'
{
  "schema": "specnav.prototype.manifest.v1",
  "type": "ui-html",
  "entry": "artifact/index.html",
  "touches_real_data": false,
  "referenced_foundation_specs": ["ui-design", "component-architecture"],
  "referenced_requirements": ["theme-toggle"]
}
JSON
cat >"$CHANGE_DIR/prototype/artifact/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Theme Toggle Prototype</title></head>
<body><button id="theme-toggle">Dark mode</button></body>
</html>
HTML
cat >"$CHANGE_DIR/prototype/verifier-report.json" <<'JSON'
{
  "schema": "specnav.prototype.verifier.v1",
  "status": "green",
  "checks": [{"name": "html-entry", "status": "pass"}]
}
JSON
cat >"$CHANGE_DIR/prototype/handoff.md" <<'MD'
# Prototype Handoff
## Approved Decisions
- Use a single ThemeToggle control.
## Rejected Decisions
- No global floating toggle.
MD
cat >"$CHANGE_DIR/prototype/decision.json" <<'JSON'
{
  "schema": "specnav.prototype.decision.v1",
  "decision": "approved",
  "approved_artifacts": ["artifact/index.html"],
  "production_constraints": ["Reimplement in production components; do not copy prototype HTML."]
}
JSON

PROJECT_DIR="$TMP" node "$ROOT/scripts/prototype-contract.js" --json >/tmp/specnav-prototype-valid.json
jq -e '.ok == true' /tmp/specnav-prototype-valid.json >/dev/null

echo "specnav prototype fixtures ok"
```

- [ ] **Step 2: Run the fixture and verify it fails**

Run:

```bash
bash tests/run-prototype-fixtures.sh
```

Expected: FAIL with `Cannot find module` for `scripts/prototype-contract.js`.

- [ ] **Step 3: Create `scripts/prototype-contract.js`**

```js
#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const lib = require('./specnav-lib');
const contracts = require('./contracts');

function validatePrototype(root = lib.projectRoot()) {
  const change = lib.activeChange(root);
  const dir = lib.changeDir(root, change);
  const proto = path.join(dir || '', 'prototype');
  const blockers = [];
  const requireFile = (name) => {
    if (!lib.fileExists(path.join(proto, name))) blockers.push(name);
  };
  requireFile('question.md');
  requireFile('prototype-manifest.json');
  requireFile('verifier-report.json');
  requireFile('handoff.md');
  requireFile('decision.json');

  const manifest = lib.readJson(path.join(proto, 'prototype-manifest.json'), null);
  if (manifest) {
    if (manifest.schema !== 'specnav.prototype.manifest.v1') blockers.push('prototype-manifest-schema');
    if (!['ui-html', 'logic-state', 'api-contract', 'data-flow', 'component-seam'].includes(manifest.type)) blockers.push('prototype-type');
    if (manifest.entry && !lib.fileExists(path.join(proto, manifest.entry))) blockers.push('prototype-entry');
  }
  const verifier = lib.readJson(path.join(proto, 'verifier-report.json'), null);
  if (verifier && verifier.status !== 'green') blockers.push('prototype-verifier');
  const decision = lib.readJson(path.join(proto, 'decision.json'), null);
  if (decision && decision.decision !== 'approved') blockers.push('prototype-decision-not-approved');

  return blockers.length
    ? contracts.block('prototype-contract', blockers, { active_change: change })
    : contracts.pass('prototype-contract', { active_change: change, type: manifest.type });
}

function main() {
  const result = validatePrototype();
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = { validatePrototype };
```

- [ ] **Step 4: Create prototype command and skills**

Create `commands/specnav-prototype.md`:

```markdown
---
description: Build and verify isolated SpecNav prototype artifacts
argument-hint: "[prototype question]"
---

Run `node "$CLAUDE_PLUGIN_ROOT/scripts/requirements-contract.js" --json`.

If requirements are blocked, stop and report the blockers.

Load `prototype`.

After prototype artifacts are written, run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json
```

Development is blocked until this contract passes.
```

Create `skills/prototype/SKILL.md`:

```markdown
---
name: prototype
description: Produce isolated runnable prototype artifacts before production development
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Prototype

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/requirements-contract.js" --json
```

Choose exactly one prototype type: `ui-html`, `logic-state`, `api-contract`, `data-flow`, or `component-seam`.

Write prototype artifacts under `openspec/changes/<change>/prototype/`.

Prototype code is review material. Production implementation must reimplement decisions through development gates.
```

Create `skills/prototype-verify/SKILL.md`:

```markdown
---
name: prototype-verify
description: Verify prototype artifacts before handoff
allowed-tools:
  - Read
  - Bash
  - Write
---

# Prototype Verify

Run the prototype entry command or inspect the prototype entry file named in `prototype-manifest.json`.

Write `prototype/verifier-report.json` with schema `specnav.prototype.verifier.v1` and status `green`, `red`, or `blocked`.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json
```
```

Create `skills/prototype-handoff/SKILL.md`:

```markdown
---
name: prototype-handoff
description: Convert approved prototype decisions into development handoff
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# Prototype Handoff

Write `prototype/handoff.md` and `prototype/decision.json`.

Use decision `approved` only when the user has approved the prototype direction.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json
```
```

- [ ] **Step 5: Wire prototype state into workflow**

In `scripts/workflow-state.js`, require:

```js
const prototype = require('./prototype-contract');
```

When requirements artifacts exist, call:

```js
  const prototypeStatus = prototype.validatePrototype(root);
```

Set `blockedActions.implement = prototypeStatus.ok ? [] : prototypeStatus.blockers;`.

- [ ] **Step 6: Run prototype fixtures**

Run:

```bash
chmod +x tests/run-prototype-fixtures.sh
bash tests/run-prototype-fixtures.sh
```

Expected:

```text
specnav prototype fixtures ok
```

- [ ] **Step 7: Commit**

```bash
git add commands/specnav-prototype.md skills/prototype/SKILL.md skills/prototype-verify/SKILL.md skills/prototype-handoff/SKILL.md scripts/prototype-contract.js tests/run-prototype-fixtures.sh scripts/workflow-state.js
git commit -m "feat: add prototype stage contract"
```

---

### Task 7: Development Stage Contracts

**Files:**
- Create: `commands/specnav-implement.md`
- Create: `skills/before-dev/SKILL.md`
- Create: `skills/scope-lock/SKILL.md`
- Create: `skills/vertical-slice-tasking/SKILL.md`
- Create: `scripts/development-contract.js`
- Create: `tests/run-development-fixtures.sh`
- Modify: `scripts/specnav-guard.js`
- Modify: `scripts/workflow-state.js`

- [ ] **Step 1: Write the development fixture**

Create `tests/run-development-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/tests/fixtures/simple-project"
TMP="$(mktemp -d)"
cp -R "$BASE/." "$TMP/"
trap 'rm -rf "$TMP"' EXIT
CHANGE_DIR="$TMP/openspec/changes/add-dark-mode"

set +e
PROJECT_DIR="$TMP" node "$ROOT/scripts/development-contract.js" --json >/tmp/specnav-development-missing.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.blockers[] | select(. == "development/handoff-to-verify.md")' /tmp/specnav-development-missing.json >/dev/null

mkdir -p "$CHANGE_DIR/development/tasks/001-theme-toggle"
cat >"$CHANGE_DIR/development/prototype-promotion-map.json" <<'JSON'
{
  "schema": "specnav.development.prototypePromotion.v1",
  "copied_decisions": ["ThemeToggle control"],
  "forbidden_direct_copies": ["prototype/artifact/index.html"],
  "production_reimplementation": ["src/ui/theme.ts"]
}
JSON
cat >"$CHANGE_DIR/development/task-ledger.jsonl" <<'JSONL'
{"task":"001-theme-toggle","status":"complete","spec_review":"approved","quality_review":"approved"}
JSONL
cat >"$CHANGE_DIR/development/drift-check.jsonl" <<'JSONL'
{"kind":"scope","status":"green","message":"No blocking drift."}
JSONL
cat >"$CHANGE_DIR/development/validation-log.jsonl" <<'JSONL'
{"command":"bash tests/run-smoke.sh","status":"pass"}
JSONL
cat >"$CHANGE_DIR/development/handoff-to-verify.md" <<'MD'
# Handoff To Verification
## Implemented Slices
- Theme toggle.
## Files Changed
- src/ui/theme.ts
## Requirements Covered
- Dark mode toggle.
## Prototype Decisions Implemented
- Single toggle control.
## Components Created / Reused / Extracted
- Reused ThemeToggle.
## API / Data Flow Changes
- None.
## Tests Added
- Smoke fixture.
## Local Validation
- bash tests/run-smoke.sh
## Known Risks
- None.
## Items Requiring Six-Domain Verification
- UI behavior and persistence.
MD

PROJECT_DIR="$TMP" node "$ROOT/scripts/development-contract.js" --json >/tmp/specnav-development-valid.json
jq -e '.ok == true' /tmp/specnav-development-valid.json >/dev/null

echo "specnav development fixtures ok"
```

- [ ] **Step 2: Run the fixture and verify it fails**

Run:

```bash
bash tests/run-development-fixtures.sh
```

Expected: FAIL with `Cannot find module` for `scripts/development-contract.js`.

- [ ] **Step 3: Create `scripts/development-contract.js`**

```js
#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const lib = require('./specnav-lib');
const contracts = require('./contracts');

function jsonlRows(file) {
  return lib.readText(file).split(/\r?\n/).filter(Boolean).map((line) => {
    try { return JSON.parse(line); } catch { return { parse_error: true, raw: line }; }
  });
}

function validateDevelopment(root = lib.projectRoot()) {
  const change = lib.activeChange(root);
  const dir = lib.changeDir(root, change);
  const dev = path.join(dir || '', 'development');
  const blockers = [];
  const requireFile = (name) => {
    if (!lib.fileExists(path.join(dev, name))) blockers.push(`development/${name}`);
  };
  if (!lib.fileExists(path.join(dir || '', 'scope.json'))) blockers.push('scope.json');
  requireFile('prototype-promotion-map.json');
  requireFile('task-ledger.jsonl');
  requireFile('drift-check.jsonl');
  requireFile('validation-log.jsonl');
  requireFile('handoff-to-verify.md');

  const promotion = lib.readJson(path.join(dev, 'prototype-promotion-map.json'), null);
  if (promotion && promotion.schema !== 'specnav.development.prototypePromotion.v1') blockers.push('prototype-promotion-map-schema');

  const ledger = jsonlRows(path.join(dev, 'task-ledger.jsonl'));
  if (ledger.some((row) => row.parse_error)) blockers.push('task-ledger-parse');
  if (ledger.some((row) => row.status !== 'complete')) blockers.push('task-ledger-incomplete');
  if (ledger.some((row) => row.spec_review !== 'approved' || row.quality_review !== 'approved')) blockers.push('task-review-not-approved');

  const drift = jsonlRows(path.join(dev, 'drift-check.jsonl'));
  if (drift.some((row) => row.status === 'blocking')) blockers.push('blocking-drift');

  const validation = jsonlRows(path.join(dev, 'validation-log.jsonl'));
  if (!validation.length || validation.some((row) => row.status !== 'pass')) blockers.push('validation-not-pass');

  return blockers.length
    ? contracts.block('development-contract', blockers, { active_change: change })
    : contracts.pass('development-contract', { active_change: change });
}

function main() {
  const result = validateDevelopment();
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = { validateDevelopment };
```

- [ ] **Step 4: Create development command and skills**

Create `commands/specnav-implement.md`:

```markdown
---
description: Implement a SpecNav change after requirements and prototype gates pass
argument-hint: "[task or slice]"
---

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json
node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --json
```

If development contract is blocked because implementation artifacts are not yet created, load `before-dev`, `scope-lock`, and `vertical-slice-tasking` before production edits.
```

Create `skills/before-dev/SKILL.md`:

```markdown
---
name: before-dev
description: Prepare SpecNav development artifacts before production edits
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# Before Dev

Run requirements and prototype contracts first.

Create `development/prototype-promotion-map.json` before editing production code.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --json
```
```

Create `skills/scope-lock/SKILL.md`:

```markdown
---
name: scope-lock
description: Create or repair scope.json for SpecNav development
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# Scope Lock

Write `openspec/changes/<change>/scope.json` with `include` and `exclude` arrays.

Keep production edits inside `include` and outside `exclude`.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --json
```
```

Create `skills/vertical-slice-tasking/SKILL.md`:

```markdown
---
name: vertical-slice-tasking
description: Split SpecNav implementation into vertical slices
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# Vertical Slice Tasking

Create task directories under `development/tasks/`.

Each task must have `brief.md`, `report.md`, `spec-review.md`, and `quality-review.md`.

Record task completion in `development/task-ledger.jsonl`.
```

- [ ] **Step 5: Enforce development handoff before verify**

In `scripts/workflow-state.js`, require:

```js
const development = require('./development-contract');
```

Use `development.validateDevelopment(root)` before adding `verify` to legal actions.

In `scripts/specnav-guard.js`, keep existing `scope.json` enforcement and add this before production writes:

```js
  if (!lib.fileExists(path.join(dir, 'development/prototype-promotion-map.json'))) {
    lib.event(root, 'hook.deny', { reason: 'missing-prototype-promotion-map', paths: productionPaths });
    deny('production edits require development/prototype-promotion-map.json.');
  }
```

- [ ] **Step 6: Run development fixture and hook fixtures**

Run:

```bash
chmod +x tests/run-development-fixtures.sh
bash tests/run-development-fixtures.sh
bash tests/run-hook-fixtures.sh
```

Expected:

```text
specnav development fixtures ok
specnav hook fixtures ok
```

- [ ] **Step 7: Commit**

```bash
git add commands/specnav-implement.md skills/before-dev/SKILL.md skills/scope-lock/SKILL.md skills/vertical-slice-tasking/SKILL.md scripts/development-contract.js scripts/specnav-guard.js scripts/workflow-state.js tests/run-development-fixtures.sh
git commit -m "feat: add development stage contract"
```

---

### Task 8: Six-Domain Verification Contracts

**Files:**
- Create: `scripts/verify-domains.js`
- Modify: `scripts/verify.js`
- Create: `tests/run-verify-domain-fixtures.sh`
- Create skills: `skills/verify-plan/SKILL.md`, `skills/verify-facticity/SKILL.md`, `skills/verify-static/SKILL.md`, `skills/verify-unit/SKILL.md`, `skills/verify-redteam/SKILL.md`, `skills/verify-e2e/SKILL.md`, `skills/verify-sensory/SKILL.md`
- Modify: `commands/specnav-verify.md`

- [ ] **Step 1: Write the verification domain fixture**

Create `tests/run-verify-domain-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/tests/fixtures/simple-project"
TMP="$(mktemp -d)"
cp -R "$BASE/." "$TMP/"
trap 'rm -rf "$TMP"' EXIT
CHANGE_DIR="$TMP/openspec/changes/add-dark-mode"
VERIFY_DIR="$CHANGE_DIR/verify"
mkdir -p "$VERIFY_DIR"/{facticity,static,unit,redteam,e2e,sensory,behavior-evals}

set +e
PROJECT_DIR="$TMP" node "$ROOT/scripts/verify-domains.js" validate --json >/tmp/specnav-verify-missing.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.blockers[] | select(. == "verify/plan.json")' /tmp/specnav-verify-missing.json >/dev/null

cat >"$VERIFY_DIR/plan.json" <<'JSON'
{"schema":"specnav.verify.plan.v1","required_domains":["facticity","static","unit","redteam","e2e","sensory"]}
JSON
cat >"$VERIFY_DIR/evidence-index.jsonl" <<'JSONL'
{"id":"ev-1","kind":"command","domain":"static","result":"pass"}
JSONL
cat >"$VERIFY_DIR/traceability-matrix.json" <<'JSON'
{"schema":"specnav.verify.traceability.v1","mapped_changes":[{"file":"src/ui/theme.ts","requirement":"theme-toggle","domains":["unit","e2e"]}],"unmapped_changes":[]}
JSON
cat >"$VERIFY_DIR/blocker-classification.jsonl" <<'JSONL'
JSONL
cat >"$VERIFY_DIR/receipt.json" <<'JSON'
{"schema":"specnav.verify.receipt.v1","covered_scope":["src/ui/theme.ts"],"uncovered_scope":[],"residual_risk":[],"confidence":"A"}
JSON
cat >"$VERIFY_DIR/behavior-evals/report.json" <<'JSON'
{"schema":"specnav.verify.behaviorEvals.v1","status":"green","scenarios":[]}
JSON

for domain in facticity static unit redteam e2e sensory; do
  cat >"$VERIFY_DIR/$domain/report.json" <<JSON
{"schema":"specnav.verify.domainReport.v1","domain":"$domain","verdict":"green","required_fixes":[],"residual_risk":[]}
JSON
done

cat >"$VERIFY_DIR/unit/test-quality-rubric.json" <<'JSON'
{"schema":"specnav.verify.testQuality.v1","blocking_findings":[]}
JSON
cat >"$VERIFY_DIR/sensory/reviewer-independence.md" <<'MD'
# Reviewer Independence
## Inputs Allowed
## Inputs Excluded
## Controller Claims Ignored
MD

PROJECT_DIR="$TMP" node "$ROOT/scripts/verify-domains.js" validate --json >/tmp/specnav-verify-valid.json
jq -e '.ok == true' /tmp/specnav-verify-valid.json >/dev/null

echo "specnav verify domain fixtures ok"
```

- [ ] **Step 2: Run the fixture and verify it fails**

Run:

```bash
bash tests/run-verify-domain-fixtures.sh
```

Expected: FAIL with `Cannot find module` for `scripts/verify-domains.js`.

- [ ] **Step 3: Create `scripts/verify-domains.js`**

```js
#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const lib = require('./specnav-lib');
const contracts = require('./contracts');

function rows(file) {
  return lib.readText(file).split(/\r?\n/).filter(Boolean).map((line) => {
    try { return JSON.parse(line); } catch { return { parse_error: true }; }
  });
}

function validateVerify(root = lib.projectRoot()) {
  const change = lib.activeChange(root);
  const dir = lib.changeDir(root, change);
  const verifyDir = path.join(dir || '', 'verify');
  const blockers = [];
  const requireFile = (relative) => {
    if (!lib.fileExists(path.join(verifyDir, relative))) blockers.push(`verify/${relative}`);
  };
  for (const file of ['plan.json', 'evidence-index.jsonl', 'traceability-matrix.json', 'blocker-classification.jsonl', 'receipt.json', 'behavior-evals/report.json']) requireFile(file);
  for (const domain of contracts.VERIFY_DOMAINS) requireFile(`${domain}/report.json`);
  requireFile('unit/test-quality-rubric.json');
  requireFile('sensory/reviewer-independence.md');

  const trace = lib.readJson(path.join(verifyDir, 'traceability-matrix.json'), null);
  if (trace && Array.isArray(trace.unmapped_changes) && trace.unmapped_changes.length) blockers.push('traceability-unmapped-changes');

  const blockerRows = rows(path.join(verifyDir, 'blocker-classification.jsonl'));
  if (blockerRows.some((row) => row.status === 'unresolved')) blockers.push('unresolved-verification-blocker');

  for (const domain of contracts.VERIFY_DOMAINS) {
    const report = lib.readJson(path.join(verifyDir, domain, 'report.json'), null);
    if (report && report.verdict !== 'green') blockers.push(`${domain}-not-green`);
    if (report && Array.isArray(report.required_fixes) && report.required_fixes.length) blockers.push(`${domain}-required-fixes`);
  }

  const rubric = lib.readJson(path.join(verifyDir, 'unit/test-quality-rubric.json'), null);
  if (rubric && Array.isArray(rubric.blocking_findings) && rubric.blocking_findings.length) blockers.push('unit-test-quality-blocking');

  return blockers.length
    ? contracts.block('verify-domains', blockers, { active_change: change })
    : contracts.pass('verify-domains', { active_change: change });
}

function writeAggregate(root = lib.projectRoot()) {
  const change = lib.activeChange(root);
  const dir = lib.changeDir(root, change);
  const verifyDir = path.join(dir || '', 'verify');
  const validation = validateVerify(root);
  const report = {
    schema: 'specnav.verify.aggregate.v1',
    generated_at: new Date().toISOString(),
    active_change: change,
    verdict: validation.ok ? 'green' : 'red',
    blockers: validation.blockers,
    required_domains: contracts.VERIFY_DOMAINS
  };
  lib.writeJson(path.join(verifyDir, 'aggregate-report.json'), report);
  fs.writeFileSync(path.join(verifyDir, 'aggregate-report.md'), `# SpecNav Aggregate Verify Report\n\n- verdict: ${report.verdict}\n- blockers: ${report.blockers.join(', ') || '-'}\n`);
  return report;
}

function main() {
  const command = process.argv[2] || 'validate';
  const result = command === 'aggregate' ? writeAggregate() : validateVerify();
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  process.exit((result.ok === false || result.verdict === 'red') ? 2 : 0);
}

if (require.main === module) main();

module.exports = { validateVerify, writeAggregate };
```

- [ ] **Step 4: Refactor `scripts/verify.js` to write aggregate**

At the top:

```js
const domains = require('./verify-domains');
```

After existing basic checks pass, call:

```js
  const aggregate = domains.writeAggregate(root);
  report.status = aggregate.verdict === 'green' ? 'green' : 'red';
  report.aggregate = aggregate;
```

Keep writing legacy `verify-report.json` for compatibility while making `verify/aggregate-report.json` the archive input.

- [ ] **Step 5: Create six verification skills**

Create one file per domain with this exact domain-specific command pattern. Example for `skills/verify-static/SKILL.md`:

```markdown
---
name: verify-static
description: Run static verification for a SpecNav change
allowed-tools:
  - Read
  - Bash
  - Write
---

# Verify Static

Read `verify/plan.json`.

Run the static commands listed in the plan. If no command is available, write a blocked report with blocker class `tool-unavailable`.

Write `verify/static/report.json` with schema `specnav.verify.domainReport.v1`.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json
```
```

For the other five files, use the same structure and replace the domain path:

- `skills/verify-facticity/SKILL.md`: writes `verify/facticity/report.json`.
- `skills/verify-unit/SKILL.md`: writes `verify/unit/report.json` and `verify/unit/test-quality-rubric.json`.
- `skills/verify-redteam/SKILL.md`: writes `verify/redteam/report.json`.
- `skills/verify-e2e/SKILL.md`: writes `verify/e2e/report.json`.
- `skills/verify-sensory/SKILL.md`: writes `verify/sensory/report.json` and `verify/sensory/reviewer-independence.md`.

Create `skills/verify-plan/SKILL.md`:

```markdown
---
name: verify-plan
description: Create the SpecNav six-domain verification plan
allowed-tools:
  - Read
  - Write
  - Bash
---

# Verify Plan

Read `development/handoff-to-verify.md`.

Write:

- `verify/plan.json`
- `verify/evidence-index.jsonl`
- `verify/traceability-matrix.json`
- `verify/blocker-classification.jsonl`
- `verify/receipt.json`
- `verify/behavior-evals/report.json`

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json
```
```

- [ ] **Step 6: Update verify command**

In `commands/specnav-verify.md`, add:

```markdown
Run `node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --json` before verification.

Use `verify-plan`, then the six verification domain skills, then run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" aggregate --json
```

Archive and operations handoff require `verify/aggregate-report.json.verdict == "green"`.
```

- [ ] **Step 7: Run verification fixtures**

Run:

```bash
chmod +x tests/run-verify-domain-fixtures.sh
bash tests/run-verify-domain-fixtures.sh
```

Expected:

```text
specnav verify domain fixtures ok
```

- [ ] **Step 8: Commit**

```bash
git add scripts/verify-domains.js scripts/verify.js commands/specnav-verify.md skills/verify-plan/SKILL.md skills/verify-facticity/SKILL.md skills/verify-static/SKILL.md skills/verify-unit/SKILL.md skills/verify-redteam/SKILL.md skills/verify-e2e/SKILL.md skills/verify-sensory/SKILL.md tests/run-verify-domain-fixtures.sh
git commit -m "feat: add six-domain verification contracts"
```

---

### Task 9: Operations Stage and Archive Gate

**Files:**
- Create: `scripts/operations-gate.js`
- Create: `commands/specnav-release.md`
- Create skills: `ops-readiness`, `release-plan`, `install-verify`, `update-policy`, `compatibility-matrix`, `branch-finish`, `deploy`, `rollback`, `monitor`, `postmortem`, `update-spec`
- Modify: `scripts/archive-gate.js`
- Create: `tests/run-operations-fixtures.sh`

- [ ] **Step 1: Write operations fixture**

Create `tests/run-operations-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/tests/fixtures/simple-project"
TMP="$(mktemp -d)"
cp -R "$BASE/." "$TMP/"
trap 'rm -rf "$TMP"' EXIT
CHANGE_DIR="$TMP/openspec/changes/add-dark-mode"
OPS="$CHANGE_DIR/operations"
VERIFY="$CHANGE_DIR/verify"
mkdir -p "$OPS" "$VERIFY"

cat >"$VERIFY/aggregate-report.json" <<'JSON'
{"schema":"specnav.verify.aggregate.v1","verdict":"green","blockers":[]}
JSON
cat >"$VERIFY/receipt.json" <<'JSON'
{"schema":"specnav.verify.receipt.v1","covered_scope":["src/ui/theme.ts"],"uncovered_scope":[],"residual_risk":[],"confidence":"A"}
JSON
touch "$VERIFY/blocker-classification.jsonl"

set +e
PROJECT_DIR="$TMP" node "$ROOT/scripts/operations-gate.js" --json >/tmp/specnav-ops-missing.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.blockers[] | select(. == "operations/readiness.json")' /tmp/specnav-ops-missing.json >/dev/null

cat >"$OPS/readiness.json" <<'JSON'
{
  "schema": "specnav.ops.readiness.v1",
  "release_target": "local-only",
  "verification": {"aggregate_verdict": "green", "receipt_confidence": "A", "uncovered_scope": [], "residual_risk": []},
  "git": {"branch": "test", "worktree_mode": "normal", "dirty": false, "untracked_reviewed": true},
  "docs": {"changelog": true, "release_notes": true, "readme_updated": true},
  "ops": {"install_verification": "not-applicable", "update_policy": "not-applicable", "rollback_plan": "not-applicable", "monitor_plan": "not-applicable"},
  "ready": true
}
JSON
cat >"$OPS/release-plan.md" <<'MD'
# Release Plan
- target: local-only
MD
cat >"$OPS/branch-finish.md" <<'MD'
# Branch Finish
- action: keep
MD
cat >"$OPS/archive-gate.json" <<'JSON'
{"schema":"specnav.ops.archiveGate.v1","verdict":"green","blockers":[]}
JSON
touch "$OPS/archive-log.jsonl"

PROJECT_DIR="$TMP" node "$ROOT/scripts/operations-gate.js" --json >/tmp/specnav-ops-valid.json
jq -e '.ok == true' /tmp/specnav-ops-valid.json >/dev/null

PROJECT_DIR="$TMP" node "$ROOT/scripts/archive-gate.js" >/tmp/specnav-archive-ops.out

echo "specnav operations fixtures ok"
```

- [ ] **Step 2: Run the fixture and verify it fails**

Run:

```bash
bash tests/run-operations-fixtures.sh
```

Expected: FAIL with `Cannot find module` for `scripts/operations-gate.js`.

- [ ] **Step 3: Create `scripts/operations-gate.js`**

```js
#!/usr/bin/env node
'use strict';

const path = require('path');
const lib = require('./specnav-lib');
const contracts = require('./contracts');

function validateOperations(root = lib.projectRoot()) {
  const change = lib.activeChange(root);
  const dir = lib.changeDir(root, change);
  const ops = path.join(dir || '', 'operations');
  const blockers = [];
  const requireFile = (name) => {
    if (!lib.fileExists(path.join(ops, name))) blockers.push(`operations/${name}`);
  };

  const aggregate = lib.readJson(path.join(dir || '', 'verify/aggregate-report.json'), null);
  if (!aggregate || aggregate.verdict !== 'green') blockers.push('verify-aggregate-green');
  if (lib.fileExists(path.join(dir || '', 'verify-report.stale'))) blockers.push('fresh-verify');
  requireFile('readiness.json');
  requireFile('release-plan.md');
  requireFile('branch-finish.md');
  requireFile('archive-gate.json');
  requireFile('archive-log.jsonl');

  const readiness = lib.readJson(path.join(ops, 'readiness.json'), null);
  if (readiness && readiness.ready !== true) blockers.push('readiness-not-ready');
  if (readiness && !contracts.RELEASE_TARGETS.includes(readiness.release_target)) blockers.push('release-target');
  const archive = lib.readJson(path.join(ops, 'archive-gate.json'), null);
  if (archive && archive.verdict !== 'green') blockers.push('operations-archive-gate');

  return blockers.length
    ? contracts.block('operations-gate', blockers, { active_change: change })
    : contracts.pass('operations-gate', { active_change: change, release_target: readiness.release_target });
}

function main() {
  const result = validateOperations();
  process.stdout.write(process.argv.includes('--json') ? `${JSON.stringify(result, null, 2)}\n` : `${result.ok ? 'operations ready' : result.blockers.join(', ')}\n`);
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = { validateOperations };
```

- [ ] **Step 4: Require operations in archive gate**

In `scripts/archive-gate.js`, add:

```js
const operations = require('./operations-gate');
```

Before return, add:

```js
  const ops = operations.validateOperations(root);
  if (!ops.ok) blockers.push(...ops.blockers);
```

- [ ] **Step 5: Create release command and operations skills**

Create `commands/specnav-release.md`:

```markdown
---
description: Run SpecNav operations release gate
argument-hint: "[release target]"
---

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```

If operations is blocked, load the exact operation skill named by the blocker.
```

Create each operations skill with this pattern. Example `skills/ops-readiness/SKILL.md`:

```markdown
---
name: ops-readiness
description: Write SpecNav operations readiness artifact
allowed-tools:
  - Read
  - Write
  - Bash
---

# Ops Readiness

Read `verify/aggregate-report.json`, `verify/receipt.json`, and git status.

Write `operations/readiness.json` with schema `specnav.ops.readiness.v1`.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```
```

Create the other operation skills with the same structure and file responsibility:

- `skills/release-plan/SKILL.md`: writes `operations/release-plan.md`.
- `skills/install-verify/SKILL.md`: writes `operations/install-verification.json`.
- `skills/update-policy/SKILL.md`: writes `operations/update-policy.json`.
- `skills/compatibility-matrix/SKILL.md`: writes `operations/compatibility-matrix.md`.
- `skills/branch-finish/SKILL.md`: writes `operations/branch-finish.md`.
- `skills/deploy/SKILL.md`: writes `operations/deploy-plan.md`.
- `skills/rollback/SKILL.md`: writes `operations/rollback-plan.md`.
- `skills/monitor/SKILL.md`: writes `operations/monitor-plan.md`.
- `skills/postmortem/SKILL.md`: writes `operations/postmortem.md`.
- `skills/update-spec/SKILL.md`: records spec writeback or no-writeback decision.

- [ ] **Step 6: Run operations fixtures**

Run:

```bash
chmod +x tests/run-operations-fixtures.sh
bash tests/run-operations-fixtures.sh
```

Expected:

```text
specnav operations fixtures ok
```

- [ ] **Step 7: Commit**

```bash
git add scripts/operations-gate.js scripts/archive-gate.js commands/specnav-release.md skills/ops-readiness/SKILL.md skills/release-plan/SKILL.md skills/install-verify/SKILL.md skills/update-policy/SKILL.md skills/compatibility-matrix/SKILL.md skills/branch-finish/SKILL.md skills/deploy/SKILL.md skills/rollback/SKILL.md skills/monitor/SKILL.md skills/postmortem/SKILL.md skills/update-spec/SKILL.md tests/run-operations-fixtures.sh
git commit -m "feat: add operations release gate"
```

---

### Task 10: Doctor and Install Verification

**Files:**
- Create: `scripts/plugin-repository.js`
- Create: `scripts/specnav-doctor.js`
- Create: `commands/specnav-doctor.md`
- Create: `skills/doctor/SKILL.md`
- Create: `tests/run-doctor-fixtures.sh`
- Modify: `scripts/specnav-session-start.js`

- [ ] **Step 1: Write doctor fixture**

Create `tests/run-doctor-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

node "$ROOT/scripts/specnav-doctor.js" --plugin-root "$ROOT" --json >/tmp/specnav-doctor.json
jq -e '.ok == true' /tmp/specnav-doctor.json >/dev/null
jq -e '.plugin.root == "'"$ROOT"'"' /tmp/specnav-doctor.json >/dev/null
jq -e '.marketplace.root == "'"$ROOT"'"' /tmp/specnav-doctor.json >/dev/null
jq -e '.marketplace.plugin_source == "./"' /tmp/specnav-doctor.json >/dev/null
jq -e '.checks[] | select(.name == "hooks" and .status == "pass")' /tmp/specnav-doctor.json >/dev/null
jq -e '.workspaceSupport == "available"' /tmp/specnav-doctor.json >/dev/null
jq -e '.configStatus == "configured"' /tmp/specnav-doctor.json >/dev/null

MULTI="$TMP/multi-plugin-repo"
mkdir -p "$MULTI/.claude-plugin" "$MULTI/plugins/specnav"
cp -R "$ROOT/.claude-plugin" "$MULTI/plugins/specnav/.claude-plugin"
cp -R "$ROOT/commands" "$MULTI/plugins/specnav/commands"
cp -R "$ROOT/skills" "$MULTI/plugins/specnav/skills"
cp -R "$ROOT/hooks" "$MULTI/plugins/specnav/hooks"
cp -R "$ROOT/scripts" "$MULTI/plugins/specnav/scripts"
cat >"$MULTI/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "multi-plugin-marketplace",
  "description": "Fixture marketplace with more than one plugin.",
  "owner": {"name": "test"},
  "plugins": [
    {
      "name": "specnav",
      "source": "plugins/specnav",
      "description": "SpecNav fixture",
      "version": "0.3.0"
    },
    {
      "name": "other-plugin",
      "source": "plugins/other-plugin",
      "description": "Other fixture",
      "version": "0.1.0"
    }
  ]
}
JSON

node "$ROOT/scripts/specnav-doctor.js" --marketplace-root "$MULTI" --plugin-name specnav --json >/tmp/specnav-doctor-multi.json
jq -e '.ok == true' /tmp/specnav-doctor-multi.json >/dev/null
jq -e '.marketplace.root == "'"$MULTI"'"' /tmp/specnav-doctor-multi.json >/dev/null
jq -e '.marketplace.plugin_source == "plugins/specnav"' /tmp/specnav-doctor-multi.json >/dev/null
jq -e '.plugin.root == "'"$MULTI/plugins/specnav"'"' /tmp/specnav-doctor-multi.json >/dev/null

set +e
node "$ROOT/scripts/specnav-doctor.js" --marketplace-root "$MULTI" --plugin-name missing --json >/tmp/specnav-doctor-missing.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.ok == false' /tmp/specnav-doctor-missing.json >/dev/null
jq -e '.checks[] | select(.name == "plugin-resolution" and .status == "fail")' /tmp/specnav-doctor-missing.json >/dev/null

echo "specnav doctor fixtures ok"
```

- [ ] **Step 2: Run fixture and verify it fails**

Run:

```bash
bash tests/run-doctor-fixtures.sh
```

Expected: FAIL with `Cannot find module` for `scripts/specnav-doctor.js`.

- [ ] **Step 3: Create `scripts/plugin-repository.js`**

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

function argValue(args, name, fallback = null) {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : fallback;
}

function marketplaceFile(root) {
  return path.join(root, '.claude-plugin', 'marketplace.json');
}

function pluginFile(root) {
  return path.join(root, '.claude-plugin', 'plugin.json');
}

function findMarketplaceRoot(start) {
  let current = path.resolve(start);
  while (true) {
    if (fs.existsSync(marketplaceFile(current))) return current;
    const parent = path.dirname(current);
    if (parent === current) return null;
    current = parent;
  }
}

function resolvePluginRepository(options = {}) {
  const requestedPluginName = options.pluginName || 'specnav';
  const explicitPluginRoot = options.pluginRoot ? path.resolve(options.pluginRoot) : null;
  const explicitMarketplaceRoot = options.marketplaceRoot ? path.resolve(options.marketplaceRoot) : null;

  const searchStart = explicitPluginRoot || explicitMarketplaceRoot || process.env.CLAUDE_PLUGIN_ROOT || process.cwd();
  const marketplaceRoot = explicitMarketplaceRoot || findMarketplaceRoot(searchStart) || explicitPluginRoot || searchStart;
  const marketplace = readJson(marketplaceFile(marketplaceRoot), null);

  if (!marketplace || !Array.isArray(marketplace.plugins)) {
    if (explicitPluginRoot && fs.existsSync(pluginFile(explicitPluginRoot))) {
      const plugin = readJson(pluginFile(explicitPluginRoot), {});
      return {
        ok: true,
        marketplaceRoot: explicitPluginRoot,
        marketplaceName: null,
        pluginName: plugin.name || requestedPluginName,
        pluginSource: './',
        pluginRoot: explicitPluginRoot,
        plugin
      };
    }
    return {
      ok: false,
      error: 'marketplace-json-missing-or-invalid',
      marketplaceRoot,
      pluginName: requestedPluginName,
      pluginRoot: explicitPluginRoot
    };
  }

  const entry = marketplace.plugins.find((item) => item.name === requestedPluginName)
    || (explicitPluginRoot && marketplace.plugins.find((item) => path.resolve(marketplaceRoot, item.source || './') === explicitPluginRoot));

  if (!entry) {
    return {
      ok: false,
      error: `plugin-not-found:${requestedPluginName}`,
      marketplaceRoot,
      marketplaceName: marketplace.name || null,
      pluginName: requestedPluginName,
      availablePlugins: marketplace.plugins.map((item) => item.name).filter(Boolean)
    };
  }

  const pluginSource = entry.source || './';
  const pluginRoot = path.resolve(marketplaceRoot, pluginSource);
  const plugin = readJson(pluginFile(pluginRoot), {});

  return {
    ok: true,
    marketplaceRoot,
    marketplaceName: marketplace.name || null,
    pluginName: entry.name,
    pluginSource,
    pluginRoot,
    plugin
  };
}

function main() {
  const args = process.argv.slice(2);
  const result = resolvePluginRepository({
    marketplaceRoot: argValue(args, '--marketplace-root'),
    pluginRoot: argValue(args, '--plugin-root'),
    pluginName: argValue(args, '--plugin-name', 'specnav')
  });
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = {
  findMarketplaceRoot,
  resolvePluginRepository
};
```

- [ ] **Step 4: Create `scripts/specnav-doctor.js`**

```js
#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const repository = require('./plugin-repository');

function argValue(args, name, fallback = null) {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : fallback;
}

function check(name, condition, detail = '') {
  return { name, status: condition ? 'pass' : 'fail', detail };
}

function doctor(options = {}) {
  const resolution = repository.resolvePluginRepository(options);
  const pluginRoot = resolution.pluginRoot ? path.resolve(resolution.pluginRoot) : path.resolve(options.pluginRoot || __dirname, '..');
  const checks = [];
  checks.push(check('plugin-resolution', resolution.ok, resolution.error || resolution.pluginName));
  checks.push(check('plugin-json', fs.existsSync(path.join(pluginRoot, '.claude-plugin/plugin.json'))));
  checks.push(check('hooks', fs.existsSync(path.join(pluginRoot, 'hooks/hooks.json'))));
  checks.push(check('skills', fs.existsSync(path.join(pluginRoot, 'skills'))));
  checks.push(check('commands', fs.existsSync(path.join(pluginRoot, 'commands'))));
  checks.push(check('scripts', fs.existsSync(path.join(pluginRoot, 'scripts/affordances.js')) && fs.existsSync(path.join(pluginRoot, 'scripts/specnav-guard.js'))));
  const ok = checks.every((item) => item.status === 'pass');
  return {
    schema: 'specnav.doctor.v1',
    generated_at: new Date().toISOString(),
    ok,
    workspaceSupport: 'available',
    configStatus: ok ? 'configured' : 'incomplete',
    marketplace: {
      root: resolution.marketplaceRoot || pluginRoot,
      name: resolution.marketplaceName || null,
      plugin_source: resolution.pluginSource || null
    },
    plugin: {
      name: resolution.pluginName || null,
      root: pluginRoot
    },
    checks
  };
}

function main() {
  const args = process.argv.slice(2);
  const result = doctor({
    marketplaceRoot: argValue(args, '--marketplace-root'),
    pluginRoot: argValue(args, '--plugin-root', path.resolve(__dirname, '..')),
    pluginName: argValue(args, '--plugin-name', 'specnav')
  });
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = { doctor };
```

- [ ] **Step 5: Create doctor command and skill**

Create `commands/specnav-doctor.md`:

```markdown
---
description: Verify SpecNav plugin installation and project health
argument-hint: "[--json]"
---

Run from the plugin root, not the target project:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/specnav-doctor.js" --plugin-root "$CLAUDE_PLUGIN_ROOT" --plugin-name specnav --json
```

For a marketplace repository containing multiple plugins, run from the marketplace root and select the plugin:

```bash
node plugins/specnav/scripts/specnav-doctor.js --marketplace-root "$PWD" --plugin-name specnav --json
```

Success requires `ok: true`, `workspaceSupport: available`, and `configStatus: configured`.
```

Create `skills/doctor/SKILL.md`:

```markdown
---
name: doctor
description: Verify SpecNav install and runtime health
allowed-tools:
  - Bash
  - Read
---

# Doctor

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/specnav-doctor.js" --plugin-root "$CLAUDE_PLUGIN_ROOT" --plugin-name specnav --json
```

Do not run doctor from the target project directory.

If the plugin is installed from a marketplace repository that contains multiple plugins, pass `--marketplace-root <repo>` and `--plugin-name specnav`. Doctor must verify the resolved individual plugin root, not every plugin in the marketplace.

Report every failed check exactly as printed.
```

- [ ] **Step 6: Run doctor fixture**

Run:

```bash
chmod +x tests/run-doctor-fixtures.sh
bash tests/run-doctor-fixtures.sh
```

Expected:

```text
specnav doctor fixtures ok
```

- [ ] **Step 7: Commit**

```bash
git add scripts/plugin-repository.js scripts/specnav-doctor.js commands/specnav-doctor.md skills/doctor/SKILL.md tests/run-doctor-fixtures.sh
git commit -m "feat: add specnav doctor"
```

---

### Task 11: Bootstrap, Debug, and Break-loop Skills

**Files:**
- Create: `skills/using-specnav/SKILL.md`
- Create: `skills/debug/SKILL.md`
- Create: `skills/break-loop/SKILL.md`
- Modify: `hooks/hooks.json`
- Modify: `.claude-plugin/plugin.json`
- Create: `tests/run-skill-surface-fixtures.sh`

- [ ] **Step 1: Write skill surface fixture**

Create `tests/run-skill-surface-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for skill in using-specnav debug break-loop doctor requirements prototype verify-static ops-readiness; do
  test -f "$ROOT/skills/$skill/SKILL.md"
  grep -q "^name: $skill" "$ROOT/skills/$skill/SKILL.md"
done

jq -e '.skills == "./skills/"' "$ROOT/.claude-plugin/plugin.json" >/dev/null
jq -e '.hooks.SessionStart | length >= 1' "$ROOT/hooks/hooks.json" >/dev/null
jq -e '.hooks.PreToolUse | length >= 1' "$ROOT/hooks/hooks.json" >/dev/null

echo "specnav skill surface fixtures ok"
```

- [ ] **Step 2: Run fixture and verify it fails**

Run:

```bash
bash tests/run-skill-surface-fixtures.sh
```

Expected: FAIL because `using-specnav`, `debug`, or `break-loop` skill files do not exist.

- [ ] **Step 3: Create `skills/using-specnav/SKILL.md`**

```markdown
---
name: using-specnav
description: Bootstrap SpecNav state and route user intent through OpenSpec lifecycle gates
allowed-tools:
  - Bash
  - Read
---

# Using SpecNav

At session start or when SpecNav is mentioned, run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/workflow-state.js" --write --json
node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --json
```

Use the returned legal actions and blocked actions.

Production edits are blocked unless the current state allows them.

If `openspec/` is missing, route only to initialization or repair.
```

- [ ] **Step 4: Create debug skills**

Create `skills/debug/SKILL.md`:

```markdown
---
name: debug
description: Investigate repeated SpecNav workflow failures with evidence
allowed-tools:
  - Bash
  - Read
  - Write
---

# Debug

Use when the same gate fails repeatedly or verification failures are unclear.

Write a debug note under `openspec/.specnav/journal/` containing:

- root-cause statement
- reproduction evidence
- failed attempts
- hypotheses
- next experiment
- re-verification command
```

Create `skills/break-loop/SKILL.md`:

```markdown
---
name: break-loop
description: Stop repeated patch loops and force a SpecNav root-cause reset
allowed-tools:
  - Bash
  - Read
  - Write
---

# Break Loop

Use when a fix is reverted, the same test keeps failing, or the agent starts patching symptoms.

Stop production edits.

Write a journal entry under `openspec/.specnav/journal/` with the exact failing command, last three attempts, suspected wrong assumption, and next smallest experiment.
```

- [ ] **Step 5: Run skill fixture**

Run:

```bash
chmod +x tests/run-skill-surface-fixtures.sh
bash tests/run-skill-surface-fixtures.sh
```

Expected:

```text
specnav skill surface fixtures ok
```

- [ ] **Step 6: Commit**

```bash
git add skills/using-specnav/SKILL.md skills/debug/SKILL.md skills/break-loop/SKILL.md tests/run-skill-surface-fixtures.sh hooks/hooks.json .claude-plugin/plugin.json
git commit -m "feat: add specnav bootstrap and debug skills"
```

---

### Task 12: Bilingual README and Release Documentation

**Files:**
- Modify: `README.md`
- Create: `README.zh-CN.md`
- Modify: `CHANGELOG.md`
- Create: `tests/run-doc-fixtures.sh`

- [ ] **Step 1: Write doc fixture**

Create `tests/run-doc-fixtures.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

grep -q "SpecNav" "$ROOT/README.md"
grep -q "Claude Code" "$ROOT/README.md"
grep -q "OpenSpec" "$ROOT/README.md"
grep -q "No fallback" "$ROOT/README.md"
grep -q "Installation verification" "$ROOT/README.md"
grep -q "Host-scoped update" "$ROOT/README.md"
grep -q "Marketplace repository" "$ROOT/README.md"
grep -q "plugin root" "$ROOT/README.md"

test -f "$ROOT/README.zh-CN.md"
grep -q "无 fallback" "$ROOT/README.zh-CN.md"
grep -q "安装验证" "$ROOT/README.zh-CN.md"
grep -q "宿主级更新" "$ROOT/README.zh-CN.md"
grep -q "多插件仓库" "$ROOT/README.zh-CN.md"
grep -q "插件根目录" "$ROOT/README.zh-CN.md"

grep -q "0.3.0" "$ROOT/CHANGELOG.md"

echo "specnav doc fixtures ok"
```

- [ ] **Step 2: Run fixture and verify it fails**

Run:

```bash
bash tests/run-doc-fixtures.sh
```

Expected: FAIL until README and changelog contain the required release language.

- [ ] **Step 3: Update English README**

Ensure `README.md` contains these sections:

```markdown
## What SpecNav Does

SpecNav is a Claude Code plugin for OpenSpec-driven engineering work. It routes work through requirements, prototype, development, six-domain verification, operations, and archive gates.

## No Fallback

Required workflow state is not optional. Missing OpenSpec state, missing foundation specs, missing prototype artifacts, missing development handoff, red verification, missing operations readiness, or failed doctor checks block dependent actions.

## Installation Verification

Run doctor from the plugin root:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/specnav-doctor.js" --plugin-root "$CLAUDE_PLUGIN_ROOT" --plugin-name specnav --json
```

Success requires `ok: true`, `workspaceSupport: "available"`, and `configStatus: "configured"`.

## Marketplace repository

Claude Code can install multiple plugins from one marketplace repository. SpecNav distinguishes:

- `marketplace root`: the repository containing `.claude-plugin/marketplace.json`
- `plugin root`: the individual plugin source directory referenced by `marketplace.json.plugins[].source`

For a multi-plugin repository, run:

```bash
node plugins/specnav/scripts/specnav-doctor.js --marketplace-root "$PWD" --plugin-name specnav --json
```

## Host-scoped Update

SpecNav updates the current host by default. Updating every registered host requires an explicit all-host request.
```

- [ ] **Step 4: Create Chinese README**

Create `README.zh-CN.md`:

```markdown
# SpecNav

SpecNav 是构建在 OpenSpec 之上的 Claude Code 工程生命周期插件。

## 主流程

SpecNav 将工作路由到需求、原型、开发、六域验证、运维和归档阶段。

## 无 fallback

必需工作流状态不可缺省。缺 OpenSpec、缺 foundation specs、缺原型 artifact、缺开发 handoff、验证为 red、缺 operations readiness 或 doctor 失败，都会阻断依赖动作。

## 安装验证

从插件根目录运行 doctor：

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/specnav-doctor.js" --plugin-root "$CLAUDE_PLUGIN_ROOT" --plugin-name specnav --json
```

成功条件是 `ok: true`、`workspaceSupport: "available"`、`configStatus: "configured"`。

## 多插件仓库

Claude Code 支持一个 marketplace 仓库下包含多个插件。SpecNav 必须区分：

- `marketplace root`：包含 `.claude-plugin/marketplace.json` 的仓库根目录。
- `plugin root`：`marketplace.json.plugins[].source` 指向的单个插件根目录。

多插件仓库下运行：

```bash
node plugins/specnav/scripts/specnav-doctor.js --marketplace-root "$PWD" --plugin-name specnav --json
```

## 宿主级更新

SpecNav 默认只更新当前宿主。更新所有已登记宿主必须由用户显式要求。
```

- [ ] **Step 5: Update changelog**

Add to top of `CHANGELOG.md`:

```markdown
## 0.3.0

- Added lifecycle contracts for requirements, prototype, development, six-domain verification, operations, doctor, and archive.
- Added strict no-fallback gates for required OpenSpec and SpecNav artifacts.
- Added marketplace repository support so install verification resolves the SpecNav plugin root inside multi-plugin repositories.
- Added bilingual documentation requirements.
```

- [ ] **Step 6: Run doc fixture**

Run:

```bash
chmod +x tests/run-doc-fixtures.sh
bash tests/run-doc-fixtures.sh
```

Expected:

```text
specnav doc fixtures ok
```

- [ ] **Step 7: Commit**

```bash
git add README.md README.zh-CN.md CHANGELOG.md tests/run-doc-fixtures.sh
git commit -m "docs: add bilingual specnav lifecycle documentation"
```

---

### Task 13: Full Fixture Suite and Release Readiness

**Files:**
- Create: `tests/run-all.sh`
- Modify: `docs/design.md`
- Modify: `docs/specnav-plan-review.html`

- [ ] **Step 1: Create aggregate test runner**

Create `tests/run-all.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

bash "$ROOT/tests/run-contract-fixtures.sh"
bash "$ROOT/tests/run-foundation-fixtures.sh"
bash "$ROOT/tests/run-workflow-state-fixtures.sh"
bash "$ROOT/tests/run-no-fallback-fixtures.sh"
bash "$ROOT/tests/run-requirements-fixtures.sh"
bash "$ROOT/tests/run-prototype-fixtures.sh"
bash "$ROOT/tests/run-development-fixtures.sh"
bash "$ROOT/tests/run-verify-domain-fixtures.sh"
bash "$ROOT/tests/run-operations-fixtures.sh"
bash "$ROOT/tests/run-doctor-fixtures.sh"
bash "$ROOT/tests/run-skill-surface-fixtures.sh"
bash "$ROOT/tests/run-doc-fixtures.sh"
bash "$ROOT/tests/run-hook-fixtures.sh"
bash "$ROOT/tests/run-override-fixtures.sh"
bash "$ROOT/tests/run-openspec-fixtures.sh"
bash "$ROOT/tests/run-archive-policy-fixtures.sh"
bash "$ROOT/tests/run-smoke.sh"

echo "specnav full fixture suite ok"
```

- [ ] **Step 2: Run aggregate suite**

Run:

```bash
chmod +x tests/run-all.sh
bash tests/run-all.sh
```

Expected:

```text
specnav full fixture suite ok
```

- [ ] **Step 3: Validate git diff hygiene**

Run:

```bash
git diff --check
git status --short --ignored
```

Expected:

- `git diff --check` prints nothing.
- `reference-repos/` remains ignored.
- No generated `.specnav/events.jsonl` fixture noise is staged.

- [ ] **Step 4: Update design docs only for implementation deltas**

If implementation changed a contract name, update `docs/design.md` and `docs/specnav-plan-review.html` to match the code. Use exact code names from scripts:

```bash
rg -n "plugin-repository|requirements-contract|prototype-contract|development-contract|verify-domains|operations-gate|specnav-doctor" docs scripts
```

Expected: docs and scripts use the same contract names.

- [ ] **Step 5: Commit final readiness**

```bash
git add tests/run-all.sh docs/design.md docs/specnav-plan-review.html
git commit -m "test: add full specnav lifecycle fixture suite"
```

---

## Self-Review

### Spec Coverage

- Global no-fallback policy: Tasks 3 and 4.
- Four foundation specs before requirements: Tasks 2 and 5.
- Requirements artifacts and question discipline: Task 5.
- Prototype code and handoff gate: Task 6.
- Development scope, task ledger, review loop, drift, handoff: Task 7.
- Six dedicated verification domains, traceability, receipt, blocker classes, aggregate report: Task 8.
- Operations readiness, release target, install/update, compatibility, branch finish, deploy, rollback, monitor, postmortem, update-spec, archive gate: Task 9.
- Multi-plugin marketplace root and plugin root resolution: Task 10.
- Doctor and installation verification: Task 10.
- Bootstrap/router/status skills: Tasks 3 and 11.
- Debug and break-loop: Task 11.
- Bilingual README and release docs: Task 12.
- Fixture suite and release readiness: Task 13.

### Placeholder Scan

Searched plan content against the prohibited placeholder patterns from the writing-plans skill. No implementation steps contain placeholder wording.

### Type and Name Consistency

Contract names used consistently:

- `specnav.requirements.specMap.v1`
- `specnav.requirements.componentImpact.v1`
- `specnav.prototype.manifest.v1`
- `specnav.prototype.verifier.v1`
- `specnav.prototype.decision.v1`
- `specnav.development.prototypePromotion.v1`
- `specnav.verify.plan.v1`
- `specnav.verify.domainReport.v1`
- `specnav.verify.aggregate.v1`
- `specnav.ops.readiness.v1`
- `specnav.doctor.v1`

Script APIs used consistently:

- `validateFoundationSpecs(root)`
- `buildWorkflowState(root)`
- `validatePrototype(root)`
- `validateDevelopment(root)`
- `validateVerify(root)`
- `writeAggregate(root)`
- `validateOperations(root)`
- `resolvePluginRepository(options)`
- `doctor(options)`
