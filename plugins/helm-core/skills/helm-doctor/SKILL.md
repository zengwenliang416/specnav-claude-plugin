---
name: helm-doctor
description: Use this skill when the user asks to diagnose Helm installation, plugin discovery, hook wiring, OpenSpec availability, suite dependency health, command exposure, or why a Helm command or skill is unavailable.
---

## Runtime Paths

Resolve every `HELM_*_ROOT` variable with the owning Helm command's installed-cache resolver before running Bash. Do not rely on `CLAUDE_PLUGIN_ROOT`; it is only guaranteed inside Claude Code hook processes. If a required installed plugin root cannot be resolved, report the exact blocker and stop.

# Helm Doctor

## Purpose

Diagnose Helm installation and runtime surfaces from direct evidence.

## Workflow

1. Run `node "$HELM_CORE_ROOT/scripts/helm-doctor.js" --json`.
2. Report plugin roots, marketplace root, hook status, OpenSpec status, contract scripts, and blockers.
3. For missing plugins, report `missing-plugin:<name>` and the expected discovery root.
4. For missing hook or command exposure, report the exact path named by doctor evidence.

## Required Outputs

- A doctor report in chat.
- Any runtime diagnostic files written by the doctor script.

## Stop Conditions

- Doctor exits non-zero.
- A required plugin, hook, command, or OpenSpec surface is missing.
- Fresh support evidence is unavailable.

## Validation

- Doctor is valid only with current `helm-doctor.js --json` output.
