# Proposal: upgrade-c0-repo-hygiene-and-ci

## Why

The SpecNav upgrade program (13 planned changes, C0-C12) starts with
repository hygiene and CI so every later change lands on a guarded,
continuously tested base. Today the working tree carries an 804MB untracked
reference-repos directory, stray copy files, and 131MB of README assets;
neither repo has CI; the shared core scripts have no drift guard against the
Codex sibling; and specnav-lib.js pure helpers have no unit tests.

## What Changes

- Archive `reference-repos/` out of the working tree and ignore it.
- Remove stray files: `*_副本.md`, `._*` AppleDouble files, `logs/` (claude repo), `canvas/` (codex repo).
- Slim README image weight (Release assets or lossless compression).
- Add GitHub Actions CI on both repos: all `tests/run-*.sh`, `node --check` over plugin JS, `claude plugin validate` where applicable.
- Add a cross-repo core-drift workflow freezing the shared-core file set against `specnav-codex-plugin`, with an explicit whitelist for known divergence.
- Add `node:test` unit tests for `specnav-lib.js` pure helpers (`globLikeMatch`, `parseScope`, `readFileScope`, `activeChangeState`).

## Impact

- No runtime behavior change to any plugin script.
- Affected surfaces: repository layout, `.gitignore`, `.github/workflows/`, `tests/unit/`.
- Risk tier: lite (infrastructure only, reversible).
- Downstream: unblocks C1 (archetype profiles) and every later upgrade change.
