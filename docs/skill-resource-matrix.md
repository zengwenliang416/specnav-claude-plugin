# SpecNav Skill Resource Matrix

This document is the Phase 0 resource plan for SpecNav skills.

It decides which skills should stay as `SKILL.md` only, which skills need
progressively loaded `references/`, which skills need reusable output
`assets/`, and which skills justify skill-local `scripts/`.

The goal is not to add empty folders. The goal is to add resources only where
they improve repeatability, reduce drift, or prevent agents from regenerating
fragile artifact structures from memory.

## 1. Current Audit

Current repository state:

- 32 public SpecNav skills exist under `plugins/*/skills/*/SKILL.md`.
- No skill-local `references/`, `assets/`, or `scripts/` directories exist yet.
- Plugin-level deterministic gates already exist under `plugins/<plugin>/scripts/`.
- Existing plugin-level scripts should remain the source of truth for validation
  and blocker detection.

Resource boundary:

- `SKILL.md`: trigger, first source-of-truth step, workflow, stop conditions,
  required outputs, and validation.
- Plugin-level `scripts/`: deterministic gates, state readers, validators, and
  cross-plugin checks.
- Skill-local `references/`: detailed rubrics, schemas, interview philosophy,
  review rules, and long examples loaded only when needed.
- Skill-local `assets/`: templates, starter code, manifests, and report shells
  used to create project artifacts.
- Skill-local `scripts/`: small non-interactive scaffold helpers that copy or
  render skill-owned assets into the active OpenSpec change.

## 2. Resource Rules

1. Do not create empty resource directories.
2. Do not duplicate plugin-level validator logic inside skill-local scripts.
3. Add `references/` when the details are too long or too conditional for
   `SKILL.md`.
4. Add `assets/` when the skill creates repeatable files with a stable shape.
5. Add skill-local `scripts/` only when copying or rendering assets by hand would
   be repetitive, fragile, or path-sensitive.
6. Every resource path must be linked from the owning `SKILL.md` with clear load
   or execution conditions.
7. Every skill-local script must be non-interactive, support `--help`, and have a
   focused fixture test.
8. No fallback is allowed when required OpenSpec, active change, upstream
   artifact, or user decision state is missing.

## 3. Core Skills

Core skills mostly read state, route work, or diagnose blockers. They should stay
lean unless repeated diagnosis examples become necessary.

| Skill | References | Assets | Skill Scripts | Priority | Decision |
| --- | --- | --- | --- | --- | --- |
| `specnav-workflow` | Maybe later | No | No | P3 | Keep as router over `affordances.js` and suite resolver. Add a reference only if route examples grow. |
| `specnav-status` | No | No | No | P3 | `workflow-state.js` and `affordances.js` are enough. |
| `specnav-doctor` | Maybe later | No | No | P3 | Plugin-level `specnav-doctor.js` owns diagnostics. A reference may later document blocker taxonomy. |
| `specnav-debug` | Yes | No | No | P2 | Add `references/debug-taxonomy.md` if failure classes become recurring. No assets. |
| `specnav-recovery` | Yes | No | No | P2 | Add `references/recovery-playbook.md` for loop classes and repair routing. No assets. |
| `specnav-route` | No | No | No | P3 | Pure route helper. Keep minimal. |

## 4. Requirements Skills

Requirements is the first resource-heavy stage. It creates fixed project specs
and change-level requirement artifacts, so it needs both references and assets.

| Skill | References | Assets | Skill Scripts | Priority | Decision |
| --- | --- | --- | --- | --- | --- |
| `specnav-foundation-specs` | Yes | Yes | Yes | P0 | Must provide the four required foundation spec templates and a scaffold script that materializes missing specs without guessing decisions. |
| `specnav-requirements` | Yes | Yes | Yes | P0 | Must provide interview philosophy, artifact schemas, and change-level templates for requirements, acceptance, spec map, and component impact map. |

Required `specnav-foundation-specs` resources:

- `references/foundation-spec-contract.md`
- `assets/ui-design/design.md`
- `assets/system-architecture/design.md`
- `assets/frontend-backend-data-flow/design.md`
- `assets/component-architecture/design.md`
- `scripts/create-foundation-specs.js`

Required `specnav-requirements` resources:

- `references/interview-philosophy.md`
- `references/requirements-artifacts.md`
- `assets/change/requirements.md`
- `assets/change/acceptance.md`
- `assets/change/spec-map.json`
- `assets/change/component-impact-map.json`
- `scripts/create-requirements-artifacts.js`

