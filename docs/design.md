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

## 2. Target Direction

Helm is not only a verification plugin. The accepted target is a full Claude Code engineering lifecycle plugin on top of OpenSpec:

```text
requirements -> prototype -> development -> verification -> operations
```

The five lifecycle stages are the product workflow. They must be supported by a separate governance layer that keeps the plugin reliable across sessions, compactions, missing state, and long-running projects.

Reference lessons from the cloned repos:

- `reference-repos/superpowers`: skills are the source of truth, and session-start bootstrap is what makes a plugin active instead of inert.
- `reference-repos/aegis`: doctor/install verification, release gates, compatibility docs, and explicit method-pack health are part of the product.
- `reference-repos/trellis`: state machines, task artifacts, context manifests, and project journals keep agent work recoverable across sessions.

Helm therefore keeps one installable plugin for now, but the design target is a lifecycle plugin plus a runtime governance layer.

## 3. Global Failure Policy

Helm has no fallback policy for required workflow state.

If a required dependency, hook, OpenSpec command, artifact, state file, context manifest, or verification tool is missing or fails, Helm must report the exact blocker and block the dependent action. It must not silently infer state from secondary files, continue with stale evidence, or downgrade a required gate to a warning.

Allowed exceptions are explicit non-production actions:

- read-only status and doctor checks;
- OpenSpec/Helm initialization actions;
- edits under `openspec/**` that create or repair required workflow artifacts;
- documentation edits that do not touch production code.

## 4. User Entry Points

- `/helm` routes intent through the active affordance table.
- `/helm-status` shows active change, risk tier, verify status, ready actions, and blockers.
- `/helm-verify` runs deterministic verification and writes reports.
- `/helm-archive` checks the archive gate.

Target entry points:

- `/helm-requirements`: requirement discovery, PRD/spec framing, acceptance criteria.
- `/helm-prototype`: UI/API/interaction prototype work before production implementation.
- `/helm-implement`: development execution after requirements, prototype decisions, design, and tasks are ready.
- `/helm-verify`: orchestration for the six verification skills.
- `/helm-release`: release, deployment, rollback, monitoring, and operational handoff.
- `/helm-doctor`: plugin, hook, OpenSpec, and state-machine health check.

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

Target skill groups:

- bootstrap/router: `using-helm`, `helm-router`, `bootstrap`, `doctor`, `status`;
- requirements: `requirements`, `explore`, `propose`, `spec`;
- prototype: `prototype`, `prototype-ui`, `prototype-api`, `prototype-review`;
- development: `design`, `tasks`, `before-dev`, `implement`, `fix`, `debug`, `break-loop`;
- verification: `verify`, `verify-facticity`, `verify-static`, `verify-unit`, `verify-redteam`, `verify-e2e`, `verify-sensory`;
- operations: `release`, `deploy`, `rollback`, `monitor`, `archive`, `postmortem`, `update-spec`.

Agents are optional judgment workers:

- `explorer`: read-only codebase discovery.
- `verifier`: independent review after deterministic evidence exists.

## 5. Runtime State

Helm writes project-local state:

```text
openspec/
  .helm/
    active-change
    affordances.json
    events.jsonl
    workflow-state.json
    doctor-report.json
    context/
      requirements-context.jsonl
      prototype-context.jsonl
      implement-context.jsonl
      verify-context.jsonl
      ops-context.jsonl
    journal/
      index.md
      session-<n>.md
  changes/<change>/
    proposal.md
    requirements.md
    acceptance.md
    prototype.md
    design.md
    scope.json
    tasks.md
    specs/
    risk-tier.json
    verify/
      facticity.json
      static.json
      unit.json
      redteam.json
      e2e.json
      sensory.json
      report.md
      report.json
    verify-report.stale
    signoff.yaml
```

`active-change` is plain text. `workflow-state.json` is the required state-machine input. `affordances.json` is cached derived state. `events.jsonl` is append-only telemetry and must not become critical state. `journal/` is human-readable project memory for session recovery and postmortems.

## 6. Script Contracts

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

Target behavior: OpenSpec command output is authoritative. If OpenSpec is required but unavailable, affordance generation must produce a blocked state with a concrete error. It must not fall back to filesystem guessing for required OpenSpec status.

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

