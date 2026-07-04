#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
PROJECT_FIXTURE="$ROOT/tests/fixtures/simple-project"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

start_session() {
  local project="$1" session="$2"
  printf '{"session_id":"%s","hook_event_name":"SessionStart"}' "$session" \
    | PROJECT_DIR="$project" node "$CORE/scripts/specnav-session-start.js"
}

# Case 1: first session acquires the lock.
PROJECT="$TMP_DIR/acquire"
cp -R "$PROJECT_FIXTURE" "$PROJECT"
OUT="$(start_session "$PROJECT" "session-aaa")"
echo "$OUT" | jq -e '.session_lock == "acquired"' >/dev/null \
  || { echo "lock fixture failed: expected acquired"; echo "$OUT"; exit 1; }
jq -e '.session_id == "session-aaa" and .host == "claude"' \
  "$PROJECT/openspec/.specnav/session-lock" >/dev/null \
  || { echo "lock fixture failed: lock file malformed"; exit 1; }

# Case 1b: same session re-entry renews, does not block.
OUT="$(start_session "$PROJECT" "session-aaa")"
echo "$OUT" | jq -e '.session_lock == "renewed"' >/dev/null \
  || { echo "lock fixture failed: expected renewed"; echo "$OUT"; exit 1; }

# Case 2: second session hits an active foreign lock and is blocked.
OUT="$(start_session "$PROJECT" "session-bbb")"
echo "$OUT" | jq -e '.session_lock == "held-by-other"' >/dev/null \
  || { echo "lock fixture failed: expected held-by-other"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.blockers | index("session-lock:held-by-other")' >/dev/null \
  || { echo "lock fixture failed: missing blocker"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.systemMessage | test("session-aaa")' >/dev/null \
  || { echo "lock fixture failed: systemMessage missing holder id"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.status == "blocked"' >/dev/null \
  || { echo "lock fixture failed: expected blocked status"; echo "$OUT"; exit 1; }
# Holder is not evicted by the failed acquisition.
jq -e '.session_id == "session-aaa"' "$PROJECT/openspec/.specnav/session-lock" >/dev/null \
  || { echo "lock fixture failed: holder was evicted"; exit 1; }

# Case 3: expired lock is taken over silently.
PROJECT="$TMP_DIR/expired"
cp -R "$PROJECT_FIXTURE" "$PROJECT"
mkdir -p "$PROJECT/openspec/.specnav"
cat >"$PROJECT/openspec/.specnav/session-lock" <<'JSON'
{"schema_version":1,"session_id":"session-old","host":"codex","acquired_at":"2020-01-01T00:00:00.000Z","ttl_minutes":240,"expires_at":"2020-01-01T04:00:00.000Z"}
JSON
OUT="$(start_session "$PROJECT" "session-new")"
echo "$OUT" | jq -e '.session_lock == "acquired"' >/dev/null \
  || { echo "lock fixture failed: expected takeover of expired lock"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '(.blockers // []) | index("session-lock:held-by-other") | not' >/dev/null \
  || { echo "lock fixture failed: expired lock wrongly blocks"; echo "$OUT"; exit 1; }
jq -e '.session_id == "session-new"' "$PROJECT/openspec/.specnav/session-lock" >/dev/null \
  || { echo "lock fixture failed: expired lock not replaced"; exit 1; }
grep -q '"takeover":true' "$PROJECT/openspec/.specnav/events.jsonl" \
  || { echo "lock fixture failed: takeover not audited"; exit 1; }

# Case 4: no session id (e.g. host omits it) degrades gracefully — no lock,
# no blocker; single-writer protection is best-effort by design.
PROJECT="$TMP_DIR/no-id"
cp -R "$PROJECT_FIXTURE" "$PROJECT"
OUT="$(printf '{"hook_event_name":"SessionStart"}' | PROJECT_DIR="$PROJECT" env -u CLAUDE_SESSION_ID node "$CORE/scripts/specnav-session-start.js")"
echo "$OUT" | jq -e '.session_lock == "no-session-id"' >/dev/null \
  || { echo "lock fixture failed: expected no-session-id"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '(.blockers // []) | index("session-lock:held-by-other") | not' >/dev/null \
  || { echo "lock fixture failed: no-id session wrongly blocked"; echo "$OUT"; exit 1; }

echo "specnav session-lock fixtures ok"
