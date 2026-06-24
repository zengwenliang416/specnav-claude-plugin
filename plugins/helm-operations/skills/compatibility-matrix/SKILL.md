---
name: compatibility-matrix
description: Document host compatibility and support evidence
allowed-tools:
  - Read
  - Bash
  - Write
---

# Compatibility Matrix

Review install verification, doctor output, host limitations, and reload behavior. Do not claim fresh support without fresh smoke evidence.

Write:

- `operations/compatibility-matrix.md`

Include supported hosts, support level, verification command, doctor result, known limitations, and reload requirement.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```
