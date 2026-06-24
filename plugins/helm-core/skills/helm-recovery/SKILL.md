---
name: helm-recovery
description: Use this skill when Helm is stuck in a repeated loop, repeats a failed gate, keeps asking the same question, has conflicting stage artifacts, or needs a safe recovery route without bypassing OpenSpec evidence.
---

# Helm Recovery

## Purpose

Break repeated Helm loops by naming the blocker and routing to the smallest valid repair.

## Workflow

1. Collect state with `node "$CLAUDE_PLUGIN_ROOT/scripts/workflow-state.js" --json`.
2. Collect legal actions with `node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --markdown`.
3. Identify the loop type: repeated question, repeated validation failure, stale change, missing artifact, contradictory artifact, or missing plugin.
4. Choose one owning stage and one repair artifact.
5. Ask one focused user question only when a decision is actually needed.

## Required Outputs

- A recovery route, blocker classification, or minimum repaired artifact.

## Stop Conditions

- OpenSpec is missing.
- The owning plugin is missing.
- The repair requires unresolved user input.
- A stage would be marked complete without its gate.

## Validation

- Recovery succeeds only when the repeated command no longer reports the same blocker or the exact unresolved blocker is documented.
