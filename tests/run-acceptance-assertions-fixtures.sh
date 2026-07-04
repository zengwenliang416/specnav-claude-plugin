#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

lib_call() {
  local change_dir="$1" fn="$2"
  node -e "
const lib = require('$CORE/scripts/specnav-lib');
const result = lib.$fn('$change_dir');
console.log(JSON.stringify(result));
"
}

CHANGE="$TMP_DIR/change"
mkdir -p "$CHANGE"

# Case 1: absent acceptance.json is not blocking (legacy changes).
OUT="$(lib_call "$CHANGE" readAcceptanceAssertions)"
echo "$OUT" | jq -e '.present == false and .ok == true' >/dev/null \
  || { echo "acceptance fixture failed: absent should be ok"; echo "$OUT"; exit 1; }

# Case 2: valid assertion list parses; passing requires evidence_ref.
cat >"$CHANGE/acceptance.json" <<'JSON'
{"schema_version":1,"change_id":"c","assertions":[
  {"id":"A1","statement":"user can log in","verify_via":"e2e","status":"failing","evidence_ref":null},
  {"id":"A2","statement":"schema validated","verify_via":"static","status":"passing","evidence_ref":"verify/static/report.json"}
]}
JSON
OUT="$(lib_call "$CHANGE" readAcceptanceAssertions)"
echo "$OUT" | jq -e '.ok == true and (.assertions | length == 2)' >/dev/null \
  || { echo "acceptance fixture failed: valid list rejected"; echo "$OUT"; exit 1; }

# Case 3: passing without evidence is a named blocker.
cat >"$CHANGE/acceptance.json" <<'JSON'
{"assertions":[{"id":"A1","statement":"s","verify_via":"unit","status":"passing","evidence_ref":null}]}
JSON
OUT="$(lib_call "$CHANGE" readAcceptanceAssertions)"
echo "$OUT" | jq -e '.ok == false and (.blockers | index("acceptance-json:passing-without-evidence:A1"))' >/dev/null \
  || { echo "acceptance fixture failed: evidence-less pass allowed"; echo "$OUT"; exit 1; }

# Case 4: invalid verify_via / status / duplicate ids are named blockers.
cat >"$CHANGE/acceptance.json" <<'JSON'
{"assertions":[
  {"id":"A1","statement":"s","verify_via":"vibes","status":"failing"},
  {"id":"A1","statement":"s2","verify_via":"unit","status":"maybe"}
]}
JSON
OUT="$(lib_call "$CHANGE" readAcceptanceAssertions)"
echo "$OUT" | jq -e '.blockers | index("acceptance-json:invalid-verify-via:A1")' >/dev/null \
  || { echo "acceptance fixture failed: bad verify_via missed"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.blockers | index("acceptance-json:duplicate-id:A1")' >/dev/null \
  || { echo "acceptance fixture failed: duplicate id missed"; echo "$OUT"; exit 1; }
echo "$OUT" | jq -e '.blockers | index("acceptance-json:invalid-status:A1")' >/dev/null \
  || { echo "acceptance fixture failed: bad status missed"; echo "$OUT"; exit 1; }

# Case 5: digest freezes identity (id+statement+verify_via) but not status.
DIGEST_BEFORE="$(node -e "
const lib = require('$CORE/scripts/specnav-lib');
console.log(lib.acceptanceAssertionsDigest([
  {id:'A1',statement:'s',verify_via:'unit',status:'failing'},
  {id:'A2',statement:'t',verify_via:'e2e',status:'failing'}
]));
")"
DIGEST_STATUS_FLIP="$(node -e "
const lib = require('$CORE/scripts/specnav-lib');
console.log(lib.acceptanceAssertionsDigest([
  {id:'A1',statement:'s',verify_via:'unit',status:'passing',evidence_ref:'x'},
  {id:'A2',statement:'t',verify_via:'e2e',status:'failing'}
]));
")"
DIGEST_REWORDED="$(node -e "
const lib = require('$CORE/scripts/specnav-lib');
console.log(lib.acceptanceAssertionsDigest([
  {id:'A1',statement:'s REWORDED',verify_via:'unit',status:'failing'},
  {id:'A2',statement:'t',verify_via:'e2e',status:'failing'}
]));
")"
[[ "$DIGEST_BEFORE" == "$DIGEST_STATUS_FLIP" ]] \
  || { echo "acceptance fixture failed: status flip changed digest"; exit 1; }
[[ "$DIGEST_BEFORE" != "$DIGEST_REWORDED" ]] \
  || { echo "acceptance fixture failed: reword did not change digest"; exit 1; }

# Case 6 (integration): development contract freezes the assertion set.
DEVEL="$ROOT/plugins/specnav-development"
node -e "
const fs = require('fs');
const path = require('path');
const os = require('os');
const lib = require('$CORE/scripts/specnav-lib');
const changeDir = fs.mkdtempSync(path.join(os.tmpdir(), 'acc-freeze-'));
fs.mkdirSync(path.join(changeDir, 'development'), { recursive: true });
const write = (assertions) => fs.writeFileSync(path.join(changeDir, 'acceptance.json'), JSON.stringify({assertions}));
// Exercise the freeze via digest + freeze file semantics (mirrors
// validateAcceptanceAssertions logic without needing a full change tree).
write([{id:'A1',statement:'s',verify_via:'unit',status:'failing'}]);
let acc = lib.readAcceptanceAssertions(changeDir);
const digest1 = lib.acceptanceAssertionsDigest(acc.assertions);
// status flip keeps digest
write([{id:'A1',statement:'s',verify_via:'unit',status:'passing',evidence_ref:'e'}]);
acc = lib.readAcceptanceAssertions(changeDir);
if (lib.acceptanceAssertionsDigest(acc.assertions) !== digest1) { console.error('flip changed digest'); process.exit(1); }
// mutation changes digest -> would trip acceptance:assertions-mutated
write([{id:'A1',statement:'weakened statement',verify_via:'unit',status:'passing',evidence_ref:'e'}]);
acc = lib.readAcceptanceAssertions(changeDir);
if (lib.acceptanceAssertionsDigest(acc.assertions) === digest1) { console.error('mutation kept digest'); process.exit(1); }
console.log('freeze semantics ok');
" || { echo "acceptance fixture failed: freeze integration"; exit 1; }

echo "specnav acceptance-assertions fixtures ok"
