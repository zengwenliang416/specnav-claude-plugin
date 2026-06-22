# Helm Claude Code Plugin

Helm is a spec-driven workflow plugin for Claude Code. It sits on top of OpenSpec and gives Claude a governed loop:

`explore -> propose -> design -> tasks -> implement -> verify -> fix -> archive`

This repository is a single-plugin MVP. It keeps the future boundaries from the implementation plan:

- workflow: commands and skills
- guardrails: hook scripts
- quality: verifier agent and verification scripts

## Install Locally

From a Claude Code environment, add this plugin marketplace root:

```bash
claude plugin marketplace add /Volumes/zwl/AI/ai-coding/helm-claude-plugin
claude plugin install helm@helm-marketplace
```

If your Claude Code build uses a different plugin command spelling, install the local marketplace root that contains `.claude-plugin/marketplace.json`.

## Project Layout

```text
.claude-plugin/       Claude plugin manifest and local marketplace
commands/             Slash command entrypoints, including /helm
skills/               Claude Code skills for each Helm action and helm-router
agents/               Explorer and verifier subagents
hooks/                Claude Code hook configuration
scripts/              Local implementation scripts
tests/                Smoke fixtures
docs/                 Engineering design notes
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
node scripts/affordances.js --markdown
node scripts/verify.js
node scripts/archive-gate.js
node scripts/risk-tier.js --paths src/auth/login.ts db/migrations/001.sql
```

Run the smoke test:

```bash
bash tests/run-smoke.sh
bash tests/run-hook-fixtures.sh
bash tests/run-override-fixtures.sh
bash tests/run-openspec-fixtures.sh
bash tests/run-archive-policy-fixtures.sh
```

## MVP Limits

- This MVP is one plugin, not the final three-plugin extracted suite.
- The verifier is deterministic and script-driven; it produces a report that Claude can expand on.
- Hooks are conservative but degrade gracefully when project state is missing or stale.
- External MCP integrations, visual regression, and SAST are extension points, not required for the first loop.
