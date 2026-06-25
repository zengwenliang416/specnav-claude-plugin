---
name: helm-development-entry
description: Use this skill when Helm development is about to start or is blocked at entry, including before-dev checks, basis.md, approved prototype consumption, development scope preparation, or proving that production edits may begin.
---

## Runtime Paths

Resolve every `HELM_*_ROOT` variable with the owning Helm command's installed-cache resolver before running Bash. Do not rely on `CLAUDE_PLUGIN_ROOT`; it is only guaranteed inside Claude Code hook processes. If a required installed plugin root cannot be resolved, report the exact blocker and stop.

# Helm Development Entry

## Purpose

Validate upstream requirements and prototype gates, then record the basis for production development.

## Workflow

1. Run `node "$HELM_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode entry --json`.
2. If prototype or requirements blockers remain, route to the owning upstream skill. No fallback to a guessed change is allowed.
3. Read only the active change reported by the contract.
4. Read `references/development-entry.md` before writing entry artifacts.
5. If entry artifacts are missing, run `node "$HELM_DEVELOPMENT_ROOT/skills/helm-development-entry/scripts/create-development-entry.js" --json`.
6. Write or repair `development/before-dev-check.json` and `development/basis.md` with exact relative path references.
7. Do not start production edits until entry passes.

## Required Outputs

- `development/before-dev-check.json`.
- `development/basis.md`.
- Entry artifact shells: `assets/before-dev-check.json`, `assets/basis.md`, `assets/prototype-promotion-map.json`, `assets/complexity-budget.json`, `assets/task-graph.json`, `assets/task-context.jsonl`, `assets/code-owner-map.json`, and `assets/extraction-map.json`.

## Stop Conditions

- Any upstream artifact is missing or invalid.
- Approved prototype source is unclear.
- The implementation needs a new product, architecture, data-flow, or component-boundary decision.

## Validation

- Rerun `node "$HELM_DEVELOPMENT_ROOT/scripts/development-contract.js" --mode entry --json` and proceed only when `ok` is true.
