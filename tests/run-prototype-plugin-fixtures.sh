#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROTO="$ROOT/plugins/helm-prototype"
PROJECT="$ROOT/tests/fixtures/simple-project"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

run_json() {
  local project="$1"
  local output="$2"
  local expected_status="$3"
  local status

  set +e
  PROJECT_DIR="$project" node "$PROTO/scripts/prototype-contract.js" --json >"$output"
  status=$?
  set -e
  [[ "$status" == "$expected_status" ]]
}

assert_blocker() {
  local output="$1"
  local blocker="$2"

  jq -e --arg blocker "$blocker" '.blockers[] | select(. == $blocker)' "$output" >/dev/null
}

write_requirements_project() {
  local project="$1"
  local change="add-dashboard"

  mkdir -p \
    "$project/openspec/.helm" \
    "$project/openspec/specs/ui-design" \
    "$project/openspec/specs/system-architecture" \
    "$project/openspec/specs/frontend-backend-data-flow" \
    "$project/openspec/specs/component-architecture" \
    "$project/openspec/changes/$change"

  printf '%s\n' "$change" >"$project/openspec/.helm/active-change"

  cat >"$project/openspec/specs/ui-design/design.md" <<'MD'
---
version: 1.0.0
name: UI Design
description: Product interface standards
colors: {}
typography: {}
spacing: {}
rounded: {}
components: []
---
# UI Design

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

  cat >"$project/openspec/changes/$change/requirements.md" <<'MD'
# Requirements

- Add a dashboard view backed by the existing application shell.
MD

  cat >"$project/openspec/changes/$change/acceptance.md" <<'MD'
# Acceptance

- Dashboard renders with loading, empty, and error states covered.
MD

  cat >"$project/openspec/changes/$change/spec-map.json" <<'JSON'
{
  "touched_specs": ["ui-design", "system-architecture"],
  "ui_rules": ["dashboard-layout"],
  "architecture_modules": ["dashboard-shell"],
  "api_contracts": [],
  "database_entities": [],
  "permissions": [],
  "operational_constraints": [],
  "data_flows": [],
  "unresolved_gaps": []
}
JSON

  cat >"$project/openspec/changes/$change/component-impact-map.json" <<'JSON'
{
  "new_components": ["DashboardView"],
  "reused_components": [],
  "extraction_triggers": [],
  "forbidden_dependencies": [],
  "hooks": [],
  "utilities": [],
  "services": [],
  "required_component_tests": ["DashboardView renders loading empty error states"],
  "unresolved_gaps": []
}
JSON
}

write_ui_prototype() {
  local project="$1"
  local prototype="$project/openspec/changes/add-dashboard/prototype"

  mkdir -p "$prototype/artifact"

  cat >"$prototype/question.md" <<'MD'
# Prototype Question

Branch: ui-html

Question: Which dashboard layout should be approved before implementation?
MD

  cat >"$prototype/artifact/index.html" <<'HTML'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Dashboard Prototype</title>
  </head>
  <body>
    <main data-helm-screen="dashboard" data-helm-variant="balanced">
      <section data-helm-component="dashboard-summary">Dashboard summary</section>
    </main>
  </body>
</html>
HTML

  cat >"$prototype/screen-map.json" <<'JSON'
{
  "screens": [
    {
      "id": "dashboard",
      "requirements": ["requirements.md#dashboard-view"],
      "acceptance": ["Dashboard renders with loading, empty, and error states covered."],
      "components": ["DashboardView", "DashboardSummary"],
      "data_flows": ["Dashboard summary API response populates dashboard view state"],
      "implementation_files": ["src/dashboard/DashboardView.tsx", "src/dashboard/useDashboardState.ts"]
    }
  ]
}
JSON

  cat >"$prototype/prototype-manifest.json" <<'JSON'
{
  "schema": "helm.prototype.manifest.v1",
  "version": "1.0.0",
  "type": "ui-html",
  "entry": "artifact/index.html",
  "dependencies": [],
  "mock_strategy": "Static HTML uses mock dashboard counts only.",
  "touches_real_data": false,
  "referenced_foundation_specs": ["ui-design", "system-architecture"],
  "referenced_requirements": ["requirements.md", "acceptance.md"],
  "may_promote": false,
  "promotion_requirement": "Prototype decisions must enter development through scope.json and tasks.md."
}
JSON

  cat >"$prototype/verifier-report.json" <<'JSON'
{
  "schema": "helm.prototype.verifier.v1",
  "status": "green",
  "checked_entry": "artifact/index.html",
  "checks": ["entry exists", "desktop viewport reviewed", "mobile viewport reviewed"]
}
JSON

  cat >"$prototype/handoff.md" <<'MD'
# Prototype Handoff

## Approved branch and variant

- Branch: ui-html
- Variant: balanced

## Screens or flows to implement

- Dashboard screen with summary metrics and reviewable states.

## Components to create

- DashboardView.

## Components to reuse

- Existing application shell and summary card primitives.

## Components, hooks, utilities, and services to extract

- Components: DashboardSummary.
- Hooks: useDashboardState.
- Utilities: formatDashboardMetric.
- Services: dashboardSummaryService.

## API contracts

- GET /api/dashboard/summary returns metric counts and permission flags for the dashboard.

## Data flows

- DashboardView loads the summary API response into local view state before rendering metrics.

## State, loading, empty, error, disabled, and permission behavior

- Required states cover loading, empty, error, disabled refresh, and permission denied views.

## Out-of-scope items

- Live analytics filtering and export workflows stay outside this prototype handoff.

## Required tests

- DashboardView covers loading, empty, error, disabled, and permission behavior.

## Open risks

- Backend summary fields may need final naming during development.
MD

  cat >"$prototype/decision.json" <<'JSON'
{
  "status": "approved",
  "prototype_code": "required_present",
  "prototype_type": "ui-html",
  "approved_variant": "balanced",
  "promotion": "requires_development_gate",
  "blocked_reasons": []
}
JSON
}

