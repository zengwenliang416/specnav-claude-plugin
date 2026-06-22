---
name: implement
description: "Implement the active Helm task list within declared scope"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - MultiEdit
  - Glob
  - Grep
---

# Helm Implement

Before editing, run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --markdown
```

Rules:

- Implement only when `implement` is ready.
- Stay inside declared file scope from `design.md`.
- Do not edit `tests/acceptance/` during implementation.
- Write and iterate unit/integration tests freely.
- Update `tasks.md` checkboxes when work is done.

After edits, run the relevant local tests, then `verify`.
