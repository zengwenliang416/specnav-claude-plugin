#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERIFY="$ROOT/plugins/helm-verification"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

run_json() {
  local project="$1"
  local command="$2"
  local output="$3"
  local expected_status="$4"
  local status

  set +e
  PROJECT_DIR="$project" node "$VERIFY/scripts/verify-domains.js" "$command" --json >"$output"
  status=$?
  set -e
  if [[ "$status" != "$expected_status" ]]; then
    echo "expected status $expected_status, got $status for $command in $project" >&2
    cat "$output" >&2
    exit 1
  fi
}

assert_blocker() {
  local output="$1"
  local blocker="$2"

  jq -e --arg blocker "$blocker" '.blockers[] | select(. == $blocker)' "$output" >/dev/null
}

write_base_project() {
  local project="$1"
  local change="add-dashboard"
  local change_dir="$project/openspec/changes/$change"
  local dev="$change_dir/development"
  local task="$dev/tasks/001-dashboard-summary"
  local proto="$change_dir/prototype"

  mkdir -p \
    "$project/openspec/.helm" \
    "$project/openspec/specs/ui-design" \
    "$project/openspec/specs/system-architecture" \
    "$project/openspec/specs/frontend-backend-data-flow" \
    "$project/openspec/specs/component-architecture" \
    "$proto/artifact" \
    "$task"
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

  cat >"$change_dir/requirements.md" <<'MD'
# Requirements
- Add dashboard summary view.
MD
  cat >"$change_dir/acceptance.md" <<'MD'
# Acceptance
- Dashboard renders loading, empty, and error states.
MD
  cat >"$change_dir/spec-map.json" <<'JSON'
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
  cat >"$change_dir/component-impact-map.json" <<'JSON'
{
  "new_components": ["DashboardView"],
  "reused_components": [],
  "extraction_triggers": [],
  "forbidden_dependencies": [],
  "hooks": [],
  "utilities": [],
  "services": [],
  "required_component_tests": ["DashboardView states"],
  "unresolved_gaps": []
}
JSON

  cat >"$proto/question.md" <<'MD'
# Prototype Question
Branch: ui-html
Question: Which dashboard variant should ship?
MD
  cat >"$proto/artifact/index.html" <<'HTML'
<!doctype html>
<html><body><main data-helm-screen="dashboard" data-helm-variant="balanced">Dashboard</main></body></html>
HTML
  cat >"$proto/screen-map.json" <<'JSON'
{
  "screens": [{
    "id": "dashboard",
    "requirements": ["requirements.md#dashboard"],
    "acceptance": ["Dashboard renders loading, empty, and error states."],
    "components": ["DashboardView"],
    "data_flows": ["Dashboard API to view state"],
    "implementation_files": ["src/dashboard/DashboardView.tsx"]
  }]
}
JSON
  cat >"$proto/prototype-manifest.json" <<'JSON'
{
  "schema": "helm.prototype.manifest.v1",
  "version": "1.0.0",
  "type": "ui-html",
  "entry": "artifact/index.html",
  "dependencies": [],
  "mock_strategy": "static mock",
  "touches_real_data": false,
  "referenced_foundation_specs": ["ui-design"],
  "referenced_requirements": ["requirements.md"],
  "may_promote": false,
  "promotion_requirement": "development gate"
}
JSON
  cat >"$proto/verifier-report.json" <<'JSON'
{
  "schema": "helm.prototype.verifier.v1",
  "status": "green",
  "checked_entry": "artifact/index.html",
  "checks": ["entry exists"]
}
JSON
  cat >"$proto/handoff.md" <<'MD'
# Prototype Handoff
## Approved branch and variant
- Branch: ui-html
- Variant: balanced
## Screens or flows to implement
- Dashboard screen.
## Components to create
- DashboardView.
## Components to reuse
- Shell.
## Components, hooks, utilities, and services to extract
- Hooks: useDashboardState.
## API contracts
- GET /api/dashboard/summary.
## Data flows
- API response populates dashboard view state.
## State, loading, empty, error, disabled, and permission behavior
- Loading, empty, error, disabled, permission states.
## Out-of-scope items
- Export.
## Required tests
- Dashboard states.
## Open risks
- Backend summary fields remain a verification watch item.
MD
  cat >"$proto/decision.json" <<'JSON'
{
  "status": "approved",
  "prototype_code": "required_present",
  "prototype_type": "ui-html",
  "approved_variant": "balanced",
  "promotion": "requires_development_gate",
  "blocked_reasons": []
}
JSON

  cat >"$change_dir/scope.json" <<'JSON'
{
  "schema_version": 1,
  "change_id": "add-dashboard",
  "stage": "development",
  "allowed_roots": ["src/dashboard/**", "tests/dashboard/**"],
  "denied_roots": [".env*"],
  "allowed_operations": {"create": true, "modify": true, "delete": false, "rename": true},
  "requires_review_on": ["src/shared/**"],
  "prototype_sources": ["openspec/changes/add-dashboard/prototype/artifact/index.html"],
  "expires_when": "verification_started"
}
JSON
  cat >"$change_dir/tasks.md" <<'MD'
# Development Tasks
- user can view dashboard summary with loading empty and error states
MD
  cat >"$dev/before-dev-check.json" <<'JSON'
{"schema_version":1,"active_change":"add-dashboard","status":"passed","ok":true}
JSON
  cat >"$dev/basis.md" <<'MD'
# Development Basis
Development is based on requirements, prototype, and handoff.
- openspec/specs/ui-design/design.md
- openspec/specs/system-architecture/design.md
- openspec/specs/frontend-backend-data-flow/design.md
- openspec/specs/component-architecture/design.md
- openspec/changes/add-dashboard/requirements.md
- openspec/changes/add-dashboard/acceptance.md
- openspec/changes/add-dashboard/spec-map.json
- openspec/changes/add-dashboard/component-impact-map.json
- openspec/changes/add-dashboard/prototype/handoff.md
- openspec/changes/add-dashboard/prototype/decision.json
- openspec/changes/add-dashboard/prototype/artifact/index.html
MD
  cat >"$dev/prototype-promotion-map.json" <<'JSON'
{"schema_version":1,"promotion_policy":"reimplement_under_development_gate","allowed_to_copy":["copy"],"must_reimplement":["state"],"blocked_direct_copies":["mock data"]}
JSON
  cat >"$dev/complexity-budget.json" <<'JSON'
{"schema_version":1,"budgets":[{"task":"001-dashboard-summary","max_files":2}]}
JSON
  cat >"$dev/task-graph.json" <<'JSON'
{"schema_version":1,"nodes":["001-dashboard-summary"],"edges":[]}
JSON
  cat >"$dev/code-owner-map.json" <<'JSON'
{"schema_version":1,"owners":[{"path":"src/dashboard/**","owner":"dashboard"}]}
JSON
  cat >"$dev/extraction-map.json" <<'JSON'
{"schema_version":1,"components":["DashboardView"]}
JSON
  cat >"$dev/task-context.jsonl" <<'JSONL'
{"task":"001-dashboard-summary","status":"ready"}
JSONL
  cat >"$dev/task-ledger.jsonl" <<'JSONL'
{"task":"001-dashboard-summary","status":"spec_review_passed"}
{"task":"001-dashboard-summary","status":"quality_review_passed"}
{"task":"001-dashboard-summary","status":"complete"}
JSONL
  cat >"$dev/drift-check.jsonl" <<'JSONL'
{"task":"001-dashboard-summary","blocking":false}
JSONL
  cat >"$dev/validation-log.jsonl" <<'JSONL'
{"task":"001-dashboard-summary","command":"npm test","status":"passed","ok":true}
JSONL
  cat >"$task/brief.md" <<'MD'
# Task 001
## Goal
Implement dashboard summary.
## Parent Artifacts
Read approved artifacts.
## Vertical Slice
User can view dashboard summary.
## In Scope
Dashboard summary.
## Out Of Scope
Export.
## Files Allowed
src/dashboard/DashboardView.tsx.
## Interfaces / Seams
Service seam.
## Components To Create
DashboardView.
## Components To Reuse
Shell.
## Components To Extract
No extraction is required for this narrow dashboard summary slice.
## API / Data Flow Contracts
GET /api/dashboard/summary.
## State / Error / Empty / Loading Behavior
All states.
## TDD Requirement
Red and green tests.
## Verification Commands
npm test.
## Stop Conditions
Scope drift.
## Unsafe Assumptions
No unsafe assumptions are accepted without controller review.
MD
  cat >"$task/context.json" <<'JSON'
{
  "task_id": "001-dashboard-summary",
  "goal": "Implement dashboard summary",
  "stop_condition": "complete",
  "must_read": [
    "openspec/changes/add-dashboard/development/tasks/001-dashboard-summary/brief.md",
    "openspec/specs/ui-design/design.md",
    "openspec/specs/system-architecture/design.md",
    "openspec/specs/frontend-backend-data-flow/design.md",
    "openspec/specs/component-architecture/design.md",
    "openspec/changes/add-dashboard/requirements.md",
    "openspec/changes/add-dashboard/acceptance.md",
    "openspec/changes/add-dashboard/spec-map.json",
    "openspec/changes/add-dashboard/component-impact-map.json",
    "openspec/changes/add-dashboard/prototype/handoff.md",
    "openspec/changes/add-dashboard/prototype/decision.json",
    "openspec/changes/add-dashboard/prototype/artifact/index.html"
  ],
  "allowed_files": ["src/dashboard/DashboardView.tsx"],
  "non_goals": ["export"],
  "expected_evidence": ["test output"],
  "unsafe_assumptions": []
}
JSON
  cat >"$task/report.md" <<'MD'
# Implementation Report
## Status
DONE
## Files Changed
- src/dashboard/DashboardView.tsx
## What Changed
Dashboard summary.
## TDD Evidence
Red and green.
## Verification Commands
- npm test
## Concerns
Backend field naming remains a verification watch item.
## Scope Deviations
No scope deviations were made.
## Follow-up Needed
Six-domain verification must confirm the user-visible states.
MD
  cat >"$task/spec-review.md" <<'MD'
# Spec Review
## Verdict
approved
## Missing Requirements
No missing requirements were found.
## Extra Behavior
No extra behavior was introduced.
## Misunderstood Requirements
No misunderstood requirements were found.
## Cannot Verify From Diff
Browser-level state coverage remains for verification.
## Required Fixes
No required fixes remain.
MD
  cat >"$task/quality-review.md" <<'MD'
# Quality Review
## Verdict
approved
## Separation Of Concerns
Good.
## Component Cohesion / Coupling
Good.
## Test Quality
Good.
## Error Handling
Good.
## Reuse / Duplication
Good.
## Complexity Delta
Low.
## Required Fixes
No required fixes remain.
MD
  cat >"$dev/handoff-to-verify.md" <<'MD'
# Handoff
## Implemented Slices
Dashboard summary.
## Files Changed
src/dashboard/DashboardView.tsx.
## Requirements Covered
Dashboard states.
## Prototype Decisions Implemented
Balanced variant.
## Components Created / Reused / Extracted
DashboardView created.
## API / Data Flow Changes
Summary API flow.
## Tests Added
Dashboard tests.
## Local Validation
npm test passed.
## Known Risks
Backend field naming remains a verification watch item.
## Items Requiring Six-Domain Verification
All six domains.
MD
}