test -f "$PROTO/scripts/prototype-contract.js"
test -f "$PROTO/skills/helm-prototype/SKILL.md"
test -f "$PROTO/skills/helm-prototype-verify/SKILL.md"
test -f "$PROTO/skills/helm-prototype-handoff/SKILL.md"
grep -q 'helm-prototype' "$PROTO/commands/helm-prototype.md"
grep -Fq '../../helm-requirements/scripts/requirements-contract' "$PROTO/scripts/prototype-contract.js"
! grep -Fq 'scripts/contracts' "$PROTO/scripts/prototype-contract.js"

grep -Fq 'node "$HELM_CORE_ROOT/scripts/plugin-suite.js" require' "$PROTO/commands/helm-prototype.md"
grep -Fq -- '--marketplace-root "$HELM_MARKETPLACE_ROOT"' "$PROTO/commands/helm-prototype.md"
grep -Fq 'node "$HELM_PROTOTYPE_ROOT/scripts/prototype-contract.js" --json' "$PROTO/commands/helm-prototype.md"

grep -Fiq 'no fallback' "$PROTO/skills/helm-prototype/SKILL.md"
grep -Fq 'Branch Classification' "$PROTO/skills/helm-prototype/SKILL.md"
grep -Fq 'node "$HELM_PROTOTYPE_ROOT/scripts/prototype-contract.js" --json' "$PROTO/skills/helm-prototype/SKILL.md"
grep -Fq 'verifier-report.json' "$PROTO/skills/helm-prototype-verify/SKILL.md"
grep -Fq 'node "$HELM_PROTOTYPE_ROOT/scripts/prototype-contract.js" --json' "$PROTO/skills/helm-prototype-verify/SKILL.md"
grep -Fq 'required_present' "$PROTO/skills/helm-prototype-handoff/SKILL.md"
grep -Fq 'node "$HELM_PROTOTYPE_ROOT/scripts/prototype-contract.js" --json' "$PROTO/skills/helm-prototype-handoff/SKILL.md"

jq -e '.contracts.prototype == "scripts/prototype-contract.js"' "$PROTO/helm-stage.json" >/dev/null
jq -e 'has("planned_contracts") | not' "$PROTO/helm-stage.json" >/dev/null

run_json "$PROJECT" "$TMP_DIR/simple-project.json" 2
jq -e '.ok == false' "$TMP_DIR/simple-project.json" >/dev/null
jq -e '.prototype_dir == null' "$TMP_DIR/simple-project.json" >/dev/null
assert_blocker "$TMP_DIR/simple-project.json" 'requirements-blocked'

