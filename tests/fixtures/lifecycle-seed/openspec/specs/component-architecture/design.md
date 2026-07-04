# Component Architecture & Reuse Spec

## Overview

Components in this repository are the reusable units of the plugin suite:
core library modules, contract scripts, scaffold assets, skills, commands,
hooks, and fixture harnesses. This spec records the taxonomy, cohesion and
coupling rules, extraction rules, public API rules, state ownership,
composition patterns, naming conventions, testing expectations, and refactor
triggers that govern them. It is the reuse contract that development-stage
reviews and verification check against.

## Component Taxonomy

| Kind | Location | Examples | Reuse scope |
| --- | --- | --- | --- |
| Core library module | `plugins/specnav-core/scripts/` | `specnav-lib.js`, `affordances.js`, `scaffold-lib.js` | all plugins via runtime resolution |
| Contract script | `plugins/<plugin>/scripts/` | `development-contract.js`, `verify-domains.js` | owning plugin's public API |
| Runtime resolver | `plugins/<plugin>/scripts/plugin-runtime.js` | intentional per-plugin copy | one per plugin, byte-identical |
| Hook script | `plugins/specnav-core/scripts/` | `specnav-guard.js`, `specnav-post-tool.js` | host-invoked only |
| Skill | `plugins/<plugin>/skills/<name>/` | `specnav-vertical-slices` | conversation surface |
| Command | `plugins/<plugin>/commands/` | `specnav-verify.md` | conversation entrypoint |
| Scaffold asset | `plugins/<plugin>/skills/<name>/assets/` | change templates, report shells | copied into governed projects |
| Agent definition | `plugins/specnav-core/agents/` | `explorer.md`, `verifier.md` | subagent dispatch |
| Test harness | `tests/run-*.sh` + `tests/fixtures/` | hook fixtures, contract fixtures | repository CI |

## Cohesion Rules

- One script owns one contract; a script that both validates and mutates
  unrelated state must be split.
- A skill owns one workflow; skills that grow beyond ~60 lines of workflow
  steps are split (the debug/fix/break-loop trio is the pattern).
- Stage plugins contain only their stage's artifacts and validation; shared
  behavior moves to specnav-core.
- Assets live beside the skill that scaffolds them, never shared across
  plugins by relative path.

## Coupling Rules

- Cross-plugin code access goes through `plugin-runtime.js`
  `requirePluginScript` with a `missing-plugin:<name>` blocker on absence;
  no relative `require` across plugin boundaries.
- Scripts communicate through documented JSON shapes and blocker strings, not
  shared mutable module state.
- Hooks read stdin and files only; they never call other plugins.
- Skills invoke scripts via documented CLI flags; they never import JS.
- The Codex sibling repo couples only through byte-identical shared files;
  any intentional divergence is recorded as drift.

## Shared Component Extraction Rules

- Extract to `specnav-core/scripts/` when a second plugin needs the same
  logic; copy-paste between stage plugins is a review finding.
- Exception (recorded): `plugin-runtime.js` is deliberately duplicated per
  plugin so each plugin is installable alone; the copies must stay
  byte-identical and are checked by suite layout fixtures.
- Scaffold templating logic lives only in `scaffold-lib.js`; skills define
  data (`items`), not copy loops.
- A helper used three or more times inside one script moves to a named
  function; used by two or more scripts, it moves to `specnav-lib.js`.

## Component Public API Rules

- Contract scripts expose: CLI (`--json`, documented flags) plus module
  exports for sibling scripts in the same plugin; both surfaces return the
  same shapes.
- Blocker identifiers, JSON field names, and exit codes are the public API;
  renaming any of them is a breaking change requiring fixture updates and a
  version bump.
- Every script supports `--help` or self-documenting usage errors on bad
  arguments (`unknown-argument:<arg>` pattern).
- Skills declare their trigger conditions in frontmatter `description` and
  their required outputs in a `Required Outputs` section; those are their API.

## State Ownership Rules

- Generated state (`openspec/.specnav/**`, `verify/**` reports, ledgers) is
  written only by scripts; skills and humans author decision artifacts
  (specs, requirements, briefs, reviews).
- Each file has exactly one owning module (see system architecture database
  model); two writers to one file is an architecture violation.
- Snapshots (`workflow-state.json`, `affordances.json`) are derived and
  disposable; source-of-truth files (`change-registry.json`, change artifacts)
  are never regenerated destructively.

## Composition Patterns

- Gate chain: command → suite check → entry contract → skill workflow → exit
  contract; every stage repeats this shape.
- Validator composition: `verify-domains.js` composes development contract,
  codegraph guard, and per-artifact validators into one aggregate; new
  validators return `{ok, blockers[]}` and are appended to the artifact list.
- Scaffold composition: skills pass `items()` descriptors to
  `scaffold-lib.runScaffold` with `requiresChange` and template values.
- Hook composition: guard composes payload normalization → global denials →
  project gates → per-path scope checks; new checks slot into that order.

## File & Naming Conventions

- Plugins: `specnav-<stage>`; skills: `specnav-<verb-or-domain>`; commands
  mirror skill names.
- Scripts: kebab-case `.js` with a `main()` guarded by
  `require.main === module` and named exports for reuse.
- Blockers: `kebab-or-colon` identifiers, namespaced by domain
  (`invalid-verify-plan:risk_tier`, `codegraph:stale-index`).
- Artifacts: fixed names defined by contracts (`tasks.md`, `scope.json`,
  `report.json`); no synonyms.
- Tests: `tests/run-<area>-fixtures.sh`; fixtures under `tests/fixtures/`.

## Testing Expectations

- Every contract script has a fixture runner that executes the real script
  against constructed project trees and asserts exit codes and exact blocker
  strings (the existing 24-runner suite is the reference standard).
- Every new blocker or JSON field lands with at least one positive and one
  negative fixture.
- Hook behavior is tested through payload fixtures piped to the real hook
  script.
- Pure helpers in `specnav-lib.js` gain `node:test` unit tests as they are
  touched (roadmap C0-T7).
- Skills are validated structurally by the skill-contract fixture runner;
  behavior evals cover their runtime effect.

## Refactor Triggers

- A blocker string produced in two scripts → extract shared validator.
- A third copy of any helper → move to `specnav-lib.js`.
- A script exceeding ~600 lines or mixing two contracts → split by contract.
- Divergence detected between per-plugin `plugin-runtime.js` copies or between
  the Claude and Codex shared cores → immediate re-sync commit before feature
  work.
- A skill workflow that needs conditional branches per project archetype →
  promote the branch into contract logic instead of prose.

## Component Do's and Don'ts

- Do keep scripts zero-dependency and host-agnostic where the surface allows.
- Do return `{ok, blockers[]}` from every new validator and mirror it in exit
  codes.
- Do add the fixture before or with the behavior change.
- Don't deep-import another plugin's scripts by relative path.
- Don't fork blocker vocabulary; reuse existing identifiers where semantics
  match.
- Don't let a skill write generated state or a script overwrite authored
  markdown without `--force` semantics.
