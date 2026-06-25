---
name: helm-route
description: Use this skill when the user asks Helm to route an ambiguous request, continue a stage, choose the next legal lifecycle action, or translate product intent into the correct Helm plugin command without bypassing OpenSpec gates.
---

## Runtime Paths

Resolve every `HELM_*_ROOT` variable with the owning Helm command's installed-cache resolver before running Bash. Do not rely on `CLAUDE_PLUGIN_ROOT`; it is only guaranteed inside Claude Code hook processes. If a required installed plugin root cannot be resolved, report the exact blocker and stop.

# Helm Route

## Purpose

Route user intent to the right Helm plugin while preserving dependency checks.

## Workflow

1. Run `node "$HELM_CORE_ROOT/scripts/plugin-suite.js" require --marketplace-root "$HELM_MARKETPLACE_ROOT" --plugin helm-core --json`.
2. Run `node "$HELM_CORE_ROOT/scripts/affordances.js" --markdown`.
3. If `bootstrap` is ready or the blockers include `missing-openspec`, route to `helm-core` and `/helm-bootstrap`.
4. Route DEFINE or REQUIREMENTS to `helm-requirements` and `/helm-requirements`.
5. Route PROTOTYPE to `helm-prototype` and `/helm-prototype`.
6. Route BUILD or FIX to `helm-development` and `/helm-implement`.
7. Route CHECK or VERIFICATION to `helm-verification` and `/helm-verify`.
8. Route RELEASE or ARCHIVE to `helm-operations` and `/helm-release` or `/helm-archive`.
9. Run the suite check with `--marketplace-root "$HELM_MARKETPLACE_ROOT"` and `--plugin helm-core --plugin <target-plugin>` before handoff.

## Required Outputs

- No lifecycle artifacts are written.
- Return the target plugin, command, blockers, and next legal action.
- When OpenSpec is missing, the required output must name `/helm-bootstrap`.

## Stop Conditions

- The target plugin is missing.
- The requested action is not legal.
- A required upstream artifact is blocked.
- A legacy monolithic route would be needed.

## Validation

- The target plugin require command must pass or report the exact blocker.
