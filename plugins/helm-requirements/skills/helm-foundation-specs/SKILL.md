---
name: helm-foundation-specs
description: Use this skill when Helm requirements are blocked by missing or invalid foundation specs, or when the user needs to create or repair UI design, system architecture/database, frontend-backend data flow, or component architecture specs.
---

# Helm Foundation Specs

## Purpose

Create or repair the four project-level foundation specs required before requirements questioning.

## Workflow

1. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/foundation-specs.js" --json` first.
2. Repair only reported blockers for missing sections, frontmatter values, token references, theme parity, component contract shape, YAML parse errors, or `frontmatter_errors`.
3. Required specs are ui-design, system-architecture, frontend-backend-data-flow, and component-architecture.
4. If UI design is missing, guide the user to create the supplied Geist-style YAML token contract and Markdown guide.
5. Preserve existing decisions outside reported blockers.

## Required Outputs

- `openspec/specs/ui-design/design.md`.
- `openspec/specs/system-architecture/design.md`.
- `openspec/specs/frontend-backend-data-flow/design.md`.
- `openspec/specs/component-architecture/design.md`.

## Stop Conditions

- Required project context is absent.
- The user must supply a design or architecture decision.
- The validator remains blocked after exact repairs.

## Validation

- Rerun `node "$CLAUDE_PLUGIN_ROOT/scripts/foundation-specs.js" --json` after each edit and proceed only when `ok` is true.
