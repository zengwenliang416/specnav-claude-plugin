---
name: helm-workflow
description: Use this skill when the user wants to start, continue, or understand the Helm OpenSpec lifecycle, including use Helm, continue, next step, requirements, prototype, implement, verify, release, archive, or inspect legal actions.
---

# Helm Workflow

## Purpose

Control the top-level Helm lifecycle and keep work inside the installed multi-plugin suite.

## Workflow

1. Require core with `node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --json`.
2. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --markdown` and treat it as the legal action table.
3. If `bootstrap` is ready or the blockers include `missing-openspec`, route to `/helm-bootstrap` and do not enter requirements yet.
4. Match the request to requirements, prototype, development, verification, or operations.
5. Before routing, require the target with `node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --plugin <target-plugin> --json`.
6. If the request is blocked, report the blocker and route to the owning Helm skill instead of using fallback behavior.

## Required Outputs

- No production artifact is written by this skill.
- Return selected stage, target plugin, ready action, blockers, and the exact next command.

## Stop Conditions

- OpenSpec is missing and `/helm-bootstrap` has been reported as the next command.
- The core plugin or target plugin cannot be resolved.
- The affordances table blocks the requested action.
- The user asks to skip a required stage gate.

## Validation

- The suite resolver must pass for `--plugin helm-core --plugin <target-plugin>` before handoff.
