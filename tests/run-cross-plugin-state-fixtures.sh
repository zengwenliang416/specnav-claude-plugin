#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/plugins/helm-core"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
PROJECT="$TMP_DIR/simple-project"
cp -R "$ROOT/tests/fixtures/simple-project" "$PROJECT"

PROJECT_DIR="$PROJECT" node "$CORE/scripts/workflow-state.js" --marketplace-root "$ROOT" --write --json >"$TMP_DIR/helm-cross-state.json"
jq -e '.ok == true' "$TMP_DIR/helm-cross-state.json" >/dev/null
jq -e '.plugin_suite.ok == true' "$TMP_DIR/helm-cross-state.json" >/dev/null
jq -e '.plugin_suite.plugins[] | select(.name == "helm-core")' "$TMP_DIR/helm-cross-state.json" >/dev/null
jq -e '.plugin_suite.plugins[] | select(.name == "helm-requirements")' "$TMP_DIR/helm-cross-state.json" >/dev/null
test -f "$PROJECT/openspec/.helm/workflow-state.json"
test -s "$PROJECT/openspec/.helm/context/requirements-context.jsonl"
test -s "$PROJECT/openspec/.helm/context/prototype-context.jsonl"
test -s "$PROJECT/openspec/.helm/context/implement-context.jsonl"
test -s "$PROJECT/openspec/.helm/context/verify-context.jsonl"
test -s "$PROJECT/openspec/.helm/context/ops-context.jsonl"
test -f "$PROJECT/openspec/.helm/journal/index.md"

PROJECT_DIR="$PROJECT" node "$CORE/scripts/affordances.js" --json >"$TMP_DIR/helm-cross-affordances.json"
jq -e '.required_plugins[] | select(. == "helm-core")' "$TMP_DIR/helm-cross-affordances.json" >/dev/null
jq -e '.required_plugins[] | select(. == "helm-verification")' "$TMP_DIR/helm-cross-affordances.json" >/dev/null
jq -e '.actions[] | select(.id == "archive") | .required_plugins[] | select(. == "helm-operations")' "$TMP_DIR/helm-cross-affordances.json" >/dev/null

node "$CORE/scripts/helm-doctor.js" --marketplace-root "$ROOT" --json >"$TMP_DIR/helm-cross-doctor.json"
jq -e '.ok == true' "$TMP_DIR/helm-cross-doctor.json" >/dev/null
jq -e '.suite.ok == true' "$TMP_DIR/helm-cross-doctor.json" >/dev/null
jq -e '.suite.plugins | length == 6' "$TMP_DIR/helm-cross-doctor.json" >/dev/null

PROJECT_DIR="$PROJECT" node "$CORE/scripts/helm-doctor.js" --marketplace-root "$ROOT" --json >"$TMP_DIR/helm-cross-project-doctor.json"
jq -e '.ok == true' "$TMP_DIR/helm-cross-project-doctor.json" >/dev/null
jq -e '.checks[] | select(.name == "context-manifests" and .ok == true)' "$TMP_DIR/helm-cross-project-doctor.json" >/dev/null
jq -e '.checks[] | select(.name == "journal" and .ok == true)' "$TMP_DIR/helm-cross-project-doctor.json" >/dev/null

echo "helm cross-plugin state fixtures ok"
