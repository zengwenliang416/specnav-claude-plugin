#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVEL="$ROOT/plugins/specnav-development"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

# Unit-level fixtures for detectTaskLoops via the exported contract module.
detect() {
  local ledger_file="$1"
  node -e "
const fs = require('fs');
const path = require('path');
const os = require('os');
const dev = fs.mkdtempSync(path.join(os.tmpdir(), 'loop-detect-'));
fs.copyFileSync('$ledger_file', path.join(dev, 'task-ledger.jsonl'));
const { detectTaskLoops } = require('$DEVEL/scripts/development-contract.js');
console.log(JSON.stringify(detectTaskLoops(dev)));
"
}

# Case 1: 3 consecutive same-cause failures trip loop-detected.
cat >"$TMP_DIR/trip.jsonl" <<'JSONL'
{"task":"001-auth","status":"spec_review_failed","blocker":"missing-requirement:auth-roles"}
{"task":"001-auth","status":"spec_review_failed","blocker":"missing-requirement:auth-roles"}
{"task":"001-auth","status":"spec_review_failed","blocker":"missing-requirement:auth-roles"}
JSONL
OUT="$(detect "$TMP_DIR/trip.jsonl")"
echo "$OUT" | jq -e 'length == 1 and .[0].task_id == "001-auth" and .[0].consecutive_failures == 3' >/dev/null \
  || { echo "loop fixture failed: threshold trip"; echo "$OUT"; exit 1; }

# Case 2: below threshold does not trip.
cat >"$TMP_DIR/below.jsonl" <<'JSONL'
{"task":"001-auth","status":"spec_review_failed","blocker":"missing-requirement:auth-roles"}
{"task":"001-auth","status":"spec_review_failed","blocker":"missing-requirement:auth-roles"}
JSONL
OUT="$(detect "$TMP_DIR/below.jsonl")"
echo "$OUT" | jq -e 'length == 0' >/dev/null \
  || { echo "loop fixture failed: below threshold tripped"; echo "$OUT"; exit 1; }

# Case 3: non-consecutive failures (pass in between) do not trip.
cat >"$TMP_DIR/broken-streak.jsonl" <<'JSONL'
{"task":"001-auth","status":"spec_review_failed","blocker":"b1"}
{"task":"001-auth","status":"spec_review_failed","blocker":"b1"}
{"task":"001-auth","status":"spec_review_passed"}
{"task":"001-auth","status":"quality_review_failed","blocker":"b1"}
JSONL
OUT="$(detect "$TMP_DIR/broken-streak.jsonl")"
echo "$OUT" | jq -e 'length == 0' >/dev/null \
  || { echo "loop fixture failed: broken streak tripped"; echo "$OUT"; exit 1; }

# Case 4: different causes do not accumulate into one streak.
cat >"$TMP_DIR/mixed-cause.jsonl" <<'JSONL'
{"task":"001-auth","status":"spec_review_failed","blocker":"b1"}
{"task":"001-auth","status":"spec_review_failed","blocker":"b2"}
{"task":"001-auth","status":"spec_review_failed","blocker":"b3"}
JSONL
OUT="$(detect "$TMP_DIR/mixed-cause.jsonl")"
echo "$OUT" | jq -e 'length == 0' >/dev/null \
  || { echo "loop fixture failed: mixed causes tripped"; echo "$OUT"; exit 1; }

# Case 5: escalation entry clears a tripped loop.
cat >"$TMP_DIR/escalated.jsonl" <<'JSONL'
{"task":"001-auth","status":"spec_review_failed","blocker":"b1"}
{"task":"001-auth","status":"spec_review_failed","blocker":"b1"}
{"task":"001-auth","status":"spec_review_failed","blocker":"b1"}
{"task":"001-auth","status":"escalated","classification":"missing-scope","routed_to":"specnav-scope-lock"}
JSONL
OUT="$(detect "$TMP_DIR/escalated.jsonl")"
echo "$OUT" | jq -e 'length == 0' >/dev/null \
  || { echo "loop fixture failed: escalation did not clear"; echo "$OUT"; exit 1; }

# Case 6: two tasks tracked independently.
cat >"$TMP_DIR/two-tasks.jsonl" <<'JSONL'
{"task":"001-auth","status":"fix_failed","blocker":"b1"}
{"task":"002-ui","status":"fix_failed","blocker":"b9"}
{"task":"001-auth","status":"fix_failed","blocker":"b1"}
{"task":"002-ui","status":"complete"}
{"task":"001-auth","status":"fix_failed","blocker":"b1"}
JSONL
OUT="$(detect "$TMP_DIR/two-tasks.jsonl")"
echo "$OUT" | jq -e 'length == 1 and .[0].task_id == "001-auth"' >/dev/null \
  || { echo "loop fixture failed: cross-task isolation"; echo "$OUT"; exit 1; }

echo "specnav loop-detection fixtures ok"
