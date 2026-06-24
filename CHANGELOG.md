# Changelog

## 0.3.0

- Convert Helm into a six-plugin Claude Code marketplace suite with `helm-*` scoped public skills.
- Rewrite all skill frontmatter to the strict Agent Skills subset: `name` and `description` only.
- Add `tests/run-skill-contract-fixtures.sh` to enforce skill names, descriptions, stage manifests, and unfinished text checks.
- Replace core workflow-state and doctor placeholders with real cross-plugin state and diagnostic output.
- Add cross-plugin state fixtures and update README with Chinese and English usage notes.

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
