# SpecNav Skill Suite Redesign

This document redesigns SpecNav's skill layer after reviewing:

- `reference-repos/agentskills` at `5d4c1fd`
- `reference-repos/anthropic-skills` at `5754626`
- the current SpecNav plugin suite under `plugins/`

The goal is to make SpecNav's Claude Code plugin suite conform to the Agent Skills
format while preserving SpecNav's stricter product rules: OpenSpec-first, no
fallbacks for required state, and full lifecycle coverage from requirements to
operations.

## 1. Design Decision

SpecNav remains a multi-plugin Claude Code marketplace repository:

```text
specnav-claude-plugin/
  .claude-plugin/marketplace.json
  plugins/
    specnav-core/
    specnav-requirements/
    specnav-prototype/
    specnav-development/
    specnav-verification/
    specnav-operations/
```

The change is not the product boundary. The change is the skill boundary.

Skills must become externally triggerable capabilities that an agent can choose
from user intent. They must not be placeholders, internal checklist labels, or
thin wrappers around one script without enough trigger context.

Commands and hooks own deterministic execution gates. Skills own procedural
reasoning: when to run a gate, which artifacts to inspect, which decisions to
ask for, what to write, when to stop, and how to validate.

## 2. Official Skill Contract

SpecNav uses the strict cross-client subset of Agent Skills.

Every skill directory must contain:

```text
skill-name/
  SKILL.md
  scripts/      # optional, executable deterministic helpers
  references/   # optional, loaded only when needed
  assets/       # optional, copied or used as output resources
```

Every `SKILL.md` must start with YAML frontmatter:

```yaml
---
name: specnav-example
description: Use this skill when ...
---
```

SpecNav's strict subset:

- `name` is required.
- `description` is required.
- `name` must match the skill folder name.
- `name` must be lowercase kebab-case, no underscores, no leading/trailing hyphen,
  no consecutive hyphens, and no more than 64 characters.
- `description` must be non-empty, no more than 1024 characters, and must explain
  both what the skill does and when to use it.
- SpecNav skills must not use `allowed-tools`, `metadata`, or `compatibility`
  frontmatter. Those fields exist in the broader Agent Skills spec, but Codex's
  local `skill-creator` guidance says only `name` and `description` are read for
  triggering. Tool requirements belong in the body, plugin manifest, or scripts.
- SpecNav skills may use a `license` field only if the distribution policy later
  requires it. Default is no `license` in skill frontmatter.

The body is loaded only after triggering. Therefore:

- Put all trigger language in `description`, not in a body section named
  "When to use".
- Keep the body focused and procedural.
- Prefer under 500 lines.
- Move detailed contracts, examples, rubrics, and artifact schemas to
  `references/`.
- Reference support files with paths relative to the skill root, one level deep.
- Avoid skill-local `README.md`, `CHANGELOG.md`, or other documentation files that
  are not directly used during execution.

## 3. Current SpecNav Gaps

Current audit:

- 32 SpecNav skills exist under `plugins/*/skills/*/SKILL.md`.
- 29 skills use `allowed-tools`, which violates SpecNav's strict subset.
- Several core skills are placeholders:
  - `using-specnav`
  - `debug`
  - `break-loop`
- `status` and `doctor` still mention not-implemented blocker paths.
- Many descriptions are too short to trigger reliably.
- Generic names such as `status`, `doctor`, `debug`, `deploy`, `monitor`, and
  `rollback` risk colliding with other installed skills.
- Many stage skills describe internal mechanics instead of user-intent triggers.
- There is no skill contract test that blocks invalid frontmatter, placeholders,
  weak descriptions, stale declared skills, or missing referenced resources.

This means the suite shape is acceptable, but the skills are not yet production
quality.

## 4. Naming Policy

All public SpecNav skills should be prefixed with `specnav-`.

Reason:

- Skills from multiple plugins appear in one available-skill pool.
- Generic names are likely to collide with other plugin suites.
- Prefixing makes trigger logs and diagnostics unambiguous.

Target examples:

| Current | Target |
| --- | --- |
| `status` | `specnav-status` |
| `doctor` | `specnav-doctor` |
| `debug` | `specnav-debug` |
| `break-loop` | `specnav-recovery` |
| `requirements` | `specnav-requirements` |
| `foundation-spec` | `specnav-foundation-specs` |
| `prototype` | `specnav-prototype` |
| `before-dev` | `specnav-development-entry` |
| `verify-static` | `specnav-verify-static` |
| `release-plan` | `specnav-release-plan` |

`using-specnav` should become `specnav-workflow` or be kept only as a compatibility
alias during migration. The primary trigger should be `specnav-workflow`.

## 5. Skill Granularity Policy

A SpecNav skill is justified only when it has all three:

