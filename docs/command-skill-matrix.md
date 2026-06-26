# Command and Skill Matrix

This matrix is the user-facing contract for Helm's public commands and primary
skills.

| Stage | Command | Owning plugin | Primary skills | First check | Reads | Writes | Side effects | Blocking conditions | Success signal | Next |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Route | `/helm` | `helm-core` | `helm-route`, `helm-workflow` | `plugin-suite.js`, `affordances.js` | plugin suite, OpenSpec state | none | reports next legal action | missing plugin, missing OpenSpec, blocked action | target command selected | stage command |
| Bootstrap | `/helm-bootstrap` | `helm-core` | `helm-bootstrap` | `helm-bootstrap.js` | project root, OpenSpec CLI | `openspec/`, `.helm/`, `.helm.json` | opts project into Helm | OpenSpec init failure | workflow state written | `/helm-status` |
| Status | `/helm-status` | `helm-core` | `helm-status` | `workflow-state.js` | `.helm`, OpenSpec status, plugin suite | derived state/context snapshots | read-only status | missing plugin/state | ready actions visible | next ready command |
| Doctor | `/helm-doctor` | `helm-core` | `helm-doctor` | `helm-doctor.js` | plugin cache, hooks, commands, skills, OpenSpec | none | diagnostics only | failed health check | `status: ready` | `/helm` |
| Spec discovery | `/helm-requirements` | `helm-requirements` | `helm-repository-discovery` | `repository-discovery.js` | repository files, existing specs | `openspec/.helm/context/repository-discovery.json` | evidence gathering | invalid evidence, unresolved questions | discovery contract valid | `helm-foundation-specs` |
| Foundation specs | `/helm-requirements` | `helm-requirements` | `helm-foundation-specs` | `foundation-specs.js` | discovery report, four specs | `openspec/specs/*/design.md` | durable spec repair | missing/invalid specs, unresolved decisions | foundation validator green | `helm-requirements` |
| Requirements | `/helm-requirements` | `helm-requirements` | `helm-requirements` | `requirements-contract.js` | foundation specs, active change | `requirements.md`, `acceptance.md`, `spec-map.json`, `component-impact-map.json` | asks one decision at a time | active change, unresolved gaps, invalid artifacts | requirements contract green | `/helm-prototype` |
| Prototype | `/helm-prototype` | `helm-prototype` | `helm-prototype`, `helm-prototype-verify`, `helm-prototype-handoff` | `prototype-contract.js` | requirements artifacts, design context | `prototype/` artifacts, verifier report, decision, handoff | creates reviewable prototype | missing context, verifier red, no user approval | handoff approved | `/helm-implement` |
| Development | `/helm-implement` | `helm-development` | `helm-development-entry`, `helm-scope-lock`, `helm-vertical-slices` | `development-contract.js` | requirements, prototype handoff, scope | `scope.json`, task artifacts, production edits | guarded code changes | invalid scope, drift, review failure | development handoff complete | `/helm-verify` |
| Verification | `/helm-verify` | `helm-verification` | six `helm-verify-*` skills | `verify-domains.js` | development handoff, specs, tests | six-domain evidence, aggregate report | test/audit execution | missing evidence, stale report, red domain | aggregate green | `/helm-release` |
| Operations | `/helm-release`, `/helm-archive` | `helm-operations` | `helm-ops-readiness`, `helm-release-plan`, `helm-rollback`, `helm-update-spec` | `operations-gate.js`, `archive-gate.js` | green verification, git/docs/release target | `operations/` readiness and release artifacts | release/archive governance | verify not green, ambiguous target, missing ops artifact | readiness approved | archive/writeback |

## User Question Policy

- Ask one question at a time.
- Do not ask questions already answered by foundation specs or repository
  discovery evidence.
- Include a recommended answer and tradeoff when asking for a missing decision.
- If the answer changes foundation specs, update the owning spec before moving to
  requirements, prototype, or development.
