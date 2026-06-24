---
name: helm-vertical-slices
description: Use this skill when Helm development needs vertical slice planning, task briefs, task context, task ledger updates, TDD evidence, spec review, quality review, validation logs, or handoff to six-domain verification.
---

# Helm Vertical Slices

## Purpose

Plan, dispatch, review, and close production implementation through file-backed vertical slices.

## Workflow

1. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --mode entry --json` before planning.
2. Write user-visible tracer-bullet slices in `tasks.md`; avoid layer-only tasks.
3. Create each task packet with `brief.md` and `context.json`.
4. Maintain task ledger, drift checks, validation logs, extraction map, reports, spec review, and quality review.
5. No fallback around failed task review is allowed.
6. Before verification handoff, run `node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --mode handoff --json`.

## Required Outputs

- `tasks.md`.
- `development/tasks/<task-id>/brief.md` and `context.json`.
- Task reports, review files, ledgers, validation logs, and `development/handoff-to-verify.md`.

## Stop Conditions

- Entry blockers remain.
- Scope is insufficient.
- A task lacks allowed files.
- Drift blocks development.
- Local validation or required review fails.

## Validation

- Run entry validation during planning and handoff validation before verification.
