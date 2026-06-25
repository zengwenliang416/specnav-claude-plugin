#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPS="$ROOT/plugins/helm-operations"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

run_gate() {
  local script="$1"
  local project="$2"
  local output="$3"
  local expected="$4"
  local status

  set +e
  PROJECT_DIR="$project" node "$OPS/scripts/$script" --json >"$output"
  status=$?
  set -e
  if [[ "$status" != "$expected" ]]; then
    echo "expected $script status $expected, got $status" >&2
    cat "$output" >&2
    exit 1
  fi
}

assert_blocker() {
  local output="$1"
  local blocker="$2"

  jq -e --arg blocker "$blocker" '.blockers[] | select(. == $blocker)' "$output" >/dev/null
}

write_verified_project() {
  local project="$1"
  local change="add-dashboard"
  local change_dir="$project/openspec/changes/$change"

  mkdir -p "$project/openspec/.helm" "$change_dir/development" "$change_dir/verify"
  printf '%s\n' "$change" >"$project/openspec/.helm/active-change"

  cat >"$change_dir/development/handoff-to-verify.md" <<'MD'
# Development Handoff
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
None.
## Items Requiring Six-Domain Verification
All six domains.
MD
  cat >"$change_dir/verify/aggregate-report.md" <<'MD'
# Helm Aggregate Verification Report
## Result
green
MD
  cat >"$change_dir/verify/aggregate-report.json" <<'JSON'
{"schema_version":1,"active_change":"add-dashboard","verdict":"green","blockers":[]}
JSON
  cat >"$change_dir/verify/receipt.json" <<'JSON'
{"schema_version":1,"change_id":"add-dashboard","result":"green","covered_scope":["dashboard summary"],"uncovered_scope":[],"residual_risk":[],"confidence":"A"}
JSON
  : >"$change_dir/verify/blocker-classification.jsonl"
}

write_plugin_marketplace_ops() {
  local project="$1"
  local change_dir="$project/openspec/changes/add-dashboard"
  local ops="$change_dir/operations"
  mkdir -p "$ops"

  cat >"$ops/readiness.md" <<'MD'
# Operations Readiness
## Operations Scope
Plugin marketplace release for dashboard summary.
## Readiness Decision
Ready.
## Evidence
Verification aggregate is green and release artifacts are present.
MD
  cat >"$ops/readiness.json" <<JSON
{
  "schema": "helm.ops.readiness.v1",
  "change": "add-dashboard",
  "release_target": "plugin-marketplace",
  "verification": {
    "aggregate_verdict": "green",
    "receipt_confidence": "A",
    "uncovered_scope": [],
    "residual_risk": []
  },
  "git": {
    "branch": "feature/add-dashboard",
    "worktree_mode": "normal",
    "dirty": false,
    "untracked_reviewed": true
  },
  "docs": {
    "changelog": true,
    "release_notes": true,
    "readme_updated": true
  },
  "ops": {
    "install_verification": "pass",
    "update_policy": "pass",
    "rollback_plan": "pass",
    "monitor_plan": "pass",
    "postmortem_required": false
  },
  "ready": true
}
JSON
  cat >"$ops/release-plan.md" <<'MD'
# Release Plan
## Release Target
plugin-marketplace.
## Required Artifacts
Checklist, install verification, update policy, compatibility matrix, changelog, release notes, and branch finish.
## Release Decision
Proceed after operations gate.
MD
  cat >"$ops/release-checklist.json" <<'JSON'
{"schema":"helm.ops.releaseChecklist.v1","change":"add-dashboard","release_target":"plugin-marketplace","checks":[{"name":"verification","status":"pass"},{"name":"install","status":"pass"},{"name":"compatibility","status":"pass"}]}
JSON
  cat >"$ops/install-verification.json" <<'JSON'
{"schema":"helm.ops.installVerification.v1","marketplace_root":"/repo","plugin_root":"/repo/plugins/helm-operations","plugin_name":"helm-operations","plugin_source":"plugins/helm-operations","target_project":"/project","command":"node plugins/helm-core/scripts/helm-doctor.js --json","ok":true,"workspaceSupport":"available","configStatus":"configured","host":"claude-code","discovery_root_checked":true,"reload_required":false}
JSON
  cat >"$ops/update-policy.json" <<'JSON'
{"schema":"helm.ops.updatePolicy.v1","registry_version":1,"default_scope":"current-host","all_hosts_requires_explicit_request":true,"installations":[{"id":"claude-code:default","host":"claude-code","pluginRoot":"/repo/plugins/helm-operations","discoveryRoot":"/repo","discoveryShape":"plugin-managed","trackedRef":"main","reloadHint":"restart Claude Code"}]}
JSON
  cat >"$ops/compatibility-matrix.md" <<'MD'
# Compatibility Matrix
## Supported Hosts
- claude-code: fresh-smoke
## Verification Command
node plugins/helm-core/scripts/helm-doctor.js --json
## Doctor Result
pass
## Known Limitations
None recorded.
## Reload Requirement
Restart Claude Code after install.
MD
  cat >"$ops/branch-finish.md" <<'MD'
# Branch Finish
## Branch State
normal worktree on feature/add-dashboard.
## Finish Action
merge to main after tests.
## Cleanup Decision
Preserve worktree until user confirms cleanup.
## Provenance
No Helm-owned cleanup marker is present.
MD
  cat >"$ops/changelog.md" <<'MD'
# Changelog
- Add dashboard summary release artifacts.
MD
  cat >"$ops/release-notes.md" <<'MD'
# Release Notes
Dashboard summary is ready for release.
MD
  cat >"$ops/update-spec.json" <<'JSON'
{"schema":"helm.ops.updateSpec.v1","change":"add-dashboard","status":"no_writeback_needed","learning_items":[],"unresolved_items":[]}
JSON
}

