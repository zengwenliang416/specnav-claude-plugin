#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
PROJECT_FIXTURE="$ROOT/tests/fixtures/simple-project"
NO_STATE_FIXTURE="$ROOT/tests/fixtures/no-state"
PAYLOADS="$ROOT/tests/fixtures/hook-payloads"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
PROJECT="$TMP_DIR/simple-project"
NO_STATE="$TMP_DIR/no-state"
cp -R "$PROJECT_FIXTURE" "$PROJECT"
cp -R "$NO_STATE_FIXTURE" "$NO_STATE"

run_case() {
  local name="$1"
  local project="$2"
  local expected="$3"
  local payload="$PAYLOADS/$name.json"
  local out="/tmp/specnav-hook-$name.out"
  local err="/tmp/specnav-hook-$name.err"

  set +e
  PROJECT_DIR="$project" node "$CORE/scripts/specnav-guard.js" <"$payload" >"$out" 2>"$err"
  local status=$?
  set -e

  if [[ "$status" != "$expected" ]]; then
    echo "hook fixture failed: $name expected=$expected actual=$status" >&2
    echo "--- stderr ---" >&2
    cat "$err" >&2
    echo "--- stdout ---" >&2
    cat "$out" >&2
    exit 1
  fi
}

run_case write-allowed "$PROJECT" 0
run_case edit-allowed "$PROJECT" 0
run_case multiedit-allowed "$PROJECT" 0
run_case scope-exclude-denied "$PROJECT" 2
run_case multiedit-denied-extra-path "$PROJECT" 2
run_case notebook-denied "$PROJECT" 2
run_case acceptance-denied "$PROJECT" 2
run_case openspec-allowed "$PROJECT" 0
run_case bash-safe "$PROJECT" 0
run_case bash-danger "$PROJECT" 2
run_case bash-openspec-propose "$PROJECT" 2
run_case write-missing-path "$PROJECT" 1
# State 1: non-SpecNav project (no marker, no openspec) — guard stays inert
run_case write-allowed "$NO_STATE" 0
run_case bash-bootstrap "$NO_STATE" 0
run_case bash-openspec-propose "$NO_STATE" 0

# State 2: SpecNav project missing openspec (.specnav.json present) — deny production writes, allow init/repair
SPECNAV_BROKEN_PROJECT="$TMP_DIR/specnav-broken-project"
mkdir -p "$SPECNAV_BROKEN_PROJECT"
printf '{"schema_version":1,"enabled":true}\n' >"$SPECNAV_BROKEN_PROJECT/.specnav.json"
run_case write-allowed "$SPECNAV_BROKEN_PROJECT" 2
run_case bash-bootstrap "$SPECNAV_BROKEN_PROJECT" 0
run_case bash-plugin-suite "$SPECNAV_BROKEN_PROJECT" 0
run_case openspec-allowed "$SPECNAV_BROKEN_PROJECT" 0

MISSING_SCOPE_PROJECT="$TMP_DIR/missing-scope-project"
cp -R "$PROJECT" "$MISSING_SCOPE_PROJECT"
rm "$MISSING_SCOPE_PROJECT/openspec/changes/add-dark-mode/scope.json"
run_case write-allowed "$MISSING_SCOPE_PROJECT" 2

LEGACY_OPENSPEC_PROJECT="$TMP_DIR/legacy-openspec-project"
cp -R "$PROJECT" "$LEGACY_OPENSPEC_PROJECT"
mkdir -p "$LEGACY_OPENSPEC_PROJECT/.claude/skills/openspec-propose"
cat >"$LEGACY_OPENSPEC_PROJECT/.claude/skills/openspec-propose/SKILL.md" <<'MD'
# OpenSpec Propose

Legacy OpenSpec proposal entrypoint.
MD
run_case write-allowed "$LEGACY_OPENSPEC_PROJECT" 2
run_case openspec-allowed "$LEGACY_OPENSPEC_PROJECT" 0

# Scope escalation (§6.3): allowed_operations + requires_review_on enforced at edit time.
ESCALATION_PROJECT="$TMP_DIR/escalation-project"
mkdir -p "$ESCALATION_PROJECT/openspec/.specnav/overrides" "$ESCALATION_PROJECT/openspec/changes/c" "$ESCALATION_PROJECT/src/locked" "$ESCALATION_PROJECT/src/shared"
printf 'c\n' >"$ESCALATION_PROJECT/openspec/.specnav/active-change"
printf -- '- task\n' >"$ESCALATION_PROJECT/openspec/changes/c/tasks.md"
cat >"$ESCALATION_PROJECT/openspec/changes/c/scope.json" <<'JSON'
{"schema_version":1,"allowed_roots":["src/**"],"denied_roots":[],"allowed_operations":{"create":true,"modify":false,"delete":false,"rename":true},"requires_review_on":["src/shared/**"]}
JSON
printf 'existing\n' >"$ESCALATION_PROJECT/src/locked/config.ts"
# modify of an existing in-scope file is blocked when allowed_operations.modify is false
run_case operation-modify-denied "$ESCALATION_PROJECT" 2
# a requires_review_on path warns (escalated review) until a review override exists
run_case review-required "$ESCALATION_PROJECT" 1
cat >"$ESCALATION_PROJECT/openspec/.specnav/overrides/review.json" <<'JSON'
{"gate":"review","reason":"shared component reviewed","active_change":"c","affected_path":"src/shared/button.tsx","expires_at":"2099-01-01T00:00:00.000Z"}
JSON
run_case review-required "$ESCALATION_PROJECT" 0

echo "specnav hook fixtures ok"
