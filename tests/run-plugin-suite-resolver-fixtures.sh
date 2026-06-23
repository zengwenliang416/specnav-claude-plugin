#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

run_failure() {
  local output="$1"
  shift

  set +e
  node "$ROOT/plugins/helm-core/scripts/plugin-suite.js" "$@" --json >"$output"
  local status=$?
  set -e

  [[ "$status" == "2" ]]
  jq -e '.ok == false' "$output" >/dev/null
}

node "$ROOT/plugins/helm-core/scripts/plugin-suite.js" list --marketplace-root "$ROOT" --json >/tmp/helm-suite-list.json
jq -e '.ok == true' /tmp/helm-suite-list.json >/dev/null
jq -e '.plugins | length == 6' /tmp/helm-suite-list.json >/dev/null
jq -e '.plugins[] | select(.name == "helm-core" and .stage == "core")' /tmp/helm-suite-list.json >/dev/null
jq -e '.plugins[] | select(.name == "helm-verification" and .stage == "verification")' /tmp/helm-suite-list.json >/dev/null

node "$ROOT/plugins/helm-core/scripts/plugin-suite.js" resolve --marketplace-root "$ROOT" --plugin helm-requirements --json >/tmp/helm-suite-requirements.json
jq -e '.ok == true' /tmp/helm-suite-requirements.json >/dev/null
jq -e '.plugin.name == "helm-requirements"' /tmp/helm-suite-requirements.json >/dev/null
jq -e '.plugin.stage == "requirements"' /tmp/helm-suite-requirements.json >/dev/null

node "$ROOT/plugins/helm-core/scripts/plugin-suite.js" require --marketplace-root "$ROOT" --plugin helm-core --plugin helm-requirements --json >/tmp/helm-suite-require.json
jq -e '.ok == true' /tmp/helm-suite-require.json >/dev/null

set +e
node "$ROOT/plugins/helm-core/scripts/plugin-suite.js" require --marketplace-root "$ROOT" --plugin helm-missing --json >/tmp/helm-suite-missing.json
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.ok == false' /tmp/helm-suite-missing.json >/dev/null
jq -e '.blockers[] | select(. == "missing-plugin:helm-missing")' /tmp/helm-suite-missing.json >/dev/null

run_failure "$tmp_dir/unknown-command.json" inspect --marketplace-root "$ROOT"
jq -e '.blockers[] | select(. == "unknown-command:inspect")' "$tmp_dir/unknown-command.json" >/dev/null

run_failure "$tmp_dir/resolve-missing-plugin.json" resolve --marketplace-root "$ROOT"
jq -e '.blockers[] | select(. == "missing-argument:--plugin")' "$tmp_dir/resolve-missing-plugin.json" >/dev/null

run_failure "$tmp_dir/require-missing-plugin.json" require --marketplace-root "$ROOT"
jq -e '.blockers[] | select(. == "missing-argument:--plugin")' "$tmp_dir/require-missing-plugin.json" >/dev/null

run_failure "$tmp_dir/list-missing-marketplace-root-value.json" list --marketplace-root
jq -e '.blockers[] | select(. == "missing-argument:--marketplace-root")' "$tmp_dir/list-missing-marketplace-root-value.json" >/dev/null

run_failure "$tmp_dir/resolve-flag-looking-plugin-value.json" resolve --plugin --marketplace-root "$ROOT"
jq -e '.blockers[] | select(. == "missing-argument:--plugin")' "$tmp_dir/resolve-flag-looking-plugin-value.json" >/dev/null

malformed_marketplace="$tmp_dir/malformed-marketplace"
mkdir -p "$malformed_marketplace/.claude-plugin"
printf '{ "plugins": [ ' >"$malformed_marketplace/.claude-plugin/marketplace.json"
run_failure "$tmp_dir/malformed-marketplace.json" list --marketplace-root "$malformed_marketplace"
jq -e '.blockers[] | select(. == "malformed-marketplace-json")' "$tmp_dir/malformed-marketplace.json" >/dev/null

invalid_plugin_entry="$tmp_dir/invalid-plugin-entry"
mkdir -p "$invalid_plugin_entry/.claude-plugin"
cat >"$invalid_plugin_entry/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "invalid-plugin-entry-fixture",
  "plugins": [
    null
  ]
}
JSON
run_failure "$tmp_dir/invalid-plugin-entry.json" list --marketplace-root "$invalid_plugin_entry"
jq -e '.blockers[] | select(. == "invalid-plugin-entry:0")' "$tmp_dir/invalid-plugin-entry.json" >/dev/null

missing_plugin_name="$tmp_dir/missing-plugin-name"
mkdir -p "$missing_plugin_name/.claude-plugin"
cat >"$missing_plugin_name/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "missing-plugin-name-fixture",
  "plugins": [
    {
      "source": "plugins/no-name",
      "version": "0.0.0"
    }
  ]
}
JSON
run_failure "$tmp_dir/missing-plugin-name.json" list --marketplace-root "$missing_plugin_name"
jq -e '.blockers[] | select(. == "missing-plugin-name:0")' "$tmp_dir/missing-plugin-name.json" >/dev/null