HAPPY_PROJECT="$TMP_DIR/happy-project"
write_requirements_project "$HAPPY_PROJECT"
write_ui_prototype "$HAPPY_PROJECT"
run_json "$HAPPY_PROJECT" "$TMP_DIR/happy-prototype.json" 0
jq -e '.ok == true' "$TMP_DIR/happy-prototype.json" >/dev/null
jq -e '.active_change == "add-dashboard"' "$TMP_DIR/happy-prototype.json" >/dev/null
jq -e '.manifest.type == "ui-html"' "$TMP_DIR/happy-prototype.json" >/dev/null

WEAK_HANDOFF_PROJECT="$TMP_DIR/weak-handoff-project"
cp -R "$HAPPY_PROJECT" "$WEAK_HANDOFF_PROJECT"
cat >"$WEAK_HANDOFF_PROJECT/openspec/changes/add-dashboard/prototype/handoff.md" <<'MD'
# Prototype Handoff

Approved branch: ui-html

Implement the dashboard screen using the existing shell.
MD
run_json "$WEAK_HANDOFF_PROJECT" "$TMP_DIR/weak-handoff.json" 2
assert_blocker "$TMP_DIR/weak-handoff.json" 'invalid-prototype-handoff:required-tests'

LABEL_ONLY_HANDOFF_PROJECT="$TMP_DIR/label-only-handoff-project"
cp -R "$HAPPY_PROJECT" "$LABEL_ONLY_HANDOFF_PROJECT"
cat >"$LABEL_ONLY_HANDOFF_PROJECT/openspec/changes/add-dashboard/prototype/handoff.md" <<'MD'
# Prototype Handoff

Approved branch and variant: ui-html balanced.
Screens or flows to implement: Dashboard screen with summary metrics and reviewable states.
Components to create: DashboardView.
Components to reuse: Existing application shell and summary card primitives.
Components, hooks, utilities, and services to extract: DashboardSummary, useDashboardState, formatDashboardMetric, dashboardSummaryService.
API contracts: GET /api/dashboard/summary returns metric counts and permission flags for the dashboard.
Data flows: DashboardView loads the summary API response into local view state before rendering metrics.
State, loading, empty, error, disabled, and permission behavior: Required states cover loading, empty, error, disabled refresh, and permission denied views.
Out-of-scope items: Live analytics filtering and export workflows stay outside this prototype handoff.
Required tests: DashboardView covers loading, empty, error, disabled, and permission behavior.
Open risks: Backend summary fields may need final naming during development.
MD
run_json "$LABEL_ONLY_HANDOFF_PROJECT" "$TMP_DIR/label-only-handoff.json" 2
assert_blocker "$TMP_DIR/label-only-handoff.json" 'invalid-prototype-handoff:approved-branch-variant'

EMPTY_HANDOFF_HEADINGS_PROJECT="$TMP_DIR/empty-handoff-headings-project"
cp -R "$HAPPY_PROJECT" "$EMPTY_HANDOFF_HEADINGS_PROJECT"
cat >"$EMPTY_HANDOFF_HEADINGS_PROJECT/openspec/changes/add-dashboard/prototype/handoff.md" <<'MD'
# Prototype Handoff

## Approved branch and variant

## Screens or flows to implement

## Components to create

## Components to reuse

## Components, hooks, utilities, and services to extract

## API contracts

## Data flows

## State, loading, empty, error, disabled, and permission behavior

## Out-of-scope items

## Required tests

## Open risks
MD
run_json "$EMPTY_HANDOFF_HEADINGS_PROJECT" "$TMP_DIR/empty-handoff-headings.json" 2
assert_blocker "$TMP_DIR/empty-handoff-headings.json" 'invalid-prototype-handoff:required-tests'

MISSING_SCREEN_IMPLEMENTATION_PROJECT="$TMP_DIR/missing-screen-implementation-project"
cp -R "$HAPPY_PROJECT" "$MISSING_SCREEN_IMPLEMENTATION_PROJECT"
jq 'del(.screens[0].implementation_files)' \
  "$MISSING_SCREEN_IMPLEMENTATION_PROJECT/openspec/changes/add-dashboard/prototype/screen-map.json" \
  >"$TMP_DIR/missing-screen-implementation.json.tmp"
mv "$TMP_DIR/missing-screen-implementation.json.tmp" "$MISSING_SCREEN_IMPLEMENTATION_PROJECT/openspec/changes/add-dashboard/prototype/screen-map.json"
run_json "$MISSING_SCREEN_IMPLEMENTATION_PROJECT" "$TMP_DIR/missing-screen-implementation.json" 2
assert_blocker "$TMP_DIR/missing-screen-implementation.json" 'invalid-screen-map-contract:screen-map.json'

