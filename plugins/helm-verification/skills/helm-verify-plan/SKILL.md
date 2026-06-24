---
name: helm-verify-plan
description: Use this skill when Helm development is complete and the user wants a six-domain verification plan, evidence index, traceability matrix, blocker classification, root-cause checks, behavior evals, or receipt shell.
---

# Helm Verify Plan

## Purpose

Create shared verification plan and evidence contracts.

## Workflow

1. Run `node "$CLAUDE_PLUGIN_ROOT/../helm-development/scripts/development-contract.js" --mode handoff --json` first.
2. If blocked, route to development.
3. Write verification plan, evidence index, traceability matrix, blocker classification, root-cause checks, behavior evals, and receipt shell.
4. Require all six domains: facticity, static, unit, redteam, e2e, and sensory.

## Required Outputs

- `verify/plan.md`, `plan.json`, `evidence-index.jsonl`, `traceability-matrix.json`, `blocker-classification.jsonl`, `root-cause-checks.jsonl`, behavior eval files, and receipt shell.

## Stop Conditions

- Development handoff is blocked.
- Active change is unclear.
- Any required domain is omitted.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json` after writing the domain report.
