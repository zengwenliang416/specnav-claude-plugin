---
name: prototype
description: Classify and create isolated Helm prototype artifacts after requirements pass
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Prototype

Run the prototype contract first and use the JSON as the source of truth:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json
```

If the result is blocked because requirements are not valid, stop and report the exact blockers. Do not choose another change, infer requirements, or continue with generic design fallback.

## Branch Classification

Classify the prototype question before writing code:

- `ui-html` for UI, visual design, layout, or interaction questions.
- `logic-state` for state machines, business logic, or backend behavior.
- `api-contract` for API shape, data contracts, schemas, and examples.
- `data-flow` for frontend-backend chains and observable transitions.
- `component-seam` for component/API boundaries and public interfaces.

Choosing the wrong branch is a blocker. If required design context, routes, components, state models, API examples, screenshots, brand assets, or domain docs are missing, stop and ask for that material. There is no fallback to a generic design, generic API, or newest-change guess.

## Required Writes

Write prototype artifacts only under:

```text
openspec/changes/<active-change>/prototype/
```

For every approved prototype path, write:

- `question.md` with the question, selected branch, rejected branches, and decision needed.
- `prototype-manifest.json` with `schema: "helm.prototype.manifest.v1"`, `version`, exact `type`, relative `entry`, `dependencies`, `mock_strategy`, `touches_real_data`, `referenced_foundation_specs`, `referenced_requirements`, `may_promote`, and `promotion_requirement`.
- Branch code:
  - `ui-html`: `artifact/index.html`
  - `logic-state`: `logic/`
  - `api-contract`: `api/`
  - `data-flow`: `data-flow-map.md`
  - `component-seam`: `component/`

Also write required review maps for the branch:

- `screen-map.json` for `ui-html`
- `component-tree.md` for `component-seam`
- `data-flow-map.md` for `data-flow`

Gap-sensitive files (`screen-map.json`, `component-tree.md`, `data-flow-map.md`, and `handoff.md`) must not contain TODO, TBD, unresolved, or gap as unresolved words. If a gap remains, record it as a blocker and do not mark the prototype approved.

After writing artifacts, run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json
```

Proceed to `prototype-verify` only when the remaining blockers are the expected absence of verification and handoff artifacts for this stage. Any invalid entry path, missing branch artifact, or upstream requirements blocker must stop the workflow.
