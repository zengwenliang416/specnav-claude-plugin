# Changelog

## 0.4.6

- Require the UI design foundation spec to state theme capability, theme toggle
  policy, i18n capability, supported locales, and default locale.
- Require change-level `spec-map.json` to record non-empty `theme_modes` and
  `locale_policy` entries.
- Require prototype manifests, screen maps, and handoffs to bind prototypes to
  the approved theme and locale policy, including explicit omission of theme or
  locale switchers when unsupported.
- Extend repository discovery to detect common i18n and theme evidence such as
  dictionaries, locale folders, theme folders, i18n configs, Tailwind configs,
  and i18n/theme dependencies.

## 0.4.5

- Add SpecNav change registry support so multiple active OpenSpec changes can
  coexist without falling back to stale `workflow-state.json` active-change
  values.
- Rename the public lifecycle action from `propose` to `requirements` while
  still routing user proposal intent to `/specnav-requirements`.
- Detect native OpenSpec/OPSX workflow entrypoints as legacy conflicts while
  still allowing SpecNav scripts to use the `openspec` CLI as the artifact
  engine.
- Report `ambiguous-change` when multiple changes exist and no explicit
  `SPECNAV_CHANGE`, registry focus, or active-change file selects one.
- Add `specnav-operations/scripts/archive-change.js` so `/specnav-archive`
  performs the full archive sequence: tasks checkbox normalization, operations
  archive gate, `openspec validate`, `openspec archive`, registry/focus update,
  evidence-index path rewrite, and archived receipt generation.

## 0.4.4

- Add `specnav-core/scripts/tasks-md.js` to normalize existing OpenSpec
  `tasks.md` files into standard checkbox task syntax.
- Run task normalization before archive so plain bullets become `- [ ]` tasks
  instead of staying as non-standard artifacts.

## 0.4.3

- Tighten archive and operations readiness instructions so plain `tasks.md`
  bullets are reported as `tasks-md:no-checkboxes`, not described as completion
  evidence.

## 0.4.2

- Require `tasks.md` to use checkbox task evidence before development handoff
  and archive readiness.
- Block archive when `tasks.md` has plain bullets, mixed checkbox/plain bullets,
  or unchecked tasks, instead of treating "no incomplete checkbox" as completion
  evidence.

## 0.4.1

- Rebuild the six-plugin cache release after hardening slash commands to avoid
  Claude Code positional placeholder substitution in plugin root resolution.
- Prevent user requirement text from being interpreted as a SpecNav plugin name
  during `/specnav-requirements` suite checks.

## 0.4.0

- Rename the repository, marketplace, plugins, commands, skills, runtime
  variables, schemas, and generated state to the SpecNav product surface.
- Move project-local runtime state from the legacy hidden state directory and
  marker file to `openspec/.specnav/` and `.specnav.json`.
- Rename the public GitHub target to
  `https://github.com/zengwenliang416/specnav-claude-plugin`.
- Update README, review docs, fixtures, and public hygiene checks for the
  SpecNav product surface.

## 0.3.4

- Resolve installed SpecNav plugin roots inside slash commands instead of relying on hook-only `CLAUDE_PLUGIN_ROOT`.
- Update SpecNav skills to use explicit `SPECNAV_*_ROOT` runtime variables and stop if installed plugin roots cannot be resolved.
- Add a regression fixture that executes `/specnav-bootstrap` with `CLAUDE_PLUGIN_ROOT` unset and verifies OpenSpec initialization succeeds.

## 0.3.3

- Add `/specnav-bootstrap` and `specnav-bootstrap` as the explicit OpenSpec initialization entrypoint when SpecNav reports `missing-openspec`.
- Update SessionStart, router, and workflow guidance to name `/specnav-bootstrap` as the next legal action.
- Allow bootstrap and read-only suite/status commands through the missing-OpenSpec guard while keeping production writes blocked.

## 0.3.2

- Support installed-cache suite discovery through `claude plugin list --json` when Claude has installed the six SpecNav plugins without a marketplace root manifest.
- Update `/specnav-doctor` so installed-cache mode validates the six required plugins by installed/enabled state instead of requiring `.claude-plugin/marketplace.json`.
- Add core runtime fixtures for installed-cache discovery and disabled-plugin blocking.

## 0.3.1

- Enable verification guidance for explicit Claude plugin enablement after install.
- Enforce `scope.json` `allowed_roots` / `denied_roots` in the PreToolUse guard and block production writes when `scope.json` is missing or invalid.
- Extend `/specnav-doctor` to verify installed Claude plugins are present and enabled through `claude plugin list --json`.
- Refresh design and README install/update instructions for the six-plugin marketplace shape.

## 0.3.0

- Convert SpecNav into a six-plugin Claude Code marketplace suite with `specnav-*` scoped public skills.
- Rewrite all skill frontmatter to the strict Agent Skills subset: `name` and `description` only.
- Add `tests/run-skill-contract-fixtures.sh` to enforce skill names, descriptions, stage manifests, and unfinished text checks.
- Add skill-local `references/`, `assets/`, and scaffold scripts across requirements, prototype, development, verification, and operations, plus `tests/run-skill-resource-fixtures.sh`.
- Replace core workflow-state and doctor placeholders with real cross-plugin state and diagnostic output.
- Add cross-plugin state fixtures, real `claude plugin validate` fixtures, and separate English/Chinese README files.
- Require `./plugins/...` marketplace sources so the multi-plugin marketplace validates under Claude Code.
- Replace OpenSpec filesystem fallback with explicit blocked states when required OpenSpec status is unavailable.
- Require clean-session behavior eval transcripts before aggregate verification can pass.

## 0.2.1

- Avoid creating `openspec/.specnav/events.jsonl` in repositories that have not been bootstrapped.
- Clean up guard helper code after hook payload normalization.

## 0.2.0

- Normalize Claude Code hook payloads for `Write`, `Edit`, `MultiEdit`, `NotebookEdit`, and `Bash`.
- Enforce all extracted paths from multi-path payloads.
- Add explicit override records under `openspec/.specnav/overrides/`.
- Add `scope.json` as the machine-readable file-scope contract with Markdown fallback.
- Prefer `openspec status --change <id> --json` for affordance state when available.
- Add fallback mode via `SPECNAV_DISABLE_OPENSPEC=1`.
- Add hook, override, OpenSpec, stale verify, and sign-off fixture tests.

## 0.1.0

- Initial single-plugin MVP with commands, skills, agents, hooks, local scripts, and smoke fixture.