The component architecture spec must explicitly encode high cohesion, low
coupling, extraction rules, shared component boundaries, and review criteria for
when reusable UI or domain components must be split out.

## 5. Prototype Skills

Prototype skills need runnable starter artifacts because a visual or behavioral
prototype cannot be reviewed from prose alone.

| Skill | References | Assets | Skill Scripts | Priority | Decision |
| --- | --- | --- | --- | --- | --- |
| `specnav-prototype` | Yes | Yes | Yes | P1 | Must provide branch taxonomy, artifact schemas, and runnable starters for UI HTML and non-UI harnesses. |
| `specnav-prototype-verify` | Yes | Yes | No | P1 | Needs verification checklist and report template. Runtime execution stays agent-driven and contract-checked. |
| `specnav-prototype-handoff` | Yes | Yes | No | P1 | Needs approval decision and handoff templates. No separate script until handoff generation becomes repetitive. |

Required `specnav-prototype` resources:

- `references/prototype-branches.md`
- `references/prototype-artifacts.md`
- `assets/ui-html/index.html`
- `assets/ui-html/styles.css`
- `assets/ui-html/app.js`
- `assets/logic-state/harness.js`
- `assets/api-contract/examples.json`
- `assets/data-flow/data-flow-map.md`
- `assets/data-flow/data-flow/flow-harness.js`
- `assets/component-seam/component-tree.md`
- `assets/component-seam/component/component-map.md`
- `assets/screen-map.json`
- `assets/prototype-manifest.json`
- `assets/question.md`
- `scripts/create-prototype.js`

Required review and handoff resources:

- `specnav-prototype-verify/references/prototype-verification.md`
- `specnav-prototype-verify/assets/verifier-report.json`
- `specnav-prototype-handoff/references/prototype-approval.md`
- `specnav-prototype-handoff/assets/handoff.md`
- `specnav-prototype-handoff/assets/decision.json`

## 6. Development Skills

Development skills should turn approved specs and prototypes into bounded,
reviewable vertical slices. The resources must make scope and task packet shapes
repeatable.

| Skill | References | Assets | Skill Scripts | Priority | Decision |
| --- | --- | --- | --- | --- | --- |
| `specnav-development-entry` | Yes | Yes | Yes | P1 | Needs basis and before-dev templates plus a scaffold script for entry artifacts. |
| `specnav-scope-lock` | Yes | Yes | Yes | P1 | Needs strict scope schema, examples, and a script to create or repair `scope.json`. |
| `specnav-vertical-slices` | Yes | Yes | Yes | P1 | Needs task packet, ledger, validation, review, and handoff templates. |

Required development resources:

- `specnav-development-entry/references/development-entry.md`
- `specnav-development-entry/assets/basis.md`
- `specnav-development-entry/assets/before-dev-check.json`
- `specnav-development-entry/assets/prototype-promotion-map.json`
- `specnav-development-entry/assets/complexity-budget.json`
- `specnav-development-entry/assets/task-graph.json`
- `specnav-development-entry/assets/task-context.jsonl`
- `specnav-development-entry/assets/code-owner-map.json`
- `specnav-development-entry/assets/extraction-map.json`
- `specnav-development-entry/scripts/create-development-entry.js`
- `specnav-scope-lock/references/scope-lock.md`
- `specnav-scope-lock/assets/scope.json`
- `specnav-scope-lock/scripts/create-scope-lock.js`
- `specnav-vertical-slices/references/development-task-packets.md`
- `specnav-vertical-slices/references/development-review.md`
- `specnav-vertical-slices/assets/tasks.md`
- `specnav-vertical-slices/assets/task/brief.md`
- `specnav-vertical-slices/assets/task/context.json`
- `specnav-vertical-slices/assets/task/report.md`
- `specnav-vertical-slices/assets/task/spec-review.md`
- `specnav-vertical-slices/assets/task/quality-review.md`
- `specnav-vertical-slices/assets/development/task-ledger.jsonl`
- `specnav-vertical-slices/assets/development/drift-check.jsonl`
- `specnav-vertical-slices/assets/development/validation-log.jsonl`
- `specnav-vertical-slices/assets/development/handoff-to-verify.md`
- `specnav-vertical-slices/scripts/create-vertical-slice.js`

