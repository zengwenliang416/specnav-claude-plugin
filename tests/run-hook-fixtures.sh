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

# run_case <payload-name> <project> <expected-exit> [expect-stdout] [strict]
run_case() {
  local name="$1"
  local project="$2"
  local expected="$3"
  local expect_stdout="${4:-}"
  local strict="${5:-}"
  local payload="$PAYLOADS/$name.json"
  local out="/tmp/specnav-hook-$name.out"
  local err="/tmp/specnav-hook-$name.err"

  set +e
  SPECNAV_STRICT="$strict" PROJECT_DIR="$project" node "$CORE/scripts/specnav-guard.js" <"$payload" >"$out" 2>"$err"
  local status=$?
  set -e

  if [[ "$status" != "$expected" ]]; then
    echo "hook fixture failed: $name (strict='$strict') expected=$expected actual=$status" >&2
    echo "--- stderr ---" >&2
    cat "$err" >&2
    echo "--- stdout ---" >&2
    cat "$out" >&2
    exit 1
  fi

  if [[ -n "$expect_stdout" ]] && ! grep -q "$expect_stdout" "$out"; then
    echo "hook fixture failed: $name stdout missing '$expect_stdout'" >&2
    echo "--- stdout ---" >&2
    cat "$out" >&2
    exit 1
  fi
}

run_case write-allowed "$PROJECT" 0
run_case edit-allowed "$PROJECT" 0
run_case multiedit-allowed "$PROJECT" 0
# Accounting-first default: scope drift warns (exit 0 + systemMessage) and is
# recorded as a hook.scope-drift event; SPECNAV_STRICT=1 restores blocking.
run_case scope-exclude-denied "$PROJECT" 0 "SpecNav gate warning"
run_case scope-exclude-denied "$PROJECT" 2 "" 1
run_case multiedit-denied-extra-path "$PROJECT" 0 "SpecNav gate warning"
run_case multiedit-denied-extra-path "$PROJECT" 2 "" 1
run_case notebook-denied "$PROJECT" 0 "SpecNav gate warning"
run_case notebook-denied "$PROJECT" 2 "" 1
# Hard gates stay hard in both modes.
run_case acceptance-denied "$PROJECT" 2
run_case acceptance-denied "$PROJECT" 2 "" 1
run_case openspec-allowed "$PROJECT" 0
run_case bash-safe "$PROJECT" 0
run_case bash-danger "$PROJECT" 2
# Routine cleanup must not trip the dangerous-command gate (observed misfires).
run_case bash-rm-cache "$PROJECT" 0
run_case bash-rm-tmp "$PROJECT" 0
# Legacy OpenSpec entrypoint invocation is a soft gate now.
run_case bash-openspec-propose "$PROJECT" 0 "SpecNav gate warning"
run_case bash-openspec-propose "$PROJECT" 2 "" 1
# A commit message merely mentioning OpenSpec propose is NOT an invocation.
run_case bash-commit-mentions-openspec "$PROJECT" 0
# warnings are non-blocking: exit 0 with a systemMessage payload (exit 1 rendered as a hook error banner)
run_case write-missing-path "$PROJECT" 0 "SpecNav gate warning"
# Harness-owned paths (Claude plans/memory, tmp) are never governed.
run_case write-harness-path "$PROJECT" 0
run_case write-harness-path "$PROJECT" 0 "" 1
# State 1: non-SpecNav project (no marker, no openspec) — guard stays inert
run_case write-allowed "$NO_STATE" 0
run_case bash-bootstrap "$NO_STATE" 0
run_case bash-openspec-propose "$NO_STATE" 0

# State 2: SpecNav project missing openspec (.specnav.json present) — soft gate
# by default, blocking under strict; init/repair always allowed.
SPECNAV_BROKEN_PROJECT="$TMP_DIR/specnav-broken-project"
mkdir -p "$SPECNAV_BROKEN_PROJECT"
printf '{"schema_version":1,"enabled":true}\n' >"$SPECNAV_BROKEN_PROJECT/.specnav.json"
run_case write-allowed "$SPECNAV_BROKEN_PROJECT" 0 "SpecNav gate warning"
run_case write-allowed "$SPECNAV_BROKEN_PROJECT" 2 "" 1
run_case bash-bootstrap "$SPECNAV_BROKEN_PROJECT" 0
run_case bash-plugin-suite "$SPECNAV_BROKEN_PROJECT" 0
run_case openspec-allowed "$SPECNAV_BROKEN_PROJECT" 0

MISSING_SCOPE_PROJECT="$TMP_DIR/missing-scope-project"
cp -R "$PROJECT" "$MISSING_SCOPE_PROJECT"
rm "$MISSING_SCOPE_PROJECT/openspec/changes/add-dark-mode/scope.json"
run_case write-allowed "$MISSING_SCOPE_PROJECT" 0 "SpecNav gate warning"
run_case write-allowed "$MISSING_SCOPE_PROJECT" 2 "" 1

