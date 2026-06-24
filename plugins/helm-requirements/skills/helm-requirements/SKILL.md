---
name: helm-requirements
description: Use this skill when the user wants to define, clarify, or continue requirements for a Helm/OpenSpec change, including feature discovery, acceptance criteria, spec maps, component impact maps, or one-question-at-a-time product grilling.
---

# Helm Requirements

## Purpose

Discover change requirements after foundation spec validation passes.

## Workflow

1. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/foundation-specs.js" --json` first.
2. If blocked, route to `helm-foundation-specs` with exact blockers.
3. Read all four foundation spec files before asking product questions.
4. Read `references/interview-philosophy.md` before asking product questions.
5. Read `references/requirements-artifacts.md` before creating or repairing requirements artifacts.
6. If required change artifacts are missing, run `node "$CLAUDE_PLUGIN_ROOT/skills/helm-requirements/scripts/create-requirements-artifacts.js" --json` to scaffold templates from `assets/change/`.
7. Ask one focused question at a time with a recommended answer and tradeoff.
8. Do not ask information already answered by foundation spec, code evidence, OpenSpec artifacts, or previous answers.
9. Close each decision branch before opening the next: record the answer, update maps, rerun contracts, and resolve blockers.
10. Write unknowns in `unresolved_gaps` instead of inventing answers.

## Required Outputs

- `openspec/changes/<change>/requirements.md`.
- `openspec/changes/<change>/acceptance.md`.
- `openspec/changes/<change>/spec-map.json`.
- `openspec/changes/<change>/component-impact-map.json`.
- Templates: `assets/change/requirements.md`, `assets/change/acceptance.md`, `assets/change/spec-map.json`, and `assets/change/component-impact-map.json`.

## Stop Conditions

- Foundation validation fails.
- `unresolved_gaps` is non-empty.
- The active change is unclear.
- A product, architecture, data-flow, or component-boundary decision is missing.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/requirements-contract.js" --json` and hand off only when `ok` is true.
