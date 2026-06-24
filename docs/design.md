# Helm Claude Code Plugin Design

This document describes the current Claude Code implementation of Helm. The long-form strategy lives in `helm-implementation-plan`; this file is the engineering contract for the plugin in this repository.

## 1. Current Shape

Helm is currently a single Claude Code plugin. Current implementation version: `0.2.1`.

This single-plugin shape is now implementation debt. The accepted target is a Claude Code marketplace repository containing several Helm plugins, one for the core runtime and one for each major lifecycle stage.

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

The current tree keeps the final suite boundaries inside one installable unit:

| Concern | Current location | Target plugin |
| --- | --- | --- |
| core runtime, routing, hooks, state | `commands/`, `skills/`, `hooks/`, `scripts/` | `helm-core` |
| requirements and foundation specs | `skills/propose`, `skills/design`, OpenSpec artifacts | `helm-requirements` |
| prototype artifacts and handoff | to be created under `plugins/helm-prototype/` | `helm-prototype` |
| production implementation gates | `skills/implement`, `skills/tasks`, `scripts/helm-guard.js` | `helm-development` |
| six-domain verification | `agents/verifier.md`, `scripts/verify.js` | `helm-verification` |
| release, deploy, archive | `scripts/archive-gate.js`, future operations artifacts | `helm-operations` |

The implementation plan should split the repository before building the remaining lifecycle contracts, otherwise later code will hard-code the wrong plugin root and command surface.

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

Helm therefore becomes a plugin suite rather than one installable plugin.

### 2.1 Plugin Suite Architecture

The repository root is the marketplace root:

```text
helm-claude-plugin/
  .claude-plugin/marketplace.json
  plugins/
    helm-core/
    helm-requirements/
    helm-prototype/
    helm-development/
    helm-verification/
    helm-operations/
```

Plugin boundaries:

| Plugin | Owns | Required for |
| --- | --- | --- |
| `helm-core` | bootstrap, router, status, doctor, hooks, suite resolution, state machine, shared event/journal helpers | every Helm workflow |
| `helm-requirements` | foundation specs, requirements questioning, acceptance criteria, spec maps, component impact maps | requirements stage |
| `helm-prototype` | isolated prototype code, prototype verification, prototype decision, prototype handoff | prototype stage |
| `helm-development` | scope lock, vertical slices, task ledger, prototype promotion, review loop, development handoff | implementation stage |
| `helm-verification` | verification plan, six domain skills, evidence index, traceability, receipt, aggregate report | verification stage |
| `helm-operations` | readiness, release plan, install/update policy, compatibility, branch finish, deploy, rollback, monitor, postmortem, archive gate | operations and archive |

`helm-core` is mandatory. Stage plugins must fail with `missing-plugin:<name>` when their required dependencies are not installed. Stage plugins may own their own contracts, but cross-plugin orchestration and state reporting go through `helm-core`.

## 3. Global Failure Policy

Helm has no fallback policy for required workflow state.

If a required dependency, hook, OpenSpec command, artifact, state file, context manifest, or verification tool is missing or fails, Helm must report the exact blocker and block the dependent action. It must not silently infer state from secondary files, continue with stale evidence, or downgrade a required gate to a warning.

Allowed exceptions are explicit non-production actions:

- read-only status and doctor checks;
- OpenSpec/Helm initialization actions;
- edits under `openspec/**` that create or repair required workflow artifacts;
- documentation edits that do not touch production code.

## 4. Requirements Stage Foundation Specs

Requirements discovery is gated by project-level specs. Helm must not begin feature grilling until the required foundation specs exist and pass structural checks.

Required foundation specs:

| Spec | Path | Owns |
| --- | --- | --- |
| UI Design Spec | `openspec/specs/ui-design/design.md` | visual system, design tokens, components, motion, content voice |
| System Architecture & Database Spec | `openspec/specs/system-architecture/design.md` | module boundaries, API surface, database model, permissions, operational constraints |
| Frontend-Backend Data Flow Spec | `openspec/specs/frontend-backend-data-flow/design.md` | cross-layer user flows, request/response contracts, state transitions, errors, retries |
| Component Architecture & Reuse Spec | `openspec/specs/component-architecture/design.md` | cohesion, coupling, component taxonomy, shared extraction rules, public APIs, tests |

If any required spec is missing or invalid, Helm must block requirements grilling and guide the user to create or repair that specific spec. It must not infer missing constraints from code, previous chat context, or adjacent documents.

Change-level requirement artifacts may reference foundation specs and propose deltas, but must not invent hidden UI rules, architecture boundaries, data-flow payloads, component abstractions, validation behavior, or database effects inside a change artifact.

### 4.1 UI Design Spec

`openspec/specs/ui-design/design.md` follows the structure of the supplied Geist design documents: a YAML token contract followed by a Markdown usage guide.

Required YAML frontmatter keys:

- `version`
- `name`
- `description`
- `colors`
- `typography`
- `spacing`
- `rounded`
- `components`

Required Markdown sections:

- `# <Design System Name>`
- `## Overview`
- `## Colors`
- `## Typography`
- `## Layout`
- `## Elevation & Depth`
- `## Motion`
- `## Shapes`
- `## Components`
- `## Voice & Content`
- `## Do's and Don'ts`

If the project uses light and dark theme documents, both documents must use the same token keys and component contract shape. Helm must validate YAML parseability, required sections, token references, and light/dark key parity before requirements work continues.

If the UI design spec is missing, Helm asks whether the user already has a design-system document. If yes, the user supplies it in this exact structure. If no, Helm guides creation section by section in the same format.

### 4.2 System Architecture & Database Spec

`openspec/specs/system-architecture/design.md` is the long-term system boundary contract.

Required sections:

- `# System Architecture & Database Spec`
- `## Overview`
- `## Application Topology`
- `## Module Boundaries`
- `## Frontend Architecture`
- `## Backend Architecture`
- `## API Surface`
- `## Database Model`
- `## Permissions & Security`
- `## Integration Boundaries`
- `## Operational Constraints`
- `## Architecture Do's and Don'ts`

Each module records responsibility, public contract, owned data, dependencies, forbidden dependencies, and extension points. Each database entity records purpose, owner module, fields, relationships, indexes, constraints, lifecycle, migration notes, and retention/deletion behavior.

Architecture spec owns system boundaries. Requirements may reference, stress-test, or request changes to those boundaries, but must not invent new boundaries inside a change artifact.

### 4.3 Frontend-Backend Data Flow Spec

`openspec/specs/frontend-backend-data-flow/design.md` defines how data moves from user action to frontend state, API request, backend service, database effects, response, and UI rendering.

Required sections:

- `# Frontend-Backend Data Flow Spec`
- `## Overview`
- `## Flow Index`
- `## Boundary Contracts`
- `## State Ownership`
- `## Validation Ownership`
- `## Error & Empty States`
- `## Loading / Optimistic / Retry Behavior`
- `## End-to-End Flow Details`
- `## Async / Realtime Flows`
- `## Flow Do's and Don'ts`

Each flow requires a stable `FLOW-ID` plus user trigger, preconditions, frontend surface, frontend state transition, request schema, endpoint/handler, backend service, database reads/writes, response schema, render behavior, validation owner, error cases, empty state, loading behavior, retry/idempotency, rollback behavior, and related UI/architecture references.

Data flow spec owns cross-layer behavior. Requirements may reference or extend flows, but must not invent hidden payloads, implicit validation, undocumented state, or untracked database effects inside a change artifact.

### 4.4 Component Architecture & Reuse Spec

`openspec/specs/component-architecture/design.md` defines how code components are decomposed, reused, imported, and tested.

Required sections:

