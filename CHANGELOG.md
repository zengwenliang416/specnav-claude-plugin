# Changelog

## 0.7.0

Graduated enforcement: soft gates now escalate instead of being purely
advisory. Field data showed both extremes fail — pure-hard misfired on ~50%
of denies (pre-0.6), pure-soft was ignored 154 times in one session (0.6.0).

- Escalating soft gates: the same (reason, change) gate warns on the 1st hit
  (announcing the escalation rule), stays silent on the 2nd, and DENIES from
  the 3rd hit in the same session — sustained drift becomes a decision, not
  an accident. Repairing the gate or creating an override stops the count.
  Threshold configurable via SPECNAV_GATE_ESCALATION (default 3).
  SPECNAV_STRICT=1 still denies from hit 1; new SPECNAV_SOFT=1 keeps gates
  purely advisory (never denies).
- Repo suitability gate: specnav-bootstrap now detects tool/library/plugin
  repositories (plugin-marketplace layout, skills layout, published-library
  shape, no UI/server/page signals) and refuses with repo-profile:tooling
  instead of scaffolding empty-shell foundation specs. --force overrides.
  Application repos (UI/server frameworks, page/route directories) proceed
  as before.

## 0.6.1

Field fix from the first day of 0.6.0 usage: one missing-tasks warning
repeated 154 times in a single session (~93KB of context) and was tuned out.

- Warning dedup: the same (reason, change) soft-gate warning now reaches the
  model/user ONCE per session (tracked in openspec/.specnav/warned.json,
  keyed by hook session_id). Every occurrence still lands in events.jsonl
  for accounting; SPECNAV_STRICT=1 blocking is unaffected.
- Requirements-stage awareness: while a change has requirements.md but no
  tasks.md / light-change.json yet, edits to docs/, README, and *.md files
  are the legal work of that stage and no longer trigger missing-tasks.
  Production-source edits still warn.
- warned.json added to the runtime .gitignore.

## 0.6.0

Accounting-first guard, cross-repo support, and a large token/artifact diet —
driven by field data from real projects (6.4k allow / 55 deny events, ~50%
of denies were misfires on harness paths and routine cleanup commands).

Guard policy (breaking behavior change, opt-out via `SPECNAV_STRICT=1`):

- Soft gates by default: scope drift, missing tasks/scope/gate artifacts,
  legacy-OpenSpec entrypoints, and missing-openspec now warn (exit 0 +
  systemMessage + `hook.scope-drift`/`hook.warn` events) instead of blocking.
  Hard gates remain hard in both modes: frozen acceptance contracts, frozen
  task tests, admitted promoted checks, and dangerous commands.
- `SPECNAV_STRICT=1` restores full blocking for every soft gate.
- Dangerous-command matching narrowed to genuinely destructive shapes
  (`rm -rf /`, `sudo rm`, `dd of=/dev/`, `curl|sh`); `rm -rf .next` and
  `/tmp` cleanup no longer trip it. Legacy-OpenSpec matching now requires
  command position — commit messages mentioning "OpenSpec propose" pass.
- Harness-owned paths (`~/.claude`, `~/.codex`, `~/.config`, tmp dirs) are
  never governed: Claude Code plans/memory writes no longer hit scope denies.

Cross-repo (new):

- `scope.json` gains optional `external_repos[]` (`root`, `include`,
  `exclude`, `reason` — reason required). Declared sibling-repo edits are
  allowed, audited via `hook.external-edit`, and best-effort mark the
  sibling's own verify report stale. Undeclared external paths soft-gate
  with a copyable repair template (`external-scope`).
- specnav-codegraph ships hooks now: a SessionStart announce that lists
  sibling repositories carrying a `.codegraph/` index (one compact line,
  silent when none), and a PreToolUse redirect that turns Grep/Bash searches
  into an equivalent `codegraph explore -p <repo>` command when the target
  repo is indexed. Reads of specific files are never intercepted; kill
  switch `SPECNAV_CROSS_REPO_REDIRECT=0`; fail-open on any internal error.
  Non-sibling repos can be declared in `openspec/.specnav/cross-repo.json`.

