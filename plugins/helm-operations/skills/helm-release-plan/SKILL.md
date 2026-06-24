---
name: helm-release-plan
description: Use this skill when Helm needs to choose or document a release target, release checklist, local-only release, plugin marketplace release, package release, host compatibility release, or project deploy path.
---

# Helm Release Plan

## Purpose

Select one release target and document required checks.

## Workflow

1. Read verification output, user intent, repository shape, and distribution surface.
2. Select exactly one primary release target: `local-only`, `plugin-marketplace`, `package`, `host-compatibility`, or `project-deploy`.
3. Write release plan and checklist.
4. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` after writing.

## Required Outputs

- `operations/release-plan.md` and `operations/release-checklist.json`.

## Stop Conditions

- Verification is blocked.
- Release target is ambiguous.
- Required release artifacts cannot be named.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` and require ok or exact blockers.
