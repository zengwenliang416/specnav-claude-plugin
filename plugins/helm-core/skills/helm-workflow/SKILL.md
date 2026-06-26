---
name: helm-workflow
description: Use this skill when the user wants to start, continue, or understand the Helm OpenSpec lifecycle, including use Helm, continue, next step, requirements, prototype, implement, verify, release, archive, or inspect legal actions.
---

## Runtime Paths

Resolve every `HELM_*_ROOT` variable with the owning Helm command's installed-cache resolver before running Bash. Do not rely on `CLAUDE_PLUGIN_ROOT`; it is only guaranteed inside Claude Code hook processes. If a required installed plugin root cannot be resolved, report the exact blocker and stop.

# Helm Workflow

## Purpose

Control the top-level Helm lifecycle and keep work inside the installed multi-plugin suite.

## Workflow

1. Run `node "$HELM_CORE_ROOT/scripts/helm-route.js" --intent "$INTENT" --json`.
2. Treat the JSON fields `target_plugin`, `command`, `skill`, `required_plugins`, `blockers`, `confirmation_required`, and `no_fallback` as authoritative.
3. If `blockers` is non-empty, report the exact blocker list and stop.
4. If `confirmation_required` is true, ask before handoff.
5. Route through the reported stage command and owning skill. Do not use a core fallback implementation when `no_fallback` is true.

## Required Outputs

- No production artifact is written by this skill.
- Return selected stage, target plugin, ready action, blockers, and the exact next command.

## Stop Conditions

- OpenSpec is missing and `/helm-bootstrap` has been reported as the next command.
- The core plugin or target plugin cannot be resolved.
- The router blocks the requested action.
- The user asks to skip a required stage gate.

## Validation

- `helm-route.js` must return `ok: true` before handoff.
