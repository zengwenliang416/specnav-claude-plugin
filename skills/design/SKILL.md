---
name: design
description: "Write Helm design.md and declared file scope"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Helm Design

Write `openspec/changes/<change>/design.md`.

Required sections:

- Approach
- Alternatives considered
- File scope
- Risk notes
- Design source for UI work, if applicable

Write machine-readable file scope to `openspec/changes/<change>/scope.json`:

```json
{
  "schema_version": 1,
  "include": [
    "src/example/**",
    "tests/example/**"
  ],
  "exclude": [
    "tests/acceptance/**"
  ]
}
```

Also keep a human-readable file scope section in `design.md`:

```markdown
## File scope

- src/example/**
- tests/example/**
```

Refresh state after edits:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --write-snapshot --markdown
```
