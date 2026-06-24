---
name: helm-route
description: Use this skill when the user asks Helm to route an ambiguous request, continue a stage, choose the next legal lifecycle action, or translate product intent into the correct Helm plugin command without bypassing OpenSpec gates.
---

# Helm Route

## Purpose

Route user intent to the right Helm plugin while preserving dependency checks.

## Workflow

1. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --json`.
2. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --markdown`.
3. Route DEFINE or REQUIREMENTS to `helm-requirements` and `/helm-requirements`.
4. Route PROTOTYPE to `helm-prototype` and `/helm-prototype`.
5. Route BUILD or FIX to `helm-development` and `/helm-implement`.
6. Route CHECK or VERIFICATION to `helm-verification` and `/helm-verify`.
7. Route RELEASE or ARCHIVE to `helm-operations` and `/helm-release` or `/helm-archive`.
8. Run the suite check with `--marketplace-root "$CLAUDE_PLUGIN_ROOT/../.."` and `--plugin helm-core --plugin <target-plugin>` before handoff.

## Required Outputs

- No lifecycle artifacts are written.
- Return the target plugin, command, blockers, and next legal action.

## Stop Conditions

- The target plugin is missing.
- The requested action is not legal.
- A required upstream artifact is blocked.
- A legacy monolithic route would be needed.

## Validation

- The target plugin require command must pass or report the exact blocker.
