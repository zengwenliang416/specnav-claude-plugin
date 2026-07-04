#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

PROJECT="$TMP_DIR/project"
mkdir -p "$PROJECT/openspec/.specnav"

# Constructed sample: scope fires 6 times with 4 overrides (wrong gate);
# dangerous-command fires 6 times, 0 overrides (healthy); one warn gate;
# an allow followed by a red verify (false-negative signal).
cat >"$PROJECT/openspec/.specnav/events.jsonl" <<'JSONL'
{"ts":"2026-07-01T00:00:00Z","type":"hook.deny","payload":{"reason":"scope","path":"a.ts"}}
{"ts":"2026-07-01T00:01:00Z","type":"hook.override","payload":{"gate":"scope","affected_path":"a.ts"}}
{"ts":"2026-07-01T00:02:00Z","type":"hook.deny","payload":{"reason":"scope","path":"b.ts"}}
{"ts":"2026-07-01T00:03:00Z","type":"hook.override","payload":{"gate":"scope","affected_path":"b.ts"}}
{"ts":"2026-07-01T00:04:00Z","type":"hook.deny","payload":{"reason":"scope","path":"c.ts"}}
{"ts":"2026-07-01T00:05:00Z","type":"hook.override","payload":{"gate":"scope","affected_path":"c.ts"}}
{"ts":"2026-07-01T00:06:00Z","type":"hook.deny","payload":{"reason":"scope","path":"d.ts"}}
{"ts":"2026-07-01T00:07:00Z","type":"hook.override","payload":{"gate":"scope","affected_path":"d.ts"}}
{"ts":"2026-07-01T00:08:00Z","type":"hook.deny","payload":{"reason":"scope","path":"e.ts"}}
{"ts":"2026-07-01T00:09:00Z","type":"hook.deny","payload":{"reason":"scope","path":"f.ts"}}
{"ts":"2026-07-01T01:00:00Z","type":"hook.deny","payload":{"reason":"dangerous-command"}}
{"ts":"2026-07-01T01:01:00Z","type":"hook.deny","payload":{"reason":"dangerous-command"}}
{"ts":"2026-07-01T01:02:00Z","type":"hook.deny","payload":{"reason":"dangerous-command"}}
{"ts":"2026-07-01T01:03:00Z","type":"hook.deny","payload":{"reason":"dangerous-command"}}
{"ts":"2026-07-01T01:04:00Z","type":"hook.deny","payload":{"reason":"dangerous-command"}}
{"ts":"2026-07-01T01:05:00Z","type":"hook.deny","payload":{"reason":"dangerous-command"}}
{"ts":"2026-07-01T02:00:00Z","type":"hook.warn","payload":{"reason":"requires-review"}}
{"ts":"2026-07-01T03:00:00Z","type":"hook.allow","payload":{"reason":"within-scope"}}
{"ts":"2026-07-01T03:10:00Z","type":"verify","payload":{"status":"red","active_change":"c"}}
JSONL

OUT="$(PROJECT_DIR="$PROJECT" node "$CORE/scripts/gate-effectiveness.js" --json)"

# scope: 6 denies + 4 overrides -> override_rate 4/10 = 0.4 -> review-criteria
echo "$OUT" | jq -e '.gates[] | select(.gate == "scope") | .denies == 6 and .overrides == 4 and .override_rate == 0.4 and .signal == "review-criteria"' >/dev/null \
  || { echo "gate-eff fixture failed: scope row"; echo "$OUT" | jq '.gates'; exit 1; }

# dangerous-command: 6 denies, 0 overrides -> healthy
echo "$OUT" | jq -e '.gates[] | select(.gate == "dangerous-command") | .override_rate == 0 and .signal == "healthy"' >/dev/null \
  || { echo "gate-eff fixture failed: dangerous-command row"; exit 1; }

# requires-review: 1 warn, below sample -> insufficient-sample
echo "$OUT" | jq -e '.gates[] | select(.gate == "requires-review") | .signal == "insufficient-sample"' >/dev/null \
  || { echo "gate-eff fixture failed: warn row"; exit 1; }

# red-after-allow counter
echo "$OUT" | jq -e '.totals.red_verifies_after_allows == 1' >/dev/null \
  || { echo "gate-eff fixture failed: red-after-allow"; exit 1; }

# markdown output renders
MD="$(PROJECT_DIR="$PROJECT" node "$CORE/scripts/gate-effectiveness.js")"
echo "$MD" | grep -q '| scope |' || { echo "gate-eff fixture failed: markdown"; exit 1; }

# Case: empty/missing events does not crash and flags insufficiency.
EMPTY="$TMP_DIR/empty"
mkdir -p "$EMPTY/openspec/.specnav"
OUT="$(PROJECT_DIR="$EMPTY" node "$CORE/scripts/gate-effectiveness.js" --json)"
echo "$OUT" | jq -e '.events_analyzed == 0 and (.gates | length == 0)' >/dev/null \
  || { echo "gate-eff fixture failed: empty events"; exit 1; }

echo "specnav gate-effectiveness fixtures ok"
