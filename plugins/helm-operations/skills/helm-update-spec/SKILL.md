---
name: helm-update-spec
description: Use this skill when Helm operations learning must be written back to OpenSpec, deferred with signoff, or marked no writeback needed before archive or release completion.
---

# Helm Update Spec

## Purpose

Record whether operations learning changes specs, runbooks, known limitations, requirements, UI, architecture, data-flow, or component architecture.

## Workflow

1. Review operations, verification, release, deploy, rollback, monitor, and postmortem outputs.
2. Use status `no_writeback_needed`, `written_back`, or `deferred`.
3. Any unresolved learning item blocks archive.
4. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` after writing.

## Required Outputs

- `operations/update-spec.json`.

## Stop Conditions

- Learning items are unresolved.
- Deferral lacks signoff.
- Required spec updates are not written.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` and require ok or exact blockers.
