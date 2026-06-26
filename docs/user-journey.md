# Helm User Journey

This page describes how a user moves from a fresh project to the first guarded
Helm change. Helm here means the OpenSpec lifecycle plugin suite, not Kubernetes
Helm charts.

## First Run

1. Install and enable all six plugins from the marketplace root.
2. Start a new Claude Code session.
3. In the target project, run `/helm-doctor`.
4. Run `/helm`.
5. If Helm reports `missing-openspec`, run `/helm-bootstrap`.
6. Run `/helm-status`.
7. Run `/helm-requirements`.

Helm must report exact blockers. It must not continue with inferred state when a
required OpenSpec artifact, plugin, hook, or contract is missing.

## Empty Project

When neither `openspec/` nor `.helm.json` exists, Helm is inactive until the user
opts in.

Expected path:

```text
/helm
  -> /helm-bootstrap
  -> /helm-status
  -> /helm-requirements
```

`/helm-bootstrap` writes:

- `openspec/`
- `openspec/.helm/workflow-state.json`
- `openspec/.helm/context/*.jsonl`
- `openspec/.helm/journal/index.md`
- project-root `.helm.json`

## Existing OpenSpec Project

If `openspec/` already exists, start with `/helm-status`. The status output must
show:

- active change;
- ready actions;
- blockers;
- risk tier;
- verification status;
- stale verification state.

If active change is ambiguous, set `HELM_CHANGE` or repair
`openspec/.helm/active-change`.

## Missing Foundation Specs

Requirements cannot start until these specs exist and pass validation:

- `openspec/specs/ui-design/design.md`
- `openspec/specs/system-architecture/design.md`
- `openspec/specs/frontend-backend-data-flow/design.md`
- `openspec/specs/component-architecture/design.md`

Expected path:

```text
/helm-requirements
  -> helm-repository-discovery
  -> helm-foundation-specs
  -> /helm-requirements
```

Repository discovery gathers evidence and questions. It does not make foundation
specs valid by itself.

## Stage Path

| Stage | Command | Success signal | Next command |
| --- | --- | --- | --- |
| Bootstrap | `/helm-bootstrap` | workflow state written | `/helm-status` |
| Spec discovery | `helm-repository-discovery` | discovery report written | `helm-foundation-specs` |
| Requirements | `/helm-requirements` | requirements artifacts valid | `/helm-prototype` |
| Prototype | `/helm-prototype` | prototype decision approved | `/helm-implement` |
| Development | `/helm-implement` | development handoff complete | `/helm-verify` |
| Verification | `/helm-verify` | aggregate report green | `/helm-release` |
| Operations | `/helm-release` | readiness approved | `/helm-archive` |

## Blocker Handling

| Blocker | Repair path |
| --- | --- |
| `missing-openspec` | `/helm-bootstrap` |
| `active-change` | set `HELM_CHANGE` or repair `.helm/active-change` |
| `missing-foundation-spec:*` | `helm-repository-discovery`, then `helm-foundation-specs` |
| `invalid-foundation-spec-*` | repair the reported spec, rerun `foundation-specs.js` |
| `unresolved-gaps:*` | ask the user one decision at a time, then update the owning spec |
| stale verification | `/helm-verify` or `helm-verify-rerun` |