EMPTY_SCREEN_COMPONENTS_PROJECT="$TMP_DIR/empty-screen-components-project"
cp -R "$HAPPY_PROJECT" "$EMPTY_SCREEN_COMPONENTS_PROJECT"
jq '.screens[0].components = []' \
  "$EMPTY_SCREEN_COMPONENTS_PROJECT/openspec/changes/add-dashboard/prototype/screen-map.json" \
  >"$TMP_DIR/empty-screen-components.json.tmp"
mv "$TMP_DIR/empty-screen-components.json.tmp" "$EMPTY_SCREEN_COMPONENTS_PROJECT/openspec/changes/add-dashboard/prototype/screen-map.json"
run_json "$EMPTY_SCREEN_COMPONENTS_PROJECT" "$TMP_DIR/empty-screen-components.json" 2
assert_blocker "$TMP_DIR/empty-screen-components.json" 'invalid-screen-map-contract:screen-map.json'

ENTRY_ESCAPE_PROJECT="$TMP_DIR/entry-escape-project"
cp -R "$HAPPY_PROJECT" "$ENTRY_ESCAPE_PROJECT"
jq '.entry = "../outside.html"' \
  "$ENTRY_ESCAPE_PROJECT/openspec/changes/add-dashboard/prototype/prototype-manifest.json" \
  >"$TMP_DIR/entry-escape-manifest.json"
mv "$TMP_DIR/entry-escape-manifest.json" "$ENTRY_ESCAPE_PROJECT/openspec/changes/add-dashboard/prototype/prototype-manifest.json"
run_json "$ENTRY_ESCAPE_PROJECT" "$TMP_DIR/entry-escape.json" 2
assert_blocker "$TMP_DIR/entry-escape.json" 'invalid-prototype-entry-path'

SYMLINK_FILE_ESCAPE_PROJECT="$TMP_DIR/symlink-file-escape-project"
cp -R "$HAPPY_PROJECT" "$SYMLINK_FILE_ESCAPE_PROJECT"
mkdir -p "$TMP_DIR/escaped-ui-artifact"
printf '%s\n' '<!doctype html><title>Escaped</title>' >"$TMP_DIR/escaped-ui-artifact/index.html"
rm "$SYMLINK_FILE_ESCAPE_PROJECT/openspec/changes/add-dashboard/prototype/artifact/index.html"
ln -s "$TMP_DIR/escaped-ui-artifact/index.html" \
  "$SYMLINK_FILE_ESCAPE_PROJECT/openspec/changes/add-dashboard/prototype/artifact/index.html"
run_json "$SYMLINK_FILE_ESCAPE_PROJECT" "$TMP_DIR/symlink-file-escape.json" 2
assert_blocker "$TMP_DIR/symlink-file-escape.json" 'prototype-path-escape:artifact/index.html'
assert_blocker "$TMP_DIR/symlink-file-escape.json" 'prototype-branch-artifact-escape:artifact/index.html'

SYMLINK_DIR_ESCAPE_PROJECT="$TMP_DIR/symlink-dir-escape-project"
cp -R "$HAPPY_PROJECT" "$SYMLINK_DIR_ESCAPE_PROJECT"
mkdir -p "$TMP_DIR/escaped-logic"
printf '%s\n' 'export const state = "escaped";' >"$TMP_DIR/escaped-logic/demo.js"
ln -s "$TMP_DIR/escaped-logic" \
  "$SYMLINK_DIR_ESCAPE_PROJECT/openspec/changes/add-dashboard/prototype/logic"
jq '.type = "logic-state" | .entry = "logic/demo.js"' \
  "$SYMLINK_DIR_ESCAPE_PROJECT/openspec/changes/add-dashboard/prototype/prototype-manifest.json" \
  >"$TMP_DIR/symlink-dir-escape-manifest.json.tmp"
mv "$TMP_DIR/symlink-dir-escape-manifest.json.tmp" "$SYMLINK_DIR_ESCAPE_PROJECT/openspec/changes/add-dashboard/prototype/prototype-manifest.json"
jq '.checked_entry = "logic/demo.js"' \
  "$SYMLINK_DIR_ESCAPE_PROJECT/openspec/changes/add-dashboard/prototype/verifier-report.json" \
  >"$TMP_DIR/symlink-dir-escape-verifier.json.tmp"
