---
name: helm-branch-finish
description: Use this skill when Helm needs to finish a git branch, review worktree state, record cleanup provenance, merge readiness, or decide whether a Helm-owned worktree can be removed.
---

# Helm Branch Finish

## Purpose

Record branch and worktree facts before finish or cleanup.

## Workflow

1. Collect git dir, common dir, current branch, base branch, worktree path, finish action, cleanup decision, and provenance.
2. Read `references/branch-finish.md` before writing cleanup decisions.
3. Preserve unknown or externally managed worktrees.
4. Use `assets/branch-finish.md` as the shell when the artifact is missing.
5. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` after writing.

## Required Outputs

- `operations/branch-finish.md`.
- Branch finish shell: `assets/branch-finish.md`.

## Stop Conditions

- Worktree ownership is unknown.
- Untracked files are unreviewed.
- Cleanup lacks Helm-owned provenance.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` and require ok or exact blockers.
