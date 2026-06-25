---
name: helm-release-plan
description: Use this skill when Helm needs to choose or document a release target, release checklist, local-only release, plugin marketplace release, package release, host compatibility release, or project deploy path.
---

## Runtime Paths

Resolve every `HELM_*_ROOT` variable with the owning Helm command's installed-cache resolver before running Bash. Do not rely on `CLAUDE_PLUGIN_ROOT`; it is only guaranteed inside Claude Code hook processes. If a required installed plugin root cannot be resolved, report the exact blocker and stop.

# Helm Release Plan

## Purpose

Select one release target and document required checks.

## Workflow

1. Read verification output, user intent, repository shape, and distribution surface.
2. Read `references/release-targets.md` before selecting the target.
3. Select exactly one primary release target: `local-only`, `plugin-marketplace`, `package`, `host-compatibility`, or `project-deploy`.
4. If release artifacts are missing, run `node "$HELM_OPERATIONS_ROOT/skills/helm-release-plan/scripts/create-release-plan.js" --release-target=<target> --json`.
5. Write release plan and checklist.
6. Run `node "$HELM_OPERATIONS_ROOT/scripts/operations-gate.js" --json` after writing.

## Required Outputs

- `operations/release-plan.md` and `operations/release-checklist.json`.
- Release shells: `assets/release-plan.md`, `assets/release-checklist.json`, `assets/changelog.md`, and `assets/release-notes.md`.

## Stop Conditions

- Verification is blocked.
- Release target is ambiguous.
- Required release artifacts cannot be named.

## Validation

- Run `node "$HELM_OPERATIONS_ROOT/scripts/operations-gate.js" --json` and require ok or exact blockers.
