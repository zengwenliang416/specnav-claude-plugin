# Changelog

## 0.3.2

- Support installed-cache suite discovery through `claude plugin list --json` when Claude has installed the six Helm plugins without a marketplace root manifest.
- Update `/helm-doctor` so installed-cache mode validates the six required plugins by installed/enabled state instead of requiring `.claude-plugin/marketplace.json`.
- Add core runtime fixtures for installed-cache discovery and disabled-plugin blocking.

## 0.3.1

- Enable verification guidance for explicit Claude plugin enablement after install.
- Enforce `scope.json` `allowed_roots` / `denied_roots` in the PreToolUse guard and block production writes when `scope.json` is missing or invalid.
- Extend `/helm-doctor` to verify installed Claude plugins are present and enabled through `claude plugin list --json`.
- Refresh design and README install/update instructions for the six-plugin marketplace shape.

## 0.3.0

- Convert Helm into a six-plugin Claude Code marketplace suite with `helm-*` scoped public skills.
- Rewrite all skill frontmatter to the strict Agent Skills subset: `name` and `description` only.
- Add `tests/run-skill-contract-fixtures.sh` to enforce skill names, descriptions, stage manifests, and unfinished text checks.
- Add skill-local `references/`, `assets/`, and scaffold scripts across requirements, prototype, development, verification, and operations, plus `tests/run-skill-resource-fixtures.sh`.
- Replace core workflow-state and doctor placeholders with real cross-plugin state and diagnostic output.
- Add cross-plugin state fixtures, real `claude plugin validate` fixtures, and separate English/Chinese README files.
- Require `./plugins/...` marketplace sources so the multi-plugin marketplace validates under Claude Code.
- Replace OpenSpec filesystem fallback with explicit blocked states when required OpenSpec status is unavailable.
- Require clean-session behavior eval transcripts before aggregate verification can pass.

## 0.2.1

- Avoid creating `openspec/.helm/events.jsonl` in repositories that have not been bootstrapped.
- Clean up guard helper code after hook payload normalization.

## 0.2.0

- Normalize Claude Code hook payloads for `Write`, `Edit`, `MultiEdit`, `NotebookEdit`, and `Bash`.
- Enforce all extracted paths from multi-path payloads.
- Add explicit override records under `openspec/.helm/overrides/`.
- Add `scope.json` as the machine-readable file-scope contract with Markdown fallback.
- Prefer `openspec status --change <id> --json` for affordance state when available.
- Add fallback mode via `HELM_DISABLE_OPENSPEC=1`.
- Add hook, override, OpenSpec, stale verify, and sign-off fixture tests.

## 0.1.0

- Initial single-plugin MVP with commands, skills, agents, hooks, local scripts, and smoke fixture.