write_verify_artifacts() {
  local project="$1"
  local verify="$project/openspec/changes/add-dashboard/verify"
  mkdir -p "$verify"/{behavior-evals/transcripts,facticity,static,unit,redteam,e2e,sensory}

  cat >"$verify/plan.md" <<'MD'
# Verification Plan
## Verification Scope
Dashboard summary.
## Required Domains
All six domains.
## Evidence Plan
Commands and artifacts.
MD
  cat >"$verify/plan.json" <<'JSON'
{
  "schema_version": 1,
  "change_id": "add-dashboard",
  "risk_tier": "medium",
  "required_domains": ["facticity", "static", "unit", "redteam", "e2e", "sensory"],
  "inputs": ["requirements.md", "acceptance.md", "prototype/handoff.md", "development/handoff-to-verify.md", "spec-map.json", "component-impact-map.json"],
  "changed_files": ["src/dashboard/DashboardView.tsx"],
  "commands": ["npm test"],
  "manual_reviews": ["sensory"]
}
JSON
  cat >"$verify/evidence-index.jsonl" <<'JSONL'
{"id":"ev-static","kind":"command","domain":"static","result":"pass"}
{"id":"ev-unit","kind":"command","domain":"unit","result":"pass"}
JSONL
  cat >"$verify/traceability-matrix.json" <<'JSON'
{
  "schema_version": 1,
  "change_id": "add-dashboard",
  "entries": [{
    "changed_file": "src/dashboard/DashboardView.tsx",
    "change_reason": "dashboard summary",
    "requirement_refs": ["requirements.md#dashboard"],
    "task_refs": ["development/tasks/001-dashboard-summary/brief.md"],
    "prototype_refs": ["prototype/handoff.md#dashboard"],
    "foundation_spec_refs": ["openspec/specs/ui-design/design.md"],
    "verification_domains": ["facticity", "static", "unit", "e2e", "sensory"],
    "impact_notes": "bounded"
  }],
  "unmapped_changes": []
}
JSON
  : >"$verify/blocker-classification.jsonl"
  : >"$verify/root-cause-checks.jsonl"
  cat >"$verify/receipt.md" <<'MD'
# Receipt
## Covered Scope
Dashboard summary.
## Uncovered Scope
None.
## Residual Risk
None.
## Confidence
A.
MD
  cat >"$verify/receipt.json" <<'JSON'
{"schema_version":1,"change_id":"add-dashboard","evidence_action":"ran six-domain verification","result":"green","covered_scope":["dashboard summary"],"uncovered_scope":[],"residual_risk":[],"confidence":"A"}
JSON
  cat >"$verify/behavior-evals/scenarios.json" <<'JSON'
{"schema_version":1,"scenarios":[{"id":"verify-runs-six-domains","prompt":"/helm-verify","expected":["write aggregate report"]}]}
JSON
  cat >"$verify/behavior-evals/report.md" <<'MD'
# Behavior Evals
## Scenarios
verify-runs-six-domains.
## Transcripts
Recorded.
## Result
green.
MD
  cat >"$verify/behavior-evals/report.json" <<'JSON'
{"schema_version":1,"status":"green","scenarios":["verify-runs-six-domains"]}
JSON
  cat >"$verify/behavior-evals/transcripts/verify-runs-six-domains.md" <<'MD'
# Clean Session Transcript

Prompt: /helm-verify

Observed:
- Loaded active change.
- Generated plan.
- Ran or blocked all six domains.
- Wrote aggregate report.
MD

  for domain in facticity static unit redteam e2e sensory; do
    cat >"$verify/$domain/report.md" <<MD
# Verification Domain Report
## Domain
$domain
## Verdict
green
## Inputs Reviewed
Plan and handoff.
## Evidence
Evidence index.
## Commands Run
Recorded.
## Findings
None.
## Required Fixes
None.
## Residual Risk
None.
## Follow-up Domain Routing
None.
MD
    cat >"$verify/$domain/report.json" <<JSON
{"schema_version":1,"domain":"$domain","verdict":"green","required":true,"evidence":[],"commands":[],"blocker_class":null,"findings":[],"required_fixes":[],"residual_risk":[]}
JSON
  done
  cat >"$verify/unit/test-quality-rubric.json" <<'JSON'
{"schema_version":1,"checks":{"behavior_facing":true,"public_interface_only":true,"survives_refactor":true,"one_logical_assertion_per_test":true,"no_internal_mock_coupling":true,"critical_paths_covered":true,"edge_cases_covered":true},"findings":[]}
JSON
  cat >"$verify/sensory/reviewer-independence.md" <<'MD'
# Reviewer Independence
## Inputs Allowed
Files and evidence.
## Inputs Excluded
Controller claims.
## Controller Claims Ignored
All unevidenced claims.
## Files Reviewed
DashboardView.
## Evidence References
Evidence index.
## Cannot Verify From Provided Evidence
None.
MD
}

