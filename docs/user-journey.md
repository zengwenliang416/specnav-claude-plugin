# SpecNav User Journey

This page describes how a user moves from a fresh project to the first guarded
SpecNav change. SpecNav is the OpenSpec lifecycle plugin suite for navigating
AI-assisted development through explicit specs and gates.

## First Run

1. Install and enable all six plugins from the marketplace root.
2. Start a new Claude Code session.
3. In the target project, run `/specnav-doctor`.
4. Run `/specnav`.
5. If SpecNav reports `missing-openspec`, run `/specnav-bootstrap`.
6. Run `/specnav-status`.
7. Run `/specnav-requirements`.

SpecNav must report exact blockers. It must not continue with inferred state when a
required OpenSpec artifact, plugin, hook, or contract is missing.

## Empty Project

When neither `openspec/` nor `.specnav.json` exists, SpecNav is inactive until the user
opts in.

Expected path:

```text
/specnav
  -> /specnav-bootstrap
  -> /specnav-status
  -> /specnav-requirements
```

`/specnav-bootstrap` writes:

- `openspec/`
- `openspec/.specnav/workflow-state.json`
- `openspec/.specnav/context/*.jsonl`
- `openspec/.specnav/journal/index.md`
- project-root `.specnav.json`

## Existing OpenSpec Project

If `openspec/` already exists, start with `/specnav-status`. The status output must
show:

- active change;
- ready actions;
- blockers;
- risk tier;
- verification status;
- stale verification state.

If active change is ambiguous, set `SPECNAV_CHANGE` or repair
`openspec/.specnav/active-change`.

## Missing Foundation Specs

Requirements cannot start until these specs exist and pass validation:

- `openspec/specs/ui-design/design.md`
- `openspec/specs/system-architecture/design.md`
- `openspec/specs/frontend-backend-data-flow/design.md`
- `openspec/specs/component-architecture/design.md`

Expected path:

```text
/specnav-requirements
  -> specnav-repository-discovery
  -> specnav-foundation-specs
  -> /specnav-requirements
```

Repository discovery gathers evidence and questions. It does not make foundation
specs valid by itself.

## Stage Path

| Stage | Command | Success signal | Next command |
| --- | --- | --- | --- |
| Bootstrap | `/specnav-bootstrap` | workflow state written | `/specnav-status` |
| Spec discovery | `specnav-repository-discovery` | discovery report written | `specnav-foundation-specs` |
| Requirements | `/specnav-requirements` | requirements artifacts valid | `/specnav-prototype` |
| Prototype | `/specnav-prototype` | prototype decision approved | `/specnav-implement` |
| Development | `/specnav-implement` | development handoff complete | `/specnav-verify` |
| Verification | `/specnav-verify` | aggregate report green | `/specnav-release` |
| Operations | `/specnav-release` | readiness approved | `/specnav-archive` |

## Blocker Handling

| Blocker | Repair path |
| --- | --- |
| `missing-openspec` | `/specnav-bootstrap` |
| `active-change` | set `SPECNAV_CHANGE` or repair `.specnav/active-change` |
| `missing-foundation-spec:*` | `specnav-repository-discovery`, then `specnav-foundation-specs` |
| `invalid-foundation-spec-*` | repair the reported spec, rerun `foundation-specs.js` |
| `unresolved-gaps:*` | ask the user one decision at a time, then update the owning spec |
| stale verification | `/specnav-verify` or `specnav-verify-rerun` |
