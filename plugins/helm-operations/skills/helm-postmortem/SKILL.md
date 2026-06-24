---
name: helm-postmortem
description: Use this skill when Helm verification, release, deploy, rollback, security, data, availability, repeated failure, or risk evidence requires a postmortem and learning capture.
---

# Helm Postmortem

## Purpose

Record operational learning after failures or risk events.

## Workflow

1. Write a postmortem when evidence requires one.
2. Include trigger, root cause, impact, mitigation, follow-up, and whether learning must be written back to OpenSpec.
3. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` after writing.

## Required Outputs

- `operations/postmortem.md`.

## Stop Conditions

- Root cause lacks evidence.
- Impact cannot be described from evidence.
- Required writeback is not classified.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` and require ok or exact blockers.
