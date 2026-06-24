---
name: helm-verify-facticity
description: Use this skill when Helm must audit whether specs, requirements, reports, generated artifacts, dependencies, APIs, routes, config, database effects, or implementation claims match actual repository state.
---

# Helm Verify Facticity

## Purpose

Audit claims against current repository evidence.

## Workflow

1. Read plan, traceability, requirements, foundation specs, prototype handoff, and development handoff.
2. Treat summaries as claims, not proof.
3. Inventory actual files, APIs, dependencies, config, database effects, and changed behavior.
4. Write red findings for unmapped changes, invented facts, stale specs, or undocumented behavior.

## Required Outputs

- `verify/facticity/claims.jsonl`, `repo-inventory.json`, `report.md`, and `report.json`.

## Stop Conditions

- Repository evidence cannot be read.
- Claims are unmapped.
- Specs are stale.
- Implementation behavior is undocumented.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json` after writing the domain report.