Light lane v2 (single-file):

- `create-light-change.js` now writes ONE `light-change.json` (lane, editable
  paths, acceptance assertions, tasks, pending user test, optional
  external_repos) instead of the 14-artifact packet. All five stage contracts
  (requirements, prototype, development, verification, operations/archive)
  short-circuit on a valid v2 file; `--format packet` keeps the v1 behavior
  and in-flight v1 changes continue to validate.
- Cross-repo paths (`../repo/...`) in `--paths` become `external_repos`
  declarations instead of validation failures.

Token/artifact diet:

- Contract scripts print a compact one-line decision by default
  (`ok/lane/blockers`); the full artifact table moved behind `--verbose`
  (~2KB → ~200B per call, 612 calls observed per project month).
- `verify-domains aggregate` writes JSON only; md/html renders moved behind
  `--render` and no longer gate operations.
- development/manifest.json can replace the six one-shot entry planning JSONs
  (before-dev-check, promotion-map, complexity-budget, task-graph,
  code-owner-map, extraction-map) with sections in one file; per-file set
  still accepted.
- Event log noise: `hook.allow` recording is now opt-in
  (`SPECNAV_EVENT_VERBOSE=1`); post-tool stale marking is idempotent (one
  `verify.stale` per implementation burst instead of per edit).
- Per-stage context manifests (5 append-only jsonl, unbounded) replaced by
  one overwrite-in-place `context/current.json`; journal keeps the latest 10
  sessions; `openspec/.specnav/.gitignore` is written on bootstrap so
  session-local runtime state (events, journal, workflow-state, session-lock)
  stays out of version control.
- Slash-command files replace the 40-line inline plugin-root resolver with a
  compact `specnav_env` bootstrap delegating to `resolve-runtime.js`;
  `/specnav-implement` inlines the light-lane fast path (create + entry gate
  in one step).

## 0.5.2

Two opt-in capabilities borrowed from PDCA "AI harness" practice, both
advisory-by-default so they never expand mandatory gates (per the repo's
anti-list):

- L3 AI-facing annotation layer. New optional `ai-annotation-policy` foundation
  spec (absent by default), `anchor-scan.js` coverage scan over touched code
  (advisory report + `anchor.coverage` event; blocks with `anchor-uncovered:<file>`
  only under `enforcement: gate`), an opt-in verify-gate fold, and an optional
  `anchor_refs` traceability column. Requirements/verification behavior is
  unchanged when no policy is present.
- Act -> capability promotion loop. `update-spec.json` gains an optional
  `promoted_checks[]` (candidate never blocks archive; admitted requires a passed
  dry-run + generalized statement + signoff). New `promotion-dry-run.js` runs a
  candidate read-only and lints one-off tokens (UID -> business variable), the
  `specnav-promote-check` skill orchestrates distillation, and the guard enforces
  admitted `promoted-check` rules only when a rule declares `enforcement: gate`
  (overridable, mirrors `frozen-tests`). `gate-effectiveness.js` now consumes
  `promotion.*` and `anchor.coverage` events for the retirement loop.

## 0.5.1

- Fix: guard warnings (`requires_review_on` escalation, missing target path)
  no longer exit with code 1, which Claude Code renders as a hook ERROR banner
  ("PreToolUse hook error … Failed with non-blocking status code") even though
  nothing is blocked. Warnings now follow the non-blocking contract: exit 0
  with structured JSON (`systemMessage` + `permissionDecision: allow`), so the
  advisory reaches the model and the user without looking like breakage. The
  `hook.warn` event is still recorded for gate-effectiveness analysis.
- Test: hook fixtures updated — warn cases assert exit 0 plus a
  "SpecNav gate warning" stdout payload, and the review-override case asserts
  the warning disappears after the override.

## 0.5.0

Guard & runtime hardening (P0):

- Guard consumes documented-stable hook payload fields first; fallback field
  hits are audited as `guard.unknown-payload-shape` events instead of failing
  silently. Denials emit structured `PreToolUse` `permissionDecision` JSON
  with blocker ids and fix guidance.
