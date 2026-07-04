#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
PROJECT_FIXTURE="$ROOT/tests/fixtures/simple-project"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

CHANGE_REL="openspec/changes/add-dark-mode"

# --- Stop hook ---

# Case 1: edits happened (stale marker) with no newer ledger entry -> block.
P="$TMP_DIR/unaccounted"
cp -R "$PROJECT_FIXTURE" "$P"
mkdir -p "$P/$CHANGE_REL/development"
printf '{"task":"t","status":"complete"}\n' >"$P/$CHANGE_REL/development/task-ledger.jsonl"
sleep 0.1
printf '2026-07-03T00:00:00Z\n' >"$P/$CHANGE_REL/verify-report.stale"
OUT="$(printf '{}' | PROJECT_DIR="$P" node "$CORE/scripts/specnav-stop-check.js")"
echo "$OUT" | jq -e '.decision == "block"' >/dev/null \
  || { echo "stop fixture failed: unaccounted edits not blocked"; echo "$OUT"; exit 1; }
grep -q 'stop.unaccounted-edits' "$P/openspec/.specnav/events.jsonl" \
  || { echo "stop fixture failed: no audit event"; exit 1; }

# Case 2: ledger updated after the edits -> no block.
printf '{"task":"t","status":"complete","note":"accounted"}\n' >>"$P/$CHANGE_REL/development/task-ledger.jsonl"
OUT="$(printf '{}' | PROJECT_DIR="$P" node "$CORE/scripts/specnav-stop-check.js")"
[[ -z "$OUT" ]] || { echo "stop fixture failed: accounted edits still blocked"; echo "$OUT"; exit 1; }

# Case 3: loop safety — stop_hook_active never blocks twice.
printf '2026-07-03T01:00:00Z\n' >"$P/$CHANGE_REL/verify-report.stale"
OUT="$(printf '{"stop_hook_active":true}' | PROJECT_DIR="$P" node "$CORE/scripts/specnav-stop-check.js")"
[[ -z "$OUT" ]] || { echo "stop fixture failed: blocked while stop_hook_active"; echo "$OUT"; exit 1; }

# Case 4: no stale marker (no production edits) -> silent.
P="$TMP_DIR/no-edits"
cp -R "$PROJECT_FIXTURE" "$P"
OUT="$(printf '{}' | PROJECT_DIR="$P" node "$CORE/scripts/specnav-stop-check.js")"
[[ -z "$OUT" ]] || { echo "stop fixture failed: noisy without edits"; echo "$OUT"; exit 1; }

# --- PostToolUseFailure hook ---

# Case 5: failures are classified and appended.
P="$TMP_DIR/failure"
cp -R "$PROJECT_FIXTURE" "$P"
printf '{"tool_name":"Bash","tool_error":"bash: playwright: command not found"}' \
  | PROJECT_DIR="$P" node "$CORE/scripts/specnav-post-tool-failure.js"
CLS="$P/$CHANGE_REL/verify/blocker-classification.jsonl"
[[ -f "$CLS" ]] || { echo "failure fixture failed: no classification file"; exit 1; }
tail -1 "$CLS" | jq -e '.blocker_class == "env-runtime" and .tool == "Bash"' >/dev/null \
  || { echo "failure fixture failed: wrong classification"; tail -1 "$CLS"; exit 1; }

printf '{"tool_name":"Bash","tool_error":"Error: permission denied (EACCES)"}' \
  | PROJECT_DIR="$P" node "$CORE/scripts/specnav-post-tool-failure.js"
tail -1 "$CLS" | jq -e '.blocker_class == "env-auth"' >/dev/null \
  || { echo "failure fixture failed: auth classification"; tail -1 "$CLS"; exit 1; }

printf '{"tool_name":"Bash","tool_error":"SpecNav gate denied: [scope] x is outside scope"}' \
  | PROJECT_DIR="$P" node "$CORE/scripts/specnav-post-tool-failure.js"
tail -1 "$CLS" | jq -e '.blocker_class == "contract-regression"' >/dev/null \
  || { echo "failure fixture failed: contract classification"; tail -1 "$CLS"; exit 1; }

# Case 6: hook is non-blocking even on unmanaged projects.
set +e
printf '{"tool_name":"Bash","tool_error":"whatever"}' \
  | PROJECT_DIR="$TMP_DIR/does-not-exist" node "$CORE/scripts/specnav-post-tool-failure.js"
STATUS=$?
set -e
[[ "$STATUS" == "0" ]] || { echo "failure fixture failed: hook blocked on unmanaged project"; exit 1; }

echo "specnav stop/failure hook fixtures ok"