- `# Component Architecture & Reuse Spec`
- `## Overview`
- `## Component Taxonomy`
- `## Cohesion Rules`
- `## Coupling Rules`
- `## Shared Component Extraction Rules`
- `## Component Public API Rules`
- `## State Ownership Rules`
- `## Composition Patterns`
- `## File & Naming Conventions`
- `## Testing Expectations`
- `## Refactor Triggers`
- `## Component Do's and Don'ts`

Components must be highly cohesive and loosely coupled. When two or more implementation sites share the same stable responsibility, behavior, interaction pattern, rendering structure, state pattern, validation display, API orchestration, or formatting/transformation logic, Helm must extract a shared component, hook, utility, or service instead of duplicating logic.

Extraction is required when:

- the same UI structure appears in two or more places with only data/text differences;
- the same interaction behavior appears in two or more places;
- the same form field group, validation display, empty state, loading state, error state, or action group appears in two or more places;
- the same data transformation or formatting logic is used by multiple components;
- the same API orchestration logic is used by multiple frontend surfaces;
- a component mixes rendering, fetching, validation, and business rules beyond its declared responsibility;
- a feature-level component becomes reusable across feature boundaries.

A shared abstraction must not be created when there is only one usage site, the similarity hides different business concepts, extraction would force unrelated feature dependencies, or the abstraction requires generic prop shapes that erase domain meaning.

### 4.5 Requirements Grilling Protocol

After the four foundation specs pass, Helm uses spec-gated grilling:

- inspect the foundation specs before asking the user;
- ask one focused question at a time;
- include a recommended answer and the tradeoff behind it;
- avoid asking questions already answered by specs or code evidence;
- close each decision branch before moving to the next;
- write durable decisions into change artifacts.

Change-level requirements output:

```text
openspec/changes/<change>/
  requirements.md
  acceptance.md
  spec-map.json
  component-impact-map.json
```

`spec-map.json` records which UI rules, architecture modules, API contracts, database entities, permissions, operational constraints, and data flows are touched by the change. `component-impact-map.json` records new components, reused components, extraction triggers, forbidden dependencies, hooks/utilities/services to extract, and required component tests.

If either map contains unresolved gaps, Helm blocks development and guides the user to update the relevant foundation spec first.

## 5. Prototype Stage

Prototype is the second lifecycle stage:

```text
requirements -> prototype -> development
```

Prototype stage produces isolated prototype code to make design decisions visible and testable. The code must be runnable and reviewable, but it is not production implementation and can only be promoted through the development gate.

Core rule:

```text
Prototype code is required for prototype-stage review.
Prototype code is not production code.
Prototype code must be isolated, labeled, runnable, reviewable, and disposable or promotable only through development gates.
```

Development may implement approved prototypes, but must not invent UI structure, interaction behavior, API contracts, data flows, component boundaries, or review decisions during coding.

### 5.1 Entry Gates

Entering `/helm-prototype` requires:

- all four foundation specs exist and pass structural validation;
- `requirements.md` exists;
- `acceptance.md` exists;
- `spec-map.json` exists and has no unresolved gaps;
- `component-impact-map.json` exists and has no unresolved gaps;
- any required project-level spec updates from requirements are complete.

If prototype work needs design context, Helm must locate the relevant design system, UI kit, existing components, screenshots, brand assets, routes, state models, API examples, or domain docs before writing prototype code. If required context cannot be found, prototype work is blocked and Helm asks for the missing material. There is no fallback to generic design.

### 5.2 Question Classification

Prototype begins by identifying the question the prototype must answer:

| Question type | Prototype branch | Output |
| --- | --- | --- |
| UI, visual design, layout, interaction | `ui-html` | high-fidelity HTML prototype with variants and tweaks |
| state machine, business logic, backend behavior | `logic-state` | runnable logic prototype that exposes full state after each action |
| API or data contract | `api-contract` | contract stub, mock server, schemas, request/response examples |
| frontend-backend chain | `data-flow` | executable or narrated flow harness with observable transitions |
| component/API boundary | `component-seam` | component or interface prototype comparing seams and public APIs |

The branch choice is recorded in `prototype/question.md` and `prototype/prototype-manifest.json`. Choosing the wrong branch is a blocker because the prototype would answer the wrong question.

### 5.3 Prototype Artifacts

Prototype artifacts live under the active change:

```text
openspec/changes/<change>/
  prototype.md
  prototype/
    context.md
    question.md
    prototype-manifest.json
    artifact/
      index.html
      assets/
      src/
    logic/
      README.md
      run.sh
      src/
    api/
      openapi.yaml
      mock-server/
      examples/
    component/
      README.md
      src/
    variants.json
    tweaks.schema.json
    screen-map.json
    interaction-map.md
    component-tree.md
    data-flow-map.md
    verifier-report.json
    review.md
    learned.md
    handoff.md
    decision.json
```

Only the branch-specific directories required by the prototype question must exist. UI and interaction prototypes use `prototype/artifact/index.html`; logic prototypes use `prototype/logic/`; API prototypes use `prototype/api/`; component seam prototypes use `prototype/component/`.

`prototype-manifest.json` records:

- prototype type;
- entry file or command;
- dependencies;
- mock strategy;
- whether it touches real data;
- referenced foundation specs;
- referenced requirements;
- whether it may be promoted;
- cleanup or promotion requirement.

### 5.4 Variants and Tweaks

When UI, interaction, API shape, or component boundary has more than one plausible answer, Helm must explore alternatives before approval.

Default UI variants:

- `conservative`: follows existing design system and components closely;
- `balanced`: improves information architecture or interaction within existing constraints;
- `exploratory`: tries a stronger visual or interaction direction and names the risks.

For component/API boundaries, Helm may use a design-it-twice pattern: produce several materially different public interfaces or seams, then compare them by leverage, locality, seam placement, dependency strategy, and testability.

Tweaks are allowed inside prototype code for review, but final approval must freeze the chosen values into `decision.json`. Tweaks do not replace a user decision.

### 5.5 Review Labels and Feedback Mapping

Prototype code must expose stable review anchors:

- screens have stable labels;
- major components have stable labels;
- variants have stable IDs;
- reviewable states have stable IDs.

For HTML prototypes, use project-local attributes such as:

```html
data-helm-screen="checkout-confirmation"
data-helm-component="payment-summary"
data-helm-state="error"
data-helm-variant="balanced"
```

`screen-map.json` maps these labels back to requirements, acceptance criteria, components, data flows, and eventual implementation files.

### 5.6 Prototype Verification

Before prototype approval, Helm must verify:

- required prototype code exists;
- the entry file or command works;
- UI prototypes open successfully;
- there are no obvious console/runtime errors;
- variants can be selected;
- tweaks work or are explicitly not needed;
- desktop and mobile viewports do not break;
- text does not overlap or overflow important containers;
- loading, empty, error, disabled, and permission states are reviewable where relevant;
- logic prototypes expose state transitions after each action;
- API prototypes include concrete request/response/error examples;
- component prototypes show the proposed public API and reuse/extraction impact;
- `screen-map.json`, `component-tree.md`, `data-flow-map.md`, and `handoff.md` have no unresolved gaps.

Failures write `prototype/verifier-report.json` and set `prototype/decision.json.status` to `blocked`.

### 5.7 Decision and Development Handoff

Only `prototype/decision.json.status = "approved"` allows transition to development.

Example:

```json
{
  "status": "approved",
  "prototype_code": "required_present",
  "prototype_type": "ui-html",
  "approved_variant": "balanced",
  "promotion": "requires_development_gate",
  "blocked_reasons": []
}
```

`prototype/handoff.md` must include:

- approved prototype branch and variant;
- screens or flows to implement;
- components to create;
- components to reuse;
- components, hooks, utilities, or services to extract;
- API contracts;
- data flows;
- state, loading, empty, error, disabled, and permission behavior;
- out-of-scope items;
- required tests;
- open risks.

Prototype code cannot be copied directly into production code. If any prototype code is promoted, it must enter development through `scope.json`, `tasks.md`, component extraction rules, API/data-flow contracts, and verification gates.

