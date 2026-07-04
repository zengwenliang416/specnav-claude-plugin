---
name: specnav-requirements
description: Use this skill when the user wants to define, clarify, or continue requirements for a SpecNav/OpenSpec change, including feature discovery, acceptance criteria, spec maps, component impact maps, or one-question-at-a-time product grilling.
---

## Runtime Paths

Resolve every `SPECNAV_*_ROOT` variable with the owning SpecNav Codex plugin resolver before running Bash. Codex plugin code must use `PLUGIN_ROOT` and explicit `SPECNAV_*_ROOT` overrides. If a required installed plugin root cannot be resolved, report the exact blocker and stop.

# SpecNav Requirements

## Purpose

Discover change requirements after foundation spec validation passes.

## Workflow

1. Run `node "$SPECNAV_REQUIREMENTS_ROOT/scripts/foundation-specs.js" --json` first.
2. If foundation specs are missing, run `node "$SPECNAV_REQUIREMENTS_ROOT/scripts/repository-discovery.js" --write --json` and use discovery output only as evidence and pending-question input.
3. If blocked, route to `specnav-foundation-specs` with exact blockers; discovery does not satisfy `foundation-specs.js` or `requirements-contract.js`.
4. Read all four foundation spec files before asking product questions.
5. Read `references/interview-philosophy.md` before asking product questions.
6. Read `references/requirements-artifacts.md` before creating or repairing requirements artifacts.
7. If required change artifacts are missing, run `node "$SPECNAV_REQUIREMENTS_ROOT/skills/specnav-requirements/scripts/create-requirements-artifacts.js" --json` to scaffold templates from `assets/change/`.
8. Before feature questioning, confirm the UI design spec's theme modes, theme toggle policy, i18n capability, supported locales, default locale, and prototype coverage expectation.
9. Ask one focused question at a time with a recommended answer and tradeoff.
10. Do not ask information already answered by foundation spec, discovery evidence, OpenSpec artifacts, or previous answers.
11. Close each decision branch before opening the next: record the answer, update maps, rerun contracts, and resolve blockers.
12. Write unknowns in `unresolved_gaps` instead of inventing answers.

## Required Outputs

- `openspec/changes/<change>/requirements.md`.
- `openspec/changes/<change>/acceptance.md`.
- `openspec/changes/<change>/acceptance.json`: the machine-checkable assertion list mirroring acceptance.md. Every criterion becomes one assertion `{id, statement, verify_via, status:"failing", evidence_ref:null}` with `verify_via` in facticity/static/unit/redteam/e2e/sensory. All assertions start `failing`; implementation may only flip `status` to `passing` with an `evidence_ref` — the assertion set itself is frozen once development starts (`acceptance:assertions-mutated` blocks otherwise), and verification cannot go green while any assertion is failing.
- `openspec/changes/<change>/spec-map.json`.
- `openspec/changes/<change>/component-impact-map.json`.
- Templates: `assets/change/requirements.md`, `assets/change/acceptance.md`, `assets/change/acceptance.json`, `assets/change/spec-map.json`, and `assets/change/component-impact-map.json`.

## Stop Conditions

- Foundation validation fails.
- `unresolved_gaps` is non-empty.
- The active change is unclear.
- A product, architecture, data-flow, or component-boundary decision is missing.

## Validation

- Run `node "$SPECNAV_REQUIREMENTS_ROOT/scripts/requirements-contract.js" --json` and hand off only when `ok` is true.
