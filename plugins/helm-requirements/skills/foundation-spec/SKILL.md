---
name: foundation-spec
description: Create or repair Helm project-level foundation specs before requirements work
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# Foundation Spec

Run the validator first:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/foundation-specs.js" --json
```

If a required spec is missing, create it at the exact reported path. Do not create substitute files, move the spec elsewhere, or infer that a different artifact satisfies the blocker.

Required project-level specs:

- `openspec/specs/ui-design/design.md`
- `openspec/specs/system-architecture/design.md`
- `openspec/specs/frontend-backend-data-flow/design.md`
- `openspec/specs/component-architecture/design.md`

If `ui-design` is missing or invalid, include YAML frontmatter with the required keys reported by the validator, then include the required Markdown sections. If any other spec is missing, create only the required Markdown section contract reported by the validator.

If a spec is invalid, repair only the missing sections or frontmatter keys in the validator report. Preserve existing decisions and wording outside the reported gaps.

After each edit, rerun:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/foundation-specs.js" --json
```

Proceed only when the validator returns `"ok": true`. If it remains blocked, report the exact blockers and stop.