Missing workflow state must block production writes. The guard may allow read-only actions, status/doctor commands, initialization, and OpenSpec/Helm artifact repair, but it must not allow production edits from inferred state.

### `scripts/helm-post-tool.js`

Runs after writes and marks an existing verify report stale. If stale marking fails, the hook must report the failure and leave the next state blocked by doctor/status. It must not let stale verification appear fresh.

## 7. Hook Policy

The hook policy mirrors the main design:

| Hook concern | Failure policy |
| --- | --- |
| dangerous command | deny |
| frozen acceptance contract | deny |
| missing tasks before production edit | deny |
| outside file scope | deny |
| missing `openspec/` | deny production writes; allow init/status/doctor/OpenSpec repair |
| OpenSpec CLI unavailable when required | block dependent action |
| missing/incomplete workflow state | deny production writes |
| missing context manifest for subagent action | block subagent dispatch |
| post-write stale marking failure | report hard failure and block fresh verification state |

Future work should add fixture coverage for every Claude Code tool payload shape.

## 8. File Scope Contract

Production edits require machine-readable `scope.json`:

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

`design.md` may contain a reviewer-facing section:

```markdown
## File scope

- src/ui/**
- tests/ui/**
```

The Markdown section is for reviewers only. `scope.json` is the guard contract. If `scope.json` is missing, production edits are blocked.

## 9. Verification Contract

Verification is two-layered:

1. `verify` orchestrates deterministic checks and dedicated verification skills.
2. `verifier` agent judges adequacy only after script evidence exists.

A report can be:

- `green`
- `red`

Warnings are per-check metadata only when the related check is optional for the current risk tier. Missing required verification is red, not warning.

After any write, `verify-report.stale` blocks archive until verify runs again.

The six required verification domains are:

| Skill | Purpose | Primary blocker |
| --- | --- | --- |
| `verify-facticity` | Audit specs, architecture claims, APIs, dependencies, and config against actual repo/system state. | undocumented or invented facts |
| `verify-static` | Run OpenSpec validation, linting, type checks, dependency checks, and structural scans. | syntax/style/type/schema failure |
| `verify-unit` | Require focused unit or regression tests for changed logic. | untested core logic or failing unit tests |
| `verify-redteam` | Exercise destructive, adversarial, injection, boundary, and abuse cases. | security or robustness exposure |
| `verify-e2e` | Validate complete user/business flows against realistic system paths. | broken integration path |
| `verify-sensory` | Human-in-the-loop UX/code review for readability, interaction quality, performance feel, and maintainability. | unacceptable human experience or code quality |

`verify` is an orchestrator. Each domain owns its evidence file under `openspec/changes/<change>/verify/`. If a required domain tool is unavailable, the domain reports blocked and the aggregate report is red.

## 10. Governance Layer

The lifecycle stages require the following runtime governance capabilities.

### 10.1 Bootstrap and Router

Helm needs a `using-helm` bootstrap equivalent to `using-superpowers` and `using-aegis`.

Responsibilities:

- load at session start;
- remind the model to check Helm/OpenSpec state before acting;
- route user intent through lifecycle state instead of free-form implementation;
- enforce that production work cannot bypass requirements, prototype/design, tasks, verification, and operations gates.

### 10.2 State Machine and Artifact Contract

The target state machine is:

```text
no_openspec -> initialized -> requirements -> prototype -> development -> verification -> operations -> archived
```

Each state declares:

- required artifacts;
- legal next actions;
- blocked actions;
- allowed repair actions;
- required context manifests;
- required verification domains.

### 10.3 Project Memory and Journal

`events.jsonl` is not enough for long sessions. Helm needs a human-readable journal under `openspec/.helm/journal/`.

Journal entries record:

- session summary;
- decisions made;
- blockers found;
- user approvals;
- verification outcomes;
- operational handoff notes.

### 10.4 Spec Update and Learning Writeback

`update-spec` promotes implementation lessons back into OpenSpec before archive/release.

It records:

- new system invariants;
- changed interfaces or contracts;
- operational constraints;
- test lessons and regression cases;
- follow-up ADRs when needed.

### 10.5 Doctor and Health Check

`/helm-doctor` verifies the actual install and runtime surface:

