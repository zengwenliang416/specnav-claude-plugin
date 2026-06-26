# Helm Claude Code Plugin Suite

Helm is a multi-plugin Claude Code workflow suite built on OpenSpec. It governs
the full engineering lifecycle:

```text
bootstrap -> spec discovery -> requirements -> prototype -> development -> verification -> operations
```

This is not a Kubernetes Helm chart plugin. "Helm" is the name of this
OpenSpec-driven lifecycle suite: Claude proposes and explains work, while
file-backed contracts, hooks, and deterministic scripts decide what can happen
next.

The repository is a local Claude Code marketplace. Each lifecycle stage is its
own plugin, while `helm-core` owns routing, hooks, status, diagnostics, and
cross-plugin state.

Chinese documentation: [README.zh-CN.md](README.zh-CN.md)

## Install Locally

From this repository root:

```bash
claude plugin marketplace add "$PWD"
claude plugin install helm-core@helm-marketplace
claude plugin install helm-requirements@helm-marketplace
claude plugin install helm-prototype@helm-marketplace
claude plugin install helm-development@helm-marketplace
claude plugin install helm-verification@helm-marketplace
claude plugin install helm-operations@helm-marketplace
claude plugin enable helm-core@helm-marketplace
claude plugin enable helm-requirements@helm-marketplace
claude plugin enable helm-prototype@helm-marketplace
claude plugin enable helm-development@helm-marketplace
claude plugin enable helm-verification@helm-marketplace
claude plugin enable helm-operations@helm-marketplace
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

After installation, use Helm from the target project, not from this plugin
repository.

```text
1. Run /helm-doctor
   Confirms the six plugins, hooks, commands, skills, OpenSpec CLI, and installed
   cache are visible.

2. Run /helm
   Reads the current affordance table and reports the next legal command.

3. If the project has no OpenSpec state, run /helm-bootstrap
   This creates openspec/, openspec/.helm/workflow-state.json, context manifests,
   and the project .helm.json marker.

4. Run /helm-status
   Confirms the active change, ready actions, blockers, risk tier, and stale
   verification state.

5. Run /helm-requirements
   If foundation specs are missing, Helm routes to repository discovery and
   foundation-spec repair before feature requirements can start.
```

The detailed walkthrough is in [docs/user-journey.md](docs/user-journey.md).

## Workflow Model

| Stage | Command | Reads | Writes | Common blockers | Next |
| --- | --- | --- | --- | --- | --- |
| Bootstrap | `/helm-bootstrap` | plugin cache, OpenSpec CLI | `openspec/`, `.helm/`, `.helm.json` | `missing-openspec-cli`, init failure | `/helm-status` |
| Spec discovery | `/helm-requirements` + `helm-repository-discovery` | repo files, existing specs | `openspec/.helm/context/repository-discovery.json` | missing evidence, unresolved questions | `helm-foundation-specs` |
| Requirements | `/helm-requirements` | foundation specs, active change | `requirements.md`, `acceptance.md`, `spec-map.json`, `component-impact-map.json` | missing/invalid foundation specs, unresolved gaps | `/helm-prototype` |
| Prototype | `/helm-prototype` | requirements artifacts, design context | `prototype/` artifacts, verifier report, handoff | missing context, verifier red, no approval | `/helm-implement` |
| Development | `/helm-implement` | requirements, prototype handoff, scope | `scope.json`, task artifacts, production edits | invalid scope, upstream drift, review failure | `/helm-verify` |
| Verification | `/helm-verify` | development handoff, specs, tests | six-domain `verify/` evidence and aggregate report | stale report, red domain, missing evidence | `/helm-release` |
| Operations | `/helm-release`, `/helm-archive` | green verification, git/docs/release target | `operations/` readiness and release artifacts | verify not green, target ambiguous, ops artifact missing | archive/writeback |

For the complete command and skill matrix, see
[docs/command-skill-matrix.md](docs/command-skill-matrix.md).

## Spec Discovery

Requirements do not start from a blank prompt. Helm first checks four foundation
specs:

- `openspec/specs/ui-design/design.md`
- `openspec/specs/system-architecture/design.md`
- `openspec/specs/frontend-backend-data-flow/design.md`
- `openspec/specs/component-architecture/design.md`

If they are missing or incomplete, Helm must discover repository facts, list
inferred conventions, ask for user confirmation where needed, and only then
write or repair foundation specs. Discovery evidence does not bypass the
foundation-spec validator. See [docs/spec-discovery.md](docs/spec-discovery.md).

## Plugin Layout

```text
.claude-plugin/marketplace.json       Local marketplace manifest
plugins/helm-core/                    Runtime, router, hooks, status, doctor
plugins/helm-requirements/            Foundation specs and requirements grilling
plugins/helm-prototype/               Runnable prototype artifacts and handoff
plugins/helm-development/             Scope lock and vertical-slice implementation
plugins/helm-verification/            Six-domain verification
plugins/helm-operations/              Release, install, deploy, rollback, archive readiness
tests/                                Contract and fixture checks
docs/                                 Engineering design notes
```

## Public Skills

All public skills use Agent Skills frontmatter with only `name` and
`description`, and all names are `helm-*` scoped.

- Core: `helm-workflow`, `helm-bootstrap`, `helm-route`, `helm-status`,
  `helm-doctor`, `helm-debug`, `helm-recovery`
- Requirements: `helm-repository-discovery`, `helm-foundation-specs`,
  `helm-requirements`
- Prototype: `helm-prototype`, `helm-prototype-verify`,
  `helm-prototype-handoff`
- Development: `helm-development-entry`, `helm-scope-lock`,
  `helm-vertical-slices`
- Verification: `helm-verify-plan`, `helm-verify-facticity`,
  `helm-verify-static`, `helm-verify-unit`, `helm-verify-redteam`,
  `helm-verify-e2e`, `helm-verify-sensory`
- Operations: `helm-ops-readiness`, `helm-release-plan`,
  `helm-install-verify`, `helm-update-policy`,
  `helm-compatibility-matrix`, `helm-branch-finish`, `helm-deploy`,
  `helm-rollback`, `helm-monitor`, `helm-postmortem`, `helm-update-spec`

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

## Design Notes

- Main engineering contract: [docs/design.md](docs/design.md)
- First-run user journey: [docs/user-journey.md](docs/user-journey.md)
- Spec discovery contract: [docs/spec-discovery.md](docs/spec-discovery.md)
- Command and skill matrix: [docs/command-skill-matrix.md](docs/command-skill-matrix.md)
- Compatibility matrix: [docs/compatibility.md](docs/compatibility.md)
- Release checklist: [docs/release-checklist.md](docs/release-checklist.md)
- Skill-suite redesign: [docs/skill-suite-redesign.md](docs/skill-suite-redesign.md)
- Skill resource matrix: [docs/skill-resource-matrix.md](docs/skill-resource-matrix.md)