## 6. Development Stage

Development is not where decisions are invented. It is where approved decisions become production code through scoped vertical slices, file-backed task execution, TDD evidence, and review loops.

No production code without:

- approved requirements;
- approved or explicitly skipped prototype;
- valid `scope.json`;
- vertical-slice tasks;
- task brief;
- TDD evidence or explicit exception;
- spec review;
- quality review.

The lifecycle position is:

```text
requirements -> prototype -> development -> verification
```

### 6.1 Entry Gates

Development can start only when all required upstream artifacts are present and valid:

- all four foundation specs are valid;
- `requirements.md` exists;
- `acceptance.md` exists;
- `spec-map.json` has no unresolved gaps;
- `component-impact-map.json` has no unresolved gaps;
- `prototype/decision.json` exists;
- `prototype/handoff.md` exists;
- `prototype/decision.json.status` is `approved`, or `not_required` with a concrete reason.

If implementation needs a new product, architecture, data-flow, or component-boundary decision, Helm must stop development and route back to the relevant requirements, prototype, or foundation-spec stage. There is no fallback path that lets development invent that decision.

### 6.2 Development Artifacts

Development writes and reads a file-backed execution contract:

```text
openspec/changes/<change>/
  design.md
  scope.json
  tasks.md
  development/
    before-dev-check.json
    basis.md
    prototype-promotion-map.json
    complexity-budget.json
    task-graph.json
    task-context.jsonl
    task-ledger.jsonl
    drift-check.jsonl
    code-owner-map.json
    extraction-map.json
    validation-log.jsonl
    handoff-to-verify.md
    tasks/
      001-<slug>/
        brief.md
        context.json
        report.md
        review-package.diff
        spec-review.md
        quality-review.md
        fix-report.md
```

`before-dev-check.json` records the deterministic entry-gate result. `basis.md` explains which requirements, prototype decisions, and specs the implementation is allowed to rely on. `task-ledger.jsonl` is append-only and is the resume source together with git state.

### 6.3 Scope Lock

`scope.json` is mandatory before any production edit:

```json
{
  "schema_version": 1,
  "change_id": "example-change",
  "stage": "development",
  "allowed_roots": [
    "src/features/example/**",
    "src/shared/components/**",
    "tests/example/**"
  ],
  "denied_roots": [
    "tests/acceptance/**",
    ".env*",
    "scripts/deploy/**"
  ],
  "allowed_operations": {
    "create": true,
    "modify": true,
    "delete": false,
    "rename": true
  },
  "requires_review_on": [
    "src/shared/**",
    "package.json",
    "database/**",
    "migrations/**"
  ],
  "prototype_sources": [
    "openspec/changes/example-change/prototype/artifact/index.html"
  ],
  "expires_when": "verification_started"
}
```

Scope rules:

- missing `scope.json` blocks production edits;
- edits outside `allowed_roots` block;
- edits inside `denied_roots` block;
- delete, migration, dependency, and shared-component changes escalate review strength;
- implementers cannot expand scope and must report `NEEDS_CONTEXT` or `BLOCKED`.

### 6.4 Vertical Slice Tasking

`tasks.md` must describe tracer-bullet vertical slices, not layer tasks.

Bad:

```markdown
- build database
- build API
- build UI
```

Good:

```markdown
- user can view checkout summary
- user can submit checkout form
- user sees payment failure state
```

Each slice must be:

- narrow but complete;
- cross the needed layers;
- independently verifiable or demoable;
- explicit about non-goals;
- bound to an owner and allowed files;
- clear about public interfaces and seams;
- backed by focused tests.

### 6.5 Task Brief Contract

Every development task gets its own brief:

```markdown
# Task 001: Checkout Summary Slice

## Goal
## Parent Artifacts
## Vertical Slice
## In Scope
## Out Of Scope
## Files Allowed
## Interfaces / Seams
## Components To Create
## Components To Reuse
## Components To Extract
## API / Data Flow Contracts
## State / Error / Empty / Loading Behavior
## TDD Requirement
## Verification Commands
## Stop Conditions
## Unsafe Assumptions
```

The dispatch context is machine-readable:

```json
{
  "task_id": "001-checkout-summary",
  "goal": "Implement checkout summary slice",
  "stop_condition": "slice implemented, tests pass, report written",
  "must_read": [
    "openspec/changes/example/development/tasks/001-checkout-summary/brief.md",
    "openspec/changes/example/prototype/handoff.md"
  ],
  "allowed_files": [
    "src/features/checkout/Summary.tsx",
    "tests/checkout/summary.test.tsx"
  ],
  "non_goals": [
    "payment submission",
    "database persistence"
  ],
  "expected_evidence": [
    "RED test output",
    "GREEN test output",
    "focused validation command"
  ],
  "unsafe_assumptions": []
}
```

### 6.6 Prototype Promotion

Prototype code is a visual and behavioral reference. It does not become production code directly.

`development/prototype-promotion-map.json` declares what can move forward:

```json
{
  "schema_version": 1,
  "promotion_policy": "reimplement_under_development_gate",
  "allowed_to_copy": [
    "approved copy text",
    "token names",
    "state names",
    "interaction names"
  ],
  "must_reimplement": [
    "component structure",
    "state management",
    "API calls",
    "validation logic",
    "styling implementation"
  ],
  "blocked_direct_copies": [
    "inline prototype JS",
    "mock data",
    "prototype CSS reset",
    "temporary helpers"
  ]
}
```

Helm migrates decisions, not temporary code. If production constraints conflict with the prototype, development stops and routes back to the prototype or foundation spec that owns the decision.

### 6.7 Implementation Loop

Implementation status is limited to:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

Status handling:

- `DONE` enters spec review;
- `DONE_WITH_CONCERNS` requires controller adjudication before review;
- `NEEDS_CONTEXT` updates the task brief or context and re-dispatches;
- `BLOCKED` determines whether the task is too large, the plan is wrong, the scope is missing, or the spec is missing.

Helm must not force a blocked task through implementation.

### 6.8 Review Loop

Each task completes through the same loop:

```text
implementer report
-> spec review
-> fix
-> spec re-review
-> quality review
-> fix
-> quality re-review
-> task ledger complete
```

`report.md`:

```markdown
# Implementation Report

## Status
DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED

## Files Changed
## What Changed
## TDD Evidence
### RED
### GREEN
### REFACTOR
## Verification Commands
## Concerns
## Scope Deviations
## Follow-up Needed
```

`spec-review.md`:

```markdown
# Spec Review

## Verdict
approved | needs-fix | blocked

## Missing Requirements
## Extra Behavior
## Misunderstood Requirements
## Cannot Verify From Diff
## Required Fixes
```

`quality-review.md`:

```markdown
# Quality Review

## Verdict
approved | needs-fix | blocked

## Separation Of Concerns
## Component Cohesion / Coupling
## Test Quality
## Error Handling
## Reuse / Duplication
## Complexity Delta
## Required Fixes
```

Rules:

- spec review runs before quality review;
- spec review failure blocks quality review;
- quality review failure blocks task completion;
- Critical and Important findings must be fixed;
- reviewer suggestions must be verified before applying;
- review conclusions must come from files, tests, logs, generated artifacts, and runtime state rather than chat memory.

### 6.9 Ledger and Drift Checks

`task-ledger.jsonl` records task progress:

```jsonl
{"task":"001-checkout-summary","status":"started","base":"abc1234","time":"2026-06-23T10:00:00Z"}
{"task":"001-checkout-summary","status":"spec_review_passed","head":"def5678"}
{"task":"001-checkout-summary","status":"quality_review_passed","head":"def5678"}
{"task":"001-checkout-summary","status":"complete","tests":"npm test summary.test.tsx"}
```

`drift-check.jsonl` records whether implementation diverged from approved artifacts:

```json
{
  "task": "001-checkout-summary",
  "against": [
    "requirements.md",
    "prototype/handoff.md",
    "spec-map.json",
    "component-impact-map.json"
  ],
  "drift": "none",
  "blocking": false,
  "notes": []
}
```

Blocking drift routes to the owning stage:

- product behavior drift -> requirements;
- UI or interaction drift -> prototype;
- API/data-flow drift -> data-flow spec;
- component-boundary drift -> component-architecture spec;
- scope drift -> development artifacts.

### 6.10 Development Completion Gate

Development can hand off to verification only when:

- `scope.json` is valid;
- `prototype-promotion-map.json` is valid;
- all task briefs are complete;
- all implementation reports are `DONE` or adjudicated;
- all spec reviews are approved;
- all quality reviews are approved;
- `task-ledger.jsonl` shows every task complete;
- `drift-check.jsonl` has no blocking drift;
- `validation-log.jsonl` has fresh checks;
- `handoff-to-verify.md` exists.

`handoff-to-verify.md`:

```markdown
# Handoff To Verification

## Implemented Slices
## Files Changed
## Requirements Covered
## Prototype Decisions Implemented
## Components Created / Reused / Extracted
## API / Data Flow Changes
## Tests Added
## Local Validation
## Known Risks
## Items Requiring Six-Domain Verification
```

## 7. User Entry Points

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
- prototype: `prototype`, `prototype-context`, `prototype-ui`, `prototype-logic`, `prototype-api`, `prototype-data-flow`, `prototype-component`, `prototype-variants`, `prototype-review`, `prototype-verify`, `prototype-handoff`;
- development: `before-dev`, `production-design`, `scope-lock`, `vertical-slice-tasking`, `task-brief`, `implement`, `prototype-promoter`, `component-extractor`, `task-spec-review`, `task-quality-review`, `dev-drift-check`, `local-validation`, `verify-handoff`, `fix`, `debug`, `break-loop`;
- verification: `verify`, `verify-plan`, `verify-facticity`, `verify-static`, `verify-unit`, `verify-redteam`, `verify-e2e`, `verify-sensory`, `verify-aggregate`, `verify-rerun`;
- operations: `ops-readiness`, `release-plan`, `install-verify`, `update-policy`, `compatibility-matrix`, `branch-finish`, `deploy`, `rollback`, `monitor`, `postmortem`, `archive`, `update-spec`.

Agents are optional judgment workers:

- `explorer`: read-only codebase discovery.
- `verifier`: independent review after deterministic evidence exists.

## 8. Runtime State

Helm writes project-local state:

```text
openspec/
  specs/
    ui-design/design.md
    system-architecture/design.md
    frontend-backend-data-flow/design.md
    component-architecture/design.md
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
    prototype/
      context.md
      question.md
      prototype-manifest.json
      artifact/
        index.html
        assets/
        src/
      logic/
        README.md
        run.sh
        src/
      api/
        openapi.yaml
        mock-server/
        examples/
      component/
        README.md
        src/
      variants.json
      tweaks.schema.json
      screen-map.json
      interaction-map.md
      component-tree.md
      data-flow-map.md
      verifier-report.json
      review.md
      learned.md
      handoff.md
      decision.json
    design.md
    spec-map.json
    component-impact-map.json
    scope.json
    tasks.md
    development/
      before-dev-check.json
      basis.md
      prototype-promotion-map.json
      complexity-budget.json
      task-graph.json
      task-context.jsonl
      task-ledger.jsonl
      drift-check.jsonl
      code-owner-map.json
      extraction-map.json
      validation-log.jsonl
      handoff-to-verify.md
      tasks/
        001-<slug>/
          brief.md
          context.json
          report.md
          review-package.diff
          spec-review.md
          quality-review.md
          fix-report.md
    specs/
    risk-tier.json
    verify/
      plan.md
      plan.json
      evidence-index.jsonl
      traceability-matrix.json
      blocker-classification.jsonl
      receipt.md
      receipt.json
      root-cause-checks.jsonl
      behavior-evals/
        scenarios.json
        transcripts/
        report.md
        report.json
      facticity/
        claims.jsonl
        repo-inventory.json
        report.md
        report.json
      static/
        commands.jsonl
        report.md
        report.json
      unit/
        test-map.json
        test-quality-rubric.json
        coverage-notes.md
        report.md
        report.json
      redteam/
        threat-model.md
        probes.jsonl
        report.md
        report.json
      e2e/
        flows.json
        run-log.jsonl
        report.md
        report.json
      sensory/
        reviewer-independence.md
        review.md
        findings.jsonl
        report.json
      aggregate-report.md
      aggregate-report.json
    operations/
      readiness.md
      readiness.json
      release-plan.md
      release-checklist.json
      install-verification.json
      update-policy.json
      compatibility-matrix.md
      deploy-plan.md
      rollback-plan.md
      monitor-plan.md
      branch-finish.md
      changelog.md
      release-notes.md
      signoff.yaml
      postmortem.md
      archive-gate.json
      archive-log.jsonl
    verify-report.stale
    signoff.yaml
```

`active-change` is plain text. `workflow-state.json` is the required state-machine input. `affordances.json` is cached derived state. `events.jsonl` is append-only telemetry and must not become critical state. `journal/` is human-readable project memory for session recovery and postmortems.

## 9. Script Contracts

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

## 10. Hook Policy

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

## 11. File Scope Contract

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

## 12. Verification Stage

Verification is the testing stage. It does not replace development review. It starts only after development has produced a complete `handoff-to-verify.md` and all development drift is resolved.

Verification has two layers:

1. `verify` orchestrates deterministic checks, evidence collection, and domain skill execution.
2. `verifier` judges adequacy only after script and file-backed evidence exists.

The aggregate report can be:

- `green`
- `red`

Domain verdicts can be:

- `green`
- `red`
- `blocked`

Warnings are per-check metadata only when the related check is optional for the current risk tier. Missing required verification is red, not warning. A blocked domain makes the aggregate report red. After any write, `verify-report.stale` blocks archive until verification runs again.

### 12.1 Entry Gates

Verification can start only when:

- all development entry gates were previously satisfied;
- `development/handoff-to-verify.md` exists;
- `development/task-ledger.jsonl` shows every task complete;
- every task has approved `spec-review.md`;
- every task has approved `quality-review.md`;
- `development/drift-check.jsonl` has no blocking drift;
- `validation-log.jsonl` has fresh local development checks;
- `risk-tier.json` exists or can be generated deterministically;
- changed files can be mapped to requirements, specs, tasks, and prototype decisions.

If any gate fails, `/helm-verify` reports the missing artifact and routes back to the owning stage. It must not fabricate evidence, skip a required domain, or downgrade the failure to a warning.

### 12.2 Verification Artifacts

Verification writes a domain-oriented evidence tree:

```text
openspec/changes/<change>/
  verify/
    plan.md
    plan.json
    evidence-index.jsonl
    traceability-matrix.json
    blocker-classification.jsonl
    receipt.md
    receipt.json
    root-cause-checks.jsonl
    behavior-evals/
      scenarios.json
      transcripts/
      report.md
      report.json
    facticity/
      claims.jsonl
      repo-inventory.json
      report.md
      report.json
    static/
      commands.jsonl
      report.md
      report.json
    unit/
      test-map.json
      test-quality-rubric.json
      coverage-notes.md
      report.md
      report.json
    redteam/
      threat-model.md
      probes.jsonl
      report.md
      report.json
    e2e/
      flows.json
      run-log.jsonl
      report.md
      report.json
    sensory/
      reviewer-independence.md
      review.md
      findings.jsonl
      report.json
    aggregate-report.md
    aggregate-report.json
```

`evidence-index.jsonl` lists every command, file, screenshot, log, report, and manual review note used by the six domains. `aggregate-report.json` is the machine-readable gate input. `aggregate-report.md` is the human review surface.

### 12.3 Verification Plan

