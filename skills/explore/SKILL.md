---
name: explore
description: "Investigate a codebase or problem before proposing a Helm change"
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Task
---

# Helm Explore

Use when the user asks why something behaves a certain way, how a subsystem works, or what should be built.

1. Read project instructions.
2. Use current repo evidence.
3. Prefer the `explorer` agent for bounded read-only investigation.
4. Summarize findings as candidate proposal material.

Do not write production code in this stage.
