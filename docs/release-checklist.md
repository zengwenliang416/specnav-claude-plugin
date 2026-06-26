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
