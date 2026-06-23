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
  local exit_code=$?
  set -e

  [[ "$exit_code" == "2" ]]
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

run_failure "$tmp_dir/resolve-duplicate-plugin.json" resolve --marketplace-root "$ROOT" --plugin helm-core --plugin helm-requirements
jq -e '.blockers[] | select(. == "duplicate-argument:--plugin")' "$tmp_dir/resolve-duplicate-plugin.json" >/dev/null

run_failure "$tmp_dir/list-duplicate-marketplace-root.json" list --marketplace-root "$ROOT" --marketplace-root "$ROOT"
jq -e '.blockers[] | select(. == "duplicate-argument:--marketplace-root")' "$tmp_dir/list-duplicate-marketplace-root.json" >/dev/null

run_failure "$tmp_dir/flag-after-bare-command.json" --marketplace-root "$ROOT" inspect
jq -e '.blockers[] | select(. == "unknown-command:inspect")' "$tmp_dir/flag-after-bare-command.json" >/dev/null

malformed_marketplace="$tmp_dir/malformed-marketplace"
mkdir -p "$malformed_marketplace/.claude-plugin"
printf '{ "plugins": [ ' >"$malformed_marketplace/.claude-plugin/marketplace.json"
run_failure "$tmp_dir/malformed-marketplace.json" list --marketplace-root "$malformed_marketplace"
jq -e '.blockers[] | select(. == "malformed-marketplace-json")' "$tmp_dir/malformed-marketplace.json" >/dev/null

unreadable_marketplace="$tmp_dir/unreadable-marketplace"
mkdir -p "$unreadable_marketplace/.claude-plugin/marketplace.json"
run_failure "$tmp_dir/unreadable-marketplace.json" list --marketplace-root "$unreadable_marketplace"
jq -e '.blockers[] | select(. == "unreadable-marketplace-json")' "$tmp_dir/unreadable-marketplace.json" >/dev/null

invalid_marketplace="$tmp_dir/invalid-marketplace"
mkdir -p "$invalid_marketplace/.claude-plugin"
cat >"$invalid_marketplace/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "invalid-marketplace-fixture",
  "plugins": {}
}
JSON
run_failure "$tmp_dir/invalid-marketplace.json" list --marketplace-root "$invalid_marketplace"
jq -e '.blockers[] | select(. == "invalid-marketplace-json")' "$tmp_dir/invalid-marketplace.json" >/dev/null

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

invalid_plugin_stage="$tmp_dir/invalid-plugin-stage"
mkdir -p \
  "$invalid_plugin_stage/.claude-plugin" \
  "$invalid_plugin_stage/plugins/bad-plugin-shape/.claude-plugin" \
  "$invalid_plugin_stage/plugins/bad-stage-plugin-field/.claude-plugin" \
  "$invalid_plugin_stage/plugins/bad-stage-required-field/.claude-plugin" \
  "$invalid_plugin_stage/plugins/bad-stage-commands-field/.claude-plugin" \
  "$invalid_plugin_stage/plugins/bad-stage-skills-field/.claude-plugin" \
  "$invalid_plugin_stage/plugins/bad-stage-contracts-field/.claude-plugin"
