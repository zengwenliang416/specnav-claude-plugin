# Helm plugin suite implementation - Checkpoint

- Task ID: 2026-06-23-helm-plugin-suite
- Current todo: Prepare checkpoint and dispatch Task 1 implementer.
- Active slice: Task 1: Convert Repository To Multi-Plugin Marketplace
- Blocked on: none
- Next step: Spawn a fresh worker subagent for Task 1.

## Checkpoint Update

- Current todo: Task 1 implementation by fresh subagent.
- Active slice: Task 1: Convert Repository To Multi-Plugin Marketplace
- Completed todos:
- none
- Evidence refs:
- Baseline smoke: bash tests/run-smoke.sh passed before structural move.
- Blocked on: none
- Next step: Spawn Task 1 worker subagent with plan lines 133-655 as authority.

## Checkpoint Update

- Current todo: Patch Task 1 valid spec-review finding: tracked non-core skills/scripts skeleton directories.
- Active slice: Task 1 remediation
- Completed todos:
- Task 1 initial implementation committed as 12e7d37; layout fixture passed; spec review completed with one valid directory-tracking issue and one future-task concern.
- Evidence refs:
- Spec review agent 019ef3cc-cbf2-7982-a7a8-2375290942f5 reported empty non-core skills/scripts directories missing from clean checkout.
- Blocked on: none
- Next step: Wait for fresh patch worker, then rerun spec review or targeted validation before code quality review.

## Checkpoint Update

- Current todo: Patch Task 1 code-quality findings for command and skill surface.
- Active slice: Task 1 quality remediation
- Completed todos:
- Task 1 spec review passed after 298f7b7; code quality review identified duplicate legacy core commands and missing declared skills.
- Evidence refs:
- Code quality agent 019ef3dc-c2aa-7cf3-a028-9d498f0baa71 reported duplicate helm-core commands and missing declared command/skill files.
- Blocked on: none
- Next step: Wait for fresh patch worker, then rerun Task 1 quality review with contract scripts explicitly deferred to later tasks.

## Checkpoint Update

- Current todo: Patch Task 1 core contract surface: workflow-state.js and helm-doctor.js explicit blockers.
- Active slice: Task 1 core placeholder remediation
- Completed todos:
- Task 1 quality surface fix committed as 3c6f61b; spec re-review found missing core state/doctor scripts.
- Evidence refs:
- Spec re-review agent 019ef3ed-1930-7e83-ae74-d850cfd2424a reported missing workflow-state.js and helm-doctor.js.
- Blocked on: none
- Next step: Wait for patch worker, then rerun Task 1 spec and quality reviews.

## Checkpoint Update

- Current todo: Patch Task 1 pending contract exposure: commands must block explicitly and manifests should not publish missing contract files.
- Active slice: Task 1 final quality remediation
- Completed todos:
- Task 1 spec passed after f3b22b2; final quality review found pending plugin-suite and stage contracts were exposed as runnable/current surfaces.
- Evidence refs:
- Code quality agent 019ef415-d25f-7a02-bdca-2b69842588eb reported missing-file command behavior and unresolved contract metadata.
- Blocked on: none
- Next step: Wait for fresh patch worker, rerun spec and quality reviews with planned_contracts boundary.

## Checkpoint Update

- Current todo: Patch Task 1 monolithic core fallback routes and add fixture guards.
- Active slice: Task 1 fallback removal
- Completed todos:
- Task 1 spec passed; quality review found /helm and helm-router still route to legacy core lifecycle skills.
- Evidence refs:
- Code quality agent 019ef420-ed15-74b2-a8bb-e22498cbd2a4 reported core fallback route through implement/verify/archive skills.
- Blocked on: none
- Next step: Wait for patch worker, then rerun final Task 1 spec and quality reviews.

## Checkpoint Update

- Current todo: Patch Task 1 remaining current-state missing-file surfaces in tests and README.
- Active slice: Task 1 fixture and README path remediation
- Completed todos:
- Final Task 1 spec passed; final quality review found root scripts references in legacy tests and README plus weak blocker assertions.
- Evidence refs:
- Code quality agent 019ef431-8b35-77f1-9753-f86b310ffb71 reported run-smoke/run-archive-policy and README root script references.
- Blocked on: none
- Next step: Wait for patch worker, then rerun final Task 1 spec and quality reviews.

## Checkpoint Update

- Current todo: Patch remaining root script references in openspec and override fixtures.
- Active slice: Task 1 remaining script path cleanup
- Completed todos:
- Task 1 fixture/README path patch committed as 41273f8; local scan found run-openspec and run-override still use root scripts.
- Evidence refs:
- Local rg found tests/run-openspec-fixtures.sh and tests/run-override-fixtures.sh using /scripts.
- Blocked on: none
- Next step: Wait for patch worker, run all current fixtures, then rerun final Task 1 reviews.

## Checkpoint Update

- Current todo: Task 2: Suite Resolver In Helm Core.
- Active slice: Task 2: Suite Resolver In Helm Core
- Completed todos:
- Task 1 completed at HEAD 3cb9e7d with final spec and quality reviews passing; current fixtures pass: layout, smoke, hook, archive policy, openspec, override.
- Evidence refs:
- task1-layout-fixture, task1-spec-review, task1-quality-review, task1-current-fixtures
- Blocked on: none
- Next step: Spawn a fresh worker subagent for Task 2 to add plugin-suite.js and resolver fixture.

## DriftCheckDraft