LEGACY_OPENSPEC_PROJECT="$TMP_DIR/legacy-openspec-project"
cp -R "$PROJECT" "$LEGACY_OPENSPEC_PROJECT"
mkdir -p "$LEGACY_OPENSPEC_PROJECT/.claude/skills/openspec-propose"
cat >"$LEGACY_OPENSPEC_PROJECT/.claude/skills/openspec-propose/SKILL.md" <<'MD'
# OpenSpec Propose

Legacy OpenSpec proposal entrypoint.
MD
run_case write-allowed "$LEGACY_OPENSPEC_PROJECT" 0 "SpecNav gate warning"
run_case write-allowed "$LEGACY_OPENSPEC_PROJECT" 2 "" 1
run_case openspec-allowed "$LEGACY_OPENSPEC_PROJECT" 0

# Scope escalation (§6.3): allowed_operations + requires_review_on.
ESCALATION_PROJECT="$TMP_DIR/escalation-project"
mkdir -p "$ESCALATION_PROJECT/openspec/.specnav/overrides" "$ESCALATION_PROJECT/openspec/changes/c" "$ESCALATION_PROJECT/src/locked" "$ESCALATION_PROJECT/src/shared"
printf 'c\n' >"$ESCALATION_PROJECT/openspec/.specnav/active-change"
printf -- '- task\n' >"$ESCALATION_PROJECT/openspec/changes/c/tasks.md"
cat >"$ESCALATION_PROJECT/openspec/changes/c/scope.json" <<'JSON'
{"schema_version":1,"allowed_roots":["src/**"],"denied_roots":[],"allowed_operations":{"create":true,"modify":false,"delete":false,"rename":true},"requires_review_on":["src/shared/**"]}
JSON
printf 'existing\n' >"$ESCALATION_PROJECT/src/locked/config.ts"
# modify of an existing in-scope file: soft warn by default, blocked under strict
run_case operation-modify-denied "$ESCALATION_PROJECT" 0 "SpecNav gate warning"
run_case operation-modify-denied "$ESCALATION_PROJECT" 2 "" 1
# a requires_review_on path warns non-blockingly (exit 0 + systemMessage) until a review override exists
run_case review-required "$ESCALATION_PROJECT" 0 "requires_review_on"
cat >"$ESCALATION_PROJECT/openspec/.specnav/overrides/review.json" <<'JSON'
{"gate":"review","reason":"shared component reviewed","active_change":"c","affected_path":"src/shared/button.tsx","expires_at":"2099-01-01T00:00:00.000Z"}
JSON
# with the override in place the warning disappears entirely
run_case review-required "$ESCALATION_PROJECT" 0
if grep -q "requires_review_on" /tmp/specnav-hook-review-required.out; then
  echo "hook fixture failed: review-required still warns after override" >&2
  exit 1
fi

# Cross-repo scope: external_repos declaration allows sibling-repo edits and
# records hook.external-edit; undeclared external paths soft-gate.
CROSS_MAIN="$TMP_DIR/cross-main"
CROSS_SIBLING="$TMP_DIR/cross-sibling"
mkdir -p "$CROSS_MAIN/openspec/.specnav" "$CROSS_MAIN/openspec/changes/x" "$CROSS_SIBLING/src"
printf 'x\n' >"$CROSS_MAIN/openspec/.specnav/active-change"
printf -- '- [ ] user can view cross repo sync\n' >"$CROSS_MAIN/openspec/changes/x/tasks.md"
cat >"$CROSS_MAIN/openspec/changes/x/scope.json" <<JSON
{"schema_version":1,"allowed_roots":["src/**"],"denied_roots":[],"external_repos":[{"root":"../cross-sibling","include":["src/**"],"reason":"frontend/backend contract sync"}]}
JSON
cat >"$PAYLOADS/write-external-declared.json" <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$CROSS_SIBLING/src/config.yaml","content":"x"}}
JSON
cat >"$PAYLOADS/write-external-undeclared.json" <<JSON
{"tool_name":"Write","tool_input":{"file_path":"$CROSS_SIBLING/secrets/topsecret.txt","content":"x"}}
JSON
run_case write-external-declared "$CROSS_MAIN" 0
run_case write-external-declared "$CROSS_MAIN" 0 "" 1
if ! grep -q "hook.external-edit" "$CROSS_MAIN/openspec/.specnav/events.jsonl"; then
  echo "hook fixture failed: external-edit event not recorded" >&2
  exit 1
fi
run_case write-external-undeclared "$CROSS_MAIN" 0 "external_repos"
run_case write-external-undeclared "$CROSS_MAIN" 2 "" 1
rm -f "$PAYLOADS/write-external-declared.json" "$PAYLOADS/write-external-undeclared.json"

