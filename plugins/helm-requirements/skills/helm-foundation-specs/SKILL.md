---
name: helm-foundation-specs
description: Use this skill when Helm requirements are blocked by missing or invalid foundation specs, or when the user needs to create or repair UI design, system architecture/database, frontend-backend data flow, or component architecture specs.
---

## Runtime Paths

Resolve every `HELM_*_ROOT` variable with the owning Helm command's installed-cache resolver before running Bash. Do not rely on `CLAUDE_PLUGIN_ROOT`; it is only guaranteed inside Claude Code hook processes. If a required installed plugin root cannot be resolved, report the exact blocker and stop.

# Helm Foundation Specs

## Purpose

Create or repair the four project-level foundation specs required before requirements questioning.

## Workflow

1. Run `node "$HELM_REQUIREMENTS_ROOT/scripts/foundation-specs.js" --json` first.
2. Repair only reported blockers for missing sections, frontmatter values, token references, theme parity, component contract shape, YAML parse errors, or `frontmatter_errors`.
3. Required specs are ui-design, system-architecture, frontend-backend-data-flow, and component-architecture.
4. Read `references/foundation-spec-contract.md` before creating or repairing foundation specs.
5. If required specs are missing, run `node "$HELM_REQUIREMENTS_ROOT/skills/helm-foundation-specs/scripts/create-foundation-specs.js" --json` to create skeletons from `assets/`.
6. If UI design is missing, guide the user to create the supplied Geist-style YAML token contract and Markdown guide.
7. Preserve existing decisions outside reported blockers.

## Required Outputs

- `openspec/specs/ui-design/design.md`.
- `openspec/specs/system-architecture/design.md`.
- `openspec/specs/frontend-backend-data-flow/design.md`.
- `openspec/specs/component-architecture/design.md`.
- Templates are supplied in `assets/ui-design/design.md`, `assets/system-architecture/design.md`, `assets/frontend-backend-data-flow/design.md`, and `assets/component-architecture/design.md`.

## Stop Conditions

- Required project context is absent.
- The user must supply a design or architecture decision.
- The validator remains blocked after exact repairs.

## Validation

- Rerun `node "$HELM_REQUIREMENTS_ROOT/scripts/foundation-specs.js" --json` after each edit and proceed only when `ok` is true.