missing_plugin_source="$tmp_dir/missing-plugin-source"
mkdir -p "$missing_plugin_source/.claude-plugin"
cat >"$missing_plugin_source/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "missing-plugin-source-fixture",
  "plugins": [
    {
      "name": "no-source",
      "version": "0.0.0"
    }
  ]
}
JSON
run_failure "$tmp_dir/missing-plugin-source.json" list --marketplace-root "$missing_plugin_source"
jq -e '.blockers[] | select(. == "missing-plugin-source:no-source")' "$tmp_dir/missing-plugin-source.json" >/dev/null

source_outside="$tmp_dir/source-outside"
outside_plugin="$tmp_dir/outside-plugin"
mkdir -p "$source_outside/.claude-plugin" "$outside_plugin/.claude-plugin"
cat >"$source_outside/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "source-outside-fixture",
  "plugins": [
    {
      "name": "escape-plugin",
      "source": "../outside-plugin",
      "version": "0.0.0"
    }
  ]
}
JSON
cat >"$outside_plugin/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "escape-plugin",
  "version": "0.0.0"
}
JSON
cat >"$outside_plugin/helm-stage.json" <<'JSON'
{
  "plugin": "escape-plugin",
  "stage": "escape"
}
JSON
run_failure "$tmp_dir/source-outside.json" resolve --marketplace-root "$source_outside" --plugin escape-plugin
jq -e '.blockers[] | select(. == "plugin-source-outside-marketplace:escape-plugin")' "$tmp_dir/source-outside.json" >/dev/null
jq -e '.plugin.ok == false' "$tmp_dir/source-outside.json" >/dev/null

malformed_plugin_stage="$tmp_dir/malformed-plugin-stage"
mkdir -p \
  "$malformed_plugin_stage/.claude-plugin" \
  "$malformed_plugin_stage/plugins/bad-plugin-json/.claude-plugin" \
  "$malformed_plugin_stage/plugins/bad-stage-manifest/.claude-plugin"
cat >"$malformed_plugin_stage/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "malformed-plugin-stage-fixture",
  "plugins": [
    {
      "name": "bad-plugin-json",
      "source": "plugins/bad-plugin-json",
      "version": "0.0.0"
    },
    {
      "name": "bad-stage-manifest",
      "source": "plugins/bad-stage-manifest",
      "version": "0.0.0"
    }
  ]
}
JSON
printf '{ "name": ' >"$malformed_plugin_stage/plugins/bad-plugin-json/.claude-plugin/plugin.json"
cat >"$malformed_plugin_stage/plugins/bad-plugin-json/helm-stage.json" <<'JSON'
{
  "plugin": "bad-plugin-json",
  "stage": "broken"
}
JSON
cat >"$malformed_plugin_stage/plugins/bad-stage-manifest/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "bad-stage-manifest",
  "version": "0.0.0"
}
JSON
printf '{ "plugin": ' >"$malformed_plugin_stage/plugins/bad-stage-manifest/helm-stage.json"
run_failure "$tmp_dir/malformed-plugin-stage.json" list --marketplace-root "$malformed_plugin_stage"
jq -e '.blockers[] | select(. == "malformed-plugin-json:bad-plugin-json")' "$tmp_dir/malformed-plugin-stage.json" >/dev/null
jq -e '.blockers[] | select(. == "malformed-stage-manifest:bad-stage-manifest")' "$tmp_dir/malformed-plugin-stage.json" >/dev/null

unreadable_plugin_stage="$tmp_dir/unreadable-plugin-stage"
mkdir -p \
  "$unreadable_plugin_stage/.claude-plugin" \
  "$unreadable_plugin_stage/plugins/unreadable-plugin-json/.claude-plugin/plugin.json" \
  "$unreadable_plugin_stage/plugins/unreadable-stage-manifest/.claude-plugin" \
  "$unreadable_plugin_stage/plugins/unreadable-stage-manifest/helm-stage.json"
cat >"$unreadable_plugin_stage/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "unreadable-plugin-stage-fixture",
  "plugins": [
    {
      "name": "unreadable-plugin-json",
      "source": "plugins/unreadable-plugin-json",
      "version": "0.0.0"
    },
    {
      "name": "unreadable-stage-manifest",
      "source": "plugins/unreadable-stage-manifest",
      "version": "0.0.0"
    }
  ]
}
JSON
cat >"$unreadable_plugin_stage/plugins/unreadable-plugin-json/helm-stage.json" <<'JSON'
{
  "plugin": "unreadable-plugin-json",
  "stage": "broken"
}
JSON
cat >"$unreadable_plugin_stage/plugins/unreadable-stage-manifest/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "unreadable-stage-manifest",
  "version": "0.0.0"
}
JSON
run_failure "$tmp_dir/unreadable-plugin-stage.json" list --marketplace-root "$unreadable_plugin_stage"
jq -e '.blockers[] | select(. == "unreadable-plugin-json:unreadable-plugin-json")' "$tmp_dir/unreadable-plugin-stage.json" >/dev/null
jq -e '.blockers[] | select(. == "unreadable-stage-manifest:unreadable-stage-manifest")' "$tmp_dir/unreadable-plugin-stage.json" >/dev/null

run_failure "$tmp_dir/require-broken-deduped.json" require --marketplace-root "$malformed_plugin_stage" --plugin bad-plugin-json
jq -e '[.blockers[] | select(. == "malformed-plugin-json:bad-plugin-json")] | length == 1' "$tmp_dir/require-broken-deduped.json" >/dev/null

echo "helm plugin suite resolver fixtures ok"
