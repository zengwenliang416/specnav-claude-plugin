---
name: helm-debug
description: Use this skill when a Helm development task reports BLOCKED, when a failing test or unexpected behavior must be diagnosed before any fix, or when the cause of a blocked implementation needs systematic root-cause investigation.
---

## Runtime Paths

Resolve every `HELM_*_ROOT` variable with the owning Helm command's installed-cache resolver before running Bash. Do not rely on `CLAUDE_PLUGIN_ROOT`; it is only guaranteed inside Claude Code hook processes. If a required installed plugin root cannot be resolved, report the exact blocker and stop.

# Helm Debug

## Purpose

Systematically diagnose a `BLOCKED` task and classify its cause before any code is changed.

## Workflow

1. Run `node "$HELM_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode entry --json` to confirm the active change and blocked task.
2. Read the task `brief.md`, `context.json`, and `report.md`; reproduce the failure and capture the exact command, output, and runtime state.
3. Form one hypothesis at a time, test it against evidence, and reject hypotheses that the logs, tests, or state contradict. Do not guess past a failing reproduction.
4. Classify the blocked cause: task too large, plan wrong, scope missing, or spec missing.
5. If the cause is a contained defect, hand off to `helm-fix` with the reproduction and root cause recorded.
6. If the cause is structural, hand off to `helm-break-loop` or route to the owning upstream skill instead of forcing the task through implementation.
7. Never mark a blocked task DONE; Helm must not force a blocked task through implementation.

## Required Outputs

- The reproduction command, observed output, and root-cause classification recorded in the task `report.md`.
- Updated `development/task-ledger.jsonl` reflecting the blocked diagnosis.

## Stop Conditions

- Entry blockers remain.
- The failure cannot be reproduced from files, tests, logs, or runtime state.
- The cause is a missing product, architecture, data-flow, scope, or spec decision.

## Validation

- Rerun `node "$HELM_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode entry --json` and confirm the recorded classification matches the contract's blocked status.
