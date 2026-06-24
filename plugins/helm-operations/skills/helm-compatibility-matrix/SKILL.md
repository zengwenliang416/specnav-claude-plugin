---
name: helm-compatibility-matrix
description: Use this skill when Helm must document host compatibility, support level, supported Claude Code surfaces, doctor result, verification command, known limitations, or reload requirements.
---

# Helm Compatibility Matrix

## Purpose

Record support evidence for host and plugin surfaces.

## Workflow

1. Review install verification, doctor output, host limitations, and reload behavior.
2. Do not claim support without fresh smoke evidence.
3. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` after writing.

## Required Outputs

- `operations/compatibility-matrix.md`.

## Stop Conditions

- Doctor evidence is missing.
- Verification command evidence is missing.
- Known limitations are not documented.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` and require ok or exact blockers.
