# Helm Claude Code Plugin Suite

Helm is a multi-plugin Claude Code workflow suite built on OpenSpec. It governs
the full engineering lifecycle:

```text
requirements -> prototype -> development -> verification -> operations
```

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
with `claude plugin list --json`.

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
- Requirements: `helm-foundation-specs`, `helm-requirements`
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
bash tests/run-core-runtime-fixtures.sh
bash tests/run-smoke.sh
```

Stage-specific fixtures live in `tests/run-*-plugin-fixtures.sh`.

## Design Notes

- Main engineering contract: [docs/design.md](docs/design.md)
- Skill-suite redesign: [docs/skill-suite-redesign.md](docs/skill-suite-redesign.md)
- Skill resource matrix: [docs/skill-resource-matrix.md](docs/skill-resource-matrix.md)