test -f "$VERIFY/scripts/verify-domains.js"
test -f "$VERIFY/skills/helm-verify-plan/SKILL.md"
test -f "$VERIFY/skills/helm-verify-facticity/SKILL.md"
test -f "$VERIFY/skills/helm-verify-static/SKILL.md"
test -f "$VERIFY/skills/helm-verify-unit/SKILL.md"
test -f "$VERIFY/skills/helm-verify-redteam/SKILL.md"
test -f "$VERIFY/skills/helm-verify-e2e/SKILL.md"
test -f "$VERIFY/skills/helm-verify-sensory/SKILL.md"
jq -e '.contracts.verification == "scripts/verify-domains.js"' "$VERIFY/helm-stage.json" >/dev/null
jq -e 'has("planned_contracts") | not' "$VERIFY/helm-stage.json" >/dev/null
grep -Fq -- '--marketplace-root "$CLAUDE_PLUGIN_ROOT/../.."' "$VERIFY/commands/helm-verify.md"
grep -Fq 'node "$CLAUDE_PLUGIN_ROOT/../helm-development/scripts/development-contract.js" --mode handoff --json' "$VERIFY/commands/helm-verify.md"
grep -Fq 'node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" aggregate --json' "$VERIFY/commands/helm-verify.md"

PROJECT="$TMP_DIR/verify-project"
write_base_project "$PROJECT"