- SessionStart runs a guard self-check with synthetic payloads; failures
  surface as a `guard-selfcheck-failed` blocker, a doctor check, and a loud
  systemMessage.
- `verify-report.stale` write failures no longer hard-block edits: the hook
  warns, records `verify.stale-marker-failed`, and doctor gains a
  `stale-marker-writable` repair check.
- Fix C4: `globLikeMatch` literal patterns no longer prefix-match unrelated
  longer paths (scope.json enforcement is segment-boundary exact).
- Single-writer session lock: `openspec/.specnav/session-lock` lease at
  SessionStart; a foreign active lease blocks with
  `session-lock:held-by-other`, expired leases are taken over with an audit
  event.
- CI runs `claude plugin validate` (release checklist gate locally).

Executed evidence (P1):

- New `specnav-verification/scripts/evidence-runner.js` replays
  validation-log commands and appends system-executed receipts
  (`specnav.validationLog.v2`, `attestation: system-executed`); replayed
  output is stored under `development/evidence/`.
- Development handoff requires at least one system-executed pass when
  replayable entries exist (`validation-log:no-executed-evidence`); executed
  failures overturn self-reported passes; non-replayable entries need a
  caveat.
- Verify receipts with confidence A/B require executed evidence
  (`receipt-confidence-unexecuted-evidence`); zero executable tests now
  yields a `blocked` verify report, never green.
- TDD tamper guard: task `context.json` `test_paths` freeze committed test
  files during implementation (`frozen-tests` gate with override + audit).

Loop convergence (P2):

- `acceptance.json` machine-checkable assertion list: assertions freeze at
  development entry (digest pinned in `development/acceptance-freeze.json`,
  `acceptance:assertions-mutated` on tampering); passing requires
  `evidence_ref`; verification blocks on failing assertions.
- Generation/evaluation separation: new `specnav-task-review` skill runs
  spec/quality reviews in a forked `verifier` agent context; approved spec
  reviews must cite verified acceptance assertion ids
  (`review:unsupported-verdict`, `review:invalid-reference:<id>`).
- Deterministic circuit breaker: three consecutive same-cause task failures
  in `task-ledger.jsonl` raise `loop-detected:<task>`; a recorded escalation
  clears it (break-loop skill owns classification, not detection).
- `rerun-scope.js` computes the minimal verification rerun set from the git
  diff and traceability matrix; unmapped changes fail conservatively to a
  full rerun.
- SessionStart emits a bounded startup ritual (active change, ready actions,
  failing assertion count, stale flag, journal tail); PreCompact injects a
  compact workflow-state summary.

Lane routing & scaffold accounting (P3):

- `risk-tier.js` emits a lane (`light`/`standard`/`full`): light lane may
  record the prototype as `not_required` (reason mandatory), folds quality
  review into spec review, and verifies static + unit only; cumulative diffs
  past the escalation threshold raise `lane-escalation-required`.
- New `gate-effectiveness.js` aggregates events.jsonl into per-gate deny/
  override/red-after-allow rates with retirement signals; release checklist
  gains a post-model-upgrade scaffold audit step.
- Adopted `Stop` (unaccounted-edit ledger check, loop-safe) and
  `PostToolUseFailure` (blocker classification) hooks; agent-type hooks and
  UserPromptSubmit injection deliberately not adopted (see compatibility.md).
- Skill audit: 45 skills pass the strict checklist; `specnav-deploy` and
  `specnav-rollback` are user-invocable only (`disable-model-invocation`).
- Plugin manifests: `defaultEnabled: true` everywhere, `strict: true` on
  marketplace entries; `dependencies` field deliberately deferred.

Codex deferral & kernel hardening (P4):

- Decision recorded (docs/decisions/2026-07-codex-production-gate.md): the
  Codex sibling is deferred; this repository optimizes standalone.
- Retired the cross-repo shared-core drift guard
  (`tests/run-core-drift-check.sh`, `tests/shared-core-manifest.json`, and
  the CI `core-drift` job); `docs/codex-plugin-system-design.md` remains as
  the design record.
