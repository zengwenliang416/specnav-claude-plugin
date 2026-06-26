#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CACHE="$TMP_DIR/.claude/plugins/cache/helm-marketplace"
VERSION="9.9.9"
PROJECT="$TMP_DIR/project"
PLUGINS=(helm-core helm-requirements helm-prototype helm-development helm-verification helm-operations)

mkdir -p "$CACHE"
cp -R "$ROOT/tests/fixtures/simple-project/." "$PROJECT/"

for plugin in "${PLUGINS[@]}"; do
  mkdir -p "$CACHE/$plugin"
  cp -R "$ROOT/plugins/$plugin" "$CACHE/$plugin/$VERSION"
done

for plugin in "${PLUGINS[@]}"; do
  jq -n \
    --arg id "$plugin@helm-marketplace" \
    --arg installPath "$CACHE/$plugin/$VERSION" \
    '{id: $id, version: "9.9.9", scope: "user", enabled: true, installPath: $installPath}'
done | jq -s '.' >"$TMP_DIR/plugin-list.json"

export HOME="$TMP_DIR"
export HELM_MARKETPLACE_ROOT="$CACHE"
export HELM_PLUGIN_LIST_JSON
HELM_PLUGIN_LIST_JSON="$(cat "$TMP_DIR/plugin-list.json")"

CORE="$CACHE/helm-core/$VERSION"
REQ="$CACHE/helm-requirements/$VERSION"
PROTO="$CACHE/helm-prototype/$VERSION"
DEV="$CACHE/helm-development/$VERSION"
VERIFY="$CACHE/helm-verification/$VERSION"
OPS="$CACHE/helm-operations/$VERSION"
export CORE REQ PROTO DEV VERIFY OPS VERSION

resolve_runtime_json="$TMP_DIR/resolve-runtime.json"
node "$CORE/scripts/resolve-runtime.js" resolve --plugin helm-core --plugin helm-requirements --json >"$resolve_runtime_json"
jq -e '.ok == true' "$resolve_runtime_json" >/dev/null
jq -e '.marketplace_root == env.HELM_MARKETPLACE_ROOT' "$resolve_runtime_json" >/dev/null
jq -e '.plugins | length == 2' "$resolve_runtime_json" >/dev/null
jq -e '.plugins[] | select(.name == "helm-core" and .root == env.CORE and .env == "HELM_CORE_ROOT" and .version == env.VERSION)' "$resolve_runtime_json" >/dev/null
jq -e '.plugins[] | select(.name == "helm-requirements" and .root == env.REQ and .env == "HELM_REQUIREMENTS_ROOT" and .version == env.VERSION)' "$resolve_runtime_json" >/dev/null

resolve_runtime_env_json="$TMP_DIR/resolve-runtime-env.json"
node "$CORE/scripts/resolve-runtime.js" env --plugin helm-core --plugin helm-verification --shell --json >"$resolve_runtime_env_json"
jq -e '.ok == true' "$resolve_runtime_env_json" >/dev/null
jq -e '.shell | contains("HELM_MARKETPLACE_ROOT=")' "$resolve_runtime_env_json" >/dev/null
jq -e '.shell | contains("HELM_CORE_ROOT=")' "$resolve_runtime_env_json" >/dev/null
jq -e '.shell | contains("HELM_VERIFICATION_ROOT=")' "$resolve_runtime_env_json" >/dev/null

(
  unset HELM_MARKETPLACE_ROOT
  unset HELM_CORE_ROOT HELM_REQUIREMENTS_ROOT HELM_PROTOTYPE_ROOT HELM_DEVELOPMENT_ROOT HELM_VERIFICATION_ROOT HELM_OPERATIONS_ROOT
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
  "$REQ/skills/helm-foundation-specs/scripts/create-foundation-specs.js" \
  "$REQ/skills/helm-requirements/scripts/create-requirements-artifacts.js" \
  "$PROTO/skills/helm-prototype/scripts/create-prototype.js" \
  "$DEV/skills/helm-development-entry/scripts/create-development-entry.js" \
  "$DEV/skills/helm-scope-lock/scripts/create-scope-lock.js" \
  "$DEV/skills/helm-vertical-slices/scripts/create-vertical-slice.js" \
  "$VERIFY/skills/helm-verify-plan/scripts/create-verify-plan.js" \
  "$OPS/skills/helm-ops-readiness/scripts/create-readiness.js" \
  "$OPS/skills/helm-release-plan/scripts/create-release-plan.js"; do
  node "$script" --help >/dev/null
done

echo "helm installed-cache runtime fixtures ok"
