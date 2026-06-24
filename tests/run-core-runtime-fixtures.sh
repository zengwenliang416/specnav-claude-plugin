#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/helm-core"
PROJECT="$ROOT/tests/fixtures/simple-project"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
EXTERNAL_PROJECT="$TMP_DIR/external-project"
mkdir -p "$EXTERNAL_PROJECT"

assert_grep() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if ! grep -q -- "$pattern" "$file"; then
    echo "$message" >&2
    exit 1
  fi
}

assert_grep_fixed() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if ! grep -Fq -- "$pattern" "$file"; then
    echo "$message" >&2
    exit 1
  fi
}

assert_jq() {
  local expression="$1"
  local file="$2"
  local message="$3"

  if ! jq -e "$expression" "$file" >/dev/null; then
    echo "$message" >&2
    exit 1
  fi
}

assert_grep 'helm-core/scripts/helm-session-start.js\|CLAUDE_PLUGIN_ROOT/scripts/helm-session-start.js' "$CORE/hooks/hooks.json" "session-start hook does not reference the helm core runtime"
assert_grep 'plugin-suite.js' "$CORE/commands/helm.md" "helm command does not reference plugin-suite.js"
assert_grep 'workflow-state.js' "$CORE/commands/helm-status.md" "helm-status command does not reference workflow-state.js"
assert_grep 'helm-doctor.js' "$CORE/commands/helm-doctor.md" "helm-doctor command does not reference helm-doctor.js"
assert_grep 'helm-requirements' "$CORE/skills/helm-router/SKILL.md" "helm router does not mention helm-requirements"
assert_grep 'helm-verification' "$CORE/skills/helm-router/SKILL.md" "helm router does not mention helm-verification"
assert_grep 'helm-operations' "$CORE/skills/helm-router/SKILL.md" "helm router does not mention helm-operations"
assert_grep_fixed '--marketplace-root "$CLAUDE_PLUGIN_ROOT/../.."' "$CORE/commands/helm.md" "helm command does not document cwd-independent marketplace root"
assert_grep_fixed '--plugin helm-core --plugin <target-plugin>' "$CORE/commands/helm.md" "helm command does not document core plus target plugin require"
assert_grep_fixed '--marketplace-root "$CLAUDE_PLUGIN_ROOT/../.."' "$CORE/skills/helm-router/SKILL.md" "helm router does not document cwd-independent marketplace root"
assert_grep_fixed '--plugin helm-core --plugin <target-plugin>' "$CORE/skills/helm-router/SKILL.md" "helm router does not document core plus target plugin require"

suite_json="$TMP_DIR/plugin-suite-require.json"
suite_status=0
(
  cd "$EXTERNAL_PROJECT"
  export CLAUDE_PLUGIN_ROOT="$CORE"
  node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --json >"$suite_json"
) || suite_status=$?
if [ "$suite_status" -ne 0 ]; then
  echo "plugin-suite require failed from external project cwd with exit $suite_status" >&2
  exit 1
fi
assert_jq '.ok == true' "$suite_json" "plugin-suite require did not return ok true"
assert_jq '.plugins[] | select(.name == "helm-core" and .ok == true)' "$suite_json" "plugin-suite require did not include ok helm-core plugin"

suite_missing_root_json="$TMP_DIR/plugin-suite-require-missing-root.json"
suite_missing_root_status=0
(
  cd "$EXTERNAL_PROJECT"
  export CLAUDE_PLUGIN_ROOT="$CORE"
  node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --plugin helm-core --json >"$suite_missing_root_json"
) || suite_missing_root_status=$?
if [ "$suite_missing_root_status" -ne 2 ]; then
  echo "plugin-suite require without marketplace root exited $suite_missing_root_status, expected 2" >&2
  exit 1
fi
assert_jq '.blockers | index("missing-marketplace-json")' "$suite_missing_root_json" "plugin-suite require without marketplace root did not report missing marketplace"

workflow_state_json="$TMP_DIR/workflow-state.json"
workflow_state_status=0
node "$CORE/scripts/workflow-state.js" --json >"$workflow_state_json" || workflow_state_status=$?
if [ "$workflow_state_status" -ne 2 ]; then
  echo "workflow-state placeholder exited $workflow_state_status, expected 2" >&2
  exit 1
fi
assert_jq '.blockers | index("not-implemented:helm-core/workflow-state")' "$workflow_state_json" "workflow-state placeholder did not report not-implemented blocker"

doctor_json="$TMP_DIR/helm-doctor.json"
doctor_status=0
node "$CORE/scripts/helm-doctor.js" --json >"$doctor_json" || doctor_status=$?
if [ "$doctor_status" -ne 2 ]; then
  echo "helm-doctor placeholder exited $doctor_status, expected 2" >&2
  exit 1
fi
assert_jq '.blockers | index("not-implemented:helm-core/helm-doctor")' "$doctor_json" "helm-doctor placeholder did not report not-implemented blocker"

affordances_json="$TMP_DIR/helm-core-affordances.json"
PROJECT_DIR="$PROJECT" node "$CORE/scripts/affordances.js" --json >"$affordances_json"
assert_jq '.active_change == "add-dark-mode"' "$affordances_json" "affordances did not report active_change add-dark-mode"

echo "helm core runtime fixtures ok"
