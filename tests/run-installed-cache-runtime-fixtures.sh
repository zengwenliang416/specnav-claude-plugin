#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CACHE="$TMP_DIR/.claude/plugins/cache/specnav-marketplace"
VERSION="9.9.9"
PROJECT="$TMP_DIR/project"
PLUGINS=(specnav-core specnav-requirements specnav-prototype specnav-development specnav-verification specnav-operations specnav-codegraph)

mkdir -p "$CACHE"
cp -R "$ROOT/tests/fixtures/simple-project/." "$PROJECT/"

for plugin in "${PLUGINS[@]}"; do
  mkdir -p "$CACHE/$plugin"
  cp -R "$ROOT/plugins/$plugin" "$CACHE/$plugin/$VERSION"
done

for plugin in "${PLUGINS[@]}"; do
  jq -n \
    --arg id "$plugin@specnav-marketplace" \
    --arg installPath "$CACHE/$plugin/$VERSION" \
    '{id: $id, version: "9.9.9", scope: "user", enabled: true, installPath: $installPath}'
done | jq -s '.' >"$TMP_DIR/plugin-list.json"

export HOME="$TMP_DIR"
export SPECNAV_MARKETPLACE_ROOT="$CACHE"
export SPECNAV_PLUGIN_LIST_JSON
SPECNAV_PLUGIN_LIST_JSON="$(cat "$TMP_DIR/plugin-list.json")"

CORE="$CACHE/specnav-core/$VERSION"
REQ="$CACHE/specnav-requirements/$VERSION"
PROTO="$CACHE/specnav-prototype/$VERSION"
DEV="$CACHE/specnav-development/$VERSION"
VERIFY="$CACHE/specnav-verification/$VERSION"
OPS="$CACHE/specnav-operations/$VERSION"
CODEGRAPH="$CACHE/specnav-codegraph/$VERSION"
export CORE REQ PROTO DEV VERIFY OPS CODEGRAPH VERSION

resolve_runtime_json="$TMP_DIR/resolve-runtime.json"
node "$CORE/scripts/resolve-runtime.js" resolve --plugin specnav-core --plugin specnav-requirements --json >"$resolve_runtime_json"
jq -e '.ok == true' "$resolve_runtime_json" >/dev/null
jq -e '.marketplace_root == env.SPECNAV_MARKETPLACE_ROOT' "$resolve_runtime_json" >/dev/null
jq -e '.plugins | length == 2' "$resolve_runtime_json" >/dev/null
jq -e '.plugins[] | select(.name == "specnav-core" and .root == env.CORE and .env == "SPECNAV_CORE_ROOT" and .version == env.VERSION)' "$resolve_runtime_json" >/dev/null
jq -e '.plugins[] | select(.name == "specnav-requirements" and .root == env.REQ and .env == "SPECNAV_REQUIREMENTS_ROOT" and .version == env.VERSION)' "$resolve_runtime_json" >/dev/null

resolve_runtime_env_json="$TMP_DIR/resolve-runtime-env.json"
node "$CORE/scripts/resolve-runtime.js" env --plugin specnav-core --plugin specnav-verification --shell --json >"$resolve_runtime_env_json"
jq -e '.ok == true' "$resolve_runtime_env_json" >/dev/null
jq -e '.shell | contains("SPECNAV_MARKETPLACE_ROOT=")' "$resolve_runtime_env_json" >/dev/null
jq -e '.shell | contains("SPECNAV_CORE_ROOT=")' "$resolve_runtime_env_json" >/dev/null
jq -e '.shell | contains("SPECNAV_VERIFICATION_ROOT=")' "$resolve_runtime_env_json" >/dev/null

(
  unset SPECNAV_MARKETPLACE_ROOT
  unset SPECNAV_CORE_ROOT SPECNAV_REQUIREMENTS_ROOT SPECNAV_PROTOTYPE_ROOT SPECNAV_DEVELOPMENT_ROOT SPECNAV_VERIFICATION_ROOT SPECNAV_OPERATIONS_ROOT
  node <<'NODE'
const scripts = [
  `${process.env.DEV}/scripts/development-contract.js`,
  `${process.env.VERIFY}/scripts/verify-domains.js`,
  `${process.env.OPS}/scripts/operations-gate.js`
];
for (const file of scripts) require(file);
NODE
)

node <<'NODE'
const scripts = [
  [`${process.env.REQ}/scripts/requirements-contract.js`, 'validateRequirements'],
  [`${process.env.REQ}/scripts/foundation-specs.js`, 'validateFoundationSpecs'],
  [`${process.env.PROTO}/scripts/prototype-contract.js`, 'validatePrototype'],
  [`${process.env.DEV}/scripts/development-contract.js`, 'validateDevelopment'],
  [`${process.env.VERIFY}/scripts/verify-domains.js`, 'validateVerify'],
  [`${process.env.OPS}/scripts/operations-gate.js`, 'validateOperations'],
  [`${process.env.CORE}/scripts/verify.js`, 'verify']
];
for (const [file, exportName] of scripts) {
  const mod = require(file);
  if (typeof mod[exportName] !== 'function') {
    throw new Error(`missing export \${exportName} from \${file}`);
  }
}
NODE

run_blocking_contract() {
  local name="$1"
  local output="$2"
  shift 2

  set +e
  PROJECT_DIR="$PROJECT" "$@" --json >"$output" 2>"$output.err"
  local status=$?
  set -e

  if [ "$status" -eq 1 ]; then
    echo "$name exited 1; expected successful load plus contract status 0 or 2" >&2
    cat "$output" >&2 || true
    cat "$output.err" >&2 || true
    exit 1
  fi
  if grep -R "MODULE_NOT_FOUND\\|Cannot find module" "$output" "$output.err" >/dev/null 2>&1; then
    echo "$name still has module resolution failure" >&2
    cat "$output" >&2 || true
    cat "$output.err" >&2 || true
    exit 1
  fi
}

run_blocking_contract requirements "$TMP_DIR/requirements.json" node "$REQ/scripts/requirements-contract.js"
run_blocking_contract prototype "$TMP_DIR/prototype.json" node "$PROTO/scripts/prototype-contract.js"
run_blocking_contract development "$TMP_DIR/development.json" node "$DEV/scripts/development-contract.js" --mode handoff
run_blocking_contract verification "$TMP_DIR/verification.json" node "$VERIFY/scripts/verify-domains.js" validate
run_blocking_contract operations "$TMP_DIR/operations.json" node "$OPS/scripts/operations-gate.js"

for script in \
  "$CORE/scripts/tasks-md.js" \
  "$REQ/skills/specnav-foundation-specs/scripts/create-foundation-specs.js" \
  "$REQ/skills/specnav-requirements/scripts/create-requirements-artifacts.js" \
  "$PROTO/skills/specnav-prototype/scripts/create-prototype.js" \
  "$DEV/skills/specnav-development-entry/scripts/create-development-entry.js" \
  "$DEV/skills/specnav-scope-lock/scripts/create-scope-lock.js" \
  "$DEV/skills/specnav-vertical-slices/scripts/create-vertical-slice.js" \
  "$CODEGRAPH/scripts/codegraph-plan.js" \
  "$VERIFY/skills/specnav-verify-plan/scripts/create-verify-plan.js" \
  "$OPS/skills/specnav-ops-readiness/scripts/create-readiness.js" \
  "$OPS/skills/specnav-release-plan/scripts/create-release-plan.js"; do
  node "$script" --help >/dev/null
done

echo "specnav installed-cache runtime fixtures ok"
