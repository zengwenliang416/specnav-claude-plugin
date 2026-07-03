# Proposal: fix-doc-version-and-skill-refs

## Why

Two fixture suites fail at git HEAD (confirmed pre-existing during
upgrade-c0 validation): `run-public-hygiene-fixtures.sh` because the 0.4.7
and 0.4.8 releases bumped versions without updating `CHANGELOG.md` and
`docs/design.md`, and `run-skill-contract-fixtures.sh` because the same
releases added skill assets without referencing every file explicitly from
their SKILL.md, plus one Stop Condition uses the word "placeholder" which the
hygiene regex treats as unfinished text. A green baseline is required before
CI (added in upgrade-c0) can be trusted as a merge gate.

## What Changes

- Add `## 0.4.7` and `## 0.4.8` entries to `CHANGELOG.md` derived from the
  actual release commits (f51dff8, c953c4b).
- Update `docs/design.md` current implementation version to `0.4.8` and add
  `Completed in \`0.4.7\`` / `Completed in \`0.4.8\`` sections.
- Reference `assets/development/migrations/README.md` and `manifest.json`
  explicitly from specnav-vertical-slices SKILL.md.
- Reference `assets/visual-inventory.json` explicitly from specnav-prototype
  SKILL.md Required Outputs.
- Reword one verify-plan Stop Condition to avoid the banned literal while
  keeping its meaning.
- Mirror the three SKILL.md wording fixes into specnav-codex-plugin to keep
  shared-skill text aligned.

## Impact

- Documentation and SKILL.md prose only; no script or contract behavior
  changes.
- Affected: `CHANGELOG.md`, `docs/design.md`, three SKILL.md files in each
  repo.
- Risk tier: lite. Verification: the two failing suites plus skill fixtures
  in both repos return green; full suite rerun stays at parity.
