#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
PROJECT_FIXTURE="$ROOT/tests/fixtures/simple-project"
NO_STATE_FIXTURE="$ROOT/tests/fixtures/no-state"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

# Case 1: managed project — ritual is present, bounded, and load-bearing.
PROJECT="$TMP_DIR/managed"
cp -R "$PROJECT_FIXTURE" "$PROJECT"
CHANGE_DIR="$PROJECT/openspec/changes/add-dark-mode"
cat >"$CHANGE_DIR/acceptance.json" <<'JSON'
{"assertions":[
  {"id":"A1","statement":"s1","verify_via":"unit","status":"passing","evidence_ref":"e"},
  {"id":"A2","statement":"s2","verify_via":"e2e","status":"failing","evidence_ref":null}
]}
JSON
printf '2026-07-03T00:00:00Z\n' >"$CHANGE_DIR/verify-report.stale"
OUT="$(printf '{"session_id":"s-ritual"}' | PROJECT_DIR="$PROJECT" node "$CORE/scripts/specnav-session-start.js")"
echo "$OUT" | jq -e '.ritual.active_change == "add-dark-mode"' >/dev/null \
  || { echo "ritual fixture failed: active_change"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.ritual.acceptance.total == 2 and .ritual.acceptance.failing == 1' >/dev/null \
  || { echo "ritual fixture failed: acceptance counters"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.ritual.verify_stale == true' >/dev/null \
  || { echo "ritual fixture failed: stale flag"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.ritual.ready_actions | type == "array"' >/dev/null \
  || { echo "ritual fixture failed: ready_actions"; echo "$OUT"; exit 1; }
# journal tail is bounded
echo "$OUT" | jq -e '(.ritual.last_session_journal // "") | length <= 600' >/dev/null \
  || { echo "ritual fixture failed: journal tail exceeds bound"; exit 1; }

# Case 2: unmanaged project — no ritual noise, minimal inactive output.
OUT="$(printf '{}' | PROJECT_DIR="$TMP_DIR/nonexistent-unmanaged" node "$CORE/scripts/specnav-session-start.js" 2>/dev/null || true)"
echo "$OUT" | jq -e '.status == "inactive" and (has("ritual") | not)' >/dev/null \
  || { echo "ritual fixture failed: unmanaged project not silent"; echo "$OUT"; exit 1; }

# Case 3: PreCompact hook injects bounded additionalContext.
OUT="$(printf '{"hook_event_name":"PreCompact"}' | PROJECT_DIR="$PROJECT" node "$CORE/scripts/specnav-pre-compact.js")"
echo "$OUT" | jq -e '.hookSpecificOutput.hookEventName == "PreCompact"' >/dev/null \
  || { echo "ritual fixture failed: precompact shape"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.hookSpecificOutput.additionalContext | test("add-dark-mode")' >/dev/null \
  || { echo "ritual fixture failed: precompact missing change"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.hookSpecificOutput.additionalContext | test("STALE")' >/dev/null \
  || { echo "ritual fixture failed: precompact missing stale"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.hookSpecificOutput.additionalContext | length < 2000' >/dev/null \
  || { echo "ritual fixture failed: precompact context too large"; exit 1; }

# Case 4: PreCompact on unmanaged project exits 0 with no output.
OUT="$(printf '{}' | PROJECT_DIR="$NO_STATE_FIXTURE" node "$CORE/scripts/specnav-pre-compact.js")"
[[ -z "$OUT" ]] || { echo "ritual fixture failed: precompact noisy on unmanaged"; echo "$OUT"; exit 1; }

echo "specnav session-ritual fixtures ok"
