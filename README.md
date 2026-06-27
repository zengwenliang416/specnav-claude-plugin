# SpecNav Claude Code Plugin Suite

SpecNav is a multi-plugin Claude Code workflow suite built on OpenSpec. It governs
the full engineering lifecycle:

```text
bootstrap -> spec discovery -> requirements -> prototype -> development -> verification -> operations
```

SpecNav means navigating development through file-backed OpenSpec contracts:
Claude proposes and explains work, while hooks and deterministic scripts decide
what can happen next.

The repository is a local Claude Code marketplace. Each lifecycle stage is its
own plugin, while `specnav-core` owns routing, hooks, status, diagnostics, and
cross-plugin state.

Chinese documentation: [README.zh-CN.md](README.zh-CN.md)

## Install Locally

From this repository root:

```bash
claude plugin marketplace add "$PWD"
claude plugin install specnav-core@specnav-marketplace
claude plugin install specnav-requirements@specnav-marketplace
claude plugin install specnav-prototype@specnav-marketplace
claude plugin install specnav-development@specnav-marketplace
claude plugin install specnav-verification@specnav-marketplace
claude plugin install specnav-operations@specnav-marketplace
claude plugin enable specnav-core@specnav-marketplace
claude plugin enable specnav-requirements@specnav-marketplace
claude plugin enable specnav-prototype@specnav-marketplace
claude plugin enable specnav-development@specnav-marketplace
claude plugin enable specnav-verification@specnav-marketplace
claude plugin enable specnav-operations@specnav-marketplace
```

If your Claude Code build uses different plugin command names, install the local
marketplace root that contains `.claude-plugin/marketplace.json`, then verify
with:

```bash
claude plugin validate "$PWD"
claude plugin list --json
```

Start a new Claude Code session after installing or updating commands, skills,
hooks, or agents.

## First Run

After installation, use SpecNav from the target project, not from this plugin
repository.

```text
1. Run /specnav-doctor
   Confirms the six plugins, hooks, commands, skills, OpenSpec CLI, and installed
   cache are visible.

2. Run /specnav
   Reads the current affordance table and reports the next legal command.

3. If the project has no OpenSpec state, run /specnav-bootstrap
   This creates openspec/, openspec/.specnav/workflow-state.json, context manifests,
   and the project .specnav.json marker.

4. Run /specnav-status
   Confirms the active change, ready actions, blockers, risk tier, and stale
   verification state.

5. Run /specnav-requirements
   If foundation specs are missing, SpecNav routes to repository discovery and
   foundation-spec repair before feature requirements can start.
```

The detailed walkthrough is in [docs/user-journey.md](docs/user-journey.md).

## Workflow Model

| Stage | Command | Reads | Writes | Common blockers | Next |
| --- | --- | --- | --- | --- | --- |
| Bootstrap | `/specnav-bootstrap` | plugin cache, OpenSpec CLI | `openspec/`, `.specnav/`, `.specnav.json` | `missing-openspec-cli`, init failure | `/specnav-status` |
| Spec discovery | `/specnav-requirements` + `specnav-repository-discovery` | repo files, existing specs | `openspec/.specnav/context/repository-discovery.json` | missing evidence, unresolved questions | `specnav-foundation-specs` |
| Requirements | `/specnav-requirements` | foundation specs, active change | `requirements.md`, `acceptance.md`, `spec-map.json`, `component-impact-map.json` | missing/invalid foundation specs, unresolved gaps | `/specnav-prototype` |
| Prototype | `/specnav-prototype` | requirements artifacts, design context | `prototype/` artifacts, verifier report, handoff | missing context, verifier red, no approval | `/specnav-implement` |
| Development | `/specnav-implement` | requirements, prototype handoff, scope | `scope.json`, task artifacts, production edits | invalid scope, upstream drift, review failure | `/specnav-verify` |
| Verification | `/specnav-verify` | development handoff, specs, tests | six-domain `verify/` evidence, aggregate report, stakeholder HTML report | stale report, red domain, missing evidence | `/specnav-release` |
| Operations | `/specnav-release`, `/specnav-archive` | green verification, git/docs/release target | `operations/` readiness and release artifacts | verify not green, target ambiguous, ops artifact missing | archive/writeback |

