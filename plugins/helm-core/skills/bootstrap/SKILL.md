---
name: bootstrap
description: "Initialize Helm/OpenSpec state for an existing repository"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Task
---

# Helm Bootstrap

Use for brownfield onboarding.

1. Inspect repo layout and current project instructions.
2. If OpenSpec is unavailable, run or recommend `openspec init`.
3. Create the minimal covered boundary. Do not demand specs for the whole repo.
4. Write baseline notes under `openspec/specs/` and Helm state under `openspec/.helm/`.
5. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --write-snapshot --markdown`.

Prefer invoking the `explorer` agent for read-only investigation.
