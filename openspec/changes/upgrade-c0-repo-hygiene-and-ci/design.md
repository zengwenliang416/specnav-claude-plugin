# Design: upgrade-c0-repo-hygiene-and-ci

## Context

First change of the SpecNav upgrade program. Infrastructure only: no plugin
runtime behavior changes. The working tree carries an 804MB untracked
`reference-repos/` directory, stray copy/AppleDouble files, 131MB of README
assets, no CI on either repo, no drift guard for the shared core against
`specnav-codex-plugin`, and no unit tests for `specnav-lib.js` helpers.

## Goals / Non-Goals

- Goals: clean working tree, CI on both repos, frozen shared-core drift
  surface, first unit tests for core pure helpers.
- Non-Goals: any change under `plugins/**` (denied by scope), evidence-ledger
  work (C3), archetype profiles (C1), README content rewrites.

## Decisions

- D1 `reference-repos/` moves to a sibling archive directory outside the
  working tree (`../specnav-reference-repos-archive/`) instead of deletion;
  it is untracked so git history is unaffected; `.gitignore` gains an entry
  so a future re-clone stays out of status.
- D2 Stray files: untracked `*_副本.md` and `._*` are deleted (AppleDouble
  files are metadata noise; the 副本 file is a duplicate of a tracked doc).
  Tracked `logs/stop-failures.log` is removed via git (history preserves it).
  Codex `canvas/` is untracked design exploration; moved into the same
  sibling archive.
- D3 README assets: only currently-referenced images stay tracked
  (`docs/assets/readme/en/**`, `docs/assets/readme/zh-CN/**`, logo). The
  root-level `docs/assets/readme/*.png` duplicates (superseded by the
  localized sets) are removed from git; recompression is attempted only with
  lossless tooling available locally, otherwise deferred.
- D4 CI: one workflow per repo running fixture suites and syntax checks.
  `claude plugin validate` runs only if available on the runner; the step is
  conditional so CI does not hard-depend on a host CLI we cannot pin.
  Fixture suites that require the `openspec` CLI get it from npm
  (`@fission-ai/openspec`) pinned to the version verified locally.
- D5 Core drift: a JSON manifest in each repo lists the byte-identical shared
  files; the workflow checks out the sibling repo and fails on divergence not
  whitelisted in the manifest. Known divergent files are whitelisted with a
  reason field, so today's drift is frozen, not hidden.
- D6 Unit tests use `node:test` (zero dependencies, matching repo policy)
  under `tests/unit/`, executed by a new `tests/run-unit-tests.sh` runner so
  CI treats it like every other fixture suite. Tests import the source
  checkout's `plugins/specnav-core/scripts/specnav-lib.js` directly.

## Risks / Trade-offs

- CI cannot execute `claude plugin validate` without the Claude CLI on
  runners; mitigated by conditional step plus local pre-release validation
  per existing release checklist.
- Removing root-level README pngs breaks any external deep links to those
  exact paths; accepted, localized sets are the documented surface.
- Drift whitelist can rot; each entry carries a reason and the C10 monorepo
  change retires the whole mechanism.

## Migration Plan

Single change, no data migration. Rollback = git revert of the commit(s);
archived directories can be moved back manually if ever needed.

## Open Questions

None blocking; recompression tooling availability is probed during T3 and
deferred without blocking if absent.
