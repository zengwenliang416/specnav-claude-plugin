---
name: vertical-slice-tasking
description: Plan and close Helm development through vertical slices
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# Vertical Slice Tasking

Run the development contract before planning or dispatching a task:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --json
```

If upstream prototype, requirements, or scope blockers remain, stop and route to the exact owning skill. Do not fallback to layer-only implementation tasks, unapproved prototype code, or a different active change.

Write vertical slices in `openspec/changes/<active-change>/tasks.md`. Tasks must describe user-visible tracer bullets such as `user can view checkout summary`, not layer tasks such as `build database`, `build API`, or `build UI`.

For each slice, create `openspec/changes/<active-change>/development/tasks/<task-id>/` where `<task-id>` is like `001-checkout-summary`. Each task must include:

- `brief.md` with the required Goal, Parent Artifacts, Vertical Slice, In Scope, Out Of Scope, Files Allowed, Interfaces / Seams, Components To Create, Components To Reuse, Components To Extract, API / Data Flow Contracts, State / Error / Empty / Loading Behavior, TDD Requirement, Verification Commands, Stop Conditions, and Unsafe Assumptions sections.
- `context.json` with clean `task_id`, `goal`, `stop_condition`, `must_read`, `allowed_files`, `non_goals`, `expected_evidence`, and `unsafe_assumptions`.
- `report.md` with `## Status`, TDD Evidence, and Verification Commands.
- `spec-review.md` with verdict `approved`.
- `quality-review.md` with verdict `approved`.

Maintain these development artifacts as the append-only execution contract:

- `prototype-promotion-map.json`
- `complexity-budget.json`
- `task-graph.json`
- `task-context.jsonl`
- `task-ledger.jsonl`
- `drift-check.jsonl`
- `code-owner-map.json`
- `extraction-map.json`
- `validation-log.jsonl`
- `handoff-to-verify.md`

Use `prototype-promotion-map.json` to reimplement approved prototype decisions under the development gate. Do not directly copy blocked prototype code or bypass prototype approval.

The ledger must show each task reaching `spec_review_passed`, `quality_review_passed`, and `complete`. Blocking drift stops development and routes to the owning stage. `validation-log.jsonl` must include a passing local validation entry before verification handoff.

Before handing off to verification, rerun:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --json
```

Proceed only when the contract returns `"ok": true`.