mv "$TMP_DIR/symlink-dir-escape-verifier.json.tmp" "$SYMLINK_DIR_ESCAPE_PROJECT/openspec/changes/add-dashboard/prototype/verifier-report.json"
jq '.prototype_type = "logic-state"' \
  "$SYMLINK_DIR_ESCAPE_PROJECT/openspec/changes/add-dashboard/prototype/decision.json" \
  >"$TMP_DIR/symlink-dir-escape-decision.json.tmp"
mv "$TMP_DIR/symlink-dir-escape-decision.json.tmp" "$SYMLINK_DIR_ESCAPE_PROJECT/openspec/changes/add-dashboard/prototype/decision.json"
run_json "$SYMLINK_DIR_ESCAPE_PROJECT" "$TMP_DIR/symlink-dir-escape.json" 2
assert_blocker "$TMP_DIR/symlink-dir-escape.json" 'prototype-path-escape:logic/demo.js'
assert_blocker "$TMP_DIR/symlink-dir-escape.json" 'prototype-branch-artifact-escape:logic'

PROTOTYPE_DIR_ESCAPE_PROJECT="$TMP_DIR/prototype-dir-escape-project"
cp -R "$HAPPY_PROJECT" "$PROTOTYPE_DIR_ESCAPE_PROJECT"
EXTERNAL_PROTOTYPE="$TMP_DIR/external-prototype"
mkdir -p "$EXTERNAL_PROTOTYPE"
cp -R "$HAPPY_PROJECT/openspec/changes/add-dashboard/prototype/." "$EXTERNAL_PROTOTYPE/"
rm -rf "$PROTOTYPE_DIR_ESCAPE_PROJECT/openspec/changes/add-dashboard/prototype"
ln -s "$EXTERNAL_PROTOTYPE" "$PROTOTYPE_DIR_ESCAPE_PROJECT/openspec/changes/add-dashboard/prototype"
run_json "$PROTOTYPE_DIR_ESCAPE_PROJECT" "$TMP_DIR/prototype-dir-escape.json" 2
assert_blocker "$TMP_DIR/prototype-dir-escape.json" 'prototype-dir-escape'

for status in red blocked; do
  VERIFIER_PROJECT="$TMP_DIR/verifier-$status-project"
  cp -R "$HAPPY_PROJECT" "$VERIFIER_PROJECT"
  jq --arg status "$status" '.status = $status' \
    "$VERIFIER_PROJECT/openspec/changes/add-dashboard/prototype/verifier-report.json" \
    >"$TMP_DIR/verifier-$status.json.tmp"
  mv "$TMP_DIR/verifier-$status.json.tmp" "$VERIFIER_PROJECT/openspec/changes/add-dashboard/prototype/verifier-report.json"
  run_json "$VERIFIER_PROJECT" "$TMP_DIR/verifier-$status.json" 2
  assert_blocker "$TMP_DIR/verifier-$status.json" "prototype-verifier-not-green:$status"
done

MISSING_VERIFIER_DETAILS_PROJECT="$TMP_DIR/missing-verifier-details-project"
cp -R "$HAPPY_PROJECT" "$MISSING_VERIFIER_DETAILS_PROJECT"
jq 'del(.checked_entry, .checks)' \
  "$MISSING_VERIFIER_DETAILS_PROJECT/openspec/changes/add-dashboard/prototype/verifier-report.json" \
  >"$TMP_DIR/missing-verifier-details.json.tmp"
mv "$TMP_DIR/missing-verifier-details.json.tmp" "$MISSING_VERIFIER_DETAILS_PROJECT/openspec/changes/add-dashboard/prototype/verifier-report.json"
run_json "$MISSING_VERIFIER_DETAILS_PROJECT" "$TMP_DIR/missing-verifier-details.json" 2
assert_blocker "$TMP_DIR/missing-verifier-details.json" 'invalid-prototype-verifier:checked_entry'
assert_blocker "$TMP_DIR/missing-verifier-details.json" 'invalid-prototype-verifier:checks'

MISMATCHED_VERIFIER_ENTRY_PROJECT="$TMP_DIR/mismatched-verifier-entry-project"
cp -R "$HAPPY_PROJECT" "$MISMATCHED_VERIFIER_ENTRY_PROJECT"
jq '.checked_entry = "artifact/alternate.html"' \
  "$MISMATCHED_VERIFIER_ENTRY_PROJECT/openspec/changes/add-dashboard/prototype/verifier-report.json" \
  >"$TMP_DIR/mismatched-verifier-entry.json.tmp"