Development resources must enforce component cohesion and coupling rules from
the component architecture spec. A task that creates duplicated component logic,
crosses denied roots, or hides reusable UI behavior in page-local code should be
blocked or routed to review.

## 7. Verification Skills

The six verification skills are independent because each domain has a different
audit philosophy, evidence type, and failure mode. They should share a common
report schema through `specnav-verify-plan` resources while keeping domain rubrics
separate.

| Skill | References | Assets | Skill Scripts | Priority | Decision |
| --- | --- | --- | --- | --- | --- |
| `specnav-verify-plan` | Yes | Yes | Yes | P1 | Must scaffold plan, traceability, evidence index, blocker classification, root-cause checks, and receipt shell. |
| `specnav-verify-facticity` | Yes | Yes | No | P1 | Needs claim audit rubric and report templates. |
| `specnav-verify-static` | Yes | Yes | No | P1 | Needs static command taxonomy and report templates. |
| `specnav-verify-unit` | Yes | Yes | No | P1 | Needs behavior coverage and test-quality rubric. |
| `specnav-verify-redteam` | Yes | Yes | No | P1 | Needs adversarial probe rubric and threat model template. |
| `specnav-verify-e2e` | Yes | Yes | No | P1 | Needs flow mapping and run log templates. |
| `specnav-verify-sensory` | Yes | Yes | No | P1 | Needs human review, UX, accessibility, cohesion, coupling, and maintainability rubric. |

Required verification resources:

- `specnav-verify-plan/references/verification-model.md`
- `specnav-verify-plan/references/domain-report-schema.md`
- `specnav-verify-plan/assets/plan.md`
- `specnav-verify-plan/assets/plan.json`
- `specnav-verify-plan/assets/evidence-index.jsonl`
- `specnav-verify-plan/assets/traceability-matrix.json`
- `specnav-verify-plan/assets/blocker-classification.jsonl`
- `specnav-verify-plan/assets/root-cause-checks.jsonl`
- `specnav-verify-plan/assets/receipt.md`
- `specnav-verify-plan/assets/receipt.json`
- `specnav-verify-plan/assets/behavior-evals/scenarios.json`
- `specnav-verify-plan/assets/behavior-evals/report.md`
- `specnav-verify-plan/assets/behavior-evals/report.json`
- `specnav-verify-plan/assets/behavior-evals/transcripts/verify-runs-six-domains.md`
- `specnav-verify-plan/scripts/create-verify-plan.js`
- `specnav-verify-facticity/references/facticity-rubric.md`
- `specnav-verify-facticity/assets/report.md`
- `specnav-verify-facticity/assets/report.json`
- `specnav-verify-static/references/static-rubric.md`
- `specnav-verify-static/assets/report.md`
- `specnav-verify-static/assets/report.json`
- `specnav-verify-unit/references/unit-rubric.md`
- `specnav-verify-unit/assets/report.md`
- `specnav-verify-unit/assets/report.json`
- `specnav-verify-redteam/references/redteam-rubric.md`
- `specnav-verify-redteam/assets/report.md`
- `specnav-verify-redteam/assets/report.json`
- `specnav-verify-e2e/references/e2e-rubric.md`
- `specnav-verify-e2e/assets/report.md`
- `specnav-verify-e2e/assets/report.json`
- `specnav-verify-sensory/references/sensory-rubric.md`
- `specnav-verify-sensory/assets/report.md`
- `specnav-verify-sensory/assets/report.json`

## 8. Operations Skills

Operations skills produce many small but structured release and readiness
artifacts. Most need assets; only a few justify scripts.

| Skill | References | Assets | Skill Scripts | Priority | Decision |
| --- | --- | --- | --- | --- | --- |
| `specnav-ops-readiness` | Yes | Yes | Yes | P2 | Aggregate readiness is path-sensitive and should have a scaffold script. |
| `specnav-release-plan` | Yes | Yes | Yes | P2 | Release target selection needs templates and a script for initial artifacts. |
| `specnav-install-verify` | Yes | Yes | No | P2 | Needs host evidence schema and template. Existing gates should validate. |
| `specnav-update-policy` | Yes | Yes | No | P2 | Needs update policy schema and template. |
| `specnav-compatibility-matrix` | Yes | Yes | No | P2 | Needs host support matrix template. |
| `specnav-branch-finish` | Yes | Yes | No | P2 | Needs branch/worktree provenance template. |
| `specnav-deploy` | Yes | Yes | No | P2 | Needs deploy plan template. |
| `specnav-rollback` | Yes | Yes | No | P2 | Needs rollback plan template. |
| `specnav-monitor` | Yes | Yes | No | P2 | Needs monitor plan template. |
| `specnav-postmortem` | Yes | Yes | No | P2 | Needs postmortem template. |
| `specnav-update-spec` | Yes | Yes | No | P2 | Needs writeback decision schema. |