test -f "$OPS/scripts/operations-gate.js"
test -f "$OPS/scripts/archive-gate.js"
for skill in helm-ops-readiness helm-release-plan helm-install-verify helm-update-policy helm-compatibility-matrix helm-branch-finish helm-deploy helm-rollback helm-monitor helm-postmortem helm-update-spec; do
  test -f "$OPS/skills/$skill/SKILL.md"
  grep -q "name: $skill" "$OPS/skills/$skill/SKILL.md"
  grep -Fq 'node "$HELM_OPERATIONS_ROOT/scripts/operations-gate.js" --json' "$OPS/skills/$skill/SKILL.md"
done
jq -e '.contracts.operations == "scripts/operations-gate.js"' "$OPS/helm-stage.json" >/dev/null
jq -e '.contracts.archive == "scripts/archive-gate.js"' "$OPS/helm-stage.json" >/dev/null
jq -e 'has("planned_contracts") | not' "$OPS/helm-stage.json" >/dev/null
grep -Fq -- '--marketplace-root "$HELM_MARKETPLACE_ROOT"' "$OPS/commands/helm-release.md"
grep -Fq 'node "$HELM_OPERATIONS_ROOT/scripts/operations-gate.js" --json' "$OPS/commands/helm-release.md"
grep -Fq 'node "$HELM_OPERATIONS_ROOT/scripts/archive-gate.js" --json' "$OPS/commands/helm-archive.md"

PROJECT="$TMP_DIR/ops-project"
write_verified_project "$PROJECT"
run_gate operations-gate.js "$PROJECT" "$TMP_DIR/missing-ops.json" 2
assert_blocker "$TMP_DIR/missing-ops.json" 'missing-operations-artifact:readiness.json'

write_plugin_marketplace_ops "$PROJECT"
run_gate operations-gate.js "$PROJECT" "$TMP_DIR/valid-ops.json" 0
jq -e '.ok == true and .release_target == "plugin-marketplace"' "$TMP_DIR/valid-ops.json" >/dev/null
run_gate archive-gate.js "$PROJECT" "$TMP_DIR/archive-green.json" 0
jq -e '.verdict == "green"' "$TMP_DIR/archive-green.json" >/dev/null
test -f "$PROJECT/openspec/changes/add-dashboard/operations/archive-gate.json"
test -s "$PROJECT/openspec/changes/add-dashboard/operations/archive-log.jsonl"

VERIFY_FAIL="$TMP_DIR/verify-fail"
cp -R "$PROJECT" "$VERIFY_FAIL"
jq '.verdict = "red"' "$VERIFY_FAIL/openspec/changes/add-dashboard/verify/aggregate-report.json" >"$TMP_DIR/verify-fail.tmp"
mv "$TMP_DIR/verify-fail.tmp" "$VERIFY_FAIL/openspec/changes/add-dashboard/verify/aggregate-report.json"
run_gate operations-gate.js "$VERIFY_FAIL" "$TMP_DIR/verify-fail.json" 2
assert_blocker "$TMP_DIR/verify-fail.json" 'verification-not-green'