- Scope status: Task 1 stayed inside marketplace layout, README, and current tests needed to remove broken root script paths.
- Compatibility status: Current fixtures pass after scripts moved under plugins/helm-core; plugin-suite remains planned for Task 2.
- Retirement status: Legacy root plugin/commands/skills and core monolithic lifecycle skill fallback retired from exposed surface.
- New risk signals:
- Future Task 3 plan text assumes helm-doctor and workflow-state are full implementations, but Task 1 added explicit blocking placeholders; Task 3 should replace placeholders deliberately.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Task 2 worker implementing plugin-suite resolver and fixture.
- Active slice: Task 2: Suite Resolver In Helm Core
- Completed todos:
- Task 1 complete at 3cb9e7d with final spec pass and quality pass; all current fixtures passed.
- Evidence refs:
- Task 1 final reviews and current fixtures
- Blocked on: none
- Next step: Wait for Task 2 implementation worker, then run spec and quality reviews.

## Checkpoint Update

- Current todo: Patch Task 2 resolver error boundaries and negative fixture coverage.
- Active slice: Task 2 quality remediation
- Completed todos:
- Task 2 initial implementation committed as 2eda9e5; spec review passed; quality review found source escape, unknown command, missing plugin argument, malformed JSON, and duplicate blocker issues.
- Evidence refs:
- Code quality agent 019ef458-8140-7b12-8e1e-24ec71dc8968 reported resolver no-fallback boundary gaps.
- Blocked on: none
- Next step: Wait for patch worker, then rerun Task 2 spec and quality reviews.

## Checkpoint Update

- Current todo: Patch Task 2 resolver input validation and plan file scope note.
- Active slice: Task 2 final quality remediation
- Completed todos:
- Task 2 spec review functionally passed but flagged helm-stage.json plan scope; quality review found flag-value, invalid entry, unreadable file issues.
- Evidence refs:
- Spec reviewer 019ef463-c08e-7221-93db-2da9c93587c4 and quality reviewer 019ef466-71f0-7f72-a2ed-8e15618d4f0c.
- Blocked on: none
- Next step: Wait for patch worker, then rerun Task 2 final spec and quality reviews.

## Checkpoint Update

- Current todo: Task 3: Core Plugin Runtime After Split.
- Active slice: Task 3: Core Plugin Runtime After Split
- Completed todos:
- Task 2 completed at HEAD 4acde26 with final spec and quality reviews passing; resolver now fails explicitly for unknown commands/flags, bad arguments, malformed/unreadable/invalid manifests, source escape, and identity mismatches.
- Evidence refs:
- task2-resolver-fixture, task2-spec-review, task2-quality-review
- Blocked on: none
- Next step: Spawn a fresh worker subagent for Task 3 to update core runtime routing text and fixtures.

## Checkpoint Update

- Current todo: Task 4: Requirements Plugin.
- Active slice: Task 4: Requirements Plugin
- Completed todos:
- Task 3 completed at HEAD a2ee64e with final spec and quality reviews passing; core runtime routing now uses cwd-independent suite checks and validates placeholder blockers in fixtures.
- Evidence refs:
- task3-core-runtime-fixture, task3-spec-review, task3-quality-review
- Blocked on: none
- Next step: Spawn a fresh worker subagent for Task 4 to add requirements plugin scripts, skills, command wiring, and fixture.

## Checkpoint Update

- Current todo: Task 5: Prototype Plugin.
- Active slice: Task 5: Prototype Plugin
- Completed todos:
- Task 4 completed at HEAD 5b29b66 with final spec and quality reviews passing; requirements plugin validates four foundation specs, requirements artifacts, spec/component maps, active-change boundaries, YAML frontmatter edge cases, and unresolved gaps with no fallback behavior.
- Evidence refs:
- task4-requirements-fixture, task4-spec-review, task4-quality-review
- Blocked on: none
- Next step: Spawn a fresh worker subagent for Task 5 to add prototype stage contract, prototype skills, command wiring, stage manifest contract exposure, and fixtures.

## DriftCheckDraft

- Scope status: Task 4 stayed inside helm-requirements, suite layout metadata, and focused fixtures.
- Compatibility status: Current requirements/core/resolver/layout fixtures pass at HEAD 5b29b66.
- Retirement status: Requirements placeholder contracts and skills are now implemented; no fallback path is exposed.
- New risk signals:
- Task 5 plan text still references a non-existent `helm-core/scripts/contracts.js`, while the accepted suite architecture and Task 4 implementation use `helm-lib` plus plugin-local contracts. Task 5 must not import the missing module.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Task 6: Development Plugin.
- Active slice: Task 6: Development Plugin
- Completed todos:
- Task 5 completed at HEAD 77d4400 with final spec and quality reviews passing; prototype plugin validates requirements gate, isolated prototype artifacts, approved-only decisions, verifier entry/check evidence, handoff sections, screen-map mapping, and realpath containment with no fallback behavior.
- Evidence refs:
- task5-prototype-fixture, task5-spec-review, task5-quality-review
- Blocked on: none
- Next step: Read Task 6 development plugin plan/design context and spawn a fresh worker subagent.

## DriftCheckDraft

- Scope status: Task 5 stayed inside helm-prototype and focused prototype fixtures.
- Compatibility status: Current prototype, requirements, core runtime, resolver, and layout fixtures pass at HEAD 77d4400.
- Retirement status: Prototype placeholder contract and skills are now implemented; `helm-stage.json` exposes `contracts.prototype`, not `planned_contracts`.
- New risk signals:
- Task 6 must consume the stricter prototype contract and should not reintroduce a `not_required` bypass unless explicitly scoped by development-stage contract and current design decisions.
- Advisory decision: continue
