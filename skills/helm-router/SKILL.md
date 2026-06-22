---
name: helm-router
description: "Intent router for the Helm spec-driven Claude Code workflow"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# Helm

Use this skill when the user asks for Helm, OpenSpec-driven workflow, change status, next action, implementation, verification, fixing verifier findings, or archiving.

## Required First Step

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --markdown
```

Use the result as the legal action table. Do not invent workflow state.

## Routing

- INVESTIGATE -> `explore`
- DEFINE -> `propose`
- REFINE -> `design` / `tasks`
- BUILD -> `implement`
- FIX -> `fix`
- CHECK -> `verify`
- FINISH -> `archive`
- STATUS -> `status`

If the requested action is blocked, explain the blocker and offer the next ready action.
