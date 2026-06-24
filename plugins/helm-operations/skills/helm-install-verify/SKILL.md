---
name: helm-install-verify
description: Use this skill when Helm must verify plugin installation, host exposure, marketplace discovery, workspace support, reload requirement, config status, or installed plugin root evidence.
---

# Helm Install Verify

## Purpose

Verify installed plugin surfaces from current host evidence.

## Workflow

1. Resolve marketplace root and plugin root from metadata.
2. Read `references/install-verification.md` before writing install evidence.
3. Run doctor or structural install checks from the plugin root.
4. Do not run install checks from the target project directory.
5. Use `assets/install-verification.json` as the shell when the artifact is missing.
6. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` after writing.

## Required Outputs

- `operations/install-verification.json`.
- Install shell: `assets/install-verification.json`.

## Stop Conditions

- Plugin source is unknown.
- Discovery root is unknown.
- Host evidence is missing.
- Reload requirement is unknown.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` and require ok or exact blockers.