# Event noise: hook.allow is only recorded under SPECNAV_EVENT_VERBOSE=1.
ALLOW_EVENTS_PROJECT="$TMP_DIR/allow-events"
cp -R "$PROJECT_FIXTURE" "$ALLOW_EVENTS_PROJECT"
: >"$ALLOW_EVENTS_PROJECT/openspec/.specnav/events.jsonl"
PROJECT_DIR="$ALLOW_EVENTS_PROJECT" node "$CORE/scripts/specnav-guard.js" <"$PAYLOADS/write-allowed.json" >/dev/null 2>&1 || true
if grep -q "hook.allow" "$ALLOW_EVENTS_PROJECT/openspec/.specnav/events.jsonl" 2>/dev/null; then
  echo "hook fixture failed: hook.allow recorded without SPECNAV_EVENT_VERBOSE" >&2
  exit 1
fi
SPECNAV_EVENT_VERBOSE=1 PROJECT_DIR="$ALLOW_EVENTS_PROJECT" node "$CORE/scripts/specnav-guard.js" <"$PAYLOADS/write-allowed.json" >/dev/null 2>&1 || true
if ! grep -q "hook.allow" "$ALLOW_EVENTS_PROJECT/openspec/.specnav/events.jsonl" 2>/dev/null; then
  echo "hook fixture failed: hook.allow missing under SPECNAV_EVENT_VERBOSE=1" >&2
  exit 1
fi


# Warning dedup: same (reason, change) warns once per session; a new session
# id resets. Events keep recording every occurrence.
DEDUP_PROJECT="$TMP_DIR/dedup-project"
mkdir -p "$DEDUP_PROJECT/openspec/.specnav" "$DEDUP_PROJECT/openspec/changes/d"
printf 'd\n' >"$DEDUP_PROJECT/openspec/.specnav/active-change"
DEDUP_PAYLOAD='{"session_id":"s-dedup-1","tool_name":"Write","tool_input":{"file_path":"src/app.ts","content":"x"}}'
OUT1="$(printf '%s' "$DEDUP_PAYLOAD" | PROJECT_DIR="$DEDUP_PROJECT" node "$CORE/scripts/specnav-guard.js")"
echo "$OUT1" | grep -q "SpecNav gate warning" || { echo "dedup: first warn missing"; exit 1; }
OUT2="$(printf '%s' "$DEDUP_PAYLOAD" | PROJECT_DIR="$DEDUP_PROJECT" node "$CORE/scripts/specnav-guard.js")"
if echo "$OUT2" | grep -q "SpecNav gate warning"; then
  echo "dedup: second identical warn should be silent"; exit 1
fi
WARN_EVENTS="$(grep -c '"reason":"missing-tasks"' "$DEDUP_PROJECT/openspec/.specnav/events.jsonl")"
[[ "$WARN_EVENTS" == "2" ]] || { echo "dedup: expected 2 warn events, got $WARN_EVENTS"; exit 1; }
OUT3="$(printf '%s' "${DEDUP_PAYLOAD/s-dedup-1/s-dedup-2}" | PROJECT_DIR="$DEDUP_PROJECT" node "$CORE/scripts/specnav-guard.js")"
echo "$OUT3" | grep -q "SpecNav gate warning" || { echo "dedup: new session should warn again"; exit 1; }

# Requirements-stage awareness: docs/markdown edits under a change that has
# requirements.md but no tasks.md yet are silent; source edits still warn.
REQ_STAGE_PROJECT="$TMP_DIR/req-stage-project"
mkdir -p "$REQ_STAGE_PROJECT/openspec/.specnav" "$REQ_STAGE_PROJECT/openspec/changes/r"
printf 'r\n' >"$REQ_STAGE_PROJECT/openspec/.specnav/active-change"
printf '# Requirements\n' >"$REQ_STAGE_PROJECT/openspec/changes/r/requirements.md"
OUT="$(printf '%s' '{"session_id":"s-req","tool_name":"Write","tool_input":{"file_path":"docs/design/plan.md","content":"x"}}' | PROJECT_DIR="$REQ_STAGE_PROJECT" node "$CORE/scripts/specnav-guard.js")"
if echo "$OUT" | grep -q "SpecNav gate warning"; then
  echo "req-stage: docs edit should be silent during requirements stage"; exit 1
fi
OUT="$(printf '%s' '{"session_id":"s-req","tool_name":"Write","tool_input":{"file_path":"src/app.ts","content":"x"}}' | PROJECT_DIR="$REQ_STAGE_PROJECT" node "$CORE/scripts/specnav-guard.js")"
echo "$OUT" | grep -q "missing-tasks" || { echo "req-stage: source edit should still warn"; exit 1; }

echo "specnav hook fixtures ok"