mv "$TMP_DIR/mismatched-verifier-entry.json.tmp" "$MISMATCHED_VERIFIER_ENTRY_PROJECT/openspec/changes/add-dashboard/prototype/verifier-report.json"
run_json "$MISMATCHED_VERIFIER_ENTRY_PROJECT" "$TMP_DIR/mismatched-verifier-entry.json" 2
assert_blocker "$TMP_DIR/mismatched-verifier-entry.json" 'prototype-verifier-entry-mismatch'

PENDING_DECISION_PROJECT="$TMP_DIR/pending-decision-project"
cp -R "$HAPPY_PROJECT" "$PENDING_DECISION_PROJECT"
jq '.status = "pending"' \
  "$PENDING_DECISION_PROJECT/openspec/changes/add-dashboard/prototype/decision.json" \
  >"$TMP_DIR/pending-decision.json.tmp"
mv "$TMP_DIR/pending-decision.json.tmp" "$PENDING_DECISION_PROJECT/openspec/changes/add-dashboard/prototype/decision.json"
run_json "$PENDING_DECISION_PROJECT" "$TMP_DIR/pending-decision.json" 2
assert_blocker "$TMP_DIR/pending-decision.json" 'invalid-prototype-decision-status:pending'

MISSING_APPROVED_VARIANT_PROJECT="$TMP_DIR/missing-approved-variant-project"
cp -R "$HAPPY_PROJECT" "$MISSING_APPROVED_VARIANT_PROJECT"
jq 'del(.approved_variant)' \
  "$MISSING_APPROVED_VARIANT_PROJECT/openspec/changes/add-dashboard/prototype/decision.json" \
  >"$TMP_DIR/missing-approved-variant.json.tmp"
mv "$TMP_DIR/missing-approved-variant.json.tmp" "$MISSING_APPROVED_VARIANT_PROJECT/openspec/changes/add-dashboard/prototype/decision.json"
run_json "$MISSING_APPROVED_VARIANT_PROJECT" "$TMP_DIR/missing-approved-variant.json" 2
assert_blocker "$TMP_DIR/missing-approved-variant.json" 'invalid-prototype-decision:approved_variant'

NO_REASON_PROJECT="$TMP_DIR/no-reason-project"
cp -R "$HAPPY_PROJECT" "$NO_REASON_PROJECT"
cat >"$NO_REASON_PROJECT/openspec/changes/add-dashboard/prototype/decision.json" <<'JSON'
{
  "status": "not_required"
}
JSON
run_json "$NO_REASON_PROJECT" "$TMP_DIR/no-reason.json" 2
assert_blocker "$TMP_DIR/no-reason.json" 'invalid-prototype-decision:not_required-reason'

NOT_REQUIRED_PROJECT="$TMP_DIR/not-required-project"
cp -R "$HAPPY_PROJECT" "$NOT_REQUIRED_PROJECT"
cat >"$NOT_REQUIRED_PROJECT/openspec/changes/add-dashboard/prototype/decision.json" <<'JSON'
{
  "status": "not_required",
  "reason": "User says this prototype is unnecessary."
}
JSON
run_json "$NOT_REQUIRED_PROJECT" "$TMP_DIR/not-required.json" 2
assert_blocker "$TMP_DIR/not-required.json" 'invalid-prototype-decision-status:not_required'

MISSING_BRANCH_PROJECT="$TMP_DIR/missing-branch-project"
cp -R "$HAPPY_PROJECT" "$MISSING_BRANCH_PROJECT"
rm "$MISSING_BRANCH_PROJECT/openspec/changes/add-dashboard/prototype/artifact/index.html"
run_json "$MISSING_BRANCH_PROJECT" "$TMP_DIR/missing-branch.json" 2
assert_blocker "$TMP_DIR/missing-branch.json" 'missing-prototype-branch-artifact:artifact/index.html'

GAP_TEXT_PROJECT="$TMP_DIR/gap-text-project"
cp -R "$HAPPY_PROJECT" "$GAP_TEXT_PROJECT"
printf '%s\n' '# Prototype Handoff' 'This leaves one unresolved item.' >"$GAP_TEXT_PROJECT/openspec/changes/add-dashboard/prototype/handoff.md"
run_json "$GAP_TEXT_PROJECT" "$TMP_DIR/gap-text.json" 2
assert_blocker "$TMP_DIR/gap-text.json" 'unresolved-prototype-gap:handoff.md'

echo "helm prototype plugin fixtures ok"
