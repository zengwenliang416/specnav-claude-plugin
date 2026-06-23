---
name: fix
description: "Address non-green Helm verify reports"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - MultiEdit
  - Glob
  - Grep
---

# Helm Fix

Use after `verify-report.md` is non-green.

1. Read `verify-report.md` and `verify-report.json`.
2. Route each finding:
   - implementation -> implement
   - design -> design
   - task/contract -> tasks
   - external-dependency -> design or proposal
3. Make the smallest required change.
4. Run `verify` again.

Do not archive with a stale or non-green report.
