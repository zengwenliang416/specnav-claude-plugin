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
node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --json
```

If it reports `prototype-blocked` or any `prototype:*` blocker, stop and route back to the owning upstream stage. Development must consume the approved prototype contract; do not create fallback decisions, infer a newer change, or implement an independent `not_required` bypass.

When upstream gates pass, read only the active change reported by the contract:

- `openspec/changes/<active-change>/requirements.md`
- `openspec/changes/<active-change>/acceptance.md`
- `openspec/changes/<active-change>/spec-map.json`
- `openspec/changes/<active-change>/component-impact-map.json`
- `openspec/changes/<active-change>/prototype/handoff.md`
- `openspec/changes/<active-change>/prototype/decision.json`

Write or repair:

- `openspec/changes/<active-change>/development/before-dev-check.json`
- `openspec/changes/<active-change>/development/basis.md`

`before-dev-check.json` must record the active change and a passing status. `basis.md` must state which requirements, prototype handoff decisions, and approved prototype variant development is allowed to rely on.

No fallback is allowed. If a required product, architecture, data-flow, or component-boundary decision is missing, report the blocker and stop instead of inventing a new decision.

After writing artifacts, rerun:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --json
```

Continue only when the remaining blockers belong to later development artifacts that have not been produced yet.
