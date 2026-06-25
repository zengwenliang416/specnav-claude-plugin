---
name: helm-verify-plan
description: Use this skill when Helm development is complete and the user wants a six-domain verification plan, evidence index, traceability matrix, blocker classification, root-cause checks, behavior evals, or receipt shell.
---

## Runtime Paths

Resolve every `HELM_*_ROOT` variable with the owning Helm command's installed-cache resolver before running Bash. Do not rely on `CLAUDE_PLUGIN_ROOT`; it is only guaranteed inside Claude Code hook processes. If a required installed plugin root cannot be resolved, report the exact blocker and stop.

# Helm Verify Plan

## Purpose

Create shared verification plan and evidence contracts.

## Workflow

1. Run `node "$HELM_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode handoff --json` first.
2. If blocked, route to development.
3. Read `references/verification-model.md` before planning domains.
4. Read `references/domain-report-schema.md` before creating report shells.
5. If shared verification artifacts are missing, run `node "$HELM_VERIFICATION_ROOT/skills/helm-verify-plan/scripts/create-verify-plan.js" --json`.
6. Write verification plan, evidence index, traceability matrix, blocker classification, root-cause checks, behavior evals, and receipt shell.
7. Require all six domains: facticity, static, unit, redteam, e2e, and sensory.

## Required Outputs

- `verify/plan.md`, `plan.json`, `evidence-index.jsonl`, `traceability-matrix.json`, `blocker-classification.jsonl`, `root-cause-checks.jsonl`, behavior eval files, and receipt shell.
- Shared shells: `assets/plan.md`, `assets/plan.json`, `assets/evidence-index.jsonl`, `assets/traceability-matrix.json`, `assets/blocker-classification.jsonl`, `assets/root-cause-checks.jsonl`, `assets/receipt.md`, `assets/receipt.json`, `assets/behavior-evals/scenarios.json`, `assets/behavior-evals/report.md`, `assets/behavior-evals/report.json`, and `assets/behavior-evals/transcripts/verify-runs-six-domains.md`.

## Stop Conditions

- Development handoff is blocked.
- Active change is unclear.
- Any required domain is omitted.

## Validation

- Run `node "$HELM_VERIFICATION_ROOT/scripts/verify-domains.js" validate --json` after writing the domain report.