run_json "$PROJECT" validate "$TMP_DIR/missing-verify.json" 2
assert_blocker "$TMP_DIR/missing-verify.json" 'missing-verify-artifact:plan.json'

write_verify_artifacts "$PROJECT"
run_json "$PROJECT" validate "$TMP_DIR/valid-verify.json" 0
jq -e '.ok == true' "$TMP_DIR/valid-verify.json" >/dev/null
jq -e '.artifacts[] | select(.name == "facticity/report.json" and .ok == true)' "$TMP_DIR/valid-verify.json" >/dev/null
run_json "$PROJECT" aggregate "$TMP_DIR/aggregate-green.json" 0
jq -e '.verdict == "green"' "$TMP_DIR/aggregate-green.json" >/dev/null
jq -e '.status == "green"' "$PROJECT/openspec/changes/add-dashboard/verify-report.json" >/dev/null
test -f "$PROJECT/openspec/changes/add-dashboard/verify/aggregate-report.json"

set +e
PROJECT_DIR="$PROJECT" node "$ROOT/plugins/helm-core/scripts/verify.js" >"$TMP_DIR/core-verify.txt"
CORE_VERIFY_STATUS=$?
set -e
[[ "$CORE_VERIFY_STATUS" == "1" ]]
jq -e '.status == "red"' "$PROJECT/openspec/changes/add-dashboard/verify-report.json" >/dev/null

