---
name: helm-prototype
description: Use this skill when the user wants a runnable Helm prototype, visual review artifact, UI HTML mock, logic-state harness, API contract mock, data-flow harness, or component seam comparison after requirements pass.
---

# Helm Prototype

## Purpose

Create isolated, runnable prototype artifacts that answer a specific design or behavior question before production development.

## Workflow

1. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json` first.
2. If requirements are blocked, report exact blockers. There is no fallback to generic design or a guessed change.
3. Classify the prototype question before writing code.
4. Read `references/prototype-branches.md` before choosing the branch.
5. Read `references/prototype-artifacts.md` before creating prototype files.
6. Branch Classification: use `ui-html`, `logic-state`, `api-contract`, `data-flow`, or `component-seam`.
7. If starting from templates, run `node "$CLAUDE_PLUGIN_ROOT/skills/helm-prototype/scripts/create-prototype.js" --branch=<branch> --json`.
8. Write artifacts only under `openspec/changes/<active-change>/prototype/`.
9. Expose stable screen, component, state, and variant labels for review.
10. Rerun the contract before moving to verification.

## Required Outputs

- `prototype/question.md`.
- `prototype/prototype-manifest.json`.
- Branch code or harness.
- Branch review maps such as `screen-map.json`, `component-tree.md`, or `data-flow-map.md`.
- Branch starters: `assets/question.md`, `assets/prototype-manifest.json`, `assets/screen-map.json`, `assets/ui-html/index.html`, `assets/ui-html/styles.css`, `assets/ui-html/app.js`, `assets/logic-state/harness.js`, `assets/api-contract/examples.json`, `assets/data-flow/data-flow-map.md`, `assets/data-flow/data-flow/flow-harness.js`, `assets/component-seam/component-tree.md`, and `assets/component-seam/component/component-map.md`.

## Stop Conditions

- Requirements are invalid.
- Required design, API, route, state, screenshot, brand, or domain context is missing.
- Branch classification is unclear.
- The prototype would edit production code.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json` and proceed only when blockers are expected next-stage artifacts.