- Kernel hardening in place of cross-host extraction: unit tests now cover
  guard payload normalization and self-check, scope matching, risk-tier lane
  classification, gate-effectiveness analytics, acceptance assertion
  parsing/digest freezing, and the session-lock lease (57 tests total); CI
  gains a dedicated unit-test job. TypeScript migration deferred to a future
  change.

## 0.4.9

- Backfill `CHANGELOG.md` and `docs/design.md` release notes for 0.4.7 and
  0.4.8 so public hygiene checks pass against the released version.
- Reference every shipped skill asset explicitly from its SKILL.md
  (vertical-slices migration shells, prototype `assets/visual-inventory.json`).
- Reword the verify-plan runtime-evidence Stop Condition to name the artifact
  and required surfaces directly, aligning with the Codex edition wording.

## 0.4.8

- Require executable evidence gates before development handoff and release:
  SQL/DDL/DML, seed-data, menu, or permission work must ship executable
  migrations under `development/migrations/` with `manifest.json` and
  execution/rollback/validation notes in `README.md`.
- Add `migration-deployment.json` and deploy-plan migration gates to the
  operations stage; readiness records migration deployment state.
- Add `runtime-evidence.json` to the verification plan: runtime and browser
  surfaces are always required, database evidence is required when a change
  declares migrations; unverified stand-in evidence blocks the aggregate.
- Extend development, operations, and verification fixture suites to cover
  the new executable-evidence blockers.

## 0.4.7

- Add the user-aligned test case gate to verification: `user-test-cases.md`
  and `user-test-cases.json` capture user-goal test cases, and
  `user-test-case-signoff.json` must reach `approved` before the six domains
  may run.
- Require `domain-case-matrix.json` to map every approved test case across
  all six verification domains.
- Extend `verify-domains.js` validation and the verify-plan, e2e, and
  facticity skills to consume the approved user test cases.

## 0.4.6

- Require the UI design foundation spec to state theme capability, theme toggle
  policy, i18n capability, supported locales, and default locale.
- Require change-level `spec-map.json` to record non-empty `theme_modes` and
  `locale_policy` entries.
- Require prototype manifests, screen maps, and handoffs to bind prototypes to
  the approved theme and locale policy, including explicit omission of theme or
  locale switchers when unsupported.
- Extend repository discovery to detect common i18n and theme evidence such as
  dictionaries, locale folders, theme folders, i18n configs, Tailwind configs,
  and i18n/theme dependencies.

## 0.4.5

- Add SpecNav change registry support so multiple active OpenSpec changes can
  coexist without falling back to stale `workflow-state.json` active-change
  values.
- Rename the public lifecycle action from `propose` to `requirements` while
  still routing user proposal intent to `/specnav-requirements`.
- Detect native OpenSpec/OPSX workflow entrypoints as legacy conflicts while
  still allowing SpecNav scripts to use the `openspec` CLI as the artifact
  engine.
- Report `ambiguous-change` when multiple changes exist and no explicit
  `SPECNAV_CHANGE`, registry focus, or active-change file selects one.
- Add `specnav-operations/scripts/archive-change.js` so `/specnav-archive`
  performs the full archive sequence: tasks checkbox normalization, operations
  archive gate, `openspec validate`, `openspec archive`, registry/focus update,
  evidence-index path rewrite, and archived receipt generation.

## 0.4.4

- Add `specnav-core/scripts/tasks-md.js` to normalize existing OpenSpec
  `tasks.md` files into standard checkbox task syntax.
- Run task normalization before archive so plain bullets become `- [ ]` tasks
  instead of staying as non-standard artifacts.

## 0.4.3

- Tighten archive and operations readiness instructions so plain `tasks.md`
  bullets are reported as `tasks-md:no-checkboxes`, not described as completion
  evidence.

## 0.4.2

- Require `tasks.md` to use checkbox task evidence before development handoff
  and archive readiness.
- Block archive when `tasks.md` has plain bullets, mixed checkbox/plain bullets,
  or unchecked tasks, instead of treating "no incomplete checkbox" as completion
  evidence.

## 0.4.1

- Rebuild the six-plugin cache release after hardening slash commands to avoid
  Claude Code positional placeholder substitution in plugin root resolution.