1. A distinct user intent that can trigger independently.
2. A distinct artifact contract or validation gate.
3. A coherent procedure that would otherwise be easy for the agent to get wrong.

Internal checklist items should be references or script modes, not separate
skills.

This keeps the suite from becoming a pile of micro-skills that must all load for
one user action.

## 6. Target Skill Map

### 6.1 specnav-core

Core owns bootstrap, suite resolution, global status, diagnostics, recovery, and
legal action routing.

Target skills:

| Skill | Purpose |
| --- | --- |
| `specnav-workflow` | Primary SpecNav entrypoint and lifecycle router. Use when the user asks to use SpecNav, continue SpecNav, inspect next action, or move through requirements/prototype/development/verification/operations. |
| `specnav-status` | Read active OpenSpec and SpecNav state, report legal actions, blockers, active change, risk tier, and installed plugin state. |
| `specnav-doctor` | Diagnose plugin installation, hook exposure, OpenSpec presence, suite dependency state, and contract script health. |
| `specnav-debug` | Investigate failed SpecNav commands, hooks, contracts, stale state, and plugin resolution errors with current evidence. |
| `specnav-recovery` | Break loops or blocked state after repeated failures by classifying the blocker, preserving evidence, and routing to the owning stage. |

Core hooks:

- `SessionStart` must check whether OpenSpec exists.
- If OpenSpec is missing, SpecNav reports the blocker and allows only initialization
  or explicit OpenSpec repair actions.
- There is no fallback path that lets lifecycle work proceed without OpenSpec.

### 6.2 specnav-requirements

Requirements owns project-level specs and change-level requirements discovery.

Target skills:

| Skill | Purpose |
| --- | --- |
| `specnav-foundation-specs` | Create or repair the four required project specs before requirements discussion. |
| `specnav-requirements` | Conduct spec-gated requirements grilling and write change-level requirements, acceptance, spec map, and component impact map. |

Required foundation specs:

- `openspec/specs/ui-design/design.md`
- `openspec/specs/system-architecture/design.md`
- `openspec/specs/frontend-backend-data-flow/design.md`
- `openspec/specs/component-architecture/design.md`

The `specnav-requirements` description must be explicit that it should trigger when
the user asks to define a feature, clarify requirements, plan a change, start a
new OpenSpec change, or continue product discovery.

The body must contain the requirements interview philosophy:

- Read existing specs before asking.
- Ask one focused question at a time.
- Include a recommended answer and tradeoff.
- Do not ask what the specs already answer.
- Close and record each decision branch before opening the next.
- Write unknowns as explicit gaps instead of inventing answers.

Detailed section templates belong in `references/requirements-artifacts.md`.

### 6.3 specnav-prototype

Prototype owns runnable review artifacts before production code.

Target skills:

| Skill | Purpose |
| --- | --- |
| `specnav-prototype` | Classify the prototype question, create isolated runnable prototype code, and write manifest/review maps. |
| `specnav-prototype-review` | Verify prototype code, collect user approval, and write decision plus development handoff. |

The current `prototype-verify` and `prototype-handoff` are too tightly coupled to
one internal sequence. They should merge into `specnav-prototype-review`, with
verification and approval as substeps.

Prototype branch references belong in `references/prototype-branches.md`.
Artifact schemas belong in `references/prototype-artifacts.md`.

### 6.4 specnav-development

Development owns scoped production implementation from approved artifacts.

Target skills:

| Skill | Purpose |
| --- | --- |
| `specnav-development-entry` | Validate development entry gates, write basis, and create/enforce scope lock. |
| `specnav-vertical-slices` | Plan, dispatch, review, and close vertical-slice implementation tasks. |
| `specnav-development-review` | Run focused spec review, quality review, drift checks, and verification handoff. |

The current `before-dev` and `scope-lock` are one coherent entry gate and should
merge. The current `vertical-slice-tasking` is doing too much and should hand
post-task review semantics to `specnav-development-review`.

Detailed task packet templates belong in `references/development-task-packets.md`.
Scope rules belong in `references/scope-lock.md`.

### 6.5 specnav-verification

Verification keeps dedicated skills for the six required testing domains because
each domain has a distinct audit philosophy, artifact contract, and failure mode.

Target skills:

| Skill | Purpose |
| --- | --- |
| `specnav-verify-plan` | Create verification plan, evidence index, traceability matrix, root-cause checks, and receipt shell. |
| `specnav-verify-facticity` | Audit specs, reports, and implementation claims against current repository evidence. |
| `specnav-verify-static` | Run static analysis, OpenSpec validation, schema checks, dependency checks, lint/type checks, and banned-pattern scans. |
| `specnav-verify-unit` | Validate focused unit/regression coverage and test quality for changed behavior. |
| `specnav-verify-redteam` | Run destructive, adversarial, permission, injection, boundary, and resilience probes. |
| `specnav-verify-e2e` | Validate complete user/business flows across frontend, backend, state, API, database, and integration boundaries. |
| `specnav-verify-sensory` | Run independent human-in-the-loop UX, accessibility, maintainability, cohesion/coupling, and code readability audit. |

