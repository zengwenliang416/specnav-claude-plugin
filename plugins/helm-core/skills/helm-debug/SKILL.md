---
name: helm-debug
description: Use this skill when a Helm command, hook, contract, plugin resolver, state file, or stage handoff fails and the user wants root-cause debugging rather than normal lifecycle progress.
---

## Runtime Paths

Resolve every `HELM_*_ROOT` variable with the owning Helm command's installed-cache resolver before running Bash. Do not rely on `CLAUDE_PLUGIN_ROOT`; it is only guaranteed inside Claude Code hook processes. If a required installed plugin root cannot be resolved, report the exact blocker and stop.

# Helm Debug

## Purpose

Debug Helm failures with current command output, files, and blockers.

## Workflow

1. Reproduce the failing Helm command with the same project directory and plugin root.
2. Run `node "$HELM_CORE_ROOT/scripts/helm-doctor.js" --json`.
3. Run the owning stage contract script named by the failure.
4. Inspect files named by the blocker before broad search.
5. Classify the failure and propose the smallest repair.

## Required Outputs

- No production code by default.
- A command, exit code, blocker, owning script, and repair route.

## Stop Conditions

- The failure cannot be reproduced.
- Credentials or environment are missing.
- The blocker is a user decision rather than an artifact repair.

## Validation

- Rerun the failing command after repair and compare the blocker.