- Prevent user requirement text from being interpreted as a SpecNav plugin name
  during `/specnav-requirements` suite checks.

## 0.4.0

- Rename the repository, marketplace, plugins, commands, skills, runtime
  variables, schemas, and generated state to the SpecNav product surface.
- Move project-local runtime state from the legacy hidden state directory and
  marker file to `openspec/.specnav/` and `.specnav.json`.
- Rename the public GitHub target to
  `https://github.com/zengwenliang416/specnav-claude-plugin`.
- Update README, review docs, fixtures, and public hygiene checks for the
  SpecNav product surface.

## 0.3.4

- Resolve installed SpecNav plugin roots inside slash commands instead of relying on hook-only `CLAUDE_PLUGIN_ROOT`.
- Update SpecNav skills to use explicit `SPECNAV_*_ROOT` runtime variables and stop if installed plugin roots cannot be resolved.
- Add a regression fixture that executes `/specnav-bootstrap` with `CLAUDE_PLUGIN_ROOT` unset and verifies OpenSpec initialization succeeds.

## 0.3.3

- Add `/specnav-bootstrap` and `specnav-bootstrap` as the explicit OpenSpec initialization entrypoint when SpecNav reports `missing-openspec`.
- Update SessionStart, router, and workflow guidance to name `/specnav-bootstrap` as the next legal action.
- Allow bootstrap and read-only suite/status commands through the missing-OpenSpec guard while keeping production writes blocked.

## 0.3.2

- Support installed-cache suite discovery through `claude plugin list --json` when Claude has installed the six SpecNav plugins without a marketplace root manifest.
- Update `/specnav-doctor` so installed-cache mode validates the six required plugins by installed/enabled state instead of requiring `.claude-plugin/marketplace.json`.
- Add core runtime fixtures for installed-cache discovery and disabled-plugin blocking.

## 0.3.1

- Enable verification guidance for explicit Claude plugin enablement after install.
- Enforce `scope.json` `allowed_roots` / `denied_roots` in the PreToolUse guard and block production writes when `scope.json` is missing or invalid.
- Extend `/specnav-doctor` to verify installed Claude plugins are present and enabled through `claude plugin list --json`.
- Refresh design and README install/update instructions for the six-plugin marketplace shape.

## 0.3.0

- Convert SpecNav into a six-plugin Claude Code marketplace suite with `specnav-*` scoped public skills.
- Rewrite all skill frontmatter to the strict Agent Skills subset: `name` and `description` only.
- Add `tests/run-skill-contract-fixtures.sh` to enforce skill names, descriptions, stage manifests, and unfinished text checks.
- Add skill-local `references/`, `assets/`, and scaffold scripts across requirements, prototype, development, verification, and operations, plus `tests/run-skill-resource-fixtures.sh`.
- Replace core workflow-state and doctor placeholders with real cross-plugin state and diagnostic output.
- Add cross-plugin state fixtures, real `claude plugin validate` fixtures, and separate English/Chinese README files.
- Require `./plugins/...` marketplace sources so the multi-plugin marketplace validates under Claude Code.
- Replace OpenSpec filesystem fallback with explicit blocked states when required OpenSpec status is unavailable.
- Require clean-session behavior eval transcripts before aggregate verification can pass.

## 0.2.1

- Avoid creating `openspec/.specnav/events.jsonl` in repositories that have not been bootstrapped.
- Clean up guard helper code after hook payload normalization.

## 0.2.0

- Normalize Claude Code hook payloads for `Write`, `Edit`, `MultiEdit`, `NotebookEdit`, and `Bash`.
- Enforce all extracted paths from multi-path payloads.
- Add explicit override records under `openspec/.specnav/overrides/`.
- Add `scope.json` as the machine-readable file-scope contract with Markdown fallback.
- Prefer `openspec status --change <id> --json` for affordance state when available.
- Add fallback mode via `SPECNAV_DISABLE_OPENSPEC=1`.
- Add hook, override, OpenSpec, stale verify, and sign-off fixture tests.

## 0.1.0

- Initial single-plugin MVP with commands, skills, agents, hooks, local scripts, and smoke fixture.
