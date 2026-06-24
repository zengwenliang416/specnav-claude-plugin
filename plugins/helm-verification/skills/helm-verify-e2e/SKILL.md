---
name: helm-verify-e2e
description: Use this skill when Helm needs end-to-end, user journey, business flow, frontend-backend, API, state, database, integration, or realistic data validation for a completed change.
---

# Helm Verify E2E

## Purpose

Validate complete user and business flows across boundaries.

## Workflow

1. Read plan, data-flow specs, requirements, prototype handoff, and development handoff.
2. Read `references/e2e-rubric.md` before selecting flows.
3. Use realistic data and execute representative flows.
4. Record screenshots, traces, logs, or explicit blocked evidence when execution is impossible.
5. Use `assets/report.md` and `assets/report.json` as shells when the domain report is missing.
6. Check frontend, backend, API, state, database, and integration effects together.

## Required Outputs

- `verify/e2e/flows.json`, `run-log.jsonl`, `report.md`, and `report.json`.
- Report shells: `assets/report.md` and `assets/report.json`.

## Stop Conditions

- Environment cannot safely run.
- Flow preconditions are unknown.
- Required data contracts are missing.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json` after writing the domain report.