`verify/plan.json` is generated before any domain runs:

```json
{
  "schema_version": 1,
  "change_id": "example-change",
  "risk_tier": "medium",
  "required_domains": [
    "facticity",
    "static",
    "unit",
    "redteam",
    "e2e",
    "sensory"
  ],
  "inputs": [
    "requirements.md",
    "acceptance.md",
    "prototype/handoff.md",
    "development/handoff-to-verify.md",
    "spec-map.json",
    "component-impact-map.json",
    "risk-tier.json"
  ],
  "changed_files": [],
  "commands": [],
  "manual_reviews": []
}
```

The plan is derived from changed files, risk tier, requirements, accepted prototype decisions, component impact, data-flow impact, and development handoff. Risk tier changes depth and required commands, but does not remove the six verification domains from the stage.

### 12.4 Traceability and Impact Matrix

Verification must prove that every changed file is traceable to the user's request and approved artifacts.

`verify/traceability-matrix.json` records:

```json
{
  "schema_version": 1,
  "change_id": "example-change",
  "entries": [
    {
      "changed_file": "src/features/checkout/Summary.tsx",
      "change_reason": "checkout summary slice",
      "requirement_refs": ["requirements.md#checkout-summary"],
      "task_refs": ["development/tasks/001-checkout-summary/brief.md"],
      "prototype_refs": ["prototype/handoff.md#summary-screen"],
      "foundation_spec_refs": [
        "openspec/specs/ui-design/design.md",
        "openspec/specs/component-architecture/design.md"
      ],
      "verification_domains": ["facticity", "static", "unit", "e2e", "sensory"],
      "impact_notes": "touches shared summary component only through approved interface"
    }
  ],
  "unmapped_changes": []
}
```

Rules:

- every changed file must have at least one requirement/task/spec reason;
- every public behavior change must map to acceptance criteria;
- every shared module or component change must map to component architecture rules;
- every cross-layer change must map to the data-flow spec;
- `unmapped_changes` makes `verify-facticity` red.

This is the Trellis-style changed-line discipline adapted to Helm: changed files must trace to the request, and verification must detect unexpected blast radius before release.

### 12.5 Evidence Receipt and Blocker Classification

`verify/receipt.json` is the completion-claim receipt. It prevents a green report from turning into an overbroad claim.

```json
{
  "schema_version": 1,
  "change_id": "example-change",
  "evidence_action": "ran six-domain verification",
  "result": "green",
  "covered_scope": [
    "checkout summary slice",
    "component extraction",
    "static checks",
    "unit and e2e checks"
  ],
  "uncovered_scope": [],
  "residual_risk": [],
  "confidence": "A"
}
```

Confidence grades:

- `A`: direct evidence plus regression coverage, no known open risks;
- `B`: direct evidence with bounded residual risk;
- `C`: partial evidence only and not release-ready.

`verify/blocker-classification.jsonl` distinguishes environment and contract failures:

```jsonl
{"domain":"static","blocker_class":"tool-unavailable","detail":"eslint command missing"}
{"domain":"e2e","blocker_class":"env-auth","detail":"browser login credential unavailable"}
{"domain":"behavior-evals","blocker_class":"contract-regression","detail":"bootstrap did not auto-trigger"}
```

Allowed blocker classes:

- `tool-unavailable`
- `env-auth`
- `env-runtime`
- `contract-regression`
- `insufficient-evidence`
- `product-ambiguity`
- `scope-drift`

Environment blockers are neither pass nor plugin regression by default. They are explicit blocked evidence. Contract regressions are red.

### 12.6 Behavior Evals and Clean-Session Acceptance

Plugin behavior must be tested separately from deterministic script fixtures.

`verify/behavior-evals/scenarios.json` defines clean-session scenarios:

```json
{
  "schema_version": 1,
  "scenarios": [
    {
      "id": "missing-openspec-blocks-production-write",
      "prompt": "implement this feature",
      "expected": [
        "detect missing openspec",
        "block production edit",
        "offer init or repair only"
      ]
    },
    {
      "id": "verify-runs-six-domains",
      "prompt": "/helm-verify",
      "expected": [
        "load active change",
        "generate verify plan",
        "run or block all six domains",
        "write aggregate report"
      ]
    }
  ]
}
```

Behavior evals require clean-session transcripts. They validate:

- bootstrap and router fire without per-session opt-in;
- `/helm-status` reports the active state from files;
- `/helm-implement` does not bypass requirements, prototype, scope, or task gates;
- `/helm-verify` writes plan, six domain reports, evidence index, receipt, and aggregate report;
- blocked tools are classified honestly.

Script tests stay under normal test suites. Skill behavior evals live under `verify/behavior-evals/` and must record transcripts or machine-readable run logs.

### 12.7 Test Quality and Interface Surface

`verify-unit` checks test quality, not just test count.

`verify/unit/test-quality-rubric.json` records:

```json
{
  "schema_version": 1,
  "checks": {
    "behavior_facing": true,
    "public_interface_only": true,
    "survives_refactor": true,
    "one_logical_assertion_per_test": true,
    "no_internal_mock_coupling": true,
    "critical_paths_covered": true,
    "edge_cases_covered": true
  },
  "findings": []
}
```

Rules:

- tests should verify behavior through stable public interfaces;
- tests should describe what the system does, not how internals collaborate;
- tests should survive internal refactors when behavior is unchanged;
- testing private methods, internal call counts, or mock-only collaborator behavior is a finding;
- if a module cannot be tested through a stable interface, `verify-sensory` or `verify-unit` must flag the design surface.

This links verification back to the component-architecture and high-cohesion/low-coupling specs: the interface is the test surface.

### 12.8 Reviewer Independence

`verify-sensory` is a review domain, so it needs an independence contract.

`verify/sensory/reviewer-independence.md` records:

```markdown
# Reviewer Independence

## Inputs Allowed
## Inputs Excluded
## Controller Claims Ignored
## Files Reviewed
## Evidence References
## Cannot Verify From Provided Evidence
```

Rules:

- the sensory reviewer is read-only;
- the reviewer must not mutate the working tree, index, branch, or artifacts under review;
- implementer reports and controller summaries are treated as claims, not evidence;
- the controller cannot tell the reviewer to ignore, downgrade, or pre-classify a finding;
- every finding needs file:line, command output, artifact reference, screenshot, transcript, or manual inspection note;
- `cannot verify from provided evidence` is a valid finding and must be resolved by the controller before aggregate green.

### 12.9 Root-Cause Check for Verification Failures

When verification fails, Helm must classify the failure before routing fixes.

`verify/root-cause-checks.jsonl` records:

```jsonl
{"domain":"e2e","topology":"chain","causal_closure":"closed","falsifier_checked":true,"self_refutation":"API mock could be wrong; live handler log disproves it","layer_ceiling":"data-flow spec owns missing retry behavior","route":"frontend-backend-data-flow spec"}
```

Rules:

- every causal edge needs an evidence anchor;
- if the claimed root is wrong, the report must name the observable falsifier checked;
- multi-root or chain failures must be classified instead of defaulting to single-root;
- if the root cause is undefined product behavior, route to requirements rather than patching code;
- if the fix would add fallback, adapter, compatibility, or duplicate-owner logic, the repair must include a retirement trigger or explicit residual risk.

### 12.10 Six Dedicated Verification Skills

Each domain has a dedicated skill. The aggregate `verify` skill only orchestrates; it does not collapse the six domains into one generic review.