- plugin manifest and marketplace metadata;
- skills, commands, agents, and hooks are discoverable;
- SessionStart, UserPromptSubmit where supported, PreToolUse, and PostToolUse hooks are wired;
- OpenSpec CLI exists and can validate the target repo;
- `openspec/` and required `.helm` state exist;
- state machine and active change are internally consistent;
- context manifests and verify artifacts are valid JSON/JSONL/Markdown as required.

### 10.6 Context Manifests and Subagent Injection

Subagent work must receive curated context manifests instead of broad prompts.

Target manifests:

- `requirements-context.jsonl`;
- `prototype-context.jsonl`;
- `implement-context.jsonl`;
- `verify-context.jsonl`;
- `ops-context.jsonl`.

If a required manifest is missing or invalid, dispatch is blocked.

### 10.7 Debug and Break-loop

`debug` / `break-loop` activates when the same failure repeats, a fix is reverted, verification keeps failing, or the agent starts patching symptoms.

It requires:

- root-cause statement;
- reproduction evidence;
- failed attempts log;
- hypothesis list;
- next experiment;
- re-verification command.

### 10.8 Git, Worktree, and Branch Finish

Helm needs a branch finish workflow separate from OpenSpec archive:

- detect current branch/worktree state;
- decide commit, PR, keep branch, or discard branch;
- prevent cleaning unrelated user worktrees;
- record final diff summary and validation evidence;
- archive only after git and OpenSpec state agree.

### 10.9 Release, Distribution, and Update

The plugin needs release engineering as part of the product:

- `CHANGELOG.md`;
- release checklist;
- plugin validation checklist;
- install/update docs;
- compatibility matrix;
- bilingual README files: `README.md` and `README.zh-CN.md`.

### 10.10 Behavior Evals and Clean-session Acceptance

Script tests are not enough. Helm needs behavior acceptance tests in clean sessions.

Required scenarios:

- missing `openspec/` blocks production edits and routes to init;
- "implement this feature" enters requirements/design before code;
- `/helm-verify` runs or blocks all required verification domains;
- archive is blocked by stale or red verification;
- doctor reports missing hooks/skills/OpenSpec without fallback.

## 11. Install and Update

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

## 12. Test Strategy

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
- OpenSpec CLI state parsing.
- stale verify archive blocking and high-risk sign-off requirements.

Next tests:

- strict no-fallback OpenSpec failure behavior;
- required `scope.json` blocking behavior;
- `helm-doctor` health checks;
- lifecycle state-machine fixtures;
- six verification domain fixtures;
- clean-session behavior evals.

## 13. Next Build Order

Completed in `0.2.0`:

- hook fixture tests and normalized payload extraction;
- explicit override records under `openspec/.helm/overrides/`;
- machine-readable `scope.json`;
- OpenSpec CLI state parsing;
- stale verify and high-risk sign-off archive policy tests.

Next:

1. Replace warning/fallback gates with strict blocked states for required workflow state.
2. Add `/helm-doctor` and `doctor-report.json`.
3. Add lifecycle `workflow-state.json` and artifact contract validation.
4. Add `using-helm` bootstrap and session state injection.
5. Add project journal and context manifest contracts.
6. Split verification into the six dedicated skills and aggregate report.
7. Add debug/break-loop, update-spec, and git finish workflows.
8. Add bilingual README, release checklist, compatibility matrix, and behavior evals.

## 14. Pilot Acceptance

The plugin is pilot-ready when:

- `claude plugin validate` passes;
- `bash tests/run-smoke.sh` passes;
- `/helm-doctor` reports plugin, hooks, OpenSpec, skills, commands, agents, and state as healthy;
- `/helm-status` works in a fresh Claude Code session through session-start bootstrap;
- missing `openspec/` blocks production writes and allows init/repair only;
- production edit without tasks is blocked;
- outside-scope edit is blocked;
- all required six verification domains are green for the active change;
- verify report staleness blocks archive;
- archive gate passes after green verify and required sign-off.

## 15. Open Questions

- Should `/helm` create OpenSpec changes directly or call OpenSpec commands only?
- Should high-risk tier escalation happen during `PreToolUse` or only at archive?
- Should sign-off default to local `signoff.yaml` or PR review metadata?
- Which SAST adapter should be first?
- Should context manifests be generated by OpenSpec state, Helm scripts, or a combined schema?
- Which behavior eval harness should Helm use first for clean-session acceptance?
