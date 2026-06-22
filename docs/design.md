# Helm Claude Code Plugin Design

This document describes the current Claude Code implementation of Helm. The long-form strategy lives in `helm-implementation-plan`; this file is the engineering contract for the plugin in this repository.

## 1. Current Shape

Helm is currently a single Claude Code plugin. Current implementation version: `0.2.1`.

```text
helm-claude-plugin/
├── .claude-plugin/
├── commands/
├── skills/
├── agents/
├── hooks/
├── scripts/
└── tests/
```

It intentionally keeps the final suite boundaries inside one installable unit:

| Concern | Current location | Future extraction |
| --- | --- | --- |
| workflow | `commands/`, `skills/`, `agents/explorer.md` | `helm-workflow` |
| guardrails | `hooks/`, `scripts/helm-guard.js`, `scripts/archive-gate.js` | `helm-guardrails` |
| quality | `agents/verifier.md`, `scripts/verify.js` | `helm-quality` |

Do not split the plugin until the affordance schema has stayed stable through real pilot use.

## 2. User Entry Points

- `/helm` routes intent through the active affordance table.
- `/helm-status` shows active change, risk tier, verify status, ready actions, and blockers.
- `/helm-verify` runs deterministic verification and writes reports.
- `/helm-archive` checks the archive gate.

Skills provide direct recovery paths:

- `bootstrap`
- `explore`
- `propose`
- `design`
- `tasks`
- `implement`
- `verify`
- `fix`
- `archive`
- `status`
- `helm-router`

Agents are optional judgment workers:

- `explorer`: read-only codebase discovery.
- `verifier`: independent review after deterministic evidence exists.

## 3. Runtime State

Helm writes project-local state:

```text
openspec/
  .helm/
    active-change
    affordances.json
    events.jsonl
  changes/<change>/
    proposal.md
    design.md
    tasks.md
    specs/
    risk-tier.json
    verify-report.md
    verify-report.json
    verify-report.stale
    signoff.yaml
```

`active-change` is plain text. `affordances.json` is cached derived state. `events.jsonl` is append-only telemetry and must not become critical state.

## 4. Script Contracts

### `scripts/affordances.js`

Builds the transition table from OpenSpec/Helm files.

Useful calls:

```bash
node scripts/affordances.js --markdown
node scripts/affordances.js --json
node scripts/affordances.js --write-snapshot
```

The table includes:

- active change
- risk tier
- verify status
- stale verify flag
- artifact presence, including `scope.json`
- legal actions and blockers

### `scripts/risk-tier.js`

Classifies risk with deterministic path triggers before model judgment.

```bash
node scripts/risk-tier.js --paths src/auth/login.ts
node scripts/risk-tier.js --write openspec/changes/<change>
```

Allowed tiers:

- `lite`
- `standard`
- `high-risk`

### `scripts/verify.js`

Produces deterministic evidence:

- required artifact checks;
- test command detection;
- test execution;
- `verify-report.json`;
- `verify-report.md`;
- affordance refresh.

It returns non-zero when the report is red.

### `scripts/archive-gate.js`

Blocks archive if:

- no active change exists;
- verify is missing or red;
- verify report is stale;
- high-risk sign-off is missing.

### `scripts/helm-guard.js`

Runs on `PreToolUse`. It denies:

- dangerous shell commands;
- edits to `tests/acceptance/`;
- production edits without active `tasks.md`;
- edits outside declared file scope.

Missing workflow state should warn or route to bootstrap, not crash the session.

### `scripts/helm-post-tool.js`

Runs after writes and marks an existing verify report stale.

## 5. Hook Policy

The hook policy mirrors the main design:

| Hook concern | Failure policy |
| --- | --- |
| dangerous command | deny |
| frozen acceptance contract | deny |
| missing tasks before production edit | deny |
| outside file scope | deny |
| missing/incomplete workflow state | warn |
| post-write stale marking failure | log and continue |

Future work should add fixture coverage for every Claude Code tool payload shape.

## 6. File Scope Contract

The MVP prefers machine-readable `scope.json`:

```json
{
  "schema_version": 1,
  "include": [
    "src/ui/**",
    "tests/ui/**"
  ],
  "exclude": [
    "tests/acceptance/**"
  ]
}
```

When `scope.json` is absent, Helm falls back to parsing `design.md`:

```markdown
## File scope

- src/ui/**
- tests/ui/**
```

The Markdown section is for reviewers. `scope.json` is the guard contract.

## 7. Verification Contract

Verification is two-layered:

1. `verify.js` collects deterministic evidence.
2. `verifier` agent judges adequacy and classifies rework.

A report can be:

- `green`
- `red`

Warnings are per-check metadata. They do not block archive unless policy changes.

After any write, `verify-report.stale` blocks archive until verify runs again.

## 8. Install and Update

Install:

```bash
claude plugin marketplace add /Volumes/zwl/AI/ai-coding/helm-claude-plugin --scope user
claude plugin install helm@helm-marketplace --scope user
```

Validate:

```bash
claude plugin validate /Volumes/zwl/AI/ai-coding/helm-claude-plugin
```

Update:

```bash
claude plugin update helm@helm-marketplace
```

Start a new Claude Code session after changing commands, skills, hooks, or agents.

## 9. Test Strategy

Current smoke test:

```bash
bash tests/run-smoke.sh
bash tests/run-hook-fixtures.sh
bash tests/run-override-fixtures.sh
bash tests/run-openspec-fixtures.sh
bash tests/run-archive-policy-fixtures.sh
```

It checks:

- affordance generation;
- risk classification;
- verify report generation;
- archive gate;
- scope allow;
- scope deny;
- `scope.json` include/exclude behavior;
- hook payload normalization for write tools and Bash;
- explicit override records for blocking gates.
- OpenSpec CLI state parsing with filesystem fallback.
- stale verify archive blocking and high-risk sign-off requirements.

Next tests:

- CI status adapter behavior;
- SAST adapter behavior;
- verifier traceability and dependency grounding behavior.

## 10. Next Build Order

Completed in `0.2.0`:

- hook fixture tests and normalized payload extraction;
- explicit override records under `openspec/.helm/overrides/`;
- machine-readable `scope.json`;
- OpenSpec CLI state parsing with filesystem fallback;
- stale verify and high-risk sign-off archive policy tests.

Next:

1. Add CI status and SAST adapters.
2. Expand verifier evidence: traceability, dependency grounding, hidden checks.
3. Run a pilot on a small repository and write a pilot report.
4. Only then consider extracting the three-plugin suite.

## 11. Pilot Acceptance

The plugin is pilot-ready when:

- `claude plugin validate` passes;
- `bash tests/run-smoke.sh` passes;
- `/helm-status` works in a fresh Claude Code session;
- production edit without tasks is blocked;
- outside-scope edit is blocked;
- verify report staleness blocks archive;
- archive gate passes after green verify and required sign-off.

## 12. Open Questions

- Should `/helm` create OpenSpec changes directly or call OpenSpec commands only?
- Should file scope eventually move from `scope.json` into OpenSpec schema metadata?
- Should high-risk tier escalation happen during `PreToolUse` or only at archive?
- Should sign-off default to local `signoff.yaml` or PR review metadata?
- Which SAST adapter should be first?
- How much event history should `/helm-status` show?
