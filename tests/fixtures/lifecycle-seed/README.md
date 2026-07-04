# lifecycle-seed

A real governed-project tree captured from a live SpecNav session (2026-07-03):
four passing foundation specs, two changes with proposals, checkbox tasks,
scopes, and validation logs, plus the legacy OpenSpec disabled stubs and the
opt-in marker.

Host-discoverable names are neutralized in the checkout so IDEs and agents do
not treat the fixture as a live project: `dot-claude/` -> `.claude/`,
`dot-codex/` -> `.codex/`, `specnav-marker.json` -> `.specnav.json`. The
harness restores the real names when materializing its temp copy.

Used by `tests/run-lifecycle-walkthrough-fixtures.sh` to drive the real
runtime scripts through an end-to-end state walkthrough: bootstrap short-circuit,
foundation gate, ambiguous-change resolution, guard scope allow/deny/review,
requirements and development entry blockers, verify, staleness, and the
archive gate.

Machine-local runtime state (`openspec/.specnav/*` files, journals, context
manifests) is intentionally absent; the harness regenerates it in a temp copy.
Do not add an `openspec/` directory or `.specnav.json` to the repository root:
this repository is not governed by SpecNav (see `.gitignore`).
