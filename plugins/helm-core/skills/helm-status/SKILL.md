---
name: helm-status
description: Use this skill when the user asks for Helm status, current OpenSpec state, active change, blockers, ready actions, risk tier, stale verification state, or what can legally happen next.
---

# Helm Status

## Purpose

Report current Helm and OpenSpec state without changing project artifacts.

## Workflow

1. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/workflow-state.js" --json`.
2. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --markdown`.
3. Report active change, stage, risk tier, verification freshness, ready actions, and blockers.
4. Treat chat history and previous summaries as claims unless current files or scripts confirm them.

## Required Outputs

- A concise status response.
- Runtime state files under `openspec/.helm/` only when scripts write them.

## Stop Conditions

- `workflow-state.js` fails.
- `affordances.js` fails.
- OpenSpec is missing and only initialization or repair actions are legal.

## Validation

- Both commands must succeed or their exact blockers must be reported.
