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
4. If the user asks to establish or repair complete project specs, project standards, foundation specs, UI design, system architecture, frontend-backend data flow, or component architecture constraints, require `helm-requirements`, run `node "$HELM_REQUIREMENTS_ROOT/scripts/foundation-specs.js" --json`, and route directly to `helm-requirements` with `/helm-requirements` plus the `helm-foundation-specs` skill when the contract reports missing or invalid foundation specs.
5. Existing `openspec/specs/development-conventions/*` files do not satisfy foundation specs by themselves. The route is still `helm-foundation-specs` until `ui-design`, `system-architecture`, `frontend-backend-data-flow`, and `component-architecture` all pass `foundation-specs.js`.
6. Do not ask the user to choose a generic route when foundation-spec blockers are exact and the request is to build complete project specs.
7. Route DEFINE or REQUIREMENTS to `helm-requirements` and `/helm-requirements`.
8. Route PROTOTYPE to `helm-prototype` and `/helm-prototype`.
9. Route BUILD or FIX to `helm-development` and `/helm-implement`.
10. Route CHECK or VERIFICATION to `helm-verification` and `/helm-verify`.
11. Route RELEASE or ARCHIVE to `helm-operations` and `/helm-release` or `/helm-archive`.
12. Run the suite check with `--marketplace-root "$HELM_MARKETPLACE_ROOT"` and `--plugin helm-core --plugin <target-plugin>` before handoff.

## Required Outputs

- No lifecycle artifacts are written.
- Return the target plugin, command, blockers, and next legal action.
- When OpenSpec is missing, the required output must name `/helm-bootstrap`.
- When foundation specs are missing or invalid, the required output must name `helm-foundation-specs` and list the exact foundation-spec blockers.

## Stop Conditions

- The target plugin is missing.
- The requested action is not legal.
- A required upstream artifact is blocked.
- A legacy monolithic route would be needed.

## Validation

- The target plugin require command must pass or report the exact blocker.
