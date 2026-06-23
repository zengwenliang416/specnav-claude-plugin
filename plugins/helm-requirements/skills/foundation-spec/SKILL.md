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

Use the validator output as the source of truth. Fix the exact blockers reported for each spec and only the reported gaps. Do not create substitute files, move specs elsewhere, infer answers, or treat adjacent docs as satisfying a blocker.

Required project-level specs:

- `openspec/specs/ui-design/design.md`
- `openspec/specs/system-architecture/design.md`
- `openspec/specs/frontend-backend-data-flow/design.md`
- `openspec/specs/component-architecture/design.md`

If a required spec is missing, create it at the exact reported path. For `ui-design`, include YAML frontmatter with the required keys reported by the validator, then include the required Markdown sections. For any other spec, create only the required Markdown section contract reported by the validator.

If a spec is invalid, repair only the reported category:

- Missing sections: add only headings listed in `missing_sections`.
- Frontmatter keys: add only keys listed in `missing_frontmatter_keys`.
- Frontmatter values / YAML parseability: make the frontmatter parseable YAML and repair only paths listed in `invalid_frontmatter_values` or the reported `frontmatter_error`.
- Token references: repair only references listed in `invalid_token_references`.
- Theme parity / component contract shape: align the reported light/dark companion specs so their token and component contract shape match without changing unrelated design decisions.

Preserve existing decisions and wording outside the reported gaps.

After each edit, rerun:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/foundation-specs.js" --json
```

Proceed only when the validator returns `"ok": true`. If it remains blocked, report the exact blockers and stop. Do not continue to `requirements` until every foundation spec is valid.