| Skill | Purpose | Required evidence | Primary blocker |
| --- | --- | --- | --- |
| `verify-facticity` | Audit specs, architecture claims, APIs, dependencies, config, routes, database claims, traceability, and generated artifacts against actual repo/system state. | `claims.jsonl`, `repo-inventory.json`, `traceability-matrix.json`, direct file or command references. | undocumented, stale, invented, or unmapped facts |
| `verify-static` | Run OpenSpec validation, linting, type checks, dependency checks, schema validation, banned-pattern scans, and structural checks. | command log, exit codes, config files, static reports. | syntax, style, type, schema, or policy failure |
| `verify-unit` | Confirm changed logic has focused unit or regression coverage, including edge cases, extreme inputs, empty states, error paths, and test-quality checks. | test map, red/green output, `test-quality-rubric.json`, coverage notes, explicit untestable exceptions. | untested core logic, failing tests, or implementation-coupled tests |
| `verify-redteam` | Exercise destructive, adversarial, injection, boundary, permission, abuse, and resilience cases. | threat model, probes, payloads, expected/actual outcomes, root-cause check when failures occur. | exploitable security or robustness issue |
| `verify-e2e` | Validate complete user/business flows against realistic frontend, backend, API, state, database, and external integration paths. | flow list, run logs, screenshots or traces when applicable. | broken integration path or state inconsistency |
| `verify-sensory` | Human-in-the-loop UX/code review for readability, interaction quality, performance feel, accessibility, maintainability, reviewer independence, and user experience. | reviewer independence record, review notes, findings, screenshots or manual inspection notes when applicable. | unacceptable human experience, maintainability, or unverifiable review claim |

### 12.11 Domain Contracts

Every domain report uses the same skeleton:

```markdown
# Verification Domain Report

## Domain
## Verdict
green | red | blocked

## Inputs Reviewed
## Evidence
## Commands Run
## Findings
## Required Fixes
## Residual Risk
## Follow-up Domain Routing
```

Every `report.json` uses:

```json
{
  "schema_version": 1,
  "domain": "static",
  "verdict": "green",
  "required": true,
  "evidence": [],
  "commands": [],
  "blocker_class": null,
  "findings": [],
  "required_fixes": [],
  "residual_risk": []
}
```

Required fixes block aggregate green. Residual risk is allowed only when it is explicit, non-blocking, and accepted by the relevant stage owner or sign-off policy.

### 12.12 Failure Routing

Verification failures route back to the stage that owns the defect:

- facticity failure in docs/specs -> requirements or foundation spec;
- facticity failure in implementation -> development;
- static failure -> development fix;
- unit failure -> development task fix or task split;
- redteam failure -> requirements, architecture spec, data-flow spec, or development depending on `root-cause-checks.jsonl`;
- e2e failure -> data-flow spec, prototype, or development depending on where the chain broke and the root-cause check;
- sensory UX failure -> prototype or UI design spec;
- sensory code-quality failure -> development, component architecture spec, or refactor task.

After any fix, Helm marks `verify-report.stale` and reruns the affected domain plus any downstream domains that depended on the changed behavior.

### 12.13 Aggregate Report

`aggregate-report.json` is the archive gate input:

```json
{
  "schema_version": 1,
  "change_id": "example-change",
  "verdict": "green",
  "domains": {
    "facticity": "green",
    "static": "green",
    "unit": "green",
    "redteam": "green",
    "e2e": "green",
    "sensory": "green"
  },
  "blocking_findings": [],
  "residual_risk": [],
  "evidence_receipt": "verify/receipt.json",
  "behavior_eval_report": "verify/behavior-evals/report.json",
  "stale": false,
  "generated_at": "2026-06-23T10:00:00Z"
}
```

The aggregate report is red when any required domain is `red` or `blocked`, any required evidence is missing, any required command cannot run, or the report is stale.

### 12.14 Verification Completion Gate

Verification can hand off to operations only when:

- `verify/plan.json` exists and all planned domains ran;
- `traceability-matrix.json` has no unmapped changes;
- all six domain reports exist;
- each required domain verdict is `green`;
- `evidence-index.jsonl` references the evidence behind every domain verdict;
- `receipt.json` lists covered scope, uncovered scope, residual risk, and confidence;
- `blocker-classification.jsonl` contains no unresolved blocker;
- `behavior-evals/report.json` passes all required clean-session scenarios;
- `unit/test-quality-rubric.json` has no blocking findings;
- `sensory/reviewer-independence.md` exists and lists excluded claims;
- `aggregate-report.json.verdict` is `green`;
- `verify-report.stale` is absent;
- high-risk changes have required sign-off;
- `aggregate-report.md` is readable by humans and lists residual risk.

If these conditions are not met, `/helm-release`, `/helm-archive`, and operations handoff are blocked.

## 13. Operations Stage

Operations is where a verified change becomes a releasable, deployable, monitorable, and archivable outcome. It is not a loose wrap-up step. It has the same artifact discipline as requirements, prototype, development, and verification.

The reference repositories point to three hard requirements for this stage:

- Aegis-style install and update discipline: verify the plugin from the method-pack/plugin root, use JSON doctor output, record host-scoped update metadata, and update all hosts only when explicitly requested.
- Superpowers-style branch finishing: verify tests before completion options, detect git/worktree state with read-only commands, preserve PR worktrees, and clean up only worktrees Helm can prove it created.
- Trellis-style lifecycle hooks and archive discipline: archive is a state transition with explicit artifacts, not deletion or a conversational ending.

### 13.1 Operations Entry Gate

Operations can start only when:

- `verify/aggregate-report.json.verdict` is `green`;
- `verify/receipt.json` exists and lists covered scope, uncovered scope, residual risk, and confidence;
- `verify/blocker-classification.jsonl` has no unresolved blocker;
- `verify-report.stale` is absent;
- high-risk sign-off required by policy is complete;
- `development/handoff-to-verify.md` and `verify/aggregate-report.md` both exist;
- current git branch, worktree, staged changes, and untracked files are known;
- release target is selected: `local-only`, `plugin-marketplace`, `package`, `host-compatibility`, or `project-deploy`.

If any item is missing, `/helm-release`, `/helm-deploy`, `/helm-archive`, and branch finish are blocked. No fallback path may silently downgrade operations to a note.

### 13.2 Operations Artifact Contract

Operations writes:

```text
openspec/changes/<change>/operations/
  readiness.md
  readiness.json
  release-plan.md
  release-checklist.json
  install-verification.json
  update-policy.json
  compatibility-matrix.md
  deploy-plan.md
  rollback-plan.md
  monitor-plan.md
  branch-finish.md
  changelog.md
  release-notes.md
  signoff.yaml
  postmortem.md
  archive-gate.json
  archive-log.jsonl
```

`readiness.json` is the machine gate:

```json
{
  "schema": "helm.ops.readiness.v1",
  "change": "add-login-flow",
  "release_target": "plugin-marketplace",
  "verification": {
    "aggregate_verdict": "green",
    "receipt_confidence": "A",
    "uncovered_scope": [],
    "residual_risk": []
  },
  "git": {
    "branch": "helm/add-login-flow",
    "worktree_mode": "normal",
    "dirty": false,
    "untracked_reviewed": true
  },
  "docs": {
    "changelog": true,
    "release_notes": true,
    "readme_updated": true
  },
  "ops": {
    "install_verification": "pass",
    "update_policy": "pass",
    "rollback_plan": "pass",
    "monitor_plan": "pass"
  },
  "ready": true
}
```

### 13.3 Release Targets

`release-plan.md` declares exactly one primary target and optional secondary targets.

| Target | Meaning | Required artifacts |
| --- | --- | --- |
| `local-only` | Keep the change local and ready for user-controlled merge or install. | readiness, branch finish, changelog if user-facing. |
| `plugin-marketplace` | Publish or install as a Claude Code plugin package. | release checklist, install verification, compatibility matrix, README updates. |
| `package` | Produce a versioned local artifact such as tarball or zip. | release notes, package validation, checksum if supported. |
| `host-compatibility` | Declare or update support for a host. | compatibility matrix, host-specific install verification, known limitations. |
| `project-deploy` | Deploy application/runtime changes. | deploy plan, rollback plan, monitor plan, postmortem template. |

The target controls which operations skills are required. A missing required artifact blocks release.

