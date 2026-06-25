---
name: helm-verify-unit
description: Use this skill when Helm needs focused unit, regression, edge-case, empty-state, error-path, boundary-input, or test-quality verification for changed production behavior.
---

## Runtime Paths

Resolve every `HELM_*_ROOT` variable with the owning Helm command's installed-cache resolver before running Bash. Do not rely on `CLAUDE_PLUGIN_ROOT`; it is only guaranteed inside Claude Code hook processes. If a required installed plugin root cannot be resolved, report the exact blocker and stop.

# Helm Verify Unit

## Purpose

Validate behavior-facing unit and regression coverage.

## Workflow

1. Read plan, development reports, changed-file traceability, and tests.
2. Read `references/unit-rubric.md` before assessing test quality.
3. Confirm public behavior coverage for critical paths and edge cases.
4. Reject tests coupled to private methods, implementation-only mocks, or collaborator call counts.
5. Use `assets/report.md` and `assets/report.json` as shells when the domain report is missing.
6. Record coverage quality and gaps.

## Required Outputs

- `verify/unit/test-map.json`, `test-quality-rubric.json`, `coverage-notes.md`, `report.md`, and `report.json`.
- Report shells: `assets/report.md` and `assets/report.json`.

## Stop Conditions

- Changed behavior has no meaningful coverage.
- Tests cannot run.
- Assertions verify implementation details rather than behavior.

## Validation

- Run `node "$HELM_VERIFICATION_ROOT/scripts/verify-domains.js" validate --json` after writing the domain report.
