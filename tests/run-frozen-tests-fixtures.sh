#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
PROJECT_FIXTURE="$ROOT/tests/fixtures/simple-project"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

guard() {
  local project="$1" payload="$2" expected="$3" label="$4"
  set +e
  printf '%s' "$payload" | PROJECT_DIR="$project" node "$CORE/scripts/specnav-guard.js" >/tmp/frozen-tests.out 2>/tmp/frozen-tests.err
  local status=$?
  set -e
  [[ "$status" == "$expected" ]] \
    || { echo "frozen-tests fixture failed ($label): expected $expected got $status"; cat /tmp/frozen-tests.err; exit 1; }
}

make_project() {
  local project="$1"
  cp -R "$PROJECT_FIXTURE" "$project"
  local task_dir="$project/openspec/changes/add-dark-mode/development/tasks/001-theme"
  mkdir -p "$task_dir"
  cat >"$task_dir/context.json" <<'JSON'
{"task_id":"001-theme","goal":"g","stop_condition":"s","must_read":[],"allowed_files":["src/ui"],"test_paths":["tests/ui/**"],"non_goals":[],"expected_evidence":[],"unsafe_assumptions":[]}
JSON
  # tests/ui must be inside scope so only the freeze (not scope) is exercised.
  python3 - "$project/openspec/changes/add-dark-mode/scope.json" <<'PY'
import json, sys
p = sys.argv[1]
scope = json.load(open(p))
if 'tests/ui/**' not in scope['allowed_roots']:
    scope['allowed_roots'].append('tests/ui/**')
json.dump(scope, open(p, 'w'), indent=2)
PY
}

WRITE_EXISTING='{"tool_name":"Write","tool_input":{"file_path":"tests/ui/theme.test.ts","content":"x"}}'

# Case 1: creating a NOT-yet-existing test file is allowed (tests-first).
P="$TMP_DIR/create-ok"
make_project "$P"
guard "$P" "$WRITE_EXISTING" 0 "create new test"

# Case 2: modifying an EXISTING committed test is denied with frozen-tests.
P="$TMP_DIR/modify-denied"
make_project "$P"
mkdir -p "$P/tests/ui"
printf 'test\n' >"$P/tests/ui/theme.test.ts"
guard "$P" "$WRITE_EXISTING" 2 "modify frozen test"
grep -q '\[frozen-tests\]' /tmp/frozen-tests.err \
  || { echo "frozen-tests fixture failed: deny reason missing blocker id"; cat /tmp/frozen-tests.err; exit 1; }
grep -q '"reason":"frozen-tests"' "$P/openspec/.specnav/events.jsonl" \
  || { echo "frozen-tests fixture failed: no audit event"; exit 1; }

# Case 3: with a frozen-tests override the modification is allowed and the
# override use is audited.
P="$TMP_DIR/override-ok"
make_project "$P"
mkdir -p "$P/tests/ui" "$P/openspec/.specnav/overrides"
printf 'test\n' >"$P/tests/ui/theme.test.ts"
cat >"$P/openspec/.specnav/overrides/frozen-tests.json" <<'JSON'
{"gate":"frozen-tests","reason":"test itself asserts wrong behavior; approved in review","active_change":"add-dark-mode","affected_path":"tests/ui/theme.test.ts","expires_at":"2099-01-01T00:00:00.000Z"}
JSON
guard "$P" "$WRITE_EXISTING" 0 "override allows"
grep -q '"gate":"frozen-tests"' "$P/openspec/.specnav/events.jsonl" \
  || { echo "frozen-tests fixture failed: override use not audited"; exit 1; }

# Case 4: tasks without test_paths are unaffected — modifying an in-scope
# non-test file works as before.
P="$TMP_DIR/unaffected"
cp -R "$PROJECT_FIXTURE" "$P"
guard "$P" '{"tool_name":"Write","tool_input":{"file_path":"src/ui/theme.ts","content":"x"}}' 0 "non-test unaffected"

echo "specnav frozen-tests fixtures ok"
