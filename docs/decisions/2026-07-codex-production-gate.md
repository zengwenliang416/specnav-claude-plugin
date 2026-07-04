# Decision Gate: Codex Sibling Production Commitment (P4.0)

- Status: **CLOSED — decided 2026-07-03**
- Owner: repository owner (Zengwenliang0416)
- Blocks: P4.1 kernel extraction (C10) scope
- Raised: 2026-07-03, from the July 2026 optimization plan
  (`docs/optimization-plan-2026-07.md`)

## The question

Will `specnav-codex-plugin` go to production within the next three months?

## Why this must be answered before C10

The two repositories currently keep 44 files byte-identical, enforced by
`tests/run-core-drift-check.sh`. Every shared-core change costs a manual sync
plus a drift-check pass. The kernel extraction (C10) is the structural fix,
but its scope doubles or halves depending on this answer:

- **YES (Codex ships):** C10 must extract a host-neutral kernel FIRST, before
  any further Codex feature work. No new files may be added to the
  `identical` set in `tests/shared-core-manifest.json` until then (the
  optimization plan's anti-list item 5).
- **NO (Codex deferred):** freeze the codex repository (archive the repo,
  keep `docs/codex-plugin-system-design.md` as the design record), retire
  `run-core-drift-check.sh` and `shared-core-manifest.json`, and scope C10 to
  a single-host kernel cleanup (TypeScript + unit tests only). This halves
  the C10 cost and removes the per-change sync tax immediately.

## Evidence gathered during the P0–P3 execution (2026-07-03)

- Every one of the 11 optimization tasks that touched shared core required a
  sibling sync step (`cp` + drift check). The tax is real and per-change.
- Codex side remains Phase 0–1 (manifests + resolver scaffolded, runtime
  untested end-to-end) per `docs/codex-plugin-system-design.md` §14.
- The `identical` set did not grow during this work (new scripts were synced
  but the manifest was not extended), honoring the freeze.

## Decision record

| Field | Value |
| --- | --- |
| Decision | **NO — Codex deferred; optimize the Claude plugin suite first** |
| Decided by | repository owner |
| Date | 2026-07-03 |
| Rationale | Codex side is Phase 0-1 with no production timeline; the per-change sync tax (measured ~15 sync steps during the P0-P3 execution) outweighs keeping the mirror warm. |

## Executed consequences (NO branch)

- `tests/run-core-drift-check.sh` and `tests/shared-core-manifest.json`
  retired; the CI `core-drift` job removed.
- `docs/codex-plugin-system-design.md` retained as the design record for a
  future revival; the sibling repo is no longer synced from this one.
- C10 rescoped from cross-host kernel extraction to single-host kernel
  hardening (unit tests for core contract scripts now; TypeScript migration
  as a future change).
- The freeze on growing the shared surface is moot; new core scripts no
  longer need sibling copies.