These skills must preserve the user's six-stage testing model exactly:

```text
facticity -> static -> unit -> redteam -> e2e -> sensory
```

Each verification skill body should use the same structure:

```text
# SpecNav Verify <Domain>
## Purpose
## Inputs
## Workflow
## Required Outputs
## Red / Blocked Conditions
## Validation
```

Domain rubrics belong in `references/verification-rubrics.md` if they become too
long.

### 6.6 specnav-operations

Operations owns release, installation, compatibility, deployment, rollback,
monitoring, postmortem, writeback, and archive readiness.

Target skills:

| Skill | Purpose |
| --- | --- |
| `specnav-ops-readiness` | Aggregate verification, release target, git state, untracked files, required docs, and operations blockers. |
| `specnav-release-plan` | Select and document the release target and checklist. |
| `specnav-install-verify` | Verify installed plugin surfaces and host exposure from direct evidence. |
| `specnav-update-policy` | Record how installed plugin surfaces are updated and re-verified. |
| `specnav-compatibility-matrix` | Document supported hosts, support level, verification evidence, limitations, and reload requirements. |
| `specnav-branch-finish` | Record git branch/worktree state and safe cleanup decision. |
| `specnav-deploy` | Prepare deployment mechanics for `project-deploy` targets. |
| `specnav-rollback` | Prepare rollback mechanics and verification for deploy-risk targets. |
| `specnav-monitor` | Prepare post-release monitoring signals, owners, windows, and escalation. |
| `specnav-postmortem` | Record required learning after failures, incidents, or repeated blockers. |
| `specnav-update-spec` | Write operational learning back to OpenSpec or explicitly defer it. |

These can remain separate because they correspond to distinct operational intents
and artifacts. Their descriptions must be much stronger and clearly say when
each one should trigger.

Archive remains a command-level gate because archive is a terminal action, not a
general reasoning capability.

## 7. Standard SKILL.md Shape

Every SpecNav skill should follow this body shape unless a simpler one is enough:

```markdown
# SpecNav <Capability>

## Purpose

One short paragraph describing what this skill controls.

## Required First Step

Run the owning contract script or read the required state source. Treat the
result as source of truth.

## Workflow

Ordered steps. Include when to ask the user, when to write artifacts, and when
to rerun validation.

## Required Outputs

Exact files or reports this skill may create or update.

## Stop Conditions

Specific blockers that must stop work. These are not warnings.

## Validation

Commands or contract scripts that must pass before handoff.

## Gotchas

Only non-obvious corrections that SpecNav agents are likely to get wrong.
```

Not every skill needs every section, but every production SpecNav skill needs:

- a source-of-truth first step;
- explicit stop conditions;
- exact output paths;
- validation or a reason it is read-only.

## 8. Script Policy

SpecNav scripts are deterministic helpers, not hidden requirements.

Script rules:

- Must be non-interactive.
- Must support `--help`.
- Must print structured data to stdout for `--json` modes.
- Must print diagnostics to stderr.
- Must fail with meaningful exit codes and actionable blocker messages.
- Must not infer required state from fallback files.
- Must not silently choose the newest change when the active change is required.
- Must be referenced from the relevant skill body or stage manifest.

Scripts should do fragile mechanical work:

- validate OpenSpec and SpecNav artifact structure;
- resolve installed plugin suite dependencies;
- classify blockers;
- aggregate state;
- validate operation/readiness/archive gates;
- generate machine-readable reports.

Skills should do context-sensitive work:

- ask questions;
- interpret specs and code evidence;
- select a lifecycle route;
- write human-readable decisions;
- decide when to stop and route upstream.

## 9. Reference Policy

Use `references/` when a skill needs detailed material that should not always be
loaded.

The per-skill resource decisions for `references/`, `assets`, and skill-local
`scripts/` are tracked in `docs/skill-resource-matrix.md`.

Recommended references:

```text
plugins/specnav-requirements/skills/specnav-requirements/references/
  interview-philosophy.md
  requirements-artifacts.md

plugins/specnav-prototype/skills/specnav-prototype/references/
  prototype-branches.md
  prototype-artifacts.md

plugins/specnav-development/skills/specnav-vertical-slices/references/
  development-task-packets.md
  scope-lock.md

plugins/specnav-verification/skills/specnav-verify-plan/references/
  verification-rubrics.md

plugins/specnav-operations/skills/specnav-ops-readiness/references/
  operations-artifacts.md
```

Reference files must be directly linked from `SKILL.md` with clear load
conditions, for example:

