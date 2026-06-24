---
name: branch-finish
description: Record branch finish and worktree cleanup decision
allowed-tools:
  - Read
  - Bash
  - Write
---

# Branch Finish

Record git/worktree facts before finish. Branch finish is separate from OpenSpec archive and must preserve unknown or externally managed worktrees.

Write:

- `operations/branch-finish.md`

Include git dir, common dir, current branch, base branch, worktree path, finish action, cleanup decision, and provenance. Cleanup is allowed only with explicit Helm-owned provenance.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```
