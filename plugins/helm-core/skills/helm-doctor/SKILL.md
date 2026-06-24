---
name: helm-doctor
description: Use this skill when the user asks to diagnose Helm installation, plugin discovery, hook wiring, OpenSpec availability, suite dependency health, command exposure, or why a Helm command or skill is unavailable.
---

# Helm Doctor

## Purpose

Diagnose Helm installation and runtime surfaces from direct evidence.

## Workflow

1. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/helm-doctor.js" --json`.
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
