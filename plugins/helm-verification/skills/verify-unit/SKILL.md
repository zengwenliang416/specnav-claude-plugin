---
name: verify-unit
description: Validate focused unit and regression coverage for a Helm change
allowed-tools:
  - Read
  - Bash
  - Write
---

# Verify Unit

Read `verify/plan.json`, development task reports, and changed-file traceability. Confirm the changed logic has behavior-facing unit or regression coverage for critical paths, edge cases, empty states, error paths, and boundary inputs.

Tests must verify stable public behavior, not private methods, internal collaborator call counts, or implementation-only mocks.

Write:

- `verify/unit/test-map.json`
- `verify/unit/test-quality-rubric.json`
- `verify/unit/coverage-notes.md`
- `verify/unit/report.md`
- `verify/unit/report.json`

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json
```
