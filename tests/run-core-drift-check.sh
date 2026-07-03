#!/usr/bin/env bash
set -euo pipefail

# Cross-repo shared-core drift guard.
# Compares files listed in tests/shared-core-manifest.json against the
# specnav-codex-plugin sibling checkout. Fails when:
#   - a file in `identical` differs, is missing, or gains divergence;
#   - a shared file diverges without a whitelist entry.
# Sibling location: $SPECNAV_SIBLING_ROOT, or ../specnav-codex-plugin.
# Skips with a notice (exit 0) when no sibling checkout is available so the
# suite stays runnable in isolation; CI checks out the sibling explicitly.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT/tests/shared-core-manifest.json"
SIBLING="${SPECNAV_SIBLING_ROOT:-$ROOT/../specnav-codex-plugin}"

if [[ ! -d "$SIBLING/plugins" ]]; then
  echo "SKIP core-drift-check: sibling checkout not found at $SIBLING (set SPECNAV_SIBLING_ROOT)"
  exit 0
fi

ROOT="$ROOT" SIBLING="$SIBLING" MANIFEST="$MANIFEST" node - <<'NODE'
const fs = require('fs');
const path = require('path');

const root = process.env.ROOT;
const sibling = process.env.SIBLING;
const manifest = JSON.parse(fs.readFileSync(process.env.MANIFEST, 'utf8'));
const whitelisted = new Set((manifest.whitelisted_divergence || []).map((entry) => entry.path));
const failures = [];

function same(a, b) {
  try {
    return fs.readFileSync(a).equals(fs.readFileSync(b));
  } catch {
    return null;
  }
}

for (const rel of manifest.identical) {
  const ours = path.join(root, rel);
  const theirs = path.join(sibling, rel);
  if (!fs.existsSync(ours)) { failures.push(`missing-local:${rel}`); continue; }
  if (!fs.existsSync(theirs)) { failures.push(`missing-sibling:${rel}`); continue; }
  if (same(ours, theirs) !== true) failures.push(`drift:${rel}`);
}

// New shared files not covered by the manifest at all are reported so the
// manifest stays complete.
function walk(dir, base, out) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, base, out);
    else if (entry.name.endsWith('.js')) out.push(path.relative(base, full).split(path.sep).join('/'));
  }
}
const ourFiles = [];
walk(path.join(root, 'plugins'), root, ourFiles);
const known = new Set([...manifest.identical, ...whitelisted]);
for (const rel of ourFiles) {
  if (known.has(rel)) continue;
  const theirs = path.join(sibling, rel);
  if (fs.existsSync(theirs) && same(path.join(root, rel), theirs) !== true) {
    failures.push(`unlisted-divergence:${rel}`);
  }
}

if (failures.length) {
  console.error('core-drift-check failed:');
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}
console.log(`core-drift-check ok (${manifest.identical.length} identical, ${whitelisted.size} whitelisted)`);
NODE
