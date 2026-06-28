#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PROJECT="$TMP/project"
CHANGE="demo-change"
OUT="$TMP/out.json"
ERR="$TMP/err.txt"
mkdir -p "$PROJECT/openspec/.specnav" "$PROJECT/openspec/changes/$CHANGE"
printf '%s\n' "$CHANGE" > "$PROJECT/openspec/.specnav/active-change"

run_json() {
  node "$1" --project "$PROJECT" --change "$CHANGE" --json "${@:2}" >"$OUT"
  node -e 'const fs=require("fs"); const data=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); if (!data.ok) process.exit(1);' "$OUT"
}

assert_file() {
  test -f "$PROJECT/$1" || {
    echo "missing expected file: $1" >&2
    exit 1
  }
}

assert_missing_openspec_blocks() {
  local script="$1"
  local empty="$TMP/no-openspec"
  mkdir -p "$empty"
  if node "$script" --project "$empty" --json >"$OUT" 2>"$ERR"; then
    echo "expected missing OpenSpec to block: $script" >&2
    exit 1
  fi
  node -e 'const fs=require("fs"); const data=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); if (!data.blockers || !data.blockers.includes("missing-openspec")) process.exit(1);' "$OUT"
}

assert_missing_active_change_blocks() {
  local script="$1"
  local no_active="$TMP/no-active-change"
  mkdir -p "$no_active/openspec/changes/$CHANGE"
  if env -u SPECNAV_CHANGE node "$script" --project "$no_active" --json >"$OUT" 2>"$ERR"; then
    echo "expected missing active change to block: $script" >&2
    exit 1
  fi
  node -e 'const fs=require("fs"); const data=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); if (!data.blockers || !data.blockers.includes("active-change")) process.exit(1);' "$OUT"
}

assert_blocks_with() {
  local blocker="$1"
  shift
  if "$@" --project "$PROJECT" --change "$CHANGE" --json >"$OUT" 2>"$ERR"; then
    echo "expected command to block: $*" >&2
    exit 1
  fi
  node -e 'const fs=require("fs"); const data=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); if (!data.blockers || !data.blockers.includes(process.argv[2])) process.exit(1);' "$OUT" "$blocker"
}

FOUNDATION="$ROOT/plugins/specnav-requirements/skills/specnav-foundation-specs/scripts/create-foundation-specs.js"
REQUIREMENTS="$ROOT/plugins/specnav-requirements/skills/specnav-requirements/scripts/create-requirements-artifacts.js"
PROTOTYPE="$ROOT/plugins/specnav-prototype/skills/specnav-prototype/scripts/create-prototype.js"
TASKS_MD="$ROOT/plugins/specnav-core/scripts/tasks-md.js"
DEV_ENTRY="$ROOT/plugins/specnav-development/skills/specnav-development-entry/scripts/create-development-entry.js"
SCOPE="$ROOT/plugins/specnav-development/skills/specnav-scope-lock/scripts/create-scope-lock.js"
SLICE="$ROOT/plugins/specnav-development/skills/specnav-vertical-slices/scripts/create-vertical-slice.js"
VERIFY="$ROOT/plugins/specnav-verification/skills/specnav-verify-plan/scripts/create-verify-plan.js"
READINESS="$ROOT/plugins/specnav-operations/skills/specnav-ops-readiness/scripts/create-readiness.js"
RELEASE="$ROOT/plugins/specnav-operations/skills/specnav-release-plan/scripts/create-release-plan.js"

assert_missing_openspec_blocks "$FOUNDATION"
assert_missing_active_change_blocks "$REQUIREMENTS"

run_json "$FOUNDATION"
assert_file "openspec/specs/ui-design/design.md"
assert_file "openspec/specs/system-architecture/design.md"
assert_file "openspec/specs/frontend-backend-data-flow/design.md"
assert_file "openspec/specs/component-architecture/design.md"
PROJECT_DIR="$PROJECT" node "$ROOT/plugins/specnav-requirements/scripts/foundation-specs.js" --json >"$OUT" || true
node -e 'const fs=require("fs"); const data=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); if (data.ok || !data.blockers.some((item) => item.startsWith("unresolved-foundation-spec-decisions:"))) process.exit(1);' "$OUT"

