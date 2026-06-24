---
name: helm-prototype-handoff
description: Use this skill when a verified Helm prototype needs explicit user approval, decision.json, required_present status, or a development handoff that freezes approved branch, variant, components, data flows, tests, and risks.
---

# Helm Prototype Handoff

## Purpose

Record explicit prototype approval and produce the development handoff.

## Workflow

1. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json` before handoff.
2. Stop on requirements, manifest, branch code, entry path, or verifier blockers.
3. Ask for explicit user approval before setting `status: approved`.
4. Write `prototype/handoff.md` with branch, variant, screens, flows, components, API contracts, data flows, states, out-of-scope items, required tests, and risks.
5. Write `prototype/decision.json` with `prototype_code: required_present` and `promotion: requires_development_gate`.

## Required Outputs

- `prototype/handoff.md`.
- `prototype/decision.json`.

## Stop Conditions

- User approval is missing.
- Verifier status is not green.
- Handoff topics have unresolved decisions.
- The decision would bypass development gates.

## Validation

- Rerun `node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json` and hand off only when `ok` is true.