cat >"$invalid_plugin_stage/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "invalid-plugin-stage-fixture",
  "plugins": [
    {
      "name": "bad-plugin-shape",
      "source": "plugins/bad-plugin-shape",
      "version": "0.0.0"
    },
    {
      "name": "bad-stage-plugin-field",
      "source": "plugins/bad-stage-plugin-field",
      "version": "0.0.0"
    },
    {
      "name": "bad-stage-required-field",
      "source": "plugins/bad-stage-required-field",
      "version": "0.0.0"
    },
    {
      "name": "bad-stage-commands-field",
      "source": "plugins/bad-stage-commands-field",
      "version": "0.0.0"
    },
    {
      "name": "bad-stage-skills-field",
      "source": "plugins/bad-stage-skills-field",
      "version": "0.0.0"
    },
    {
      "name": "bad-stage-contracts-field",
      "source": "plugins/bad-stage-contracts-field",
      "version": "0.0.0"
    }
  ]
}
JSON
cat >"$invalid_plugin_stage/plugins/bad-plugin-shape/.claude-plugin/plugin.json" <<'JSON'
{
  "version": "0.0.0"
}
JSON
cat >"$invalid_plugin_stage/plugins/bad-plugin-shape/helm-stage.json" <<'JSON'
{
  "plugin": "bad-plugin-shape",
  "stage": "broken"
}
JSON
cat >"$invalid_plugin_stage/plugins/bad-stage-plugin-field/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "bad-stage-plugin-field",
  "version": "0.0.0"
}
JSON
cat >"$invalid_plugin_stage/plugins/bad-stage-plugin-field/helm-stage.json" <<'JSON'
{
  "plugin": 123,
  "stage": "broken"
}
JSON
cat >"$invalid_plugin_stage/plugins/bad-stage-required-field/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "bad-stage-required-field",
  "version": "0.0.0"
}
JSON
cat >"$invalid_plugin_stage/plugins/bad-stage-required-field/helm-stage.json" <<'JSON'
{
  "plugin": "bad-stage-required-field",
  "stage": "broken",
  "required": "yes"
}
JSON
cat >"$invalid_plugin_stage/plugins/bad-stage-commands-field/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "bad-stage-commands-field",
  "version": "0.0.0"
}
JSON
cat >"$invalid_plugin_stage/plugins/bad-stage-commands-field/helm-stage.json" <<'JSON'
{
  "plugin": "bad-stage-commands-field",
  "stage": "broken",
  "commands": [
    "ok",
    123
  ]
}
JSON
cat >"$invalid_plugin_stage/plugins/bad-stage-skills-field/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "bad-stage-skills-field",
  "version": "0.0.0"
}
JSON
cat >"$invalid_plugin_stage/plugins/bad-stage-skills-field/helm-stage.json" <<'JSON'
{
  "plugin": "bad-stage-skills-field",
  "stage": "broken",
  "skills": [
    "ok",
    false
  ]
}
JSON
cat >"$invalid_plugin_stage/plugins/bad-stage-contracts-field/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "bad-stage-contracts-field",
  "version": "0.0.0"
}
JSON
cat >"$invalid_plugin_stage/plugins/bad-stage-contracts-field/helm-stage.json" <<'JSON'
{
  "plugin": "bad-stage-contracts-field",
  "stage": "broken",
  "contracts": {
    "bad": 123
  }
}
JSON
run_failure "$tmp_dir/invalid-plugin-stage.json" list --marketplace-root "$invalid_plugin_stage"
jq -e '.blockers[] | select(. == "invalid-plugin-json:bad-plugin-shape")' "$tmp_dir/invalid-plugin-stage.json" >/dev/null
jq -e '.blockers[] | select(. == "invalid-stage-manifest:bad-stage-plugin-field")' "$tmp_dir/invalid-plugin-stage.json" >/dev/null
jq -e '.blockers[] | select(. == "invalid-stage-manifest:bad-stage-required-field")' "$tmp_dir/invalid-plugin-stage.json" >/dev/null
jq -e '.blockers[] | select(. == "invalid-stage-manifest:bad-stage-commands-field")' "$tmp_dir/invalid-plugin-stage.json" >/dev/null
jq -e '.blockers[] | select(. == "invalid-stage-manifest:bad-stage-skills-field")' "$tmp_dir/invalid-plugin-stage.json" >/dev/null
jq -e '.blockers[] | select(. == "invalid-stage-manifest:bad-stage-contracts-field")' "$tmp_dir/invalid-plugin-stage.json" >/dev/null

good_bad_marketplace="$tmp_dir/good-bad-marketplace"
mkdir -p \
  "$good_bad_marketplace/.claude-plugin" \
  "$good_bad_marketplace/plugins/good/.claude-plugin" \
  "$good_bad_marketplace/plugins/bad/.claude-plugin"
cat >"$good_bad_marketplace/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "good-bad-marketplace-fixture",
  "plugins": [
    {
      "name": "good",
      "source": "plugins/good",
      "version": "0.0.0"
    },
    {
      "name": "bad",
      "source": "plugins/bad",
      "version": "0.0.0"
    }
  ]
}
JSON
cat >"$good_bad_marketplace/plugins/good/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "good",
  "version": "0.0.0"
}
JSON
cat >"$good_bad_marketplace/plugins/good/helm-stage.json" <<'JSON'
{
  "plugin": "good",
  "stage": "ok"
}
JSON
cat >"$good_bad_marketplace/plugins/bad/.claude-plugin/plugin.json" <<'JSON'
{
  "version": "0.0.0"
}
JSON
cat >"$good_bad_marketplace/plugins/bad/helm-stage.json" <<'JSON'
{
  "plugin": "bad",
  "stage": "broken"
}
JSON
node "$ROOT/plugins/helm-core/scripts/plugin-suite.js" require --marketplace-root "$good_bad_marketplace" --plugin good --json >"$tmp_dir/good-bad-require-good.json"
jq -e '.ok == true' "$tmp_dir/good-bad-require-good.json" >/dev/null
jq -e '.blockers | length == 0' "$tmp_dir/good-bad-require-good.json" >/dev/null
jq -e '.plugins | length == 1' "$tmp_dir/good-bad-require-good.json" >/dev/null
jq -e '.plugins[] | select(.name == "good")' "$tmp_dir/good-bad-require-good.json" >/dev/null
run_failure "$tmp_dir/good-bad-list.json" list --marketplace-root "$good_bad_marketplace"
jq -e '.blockers[] | select(. == "invalid-plugin-json:bad")' "$tmp_dir/good-bad-list.json" >/dev/null

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
