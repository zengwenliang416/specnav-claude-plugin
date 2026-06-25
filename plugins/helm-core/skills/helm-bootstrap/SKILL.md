---
name: helm-bootstrap
description: Use this skill when Helm reports missing-openspec, the user asks to initialize OpenSpec, bootstrap a project, repair a missing openspec directory, or asks what command to call before requirements can begin.
---

## Runtime Paths

Resolve every `HELM_*_ROOT` variable with the owning Helm command's installed-cache resolver before running Bash. Do not rely on `CLAUDE_PLUGIN_ROOT`; it is only guaranteed inside Claude Code hook processes. If a required installed plugin root cannot be resolved, report the exact blocker and stop.

# Helm Bootstrap

## Purpose

Initialize OpenSpec for the target project and write the minimal Helm runtime state needed for the rest of the lifecycle to become available.

## Workflow

1. Run `node "$HELM_CORE_ROOT/scripts/helm-bootstrap.js" --json`.
2. If the command returns `ok: true`, report `status`, `project_root`, `workflow_state`, and `next_actions`.
3. If the command returns `ok: false`, report the exact `blockers` and exit status.
4. Do not load requirements, prototype, development, verification, or operations skills during bootstrap.

## Required Outputs

- A concise bootstrap result.
- The exact next command list from `next_actions`.

## Stop Conditions

- `openspec` CLI is missing.
- `openspec init` fails.
- OpenSpec initialization does not create `openspec/`.
- The user asks to skip bootstrap and continue production work anyway.

## Validation

- Bootstrap succeeds only when `openspec/` exists and `openspec/.helm/workflow-state.json` is written.
