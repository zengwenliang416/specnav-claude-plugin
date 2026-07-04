#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
PROJECT_FIXTURE="$ROOT/tests/fixtures/simple-project"
TMP_DIR="$(mktemp -d)"
cleanup() {
  chmod -R u+w "$TMP_DIR" 2>/dev/null || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

# Case 1: happy path — stale marker written, exit 0, no systemMessage.
PROJECT="$TMP_DIR/happy"
cp -R "$PROJECT_FIXTURE" "$PROJECT"
CHANGE_DIR="$PROJECT/openspec/changes/add-dark-mode"
printf '{"status":"green"}\n' >"$CHANGE_DIR/verify-report.json"
OUT="$(printf '{}' | PROJECT_DIR="$PROJECT" node "$CORE/scripts/specnav-post-tool.js")"
[[ -f "$CHANGE_DIR/verify-report.stale" ]] \
  || { echo "stale fixture failed: marker not written on happy path"; exit 1; }
[[ -z "$OUT" ]] \
  || { echo "stale fixture failed: unexpected output on happy path"; echo "$OUT"; exit 1; }

# Case 2: unwritable change dir — edit must NOT be blocked; warn + event instead.
PROJECT="$TMP_DIR/unwritable"
cp -R "$PROJECT_FIXTURE" "$PROJECT"
CHANGE_DIR="$PROJECT/openspec/changes/add-dark-mode"
printf '{"status":"green"}\n' >"$CHANGE_DIR/verify-report.json"
chmod a-w "$CHANGE_DIR"
set +e
OUT="$(printf '{}' | PROJECT_DIR="$PROJECT" node "$CORE/scripts/specnav-post-tool.js")"
STATUS=$?
set -e
chmod u+w "$CHANGE_DIR"
[[ "$STATUS" == "0" ]] \
  || { echo "stale fixture failed: expected non-blocking exit 0, got $STATUS"; exit 1; }
echo "$OUT" | jq -e '.systemMessage | test("could not mark verify-report as stale")' >/dev/null \
  || { echo "stale fixture failed: missing systemMessage warning"; echo "$OUT"; exit 1; }
grep -q 'verify.stale-marker-failed' "$PROJECT/openspec/.specnav/events.jsonl" \
  || { echo "stale fixture failed: missing verify.stale-marker-failed event"; exit 1; }

# Case 3: doctor detects the unwritable dir as a repair item.
chmod a-w "$CHANGE_DIR"
set +e
DOCTOR_OUT="$(PROJECT_DIR="$PROJECT" SPECNAV_PLUGIN_LIST_JSON='[]' node "$CORE/scripts/specnav-doctor.js" --json 2>/dev/null)"
set -e
chmod u+w "$CHANGE_DIR"
echo "$DOCTOR_OUT" | jq -e '.checks[] | select(.name == "stale-marker-writable") | .ok == false' >/dev/null \
  || { echo "stale fixture failed: doctor did not flag unwritable change dir"; echo "$DOCTOR_OUT" | jq '.checks[] | select(.name == "stale-marker-writable")'; exit 1; }

# Case 4: existing stale→archive enforcement is unchanged (marker still blocks
# archive via fresh-verify — covered by lifecycle walkthrough; assert marker
# presence semantics here as a fast proxy).
PROJECT="$TMP_DIR/enforce"
cp -R "$PROJECT_FIXTURE" "$PROJECT"
CHANGE_DIR="$PROJECT/openspec/changes/add-dark-mode"
printf '{"status":"green"}\n' >"$CHANGE_DIR/verify-report.json"
printf '{}' | PROJECT_DIR="$PROJECT" node "$CORE/scripts/specnav-post-tool.js" >/dev/null
AFFORD="$(PROJECT_DIR="$PROJECT" node "$CORE/scripts/affordances.js" --json)"
echo "$AFFORD" | jq -e '.verify_report_stale == true' >/dev/null \
  || { echo "stale fixture failed: affordances lost stale detection"; exit 1; }
echo "$AFFORD" | jq -e '[.actions[] | select(.id == "release") | .blocked_by[]] | index("fresh-verify")' >/dev/null \
  || { echo "stale fixture failed: release not blocked by fresh-verify"; exit 1; }

echo "specnav stale-marker fixtures ok"