TRACE_FAIL_PROJECT="$TMP_DIR/trace-fail-project"
cp -R "$PROJECT" "$TRACE_FAIL_PROJECT"
jq '.unmapped_changes = ["src/unmapped.ts"]' \
  "$TRACE_FAIL_PROJECT/openspec/changes/add-dashboard/verify/traceability-matrix.json" \
  >"$TMP_DIR/trace-fail.json.tmp"
mv "$TMP_DIR/trace-fail.json.tmp" "$TRACE_FAIL_PROJECT/openspec/changes/add-dashboard/verify/traceability-matrix.json"
run_json "$TRACE_FAIL_PROJECT" validate "$TMP_DIR/trace-fail.json" 2
assert_blocker "$TMP_DIR/trace-fail.json" 'traceability-unmapped-changes'

UNIT_FAIL_PROJECT="$TMP_DIR/unit-fail-project"
cp -R "$PROJECT" "$UNIT_FAIL_PROJECT"
jq '.checks.public_interface_only = false' \
  "$UNIT_FAIL_PROJECT/openspec/changes/add-dashboard/verify/unit/test-quality-rubric.json" \
  >"$TMP_DIR/unit-fail.json.tmp"
mv "$TMP_DIR/unit-fail.json.tmp" "$UNIT_FAIL_PROJECT/openspec/changes/add-dashboard/verify/unit/test-quality-rubric.json"
run_json "$UNIT_FAIL_PROJECT" validate "$TMP_DIR/unit-fail.json" 2
assert_blocker "$TMP_DIR/unit-fail.json" 'unit-test-quality-blocking:public_interface_only'

