---
name: requirements
description: Discover Helm requirements after foundation specs pass
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Requirements

Run foundation validation first:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/foundation-specs.js" --json
```

If foundation validation is blocked, stop requirements discovery and route to `foundation-spec` with the exact blockers. Do not ask feature questions until all four foundation specs pass.

When foundation validation passes, read all four specs before asking the user any product question:

- `openspec/specs/ui-design/design.md`
- `openspec/specs/system-architecture/design.md`
- `openspec/specs/frontend-backend-data-flow/design.md`
- `openspec/specs/component-architecture/design.md`

Ask one focused question at a time. Do not ask for information already present in foundation specs, current code, OpenSpec artifacts, or previous answers.

For the active change, write or repair these artifacts in `openspec/changes/<change>/`:

- `requirements.md`
- `acceptance.md`
- `spec-map.json`
- `component-impact-map.json`

`spec-map.json` must identify which foundation specs, UI rules, architecture modules, API contracts, database entities, permissions, operational constraints, and data flows are touched by the change. Use an `unresolved_gaps` array for known missing decisions instead of inventing answers.

`component-impact-map.json` must identify new components, reused components, extraction triggers, forbidden dependencies, hooks/utilities/services to extract, and required component tests. Use an `unresolved_gaps` array for known missing decisions instead of inventing answers.

Then run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/requirements-contract.js" --json
```

If the contract is blocked, report the exact blockers and stop. Do not proceed to prototype, development, or verification until it returns `"ok": true`.