Required operations resources:

- `specnav-ops-readiness/references/operations-readiness.md`
- `specnav-ops-readiness/assets/readiness.md`
- `specnav-ops-readiness/assets/readiness.json`
- `specnav-ops-readiness/scripts/create-readiness.js`
- `specnav-release-plan/references/release-targets.md`
- `specnav-release-plan/assets/release-plan.md`
- `specnav-release-plan/assets/release-checklist.json`
- `specnav-release-plan/assets/changelog.md`
- `specnav-release-plan/assets/release-notes.md`
- `specnav-release-plan/scripts/create-release-plan.js`
- `specnav-install-verify/references/install-verification.md`
- `specnav-install-verify/assets/install-verification.json`
- `specnav-update-policy/references/update-policy.md`
- `specnav-update-policy/assets/update-policy.json`
- `specnav-compatibility-matrix/references/compatibility-matrix.md`
- `specnav-compatibility-matrix/assets/compatibility-matrix.md`
- `specnav-branch-finish/references/branch-finish.md`
- `specnav-branch-finish/assets/branch-finish.md`
- `specnav-deploy/references/deploy-plan.md`
- `specnav-deploy/assets/deploy-plan.md`
- `specnav-rollback/references/rollback-plan.md`
- `specnav-rollback/assets/rollback-plan.md`
- `specnav-monitor/references/monitor-plan.md`
- `specnav-monitor/assets/monitor-plan.md`
- `specnav-postmortem/references/postmortem.md`
- `specnav-postmortem/assets/postmortem.md`
- `specnav-update-spec/references/update-spec.md`
- `specnav-update-spec/assets/update-spec.json`

## 9. Implementation Phases

### Phase 1: Requirements Resources

Implement foundation and requirements resources first.

Acceptance:

- `specnav-foundation-specs` and `specnav-requirements` link every new resource from
  `SKILL.md`.
- Scaffold scripts support `--help` and `--json`.
- Scripts refuse to run without OpenSpec and active-change state when required.
- `foundation-specs.js` and `requirements-contract.js` still own validation.
- Skill contract tests pass.

### Phase 2: Prototype Resources

Implement runnable prototype starters and review/handoff templates.

Acceptance:

- `specnav-prototype` can scaffold a reviewable artifact under
  `openspec/changes/<active-change>/prototype/`.
- UI prototypes have visible, runnable code instead of prose-only mockups.
- The prototype contract remains the final gate.

### Phase 3: Development Resources

Implement entry, scope, and vertical-slice resources.

Acceptance:

- Development artifacts can be scaffolded without production edits.
- Task packets include allowed files, denied roots, expected tests, evidence,
  and review requirements.
- Component cohesion and coupling checks are visible in templates and review
  references.

### Phase 4: Verification Resources

Implement six-domain verification resources.

Acceptance:

- `specnav-verify-plan` scaffolds shared verification artifacts.
- Each domain has a dedicated rubric and report template.
- `verify-domains.js validate --json` remains the required domain contract.

### Phase 5: Operations Resources

Implement release, readiness, installation, compatibility, deployment, rollback,
monitoring, postmortem, and writeback templates.

Acceptance:

- Operations artifacts are generated from templates rather than invented per run.
- `operations-gate.js --json` remains the final readiness contract.

### Phase 6: Resource Contract Tests

Extend tests so resource regressions are caught.

Acceptance:

- `tests/run-skill-contract-fixtures.sh` verifies all referenced resources exist.
- New fixture tests execute skill-local scripts with `--help`.
- Scaffold tests verify output paths and no-fallback behavior.
- Existing stage tests still pass.

## 10. Non-Goals

- Do not migrate plugin-level gates into skill-local scripts.
- Do not add scripts to every skill for symmetry.
- Do not add assets that are never copied or used in generated output.
- Do not add long examples to `SKILL.md` when a reference file is enough.
- Do not create compatibility fallback paths for missing OpenSpec state.
