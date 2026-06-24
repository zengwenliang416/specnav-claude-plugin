---
name: helm-ops-readiness
description: Use this skill when Helm needs release or archive readiness, operations blocker aggregation, verification receipt review, git state review, required docs review, or a final ready/not-ready decision.
---

# Helm Ops Readiness

## Purpose

Build the final operations readiness decision.

## Workflow

1. Read verification aggregate report, receipt, blocker classification, development handoff, release plan, git state, and operations artifacts.
2. Write readiness from direct evidence only.
3. Read `references/operations-readiness.md` before writing readiness.
4. If readiness artifacts are missing, run `node "$CLAUDE_PLUGIN_ROOT/skills/helm-ops-readiness/scripts/create-readiness.js" --release-target=<target> --json`.
5. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` before and after edits.

## Required Outputs

- `operations/readiness.md` and `operations/readiness.json`.
- Readiness shells: `assets/readiness.md` and `assets/readiness.json`.

## Stop Conditions

- Verification is not green.
- Release target is missing.
- Git state is unknown.
- Required operations artifacts are missing.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` and require ok or exact blockers.
