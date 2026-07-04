#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
PROTO="$ROOT/plugins/specnav-prototype"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

# Case 1: risk-tier now emits lane + reason + escalation threshold.
OUT="$(node "$CORE/scripts/risk-tier.js" --paths docs/readme.md)"
echo "$OUT" | jq -e '.tier == "lite" and .lane == "light" and .escalation_threshold == 10 and (.reason | length > 0)' >/dev/null \
  || { echo "lane fixture failed: lite classification"; echo "$OUT"; exit 1; }
OUT="$(node "$CORE/scripts/risk-tier.js" --paths src/ui/button.tsx)"
echo "$OUT" | jq -e '.tier == "standard" and .lane == "standard"' >/dev/null \
  || { echo "lane fixture failed: standard classification"; echo "$OUT"; exit 1; }
OUT="$(node "$CORE/scripts/risk-tier.js" --paths src/auth/login.ts)"
echo "$OUT" | jq -e '.tier == "high-risk" and .lane == "full"' >/dev/null \
  || { echo "lane fixture failed: full classification"; echo "$OUT"; exit 1; }

# Case 2: readLane defaults to standard when risk-tier.json is absent or bad.
CHANGE="$TMP_DIR/change"
mkdir -p "$CHANGE"
OUT="$(node -e "const lib=require('$CORE/scripts/specnav-lib');console.log(JSON.stringify(lib.readLane('$CHANGE')))")"
echo "$OUT" | jq -e '.lane == "standard" and .source == "default"' >/dev/null \
  || { echo "lane fixture failed: default lane"; echo "$OUT"; exit 1; }
printf 'not-json' >"$CHANGE/risk-tier.json"
OUT="$(node -e "const lib=require('$CORE/scripts/specnav-lib');console.log(JSON.stringify(lib.readLane('$CHANGE')))")"
echo "$OUT" | jq -e '.lane == "standard"' >/dev/null \
  || { echo "lane fixture failed: malformed defaults to standard"; echo "$OUT"; exit 1; }

# Case 3: light lane accepts a not_required prototype decision with reason;
# standard lane rejects the same decision (existing blocker preserved).
# Reuse the prototype suite's requirements-project builder for a valid base.
python3 - "$ROOT/tests/run-prototype-plugin-fixtures.sh" "$TMP_DIR/helpers.sh" <<'PY'
import sys, re
src = open(sys.argv[1]).read()
lines = src.split('\n')
start = next(i for i, l in enumerate(lines) if l.startswith('write_requirements_project() {'))
end = next(i for i, l in enumerate(lines) if l.startswith('write_ui_prototype() {'))
open(sys.argv[2], 'w').write('\n'.join(lines[start:end]) + '\n')
PY
# shellcheck disable=SC1090
source "$TMP_DIR/helpers.sh"
WORK="$TMP_DIR/proto-light"
C="add-dashboard"
write_requirements_project "$WORK"
CHANGE_DIR="$WORK/openspec/changes/$C"
mkdir -p "$CHANGE_DIR/prototype"
cat >"$CHANGE_DIR/prototype/decision.json" <<'JSON'
{"status":"not_required","reason":"docs and CI config only; nothing runnable to prototype"}
JSON
cat >"$CHANGE_DIR/risk-tier.json" <<'JSON'
{"tier":"lite","lane":"light","source":"path-heuristic","escalation_threshold":10}
JSON
set +e
PROJECT_DIR="$WORK" SPECNAV_CHANGE="$C" SPECNAV_DISABLE_OPENSPEC=1 \
  node "$PROTO/scripts/prototype-contract.js" --json >"$TMP_DIR/proto-light.json" 2>/dev/null
LIGHT_STATUS=$?
set -e
jq -e '(.blockers // []) | map(select(startswith("invalid-prototype-decision-status"))) | length == 0' "$TMP_DIR/proto-light.json" >/dev/null \
  || { echo "lane fixture failed: light lane rejected not_required"; jq '.blockers' "$TMP_DIR/proto-light.json"; exit 1; }

# Same project forced to standard lane: not_required must be a named blocker.
cat >"$CHANGE_DIR/risk-tier.json" <<'JSON'
{"tier":"standard","lane":"standard","source":"path-heuristic","escalation_threshold":10}
JSON
set +e
PROJECT_DIR="$WORK" SPECNAV_CHANGE="$C" SPECNAV_DISABLE_OPENSPEC=1 \
  node "$PROTO/scripts/prototype-contract.js" --json >"$TMP_DIR/proto-std.json" 2>/dev/null
set -e
jq -e '.blockers | index("invalid-prototype-decision-status:not_required")' "$TMP_DIR/proto-std.json" >/dev/null \
  || { echo "lane fixture failed: standard lane accepted not_required"; jq '.blockers' "$TMP_DIR/proto-std.json"; exit 1; }

echo "specnav lane-routing fixtures ok"