run_json "$REQUIREMENTS"
assert_file "openspec/changes/$CHANGE/requirements.md"
assert_file "openspec/changes/$CHANGE/acceptance.md"
assert_file "openspec/changes/$CHANGE/spec-map.json"
assert_file "openspec/changes/$CHANGE/component-impact-map.json"

run_json "$PROTOTYPE" --branch=ui-html
assert_blocks_with invalid-prototype-branch node "$PROTOTYPE" --branch=unknown
assert_blocks_with missing-option-value:--branch node "$PROTOTYPE" --branch --json
assert_file "openspec/changes/$CHANGE/prototype/question.md"
assert_file "openspec/changes/$CHANGE/prototype/prototype-manifest.json"
assert_file "openspec/changes/$CHANGE/prototype/artifact/index.html"
assert_file "openspec/changes/$CHANGE/prototype/screen-map.json"

run_json "$DEV_ENTRY"
assert_file "openspec/changes/$CHANGE/development/before-dev-check.json"
assert_file "openspec/changes/$CHANGE/development/basis.md"
assert_file "openspec/changes/$CHANGE/development/prototype-promotion-map.json"

run_json "$SCOPE"
assert_file "openspec/changes/$CHANGE/scope.json"

run_json "$SLICE" --task-id=slice-001
assert_blocks_with missing-task-id node "$SLICE"
assert_blocks_with missing-option-value:--task-id node "$SLICE" --task-id --json
assert_blocks_with invalid-task-id node "$SLICE" --task-id=../../outside
assert_file "openspec/changes/$CHANGE/tasks.md"
grep -Fq -- '- [ ] User can complete the primary approved flow from the prototype handoff.' "$PROJECT/openspec/changes/$CHANGE/tasks.md"
assert_file "openspec/changes/$CHANGE/development/tasks/slice-001/brief.md"
assert_file "openspec/changes/$CHANGE/development/tasks/slice-001/context.json"
assert_file "openspec/changes/$CHANGE/development/handoff-to-verify.md"

cat >"$PROJECT/openspec/changes/$CHANGE/tasks.md" <<'MD'
# Tasks

- user can complete the primary approved flow from the prototype handoff
MD
if node "$TASKS_MD" normalize --project "$PROJECT" --change "$CHANGE" --json >"$OUT"; then
  echo "expected tasks-md normalize to keep unchecked tasks blocking handoff" >&2
  exit 1
fi
grep -Fq -- '- [ ] user can complete the primary approved flow from the prototype handoff' "$PROJECT/openspec/changes/$CHANGE/tasks.md"

run_json "$VERIFY"
assert_file "openspec/changes/$CHANGE/verify/plan.json"
grep -Fq '## Verification Scope' "$PROJECT/openspec/changes/$CHANGE/verify/plan.md"
grep -Fq '## Required Domains' "$PROJECT/openspec/changes/$CHANGE/verify/plan.md"
grep -Fq '## Evidence Plan' "$PROJECT/openspec/changes/$CHANGE/verify/plan.md"
assert_file "openspec/changes/$CHANGE/verify/traceability-matrix.json"
assert_file "openspec/changes/$CHANGE/verify/receipt.json"

run_json "$RELEASE" --release-target=local-only
assert_blocks_with invalid-release-target node "$RELEASE"
assert_file "openspec/changes/$CHANGE/operations/release-plan.md"
assert_file "openspec/changes/$CHANGE/operations/release-checklist.json"
assert_file "openspec/changes/$CHANGE/operations/changelog.md"

run_json "$READINESS" --release-target=local-only
assert_blocks_with invalid-release-target node "$READINESS"
assert_file "openspec/changes/$CHANGE/operations/readiness.md"
assert_file "openspec/changes/$CHANGE/operations/readiness.json"

echo "specnav skill resource fixtures ok"