```markdown
Read `references/requirements-artifacts.md` before creating or repairing
`requirements.md`, `acceptance.md`, `spec-map.json`, or
`component-impact-map.json`.
```

Avoid nested reference chains.

## 10. Trigger Description Policy

Every description should be written as a trigger instruction, not a label.

Pattern:

```yaml
description: >
  Use this skill when the user wants to [intent], including [nearby phrasings].
  It [does the capability]. Do not use it for [near miss] unless [condition].
```

Good SpecNav description properties:

- mentions user intent;
- mentions stage and artifact scope;
- includes common aliases such as "continue", "next step", "define feature",
  "prototype", "implement", "verify", "release", "archive";
- names the owned artifacts or gates when that helps precision;
- states near-miss boundaries when another SpecNav skill owns the work;
- stays under 1024 characters.

Description evals should include:

- direct requests;
- casual Chinese and English prompts;
- "continue" prompts with context;
- near misses that should route to another SpecNav skill;
- generic terms like "status", "deploy", or "debug" that should not trigger a
  non-SpecNav skill accidentally.

## 11. Validation Plan

Add a first-class skill contract test:

```text
tests/run-skill-contract-fixtures.sh
```

It must validate:

- every declared skill in each `specnav-stage.json` exists;
- every skill folder has `SKILL.md`;
- frontmatter contains exactly `name` and `description` for SpecNav strict subset;
- `name` matches the folder;
- `name` is lowercase kebab-case and starts with `specnav-`;
- descriptions are non-empty, <= 1024 chars, and contain explicit trigger
  language;
- no `allowed-tools`, `metadata`, `compatibility`, placeholder, TODO, or
  not-implemented text exists in any `SKILL.md`;
- no generic public skill names remain;
- referenced `scripts/`, `references/`, and `assets/` paths exist;
- each script referenced as a required command exists and passes `node --check`,
  `bash -n`, or the appropriate syntax check when practical.

Add trigger description fixtures:

```text
tests/fixtures/skill-triggers/
  specnav-workflow.json
  specnav-requirements.json
  specnav-prototype.json
  specnav-development.json
  specnav-verification.json
  specnav-operations.json
```

Each fixture contains:

```json
{
  "skill": "specnav-requirements",
  "should_trigger": [],
  "should_not_trigger": []
}
```

The static test cannot prove model activation, but it can prevent weak,
ambiguous, or missing trigger descriptions. Later, if Claude Code exposes
reliable skill activation logs, these fixtures can become live trigger evals.

## 12. Migration Plan

### Phase 1: Contract before rewrite

Add `tests/run-skill-contract-fixtures.sh` with the current expected failures
documented in output. This makes the rewrite measurable.

### Phase 2: Rename and remap skills

Rename skill folders to the `specnav-*` names and update each plugin's
`specnav-stage.json`.

Do not leave generic names as the primary names. If compatibility aliases are
needed, keep them temporary and explicitly marked for removal before release.

### Phase 3: Rewrite core skills

Implement:

- `specnav-workflow`
- `specnav-status`
- `specnav-doctor`
- `specnav-debug`
- `specnav-recovery`

Remove placeholder language.

### Phase 4: Rewrite lifecycle stage skills

Rewrite requirements, prototype, development, verification, and operations
skills in the standard shape.

Use references only where the skill body would become too long or too detailed.

### Phase 5: Validate and repair scripts

Run:

```bash
bash tests/run-skill-contract-fixtures.sh
bash tests/run-plugin-suite-layout-fixtures.sh
bash tests/run-plugin-suite-resolver-fixtures.sh
bash tests/run-core-runtime-fixtures.sh
bash tests/run-smoke.sh
```

Then run stage-specific tests for requirements, prototype, development,
verification, and operations.

### Phase 6: Resume cross-plugin workflow state

Only after skill compliance is green, resume the unfinished cross-plugin
workflow state work:

- `plugins/specnav-core/scripts/workflow-state.js`
- `plugins/specnav-core/scripts/specnav-doctor.js`
- `plugins/specnav-core/scripts/affordances.js`
- `tests/run-cross-plugin-state-fixtures.sh`

This avoids building more runtime behavior on top of invalid skill contracts.

## 13. Final Acceptance Criteria

The skill redesign is complete when:

- all SpecNav public skills use valid Agent Skills frontmatter;
- no placeholder skills remain;
- skill names are globally safe;
- every skill description is trigger-ready;
- each skill body has source-of-truth first steps, stop conditions, outputs, and
  validation;
- deterministic gates stay in scripts and commands;
- detailed schemas and rubrics use progressive disclosure through references;
- the skill contract test passes;
- existing plugin suite and stage tests still pass;
- the README documents the multi-plugin install shape and skill philosophy in
  both Chinese and English.