### 13.4 Install Verification Contract

`install-verification.json` records plugin install health. Helm must verify from the plugin/method-pack root, not from the target project directory.

Claude Code plugin repositories may contain more than one plugin. Helm therefore distinguishes:

- `marketplace_root`: the repository root containing `.claude-plugin/marketplace.json`;
- `plugin_root`: the individual plugin source directory referenced by `marketplace.json.plugins[].source`.

Single-plugin repositories may have `plugins[0].source == "./"` and `marketplace_root == plugin_root`. Multi-plugin repositories may place Helm under `plugins/helm/` while sibling plugins live in the same marketplace. Doctor, install verification, update policy, compatibility checks, and release packaging must resolve the Helm `plugin_root` from marketplace metadata and must not assume the repository root is the plugin root.

Required fields:

```json
{
  "schema": "helm.ops.installVerification.v1",
  "marketplace_root": "/path/to/plugin-marketplace",
  "plugin_root": "/path/to/helm-plugin",
  "plugin_name": "helm",
  "plugin_source": "plugins/helm",
  "target_project": "/path/to/project",
  "command": "cd <helm-plugin-root> && <doctor-command> --write-config --json",
  "ok": true,
  "workspaceSupport": "available",
  "configStatus": "configured",
  "host": "claude-code",
  "discovery_root_checked": true,
  "reload_required": false
}
```

For Helm's own doctor output, the success contract must be equally explicit: `ok: true`, discoverable skills/commands/hooks, OpenSpec available, state machine valid, and required context manifests present.

### 13.5 Update Policy Contract

`update-policy.json` records how installed Helm surfaces are updated:

- default update is host-scoped;
- multi-host update requires an explicit all-host request;
- shared plugin roots may be updated once, but every registered host exposure must be re-synced and re-verified;
- discovery root and discovery shape are recorded when the host uses a separate skill/plugin discovery directory;
- update never runs as an unannounced background task.

Example:

```json
{
  "schema": "helm.ops.updatePolicy.v1",
  "registry_version": 1,
  "default_scope": "current-host",
  "all_hosts_requires_explicit_request": true,
  "installations": [
    {
      "id": "claude-code:default",
      "host": "claude-code",
      "pluginRoot": "/path/to/helm-plugin",
      "discoveryRoot": "/path/to/claude/plugins",
      "discoveryShape": "plugin-managed",
      "trackedRef": "main",
      "reloadHint": "restart Claude Code"
    }
  ]
}
```

### 13.6 Branch Finish Contract

`branch-finish.md` is separate from OpenSpec archive. It records:

- tests and verification checked before presenting finish options;
- `git rev-parse --git-dir`, `git rev-parse --git-common-dir`, current branch, base branch, and worktree path;
- selected finish action: local merge, push/PR, keep branch, or discard;
- whether the workspace is normal repo, linked worktree, or detached HEAD;
- cleanup decision and provenance.

Cleanup is allowed only when Helm can prove the worktree was Helm-created, for example by a matching record under `openspec/.helm/worktrees/` or another explicit Helm-owned provenance artifact. Harness-owned, externally managed, detached, or unknown worktrees must be preserved.

### 13.7 Deploy, Rollback, and Monitor

`deploy-plan.md` is required before a project deployment. It must list:

- environment and target;
- exact deploy command or manual step;
- config and secret prerequisites;
- database or migration effects;
- smoke checks;
- owner and deploy window.

`rollback-plan.md` is required before any deploy. It must list:

- rollback trigger conditions;
- exact rollback command or manual step;
- data recovery or migration reversal notes;
- expected rollback verification.

`monitor-plan.md` is required after deploy. It must list:

- logs, metrics, endpoints, queues, or user flows to watch;
- observation window;
- alert or manual check owner;
- expected normal values;
- escalation route.

If rollback or monitoring is impossible, operations is blocked until the user explicitly accepts that risk in `operations/signoff.yaml`.

### 13.8 Changelog, Release Notes, and Compatibility

User-facing changes require `changelog.md` and `release-notes.md`.

Host-facing plugin changes require `compatibility-matrix.md`:

- supported host;
- support level: `fresh-smoke`, `structural`, `documented-only`, or `unsupported`;
- install verification command;
- doctor result;
- known limitations;
- reload requirement.

Helm must not claim fresh host support without fresh host smoke evidence.

### 13.9 Postmortem and Learning Writeback

`postmortem.md` is required when:

- verification or deployment had blocking failures;
- rollback was used;
- security, data, or availability risk was discovered;
- the same failure repeated;
- operations introduced new system knowledge.

Before archive, `update-spec` checks whether the learning belongs in:

- requirements or acceptance criteria;
- UI design spec;
- system architecture spec;
- frontend-backend data-flow spec;
- component architecture spec;
- operational runbook or known limitations.

If learning exists and is not written back or explicitly deferred, archive is blocked.

### 13.10 Operations Completion Gate

Operations can hand off to archive only when:

- `readiness.json.ready` is `true`;
- release target required artifacts exist;
- install verification passes when plugin surfaces changed;
- update policy is recorded when installation or distribution changed;
- compatibility matrix is updated when host support claims changed;
- deploy has rollback and monitor plans when deployment is in scope;
- branch finish state is recorded, or explicitly not applicable;
- changelog and release notes exist for user-facing changes;
- residual risk is empty or accepted in `operations/signoff.yaml`;
- postmortem exists when required;
- `update-spec` ran or recorded no learning to write back;
- `archive-gate.json.verdict` is `green`;
- `archive-log.jsonl` records the final transition.

## 14. Governance Layer

The lifecycle stages require the following runtime governance capabilities.

### 14.1 Bootstrap and Router

Helm needs a `using-helm` bootstrap equivalent to `using-superpowers` and `using-aegis`.

Responsibilities:

- load at session start;
- remind the model to check Helm/OpenSpec state before acting;
- route user intent through lifecycle state instead of free-form implementation;
- enforce that production work cannot bypass requirements, prototype/design, tasks, verification, and operations gates.

### 14.2 State Machine and Artifact Contract

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

### 14.3 Project Memory and Journal

`events.jsonl` is not enough for long sessions. Helm needs a human-readable journal under `openspec/.helm/journal/`.

Journal entries record:

- session summary;
- decisions made;
- blockers found;
- user approvals;
- verification outcomes;
- operational handoff notes.

### 14.4 Spec Update and Learning Writeback

`update-spec` promotes implementation lessons back into OpenSpec before archive/release.

It records:

- new system invariants;
- changed interfaces or contracts;
- operational constraints;
- test lessons and regression cases;
- follow-up ADRs when needed.

### 14.5 Doctor and Health Check

`/helm-doctor` verifies the actual install and runtime surface:

- plugin manifest and marketplace metadata;
- skills, commands, agents, and hooks are discoverable;
- SessionStart, UserPromptSubmit where supported, PreToolUse, and PostToolUse hooks are wired;
- OpenSpec CLI exists and can validate the target repo;
- `openspec/` and required `.helm` state exist;
- state machine and active change are internally consistent;
- context manifests and verify artifacts are valid JSON/JSONL/Markdown as required.

### 14.6 Context Manifests and Subagent Injection

Subagent work must receive curated context manifests instead of broad prompts.

Target manifests:

- `requirements-context.jsonl`;
- `prototype-context.jsonl`;
- `implement-context.jsonl`;
- `verify-context.jsonl`;
- `ops-context.jsonl`.

If a required manifest is missing or invalid, dispatch is blocked.

### 14.7 Debug and Break-loop

`debug` / `break-loop` activates when the same failure repeats, a fix is reverted, verification keeps failing, or the agent starts patching symptoms.

It requires:

- root-cause statement;
- reproduction evidence;
- failed attempts log;
- hypothesis list;
- next experiment;
- re-verification command.

### 14.8 Git, Worktree, and Branch Finish

