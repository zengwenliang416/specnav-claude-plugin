#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/specnav-core"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
PROJECT="$TMP_DIR/simple-project"
cp -R "$ROOT/tests/fixtures/simple-project" "$PROJECT"
PLUGINS=(specnav-core specnav-requirements specnav-prototype specnav-development specnav-verification specnav-operations specnav-codegraph)
for plugin in "${PLUGINS[@]}"; do
  jq -n \
    --arg id "$plugin@specnav-marketplace" \
    --arg installPath "$ROOT/plugins/$plugin" \
    '{id: $id, version: "0.4.0", scope: "user", enabled: true, installPath: $installPath}'
done | jq -s '.' >"$TMP_DIR/plugin-list.json"

PROJECT_DIR="$PROJECT" node "$CORE/scripts/workflow-state.js" --marketplace-root "$ROOT" --write --json >"$TMP_DIR/specnav-cross-state.json"
jq -e '.ok == true' "$TMP_DIR/specnav-cross-state.json" >/dev/null
jq -e '.plugin_suite.ok == true' "$TMP_DIR/specnav-cross-state.json" >/dev/null
jq -e '.plugin_suite.plugins[] | select(.name == "specnav-core")' "$TMP_DIR/specnav-cross-state.json" >/dev/null
jq -e '.plugin_suite.plugins[] | select(.name == "specnav-requirements")' "$TMP_DIR/specnav-cross-state.json" >/dev/null
test -f "$PROJECT/openspec/.specnav/workflow-state.json"
test -s "$PROJECT/openspec/.specnav/context/requirements-context.jsonl"
test -s "$PROJECT/openspec/.specnav/context/prototype-context.jsonl"
test -s "$PROJECT/openspec/.specnav/context/implement-context.jsonl"
test -s "$PROJECT/openspec/.specnav/context/verify-context.jsonl"
test -s "$PROJECT/openspec/.specnav/context/ops-context.jsonl"
test -f "$PROJECT/openspec/.specnav/journal/index.md"

PROJECT_DIR="$PROJECT" node "$CORE/scripts/affordances.js" --json >"$TMP_DIR/specnav-cross-affordances.json"
jq -e '.required_plugins[] | select(. == "specnav-core")' "$TMP_DIR/specnav-cross-affordances.json" >/dev/null
jq -e '.required_plugins[] | select(. == "specnav-verification")' "$TMP_DIR/specnav-cross-affordances.json" >/dev/null
jq -e '.actions[] | select(.id == "archive") | .required_plugins[] | select(. == "specnav-operations")' "$TMP_DIR/specnav-cross-affordances.json" >/dev/null

SPECNAV_PLUGIN_LIST_JSON="$(cat "$TMP_DIR/plugin-list.json")" node "$CORE/scripts/specnav-doctor.js" --marketplace-root "$ROOT" --json >"$TMP_DIR/specnav-cross-doctor.json"
jq -e '.ok == true' "$TMP_DIR/specnav-cross-doctor.json" >/dev/null
jq -e '.suite.ok == true' "$TMP_DIR/specnav-cross-doctor.json" >/dev/null
jq -e '.suite.plugins | length == 7' "$TMP_DIR/specnav-cross-doctor.json" >/dev/null

SPECNAV_PLUGIN_LIST_JSON="$(cat "$TMP_DIR/plugin-list.json")" PROJECT_DIR="$PROJECT" node "$CORE/scripts/specnav-doctor.js" --marketplace-root "$ROOT" --json >"$TMP_DIR/specnav-cross-project-doctor.json"
jq -e '.ok == true' "$TMP_DIR/specnav-cross-project-doctor.json" >/dev/null
jq -e '.checks[] | select(.name == "context-manifests" and .ok == true)' "$TMP_DIR/specnav-cross-project-doctor.json" >/dev/null
jq -e '.checks[] | select(.name == "journal" and .ok == true)' "$TMP_DIR/specnav-cross-project-doctor.json" >/dev/null

echo "specnav cross-plugin state fixtures ok"