UNRESOLVED="$TMP_DIR/unresolved"
cp -R "$PROJECT" "$UNRESOLVED"
printf '%s\n' '{"domain":"facticity","blocker_class":"insufficient-evidence","status":"unresolved"}' >"$UNRESOLVED/openspec/changes/add-dashboard/verify/blocker-classification.jsonl"
run_gate operations-gate.js "$UNRESOLVED" "$TMP_DIR/unresolved.json" 2
assert_blocker "$TMP_DIR/unresolved.json" 'unresolved-verification-blocker:facticity'

MISSING_INSTALL="$TMP_DIR/missing-install"
cp -R "$PROJECT" "$MISSING_INSTALL"
rm "$MISSING_INSTALL/openspec/changes/add-dashboard/operations/install-verification.json"
run_gate operations-gate.js "$MISSING_INSTALL" "$TMP_DIR/missing-install.json" 2
assert_blocker "$TMP_DIR/missing-install.json" 'missing-operations-artifact:install-verification.json'

MISSING_README="$TMP_DIR/missing-readme"
cp -R "$PROJECT" "$MISSING_README"
jq '.docs.readme_updated = false' \
  "$MISSING_README/openspec/changes/add-dashboard/operations/readiness.json" >"$TMP_DIR/missing-readme.tmp"
mv "$TMP_DIR/missing-readme.tmp" "$MISSING_README/openspec/changes/add-dashboard/operations/readiness.json"
run_gate operations-gate.js "$MISSING_README" "$TMP_DIR/missing-readme.json" 2
assert_blocker "$TMP_DIR/missing-readme.json" 'readiness-docs-readme'

LOCAL_ONLY="$TMP_DIR/local-only"
cp -R "$PROJECT" "$LOCAL_ONLY"
jq '.release_target = "local-only" | .docs.readme_updated = false | .ops.install_verification = "not_required" | .ops.update_policy = "not_required"' \
  "$LOCAL_ONLY/openspec/changes/add-dashboard/operations/readiness.json" >"$TMP_DIR/local-readiness.tmp"
mv "$TMP_DIR/local-readiness.tmp" "$LOCAL_ONLY/openspec/changes/add-dashboard/operations/readiness.json"
jq '.release_target = "local-only"' "$LOCAL_ONLY/openspec/changes/add-dashboard/operations/release-checklist.json" >"$TMP_DIR/local-checklist.tmp"
mv "$TMP_DIR/local-checklist.tmp" "$LOCAL_ONLY/openspec/changes/add-dashboard/operations/release-checklist.json"
rm "$LOCAL_ONLY/openspec/changes/add-dashboard/operations/install-verification.json"
rm "$LOCAL_ONLY/openspec/changes/add-dashboard/operations/update-policy.json"
rm "$LOCAL_ONLY/openspec/changes/add-dashboard/operations/compatibility-matrix.md"
run_gate operations-gate.js "$LOCAL_ONLY" "$TMP_DIR/local-only.json" 0
jq -e '.release_target == "local-only"' "$TMP_DIR/local-only.json" >/dev/null

# Non-user-facing change: changelog/release-notes are not required and may be absent.
NON_USER_FACING="$TMP_DIR/non-user-facing"
cp -R "$PROJECT" "$NON_USER_FACING"
jq '.docs.user_facing = false | .docs.changelog = false | .docs.release_notes = false' \
  "$NON_USER_FACING/openspec/changes/add-dashboard/operations/readiness.json" >"$TMP_DIR/nuf-readiness.tmp"
mv "$TMP_DIR/nuf-readiness.tmp" "$NON_USER_FACING/openspec/changes/add-dashboard/operations/readiness.json"
rm "$NON_USER_FACING/openspec/changes/add-dashboard/operations/changelog.md"
rm "$NON_USER_FACING/openspec/changes/add-dashboard/operations/release-notes.md"
run_gate operations-gate.js "$NON_USER_FACING" "$TMP_DIR/non-user-facing.json" 0
jq -e '.ok == true' "$TMP_DIR/non-user-facing.json" >/dev/null

# Package target: missing package validation blocks; release notes stay required.
PACKAGE_FAIL="$TMP_DIR/package-fail"
cp -R "$PROJECT" "$PACKAGE_FAIL"
jq '.release_target = "package" | .ops.package_validation = "missing"' \
  "$PACKAGE_FAIL/openspec/changes/add-dashboard/operations/readiness.json" >"$TMP_DIR/pkg-fail-readiness.tmp"
