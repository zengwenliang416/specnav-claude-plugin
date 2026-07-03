# Tasks: upgrade-c0-repo-hygiene-and-ci

- [x] T1 Archive `reference-repos/` out of the working tree and add `.gitignore` entry
- [x] T2 Remove `*_副本.md`, `._*` AppleDouble files, `logs/` (claude repo), `canvas/` (codex repo)
- [x] T3 Slim README image assets (removed 8 unreferenced root-level duplicates in claude repo, 11 unreferenced assets in codex repo; lossless recompression deferred: no tooling locally, per design.md D3)
- [x] T4 Add claude-repo CI workflow: all `tests/run-*.sh` + `node --check` all plugin JS + `claude plugin validate` (validate stays a local release gate; documented in ci.yml)
- [x] T5 Add codex-repo CI workflow: same shape with codex fixture runners
- [x] T6 Add core-drift workflow: diff shared-core file list across repos, fail on non-whitelisted divergence
- [x] T7 Add `node:test` unit tests for `specnav-lib.js` pure helpers (`globLikeMatch`, `parseScope`, `readFileScope`, `activeChangeState`)
