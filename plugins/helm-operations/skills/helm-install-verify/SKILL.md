---
name: helm-install-verify
description: Use this skill when Helm must verify plugin installation, host exposure, marketplace discovery, workspace support, reload requirement, config status, or installed plugin root evidence.
---

# Helm Install Verify

## Purpose

Verify installed plugin surfaces from current host evidence.

## Workflow

1. Resolve marketplace root and plugin root from metadata.
2. Run doctor or structural install checks from the plugin root.
3. Do not run install checks from the target project directory.
4. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` after writing.

## Required Outputs

- `operations/install-verification.json`.

## Stop Conditions

- Plugin source is unknown.
- Discovery root is unknown.
- Host evidence is missing.
- Reload requirement is unknown.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` and require ok or exact blockers.
