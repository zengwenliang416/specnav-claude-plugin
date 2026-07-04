# Release Checklist

Use this checklist before tagging or publishing the SpecNav plugin suite.

## Metadata

- Marketplace version matches every child plugin version.
- `CHANGELOG.md` has an entry for the release version.
- `docs/design.md` current implementation version matches the release version.
- Plugin `homepage` and `repository` point to the public repository.
- No public docs contain local home-directory or external-volume absolute paths.

## Documentation

- `README.md` and `README.zh-CN.md` both include install verification, first-run
  guidance, useful checks, and design doc links.
- `docs/user-journey.md` explains first use from empty and existing projects.
- `docs/spec-discovery.md` explains repository discovery and negotiation.
- `docs/command-skill-matrix.md` maps commands to reads, writes, blockers, and
  next steps.
- `docs/compatibility.md` reflects the latest smoke evidence.

## Verification

Run:

```bash
bash tests/run-public-hygiene-fixtures.sh
bash tests/run-plugin-validate-fixtures.sh
bash tests/run-skill-contract-fixtures.sh
bash tests/run-plugin-suite-layout-fixtures.sh
bash tests/run-plugin-suite-resolver-fixtures.sh
bash tests/run-installed-cache-runtime-fixtures.sh
bash tests/run-smoke.sh
```

## Scaffold audit (after any main-model upgrade)

Every gate encodes an assumption about what the model cannot do reliably;
those assumptions go stale as models improve. After upgrading the primary
model (or at least once per release cycle), run the gate-effectiveness report
against a project with real usage history and review the signals:

```bash
PROJECT_DIR=<managed-project> node plugins/specnav-core/scripts/gate-effectiveness.js
```

- `candidate-wrong-gate` (override rate >= 0.5): fix the gate criteria or demote to a warning.
- `review-criteria` (override rate >= 0.2): inspect recent overrides for a pattern.
- `never-fired`: candidate for retirement — it costs maintenance and protects nothing.
- Rising `red-after-allow`: a missing gate, not an excess one.

For release candidates, run the full suite:

```bash
for test_script in tests/run-*.sh; do
  bash "$test_script"
done
```

## Post-Release

- Confirm the installed cache has the expected version.
- Start a fresh Claude Code session.
- Run `/specnav-doctor` in a target project.
- Run `/specnav` and confirm it reports the next legal action instead of using
  fallback behavior.