mv "$TMP_DIR/pkg-fail-readiness.tmp" "$PACKAGE_FAIL/openspec/changes/add-dashboard/operations/readiness.json"
jq '.release_target = "package"' "$PACKAGE_FAIL/openspec/changes/add-dashboard/operations/release-checklist.json" >"$TMP_DIR/pkg-fail-checklist.tmp"
mv "$TMP_DIR/pkg-fail-checklist.tmp" "$PACKAGE_FAIL/openspec/changes/add-dashboard/operations/release-checklist.json"
run_gate operations-gate.js "$PACKAGE_FAIL" "$TMP_DIR/package-fail.json" 2
assert_blocker "$TMP_DIR/package-fail.json" 'package-validation'

# Package target satisfied: package validation pass + checksum present when supported.
PACKAGE_OK="$TMP_DIR/package-ok"
cp -R "$PROJECT" "$PACKAGE_OK"
jq '.release_target = "package" | .ops.package_validation = "pass" | .ops.checksum_supported = true | .ops.checksum = "sha256:abc123"' \
  "$PACKAGE_OK/openspec/changes/add-dashboard/operations/readiness.json" >"$TMP_DIR/pkg-ok-readiness.tmp"
mv "$TMP_DIR/pkg-ok-readiness.tmp" "$PACKAGE_OK/openspec/changes/add-dashboard/operations/readiness.json"
jq '.release_target = "package"' "$PACKAGE_OK/openspec/changes/add-dashboard/operations/release-checklist.json" >"$TMP_DIR/pkg-ok-checklist.tmp"
mv "$TMP_DIR/pkg-ok-checklist.tmp" "$PACKAGE_OK/openspec/changes/add-dashboard/operations/release-checklist.json"
run_gate operations-gate.js "$PACKAGE_OK" "$TMP_DIR/package-ok.json" 0
jq -e '.ok == true and .release_target == "package"' "$TMP_DIR/package-ok.json" >/dev/null

DEPLOY_FAIL="$TMP_DIR/deploy-fail"
cp -R "$PROJECT" "$DEPLOY_FAIL"
jq '.release_target = "project-deploy" | .ops.rollback_plan = "missing"' \
  "$DEPLOY_FAIL/openspec/changes/add-dashboard/operations/readiness.json" >"$TMP_DIR/deploy-readiness.tmp"
mv "$TMP_DIR/deploy-readiness.tmp" "$DEPLOY_FAIL/openspec/changes/add-dashboard/operations/readiness.json"
jq '.release_target = "project-deploy"' "$DEPLOY_FAIL/openspec/changes/add-dashboard/operations/release-checklist.json" >"$TMP_DIR/deploy-checklist.tmp"
mv "$TMP_DIR/deploy-checklist.tmp" "$DEPLOY_FAIL/openspec/changes/add-dashboard/operations/release-checklist.json"
cat >"$DEPLOY_FAIL/openspec/changes/add-dashboard/operations/deploy-plan.md" <<'MD'
# Deploy Plan
## Environment
staging
## Command
npm run deploy
## Smoke Checks
GET /health
## Owner
release owner
MD
cat >"$DEPLOY_FAIL/openspec/changes/add-dashboard/operations/monitor-plan.md" <<'MD'
# Monitor Plan
## Signals
health check
## Observation Window
30 minutes
## Escalation
release owner
MD
run_gate operations-gate.js "$DEPLOY_FAIL" "$TMP_DIR/deploy-fail.json" 2
assert_blocker "$TMP_DIR/deploy-fail.json" 'project-deploy-rollback-plan'

HIGH_RISK="$TMP_DIR/high-risk"
cp -R "$PROJECT" "$HIGH_RISK"
cat >"$HIGH_RISK/openspec/changes/add-dashboard/risk-tier.json" <<'JSON'
{"tier":"high-risk","source":"fixture"}
JSON
run_gate operations-gate.js "$HIGH_RISK" "$TMP_DIR/high-risk.json" 2
assert_blocker "$TMP_DIR/high-risk.json" 'high-risk-signoff'

UPDATE_FAIL="$TMP_DIR/update-fail"
cp -R "$PROJECT" "$UPDATE_FAIL"
jq '.unresolved_items = ["write architecture limitation"]' \
  "$UPDATE_FAIL/openspec/changes/add-dashboard/operations/update-spec.json" >"$TMP_DIR/update-fail.tmp"
mv "$TMP_DIR/update-fail.tmp" "$UPDATE_FAIL/openspec/changes/add-dashboard/operations/update-spec.json"
run_gate operations-gate.js "$UPDATE_FAIL" "$TMP_DIR/update-fail.json" 2
assert_blocker "$TMP_DIR/update-fail.json" 'update-spec-unresolved-items'

echo "helm operations plugin fixtures ok"