DOMAIN_FAIL_PROJECT="$TMP_DIR/domain-fail-project"
cp -R "$PROJECT" "$DOMAIN_FAIL_PROJECT"
jq '.verdict = "red"' \
  "$DOMAIN_FAIL_PROJECT/openspec/changes/add-dashboard/verify/static/report.json" \
  >"$TMP_DIR/domain-fail.json.tmp"
mv "$TMP_DIR/domain-fail.json.tmp" "$DOMAIN_FAIL_PROJECT/openspec/changes/add-dashboard/verify/static/report.json"
run_json "$DOMAIN_FAIL_PROJECT" validate "$TMP_DIR/domain-fail.json" 2
assert_blocker "$TMP_DIR/domain-fail.json" 'static-not-green'

BEHAVIOR_FAIL_PROJECT="$TMP_DIR/behavior-fail-project"
cp -R "$PROJECT" "$BEHAVIOR_FAIL_PROJECT"
rm "$BEHAVIOR_FAIL_PROJECT/openspec/changes/add-dashboard/verify/behavior-evals/transcripts/verify-runs-six-domains.md"
run_json "$BEHAVIOR_FAIL_PROJECT" validate "$TMP_DIR/behavior-fail.json" 2
assert_blocker "$TMP_DIR/behavior-fail.json" 'missing-behavior-eval-transcript:verify-runs-six-domains'

SENSORY_FAIL_PROJECT="$TMP_DIR/sensory-fail-project"
cp -R "$PROJECT" "$SENSORY_FAIL_PROJECT"
cat >"$SENSORY_FAIL_PROJECT/openspec/changes/add-dashboard/verify/sensory/reviewer-independence.md" <<'MD'
# Reviewer Independence
## Inputs Allowed
Files.
MD
run_json "$SENSORY_FAIL_PROJECT" validate "$TMP_DIR/sensory-fail.json" 2
assert_blocker "$TMP_DIR/sensory-fail.json" 'invalid-reviewer-independence:missing-heading:Inputs Excluded'

DEVELOPMENT_FAIL_PROJECT="$TMP_DIR/development-fail-project"
cp -R "$PROJECT" "$DEVELOPMENT_FAIL_PROJECT"
rm "$DEVELOPMENT_FAIL_PROJECT/openspec/changes/add-dashboard/development/handoff-to-verify.md"
run_json "$DEVELOPMENT_FAIL_PROJECT" validate "$TMP_DIR/development-fail.json" 2
assert_blocker "$TMP_DIR/development-fail.json" 'development-blocked'

echo "helm verification plugin fixtures ok"
