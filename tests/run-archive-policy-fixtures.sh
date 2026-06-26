#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/tests/fixtures/simple-project"
CORE="$ROOT/plugins/specnav-core"
TMP="$(mktemp -d)"
cp -R "$BASE/." "$TMP/"
trap 'rm -rf "$TMP"' EXIT

CHANGE_DIR="$TMP/openspec/changes/add-dark-mode"

PROJECT_DIR="$TMP" node "$CORE/scripts/verify.js" >/tmp/specnav-policy-verify.md
PROJECT_DIR="$TMP" node "$CORE/scripts/archive-gate.js" >/tmp/specnav-policy-archive.txt

printf '{"tool_name":"Write","tool_input":{"file_path":"src/ui/theme.ts"}}' | \
  PROJECT_DIR="$TMP" node "$CORE/scripts/specnav-post-tool.js"

if PROJECT_DIR="$TMP" node "$CORE/scripts/archive-gate.js" >/tmp/specnav-policy-stale.out 2>/tmp/specnav-policy-stale.err; then
  echo "expected archive gate to block stale verify report" >&2
  exit 1
fi

PROJECT_DIR="$TMP" node "$CORE/scripts/verify.js" >/tmp/specnav-policy-verify.md
PROJECT_DIR="$TMP" node "$CORE/scripts/archive-gate.js" >/tmp/specnav-policy-archive.txt

cat >"$CHANGE_DIR/risk-tier.json" <<'JSON'
{
  "tier": "high-risk",
  "source": "test",
  "triggers": ["src/auth/login.ts"],
  "checked_paths": ["src/auth/login.ts"],
  "generated_at": "2026-06-22T00:00:00.000Z"
}
JSON

if PROJECT_DIR="$TMP" node "$CORE/scripts/archive-gate.js" >/tmp/specnav-policy-signoff.out 2>/tmp/specnav-policy-signoff.err; then
  echo "expected archive gate to require high-risk signoff" >&2
  exit 1
fi

cat >"$CHANGE_DIR/signoff.yaml" <<'YAML'
schema_version: 1
reviewer: test@example.com
reviewed_commit: test
reviewed_at: 2026-06-22T00:00:00Z
policy: high-risk-human-signoff
decision: approved
YAML

PROJECT_DIR="$TMP" node "$CORE/scripts/archive-gate.js" >/tmp/specnav-policy-archive.txt

echo "specnav archive policy fixtures ok"
