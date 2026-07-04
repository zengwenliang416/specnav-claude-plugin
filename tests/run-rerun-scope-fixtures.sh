#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERIF="$ROOT/plugins/specnav-verification"
PROJECT_FIXTURE="$ROOT/tests/fixtures/simple-project"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

make_project() {
  local project="$1"
  cp -R "$PROJECT_FIXTURE" "$project"
  mkdir -p "$project/openspec/changes/add-dark-mode/verify"
  cat >"$project/openspec/changes/add-dark-mode/verify/traceability-matrix.json" <<'JSON'
{
  "schema_version": 1,
  "change_id": "add-dark-mode",
  "entries": [
    {"changed_file":"src/ui/theme.ts","requirement_refs":["requirements.md#theme"],"task_refs":["t1"],"prototype_refs":["p"],"foundation_spec_refs":["f"],"verification_domains":["static","unit"]},
    {"changed_file":"src/ui/toggle.tsx","requirement_refs":["requirements.md#toggle"],"task_refs":["t2"],"prototype_refs":["p"],"foundation_spec_refs":["f"],"verification_domains":["unit","e2e","sensory"]}
  ],
  "unmapped_changes": []
}
JSON
}

runner() {
  local project="$1" files="$2" out="$3" expected="$4"
  set +e
  PROJECT_DIR="$project" SPECNAV_MARKETPLACE_ROOT="$ROOT" \
    node "$VERIF/scripts/rerun-scope.js" --files "$files" >"$out" 2>/dev/null
  local status=$?
  set -e
  [[ "$status" == "$expected" ]] \
    || { echo "rerun-scope fixture failed: expected exit $expected got $status"; cat "$out"; exit 1; }
}

# Case 1: single mapped file -> exactly its domains.
P="$TMP_DIR/single"
make_project "$P"
runner "$P" "src/ui/theme.ts" "$TMP_DIR/single.json" 0
jq -e '.domains_to_rerun == ["static","unit"] and .full_rerun == false' "$TMP_DIR/single.json" >/dev/null \
  || { echo "case1 failed"; cat "$TMP_DIR/single.json"; exit 1; }

# Case 2: multiple mapped files -> union of domains, sorted.
P="$TMP_DIR/multi"
make_project "$P"
runner "$P" "src/ui/theme.ts,src/ui/toggle.tsx" "$TMP_DIR/multi.json" 0
jq -e '.domains_to_rerun == ["e2e","sensory","static","unit"]' "$TMP_DIR/multi.json" >/dev/null \
  || { echo "case2 failed"; cat "$TMP_DIR/multi.json"; exit 1; }

# Case 3: unmapped file -> conservative full rerun + warning.
P="$TMP_DIR/unmapped"
make_project "$P"
runner "$P" "src/api/new-endpoint.ts" "$TMP_DIR/unmapped.json" 0
jq -e '.full_rerun == true and (.domains_to_rerun | length == 6)' "$TMP_DIR/unmapped.json" >/dev/null \
  || { echo "case3 failed"; cat "$TMP_DIR/unmapped.json"; exit 1; }
jq -e '.warnings[0] | test("unmapped-changes")' "$TMP_DIR/unmapped.json" >/dev/null \
  || { echo "case3 failed: warning missing"; exit 1; }

# Case 4: missing matrix -> blocked with full rerun fallback.
P="$TMP_DIR/no-matrix"
cp -R "$PROJECT_FIXTURE" "$P"
runner "$P" "src/ui/theme.ts" "$TMP_DIR/no-matrix.json" 2
jq -e '.blockers | index("missing-verify-artifact:traceability-matrix.json")' "$TMP_DIR/no-matrix.json" >/dev/null \
  || { echo "case4 failed"; cat "$TMP_DIR/no-matrix.json"; exit 1; }
jq -e '.domains_to_rerun | length == 6' "$TMP_DIR/no-matrix.json" >/dev/null \
  || { echo "case4 failed: fallback domains"; exit 1; }

# Case 5: openspec/ artifact edits are excluded from diff scope.
P="$TMP_DIR/openspec-only"
make_project "$P"
runner "$P" "src/ui/theme.ts" "$TMP_DIR/scoped.json" 0
jq -e '.changed_files == ["src/ui/theme.ts"]' "$TMP_DIR/scoped.json" >/dev/null \
  || { echo "case5 failed"; cat "$TMP_DIR/scoped.json"; exit 1; }

echo "specnav rerun-scope fixtures ok"