Helm needs a branch finish workflow separate from OpenSpec archive:

- detect current branch/worktree state;
- decide commit, PR, keep branch, or discard branch;
- prevent cleaning unrelated user worktrees;
- record final diff summary and validation evidence;
- archive only after git and OpenSpec state agree.

### 14.9 Release, Distribution, and Update

The plugin needs release engineering as part of the product:

- `CHANGELOG.md`;
- release checklist;
- plugin validation checklist;
- install/update docs;
- compatibility matrix;
- bilingual README files: `README.md` and `README.zh-CN.md`.

### 14.10 Behavior Evals and Clean-session Acceptance

Script tests are not enough. Helm needs behavior acceptance tests in clean sessions.

Required scenarios:

- missing `openspec/` blocks production edits and routes to init;
- "implement this feature" enters requirements/design before code;
- `/helm-verify` runs or blocks all required verification domains;
- archive is blocked by stale or red verification;
- doctor reports missing hooks/skills/OpenSpec without fallback.

## 15. Install and Update

Install:

```bash
claude plugin marketplace add /Volumes/zwl/AI/ai-coding/helm-claude-plugin --scope user
claude plugin install helm-core@helm-marketplace --scope user
claude plugin install helm-requirements@helm-marketplace --scope user
claude plugin install helm-prototype@helm-marketplace --scope user
claude plugin install helm-development@helm-marketplace --scope user
claude plugin install helm-verification@helm-marketplace --scope user
claude plugin install helm-operations@helm-marketplace --scope user
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

## 16. Test Strategy

Current test surface:

```bash
bash tests/run-plugin-validate-fixtures.sh
bash tests/run-smoke.sh
bash tests/run-hook-fixtures.sh
bash tests/run-override-fixtures.sh
bash tests/run-openspec-fixtures.sh
bash tests/run-archive-policy-fixtures.sh
bash tests/run-plugin-suite-layout-fixtures.sh
bash tests/run-plugin-suite-resolver-fixtures.sh
bash tests/run-core-runtime-fixtures.sh
bash tests/run-cross-plugin-state-fixtures.sh
bash tests/run-requirements-plugin-fixtures.sh
bash tests/run-prototype-plugin-fixtures.sh
bash tests/run-development-plugin-fixtures.sh
bash tests/run-verification-plugin-fixtures.sh
bash tests/run-operations-plugin-fixtures.sh
bash tests/run-skill-contract-fixtures.sh
bash tests/run-skill-resource-fixtures.sh
```

It checks:

- Claude Code marketplace and child plugin manifest validation;
- affordance generation;
- risk classification;
- verify report generation;
- archive gate;
- scope allow;
- scope deny;
- `scope.json` include/exclude behavior;
- hook payload normalization for write tools and Bash;
- explicit override records for blocking gates.
- OpenSpec CLI state parsing and explicit blocked states when required OpenSpec status is unavailable.
- stale verify archive blocking and high-risk sign-off requirements.
- foundation spec gate fixtures for requirements;
- prototype artifact contracts, branch classification, and prototype verification;
- development scope, vertical-slice tasking, review loop, ledger, drift, and handoff contracts;
- verification plan, traceability, evidence receipt, blocker classification, behavior eval transcript, unit rubric, reviewer independence, aggregate gate, and six domain contracts;
- operations readiness, release targets, install/update policy, compatibility, branch finish, deploy/rollback/monitor, postmortem, update-spec, and archive gate contracts;
- lifecycle state-machine, context manifest, journal, and doctor health checks.

## 17. Next Build Order

Completed in `0.2.0`:

- hook fixture tests and normalized payload extraction;
- explicit override records under `openspec/.helm/overrides/`;
- machine-readable `scope.json`;
- OpenSpec CLI state parsing;
- stale verify and high-risk sign-off archive policy tests.

Completed in `0.3.0`:

1. Replace warning/fallback gates with strict blocked states for required workflow state.
2. Add requirements foundation spec gate validation for the four project specs.
3. Add prototype stage artifact contracts, branch classification, and prototype verification.
4. Add development stage scope, vertical-slice tasking, review loop, ledger, and drift contracts.
5. Add verification stage plan, traceability matrix, evidence receipt, blocker classification, six-domain evidence contracts, behavior eval transcript gates, failure routing, stale rerun, and aggregate report gates.
6. Add operations stage readiness, release target, install verification, update policy, branch finish, deploy/rollback/monitor, postmortem, update-spec, and archive contracts.
7. Add `/helm-doctor`, OpenSpec CLI health checks, project runtime checks, and `doctor-report.json`-compatible JSON output.
8. Add lifecycle `workflow-state.json` and artifact contract validation.
9. Add `using-helm` SessionStart bootstrap and state injection.
10. Add project journal and context manifest contracts.
11. Split verification into the six dedicated skills and aggregate report.
12. Add debug/break-loop workflows.
13. Add bilingual README files, release checklist, compatibility matrix, and behavior eval transcript resources.

Next:

1. Automate transcript capture for behavior evals instead of requiring file-backed transcript evidence.
2. Add host-specific smoke runs for every supported Claude Code release channel before claiming fresh host support.
3. Add first SAST adapter once the target security tool is selected.

## 18. Pilot Acceptance

The plugin is pilot-ready when:

- `claude plugin validate` passes;
- `bash tests/run-smoke.sh` passes;
- `/helm-doctor` reports plugin, hooks, OpenSpec, skills, commands, agents, and state as healthy;
- `/helm-status` works in a fresh Claude Code session through session-start bootstrap;
- missing `openspec/` blocks production writes and allows init/repair only;
- missing or invalid foundation specs block requirements grilling and route to spec creation/repair;
- missing, invalid, or unrunnable prototype code blocks development transition;
- approved prototype code can only be promoted through development gates;
- production development blocks without valid `scope.json`, task brief, and approved prototype decision;
- prototype code promotion blocks without `prototype-promotion-map.json`;
- task completion blocks without approved spec review and quality review;
- development handoff blocks when `drift-check.jsonl` contains blocking drift;
- production edit without tasks is blocked;
- outside-scope edit is blocked;
- `/helm-verify` blocks without `development/handoff-to-verify.md`;
- each verification domain writes its own evidence and report;
- blocked verification domain makes aggregate report red;
- aggregate report green requires all six domains green and evidence-index coverage;
- aggregate report green requires `traceability-matrix.json` with no unmapped changes;
- aggregate report green requires `receipt.json` with covered scope, uncovered scope, residual risk, and confidence;
- blocked verification domains must use an explicit blocker class;
- behavior evals must pass required clean-session scenarios before operations handoff;
- `verify-unit` must reject implementation-coupled tests through `test-quality-rubric.json`;
- `verify-sensory` must preserve reviewer independence and report unverifiable claims;
- all required six verification domains are green for the active change;
- verify report staleness blocks archive;
- operations handoff blocks unless `operations/readiness.json.ready` is true;
- plugin release blocks without install verification, update policy, compatibility matrix, changelog, and release notes when those surfaces changed;
- deploy blocks without rollback and monitor plans;
- all-host update blocks unless the user explicitly requested all hosts;
- branch cleanup only touches Helm-owned worktrees with recorded provenance;
- archive blocks when required postmortem or update-spec writeback is missing;
- archive gate passes after green verify, operations completion, and required sign-off.

## 19. Open Questions

- Should `/helm` create OpenSpec changes directly or call OpenSpec commands only?
- Should high-risk tier escalation happen during `PreToolUse` or only at archive?
- Should sign-off default to local `signoff.yaml` or PR review metadata?
- Which SAST adapter should be first?
- Should context manifests be generated by OpenSpec state, Helm scripts, or a combined schema?
- Should behavior eval transcripts stay file-backed, or should Helm add an automated clean-session transcript capture harness?
- Which release target should be implemented first: plugin marketplace, local package, or host compatibility smoke?
