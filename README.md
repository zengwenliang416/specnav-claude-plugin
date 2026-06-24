# Helm Claude Code Plugin

Helm is a spec-driven workflow plugin for Claude Code. It sits on top of OpenSpec and gives Claude a governed loop:

`explore -> propose -> design -> tasks -> implement -> verify -> fix -> archive`

This repository is a local marketplace containing six plugins. Task 1 split the suite boundaries from the implementation plan:

- workflow: commands and skills
- core guardrails: hook scripts and shared runtime helpers
- stage plugins: requirements, prototype, development, verification, and operations

## Install Locally

From a Claude Code environment, add this plugin marketplace root:

```bash
claude plugin marketplace add "$PWD"
claude plugin install helm-core@helm-marketplace
claude plugin install helm-requirements@helm-marketplace
claude plugin install helm-prototype@helm-marketplace
claude plugin install helm-development@helm-marketplace
claude plugin install helm-verification@helm-marketplace
claude plugin install helm-operations@helm-marketplace
```

If your Claude Code build uses a different plugin command spelling, install the local marketplace root that contains `.claude-plugin/marketplace.json`.

## Project Layout

```text
.claude-plugin/marketplace.json       Local plugin marketplace manifest
plugins/helm-core/                    Router, core commands, hooks, and shared scripts
plugins/helm-requirements/            Requirements stage commands and skills
plugins/helm-prototype/               Prototype stage commands and skills
plugins/helm-development/             Development stage commands and skills
plugins/helm-verification/            Verification stage commands and skills
plugins/helm-operations/              Release and archive stage commands and skills
tests/                                Smoke and fixture checks
docs/                                 Engineering design notes
```

Design details: [docs/design.md](docs/design.md).

## Project State

Helm expects project-local state under:

```text
openspec/
  .helm/
    active-change
    affordances.json
    events.jsonl
  changes/<change>/
    proposal.md
    design.md
    scope.json
    tasks.md
    specs/
    risk-tier.json
    verify-report.md
    verify-report.json
    signoff.yaml
```

## Useful Commands

```bash
node plugins/helm-core/scripts/affordances.js --markdown
node plugins/helm-core/scripts/verify.js
node plugins/helm-core/scripts/archive-gate.js
node plugins/helm-core/scripts/risk-tier.js --paths src/auth/login.ts db/migrations/001.sql
```

Run the smoke test:

```bash
bash tests/run-plugin-suite-layout-fixtures.sh
bash tests/run-smoke.sh
bash tests/run-hook-fixtures.sh
bash tests/run-override-fixtures.sh
bash tests/run-openspec-fixtures.sh
bash tests/run-archive-policy-fixtures.sh
```

## Current Limits

- Task 1 establishes the split marketplace layout; it does not implement every stage contract script.
- Stage commands that need missing suite or stage contracts block explicitly with `not-implemented:*`, including `not-implemented:helm-core/plugin-suite` and `not-implemented:helm-operations/archive-gate`.
- Core scripts under `plugins/helm-core/scripts/` remain deterministic and script-driven.
- Hooks are conservative but degrade gracefully when project state is missing or stale.
