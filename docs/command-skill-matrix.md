# Command and Skill Matrix

This matrix is the user-facing contract for SpecNav's public commands and primary
skills.

| Stage | Command | Owning plugin | Primary skills | First check | Reads | Writes | Side effects | Blocking conditions | Success signal | Next |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Route | `/specnav` | `specnav-core` | `specnav-route`, `specnav-workflow` | `plugin-suite.js`, `affordances.js` | plugin suite, OpenSpec state | none | reports next legal action | missing plugin, missing OpenSpec, blocked action | target command selected | stage command |
| Bootstrap | `/specnav-bootstrap` | `specnav-core` | `specnav-bootstrap` | `specnav-bootstrap.js` | project root, OpenSpec CLI | `openspec/`, `.specnav/`, `.specnav.json` | opts project into SpecNav | OpenSpec init failure | workflow state written | `/specnav-status` |
| Status | `/specnav-status` | `specnav-core` | `specnav-status` | `workflow-state.js` | `.specnav`, OpenSpec status, plugin suite | derived state/context snapshots | read-only status | missing plugin/state | ready actions visible | next ready command |
| Doctor | `/specnav-doctor` | `specnav-core` | `specnav-doctor` | `specnav-doctor.js` | plugin cache, hooks, commands, skills, OpenSpec | none | diagnostics only | failed health check | `status: ready` | `/specnav` |
| Spec discovery | `/specnav-requirements` | `specnav-requirements` | `specnav-repository-discovery` | `repository-discovery.js` | repository files, existing specs | `openspec/.specnav/context/repository-discovery.json` | evidence gathering | invalid evidence, unresolved questions | discovery contract valid | `specnav-foundation-specs` |
| Foundation specs | `/specnav-requirements` | `specnav-requirements` | `specnav-foundation-specs` | `foundation-specs.js` | discovery report, four specs | `openspec/specs/*/design.md` | durable spec repair | missing/invalid specs, unresolved decisions | foundation validator green | `specnav-requirements` |
| Requirements | `/specnav-requirements` | `specnav-requirements` | `specnav-requirements` | `requirements-contract.js` | foundation specs, active change | `requirements.md`, `acceptance.md`, `spec-map.json`, `component-impact-map.json` | asks one decision at a time | active change, unresolved gaps, invalid artifacts | requirements contract green | `/specnav-prototype` |
| Prototype | `/specnav-prototype` | `specnav-prototype` | `specnav-prototype`, `specnav-prototype-verify`, `specnav-prototype-handoff` | `prototype-contract.js` | requirements artifacts, design context | `prototype/` artifacts, verifier report, decision, handoff | creates reviewable prototype | missing context, verifier red, no user approval | handoff approved | `/specnav-implement` |
| Development | `/specnav-implement` | `specnav-development` | `specnav-development-entry`, `specnav-scope-lock`, `specnav-vertical-slices` | `development-contract.js` | requirements, prototype handoff, scope | `scope.json`, task artifacts, production edits | guarded code changes | invalid scope, drift, review failure | development handoff complete | `/specnav-verify` |
| Verification | `/specnav-verify` | `specnav-verification` | six `specnav-verify-*` skills | `verify-domains.js` | development handoff, specs, tests | six-domain evidence, aggregate report | test/audit execution | missing evidence, stale report, red domain | aggregate green | `/specnav-release` |
| Operations | `/specnav-release`, `/specnav-archive` | `specnav-operations` | `specnav-ops-readiness`, `specnav-release-plan`, `specnav-rollback`, `specnav-update-spec` | `operations-gate.js`, `archive-gate.js` | green verification, git/docs/release target | `operations/` readiness and release artifacts | release/archive governance | verify not green, ambiguous target, missing ops artifact | readiness approved | archive/writeback |

## User Question Policy

- Ask one question at a time.
- Do not ask questions already answered by foundation specs or repository
  discovery evidence.
- Include a recommended answer and tradeoff when asking for a missing decision.
- If the answer changes foundation specs, update the owning spec before moving to
  requirements, prototype, or development.
