---
name: before-dev
description: Validate Helm development entry gates and record the before-dev basis
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# Before Dev

Run the development contract first and use the JSON as the source of truth:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --mode entry --json
```

If it reports `prototype-blocked` or any `prototype:*` blocker, stop and route back to the owning upstream stage. Development must consume the approved prototype contract; do not create fallback decisions, infer a newer change, or implement an independent `not_required` bypass.

When upstream gates pass, read only the active change reported by the contract:

- `openspec/specs/ui-design/design.md`
- `openspec/specs/system-architecture/design.md`
- `openspec/specs/frontend-backend-data-flow/design.md`
- `openspec/specs/component-architecture/design.md`
- `openspec/changes/<active-change>/requirements.md`
- `openspec/changes/<active-change>/acceptance.md`
- `openspec/changes/<active-change>/spec-map.json`
- `openspec/changes/<active-change>/component-impact-map.json`
- `openspec/changes/<active-change>/prototype/handoff.md`
- `openspec/changes/<active-change>/prototype/decision.json`
- approved prototype entry reported by `prototype/prototype-manifest.json`

Write or repair:

- `openspec/changes/<active-change>/development/before-dev-check.json`
- `openspec/changes/<active-change>/development/basis.md`

`before-dev-check.json` must record the active change and a passing status. `basis.md` must include exact relative path references to all four foundation specs, the active change requirements, acceptance, spec map, component impact map, prototype handoff, prototype decision, and approved prototype entry source.

No fallback is allowed. If a required product, architecture, data-flow, or component-boundary decision is missing, report the blocker and stop instead of inventing a new decision.

After writing artifacts, rerun:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --mode entry --json
```

Continue only when the entry gate returns `"ok": true`.
