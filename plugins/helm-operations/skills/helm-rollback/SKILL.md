---
name: helm-rollback
description: Use this skill when Helm needs rollback planning, rollback triggers, exact rollback command or manual step, migration reversal, data recovery notes, or rollback verification for a release with deploy risk.
---

# Helm Rollback

## Purpose

Prepare rollback mechanics for deploy-risk targets.

## Workflow

1. Use for any release target with deploy risk.
2. Read `references/rollback-plan.md` before writing rollback mechanics.
3. If rollback is impossible, require explicit risk acceptance in `operations/signoff.yaml`.
4. Use `assets/rollback-plan.md` as the shell when the artifact is missing.
5. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` after writing.

## Required Outputs

- `operations/rollback-plan.md`.
- Rollback shell: `assets/rollback-plan.md`.

## Stop Conditions

- Rollback is impossible without signoff.
- Data recovery is unknown.
- Rollback verification cannot be documented.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` and require ok or exact blockers.
