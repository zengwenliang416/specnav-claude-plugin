---
name: helm-verify-unit
description: Use this skill when Helm needs focused unit, regression, edge-case, empty-state, error-path, boundary-input, or test-quality verification for changed production behavior.
---

# Helm Verify Unit

## Purpose

Validate behavior-facing unit and regression coverage.

## Workflow

1. Read plan, development reports, changed-file traceability, and tests.
2. Confirm public behavior coverage for critical paths and edge cases.
3. Reject tests coupled to private methods, implementation-only mocks, or collaborator call counts.
4. Record coverage quality and gaps.

## Required Outputs

- `verify/unit/test-map.json`, `test-quality-rubric.json`, `coverage-notes.md`, `report.md`, and `report.json`.

## Stop Conditions

- Changed behavior has no meaningful coverage.
- Tests cannot run.
- Assertions verify implementation details rather than behavior.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json` after writing the domain report.
