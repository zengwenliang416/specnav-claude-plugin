---
name: helm-prototype-verify
description: Use this skill when a Helm prototype exists and must be checked before approval, including runnable HTML review, logic-state execution, API examples, data-flow transitions, component seam review, verifier-report.json, or prototype runtime evidence.
---

# Helm Prototype Verify

## Purpose

Verify that the selected prototype branch exists, runs, and exposes reviewable states.

## Workflow

1. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json` first.
2. Read `prototype/prototype-manifest.json` and verify only the declared branch and entry.
3. For `ui-html`, inspect desktop, mobile, variants, tweaks, and loading, empty, error, disabled, and permission states.
4. For other branches, run the declared harness or inspect concrete schemas, transitions, and public APIs.
5. Write `prototype/verifier-report.json` with green, red, or blocked status and evidence.

## Required Outputs

- `openspec/changes/<active-change>/prototype/verifier-report.json`.
- Supporting logs or screenshots named by the report.

## Stop Conditions

- Manifest is invalid.
- Declared entry is missing.
- Runtime execution fails.
- Direct verification evidence cannot be produced.

## Validation

- Rerun `node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json` after writing `verifier-report.json`.
