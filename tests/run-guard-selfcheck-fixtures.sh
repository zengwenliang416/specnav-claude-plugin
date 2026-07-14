#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
PROJECT_FIXTURE="$ROOT/tests/fixtures/simple-project"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
PROJECT="$TMP_DIR/simple-project"
cp -R "$PROJECT_FIXTURE" "$PROJECT"

require_jq() {
  command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
}
require_jq

# Case 1: healthy parse path — session start reports guard_selfcheck ok and no
# guard-selfcheck-failed blocker.
OUT="$(PROJECT_DIR="$PROJECT" node "$CORE/scripts/specnav-session-start.js")"
echo "$OUT" | jq -e '.guard_selfcheck == "ok"' >/dev/null \
  || { echo "selfcheck fixture failed: expected guard_selfcheck=ok"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '(.blockers // []) | index("guard-selfcheck-failed") | not' >/dev/null \
  || { echo "selfcheck fixture failed: unexpected guard-selfcheck-failed blocker"; echo "$OUT"; exit 1; }

# Case 2: forced parse failure — session start must loudly report the failure,
# add the blocker, and emit a systemMessage warning.
OUT="$(PROJECT_DIR="$PROJECT" SPECNAV_GUARD_SELFCHECK_FORCE_FAIL=1 node "$CORE/scripts/specnav-session-start.js")"
echo "$OUT" | jq -e '.guard_selfcheck == "failed"' >/dev/null \
  || { echo "selfcheck fixture failed: expected guard_selfcheck=failed"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.blockers | index("guard-selfcheck-failed")' >/dev/null \
  || { echo "selfcheck fixture failed: missing guard-selfcheck-failed blocker"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.systemMessage | test("self-check FAILED")' >/dev/null \
  || { echo "selfcheck fixture failed: missing systemMessage"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.status == "blocked"' >/dev/null \
  || { echo "selfcheck fixture failed: expected status=blocked"; echo "$OUT"; exit 1; }

# Case 2b: failure is recorded in the audit log.
grep -q 'guard.selfcheck-failed' "$PROJECT/openspec/.specnav/events.jsonl" \
  || { echo "selfcheck fixture failed: no guard.selfcheck-failed event"; exit 1; }

# Case 3: affordances surface the blocker too.
OUT="$(PROJECT_DIR="$PROJECT" SPECNAV_GUARD_SELFCHECK_FORCE_FAIL=1 node "$CORE/scripts/affordances.js" --json)"
echo "$OUT" | jq -e '.blockers | index("guard-selfcheck-failed")' >/dev/null \
  || { echo "selfcheck fixture failed: affordances missing guard-selfcheck-failed"; echo "$OUT"; exit 1; }

# Case 4: fallback-field payloads still resolve paths AND report the shape
# drift as a guard.unknown-payload-shape event.
FALLBACK_PROJECT="$TMP_DIR/fallback-project"
cp -R "$PROJECT_FIXTURE" "$FALLBACK_PROJECT"
set +e
printf '{"tool_name":"Write","tool_input":{"target_path":"src/ui/theme.ts","content":"x"}}' \
  | PROJECT_DIR="$FALLBACK_PROJECT" node "$CORE/scripts/specnav-guard.js" >/dev/null 2>&1
STATUS=$?
set -e
[[ "$STATUS" == "0" ]] || { echo "selfcheck fixture failed: fallback path should still be allowed (in scope), got $STATUS"; exit 1; }
grep -q 'guard.unknown-payload-shape' "$FALLBACK_PROJECT/openspec/.specnav/events.jsonl" \
  || { echo "selfcheck fixture failed: no unknown-payload-shape event for fallback field"; exit 1; }

# Case 5: stable-field payloads must NOT emit unknown-payload-shape noise.
STABLE_PROJECT="$TMP_DIR/stable-project"
cp -R "$PROJECT_FIXTURE" "$STABLE_PROJECT"
printf '{"tool_name":"Write","tool_input":{"file_path":"src/ui/theme.ts","content":"x"}}' \
  | PROJECT_DIR="$STABLE_PROJECT" node "$CORE/scripts/specnav-guard.js" >/dev/null 2>&1
if [[ -f "$STABLE_PROJECT/openspec/.specnav/events.jsonl" ]] \
  && grep -q 'guard.unknown-payload-shape' "$STABLE_PROJECT/openspec/.specnav/events.jsonl"; then
  echo "selfcheck fixture failed: stable field wrongly reported as fallback"; exit 1
fi

# Case 6: strict-mode deny path emits a structured PreToolUse decision with
# blocker id (accounting-first default downgrades scope drift to a warning).
DENY_PROJECT="$TMP_DIR/deny-project"
cp -R "$PROJECT_FIXTURE" "$DENY_PROJECT"
set +e
OUT="$(printf '{"tool_name":"Write","tool_input":{"file_path":"src/ui/private/secret.ts","content":"x"}}' \
  | SPECNAV_STRICT=1 PROJECT_DIR="$DENY_PROJECT" node "$CORE/scripts/specnav-guard.js" 2>/dev/null)"
STATUS=$?
set -e
[[ "$STATUS" == "2" ]] || { echo "selfcheck fixture failed: expected deny exit 2, got $STATUS"; exit 1; }
echo "$OUT" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null \
  || { echo "selfcheck fixture failed: missing structured deny decision"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.hookSpecificOutput.permissionDecisionReason | test("^\\[scope\\]")' >/dev/null \
  || { echo "selfcheck fixture failed: deny reason missing blocker id prefix"; echo "$OUT"; exit 1; }

echo "specnav guard selfcheck fixtures ok"
