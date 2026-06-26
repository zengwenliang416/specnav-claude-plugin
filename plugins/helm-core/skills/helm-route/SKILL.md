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

1. Run `node "$HELM_CORE_ROOT/scripts/helm-route.js" --intent "$INTENT" --json`.
2. Treat the router JSON as authoritative: `target_plugin`, `command`, `skill`, `required_plugins`, `blockers`, `confirmation_required`, and `no_fallback`.
3. If `blockers` is non-empty, report the exact blockers and stop.
4. If `confirmation_required` is true, ask before handoff.
5. If `no_fallback` is true, do not use a monolithic core lifecycle fallback.

The router itself runs `plugin-suite.js`, `affordances.js`, and, for foundation routes, `foundation-specs.js`.

Routing order:

1. Missing OpenSpec or ready bootstrap action -> `helm-core`, `/helm-bootstrap`, `helm-bootstrap`.
2. Repository discovery -> foundation -> requirements. Project standards, foundation specs, complete specs, UI design, system architecture, frontend-backend data flow, component architecture, architecture constraints, and development conventions route to `helm-requirements`, `/helm-requirements`, and `helm-foundation-specs`; the JSON also reports the discovery step before foundation work.
3. DEFINE or REQUIREMENTS -> `helm-requirements`, `/helm-requirements`, `helm-requirements`.
4. PROTOTYPE -> `helm-prototype`, `/helm-prototype`, `helm-prototype`.
5. BUILD -> `helm-development`, `/helm-implement`, `helm-development-entry`.
6. FIX -> `helm-development`, `/helm-implement`, `helm-fix`.
7. CHECK or VERIFICATION -> `helm-verification`, `/helm-verify`, `helm-verify-plan`.
8. RELEASE -> `helm-operations`, `/helm-release`, `helm-release-plan`.
9. ARCHIVE -> `helm-operations`, `/helm-archive`, `helm-branch-finish`.

Existing `openspec/specs/development-conventions/*` files do not satisfy foundation specs by themselves. The route remains `helm-foundation-specs` until `ui-design`, `system-architecture`, `frontend-backend-data-flow`, and `component-architecture` all pass `foundation-specs.js`.

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