For the complete command and skill matrix, see
[docs/command-skill-matrix.md](docs/command-skill-matrix.md).

## Spec Discovery

Requirements do not start from a blank prompt. SpecNav first checks four foundation
specs:

- `openspec/specs/ui-design/design.md`
- `openspec/specs/system-architecture/design.md`
- `openspec/specs/frontend-backend-data-flow/design.md`
- `openspec/specs/component-architecture/design.md`

If they are missing or incomplete, SpecNav must discover repository facts, list
inferred conventions, ask for user confirmation where needed, and only then
write or repair foundation specs. Discovery evidence does not bypass the
foundation-spec validator. See [docs/spec-discovery.md](docs/spec-discovery.md).

## Plugin Layout

```text
.claude-plugin/marketplace.json       Local marketplace manifest
plugins/specnav-core/                    Runtime, router, hooks, status, doctor
plugins/specnav-requirements/            Foundation specs and requirements grilling
plugins/specnav-prototype/               Runnable prototype artifacts and handoff
plugins/specnav-development/             Scope lock and vertical-slice implementation
plugins/specnav-verification/            Six-domain verification
plugins/specnav-operations/              Release, install, deploy, rollback, archive readiness
tests/                                Contract and fixture checks
docs/                                 Engineering design notes
```

## Public Skills

All public skills use Agent Skills frontmatter with only `name` and
`description`, and all names are `specnav-*` scoped.

- Core: `specnav-workflow`, `specnav-bootstrap`, `specnav-route`, `specnav-status`,
  `specnav-doctor`, `specnav-debug`, `specnav-recovery`
- Requirements: `specnav-repository-discovery`, `specnav-foundation-specs`,
  `specnav-requirements`
- Prototype: `specnav-prototype`, `specnav-prototype-verify`,
  `specnav-prototype-handoff`
- Development: `specnav-development-entry`, `specnav-scope-lock`,
  `specnav-vertical-slices`
- Verification: `specnav-verify-plan`, `specnav-verify-facticity`,
  `specnav-verify-static`, `specnav-verify-unit`, `specnav-verify-redteam`,
  `specnav-verify-e2e`, `specnav-verify-sensory`
- Operations: `specnav-ops-readiness`, `specnav-release-plan`,
  `specnav-install-verify`, `specnav-update-policy`,
  `specnav-compatibility-matrix`, `specnav-branch-finish`, `specnav-deploy`,
  `specnav-rollback`, `specnav-monitor`, `specnav-postmortem`, `specnav-update-spec`

## Useful Checks

```bash
bash tests/run-plugin-validate-fixtures.sh
bash tests/run-skill-contract-fixtures.sh
bash tests/run-skill-resource-fixtures.sh
bash tests/run-plugin-suite-layout-fixtures.sh
bash tests/run-plugin-suite-resolver-fixtures.sh
bash tests/run-public-hygiene-fixtures.sh
bash tests/run-core-runtime-fixtures.sh
bash tests/run-installed-cache-runtime-fixtures.sh
bash tests/run-smoke.sh
```

Stage-specific fixtures live in `tests/run-*-plugin-fixtures.sh`.

Verification aggregate output includes both machine and review artifacts:
`verify/aggregate-report.json`, `verify/aggregate-report.md`,
`verify/aggregate-report.html`, plus change-level `verify-report.json`,
`verify-report.md`, and `verify-report.html`. The HTML report uses the warm
Claude editorial style so it can be shared for stakeholder review without
opening JSON.

## Design Notes

- Main engineering contract: [docs/design.md](docs/design.md)
- First-run user journey: [docs/user-journey.md](docs/user-journey.md)
- Spec discovery contract: [docs/spec-discovery.md](docs/spec-discovery.md)
- Command and skill matrix: [docs/command-skill-matrix.md](docs/command-skill-matrix.md)
- Compatibility matrix: [docs/compatibility.md](docs/compatibility.md)
- Release checklist: [docs/release-checklist.md](docs/release-checklist.md)
- Skill-suite redesign: [docs/skill-suite-redesign.md](docs/skill-suite-redesign.md)
- Skill resource matrix: [docs/skill-resource-matrix.md](docs/skill-resource-matrix.md)
