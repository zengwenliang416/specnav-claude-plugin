# System Architecture & Database Spec

## Overview

This repository is a Claude Code marketplace shipping seven SpecNav plugins.
The project archetype is cli-plugin, not a web application, so this spec maps
the required architecture concerns honestly onto that archetype: the
"frontend" is the Claude Code conversation surface (commands, skills, hook
output, generated HTML reports), the "backend" is the Node.js script layer,
and the "database" is the file-backed state store under `openspec/` in each
governed project. There is no network service and no SQL database in this
system; every persistence concern is a file contract.

## Application Topology

- Host: Claude Code CLI loads plugins from the installed cache
  (`~/.claude/plugins/cache/specnav-marketplace/<plugin>/<version>/`).
- Source of truth: this repository is the marketplace root
  (`.claude-plugin/marketplace.json`) with plugins under `plugins/`.
- Execution model: Claude Code fires hooks (SessionStart, PreToolUse,
  PostToolUse) and slash commands; commands resolve installed plugin roots and
  run Node scripts; scripts read and write file state in the governed project.
- A sibling repository (`specnav-codex-plugin`) mirrors this suite for the
  OpenAI Codex host. Shared core scripts are kept byte-identical by policy;
  divergence is tracked as drift.

## Module Boundaries

Each plugin is a module with a declared responsibility, a public contract, and
owned data. Cross-plugin calls go through `plugin-runtime.js` script
resolution; skills must not deep-import another plugin's internals.

| Module | Responsibility | Public contract (scripts) | Owned data |
| --- | --- | --- | --- |
| specnav-core | routing, hooks, state machine, doctor, suite governance | `workflow-state.js`, `specnav-guard.js`, `specnav-route.js`, `plugin-suite.js`, `tasks-md.js`, `override.js` | `openspec/.specnav/**`, `.specnav.json` |
| specnav-requirements | foundation specs, discovery, requirements grilling | `foundation-specs.js`, `repository-discovery.js`, `requirements-contract.js` | `openspec/specs/**`, change requirements artifacts |
| specnav-prototype | prototype artifacts, verification, handoff | `prototype-contract.js` | `openspec/changes/<id>/prototype/**` |
| specnav-development | scope lock, vertical slices, review loop | `development-contract.js` | `openspec/changes/<id>/development/**`, `scope.json` |
| specnav-verification | six-domain verification, aggregate report | `verify-domains.js` | `openspec/changes/<id>/verify/**`, `verify-report.*` |
| specnav-operations | readiness, release, archive | `operations-gate.js`, `archive-gate.js`, `archive-change.js` | `openspec/changes/<id>/operations/**` |
| specnav-codegraph | code evidence, claims, drift | `codegraph-contract.js`, `codegraph-plan.js` | `openspec/changes/<id>/codegraph/**` |

Forbidden dependencies: stage plugins must not depend on each other's
internals; every stage plugin may depend on specnav-core; specnav-core must
not depend on any stage plugin except through optional runtime resolution
(`requirePluginScript`) that reports `missing-plugin:<name>` when absent.

Extension points: new lifecycle stages are added as new plugins registered in
`marketplace.json` plus a `specnav-stage.json` declaration; new verification
domains extend `DOMAINS` in `verify-domains.js` together with a dedicated
skill.

## Frontend Architecture

The user-facing surface is conversational and generated, not a SPA:

- Slash commands (`/specnav-*`) and skills render markdown into the Claude
  Code session.
- Hook stderr/stdout injects state (`specnav-session-start.js` JSON, guard
  denial messages).
- Generated stakeholder pages (`verify/aggregate-report.html`,
  `verify-report.html`) are static HTML rendered by `renderAggregateHtml` in
  `verify-domains.js`, styled per the UI design spec.
- README stage diagrams are pre-rendered PNG assets under
  `docs/assets/readme/`.

## Backend Architecture

- Runtime: Node.js (host-provided), zero npm dependencies by design; only
  `fs`, `path`, `child_process`, `os` are used.
- Scripts are CLI entrypoints with `--json` machine output and nonzero exit
  codes as blocking signals (0 allow, 1 warn, 2 deny/blocked).
- Shared helpers live in `specnav-core/scripts/specnav-lib.js`;
  `plugin-runtime.js` is intentionally duplicated per plugin so each plugin
  stays installable in isolation.
- External processes invoked: `openspec` CLI (init, status, validate,
  archive), `codegraph` CLI (explore, index status), `claude plugin list`
  (suite discovery), `git` (branch finish, worktree checks).

## API Surface

The public API is the script contract surface, not HTTP:

- Every contract script accepts `--json` and prints a single JSON object with
  `ok`, `blockers`, and stage-specific fields; exit code mirrors `ok`.
- Hook payloads follow the Claude Code hook schema on stdin
  (`tool_name`, `tool_input`); the guard extracts paths via
  `normalizePayload`.
- Environment inputs: `PROJECT_DIR`, `SPECNAV_CHANGE`,
  `SPECNAV_MARKETPLACE_ROOT`, `SPECNAV_TEST_COMMAND`, `SPECNAV_*_ROOT`
  overrides.
- Breaking changes to any script's JSON shape or blocker identifiers require a
  version bump and fixture updates in `tests/`.

## Database Model

The persistence layer is file-backed state. Each entity below records its
purpose, owner, fields, relationships, indexes, constraints, lifecycle,
migration, and retention concerns.

### Entity: workflow-state.json (`openspec/.specnav/`)

- Purpose: cached snapshot of computed affordances and blockers.
- Owner: specnav-core (`workflow-state.js`).
- Fields: `schema_version`, `generated_at`, `ok`, `status`, `active_change`, `blockers[]`, `actions[]`, `plugin_suite`.
- Relationships: derived from change directories and `change-registry.json`; never authoritative over them.
- Indexes: none; single document, no lookup index is needed at this scale.
- Constraints: `schema_version` is 1; regenerated snapshots must never be hand-edited.
- Lifecycle: rewritten on session start and on `--write` runs.
- Migration: schema changes bump `schema_version` and are handled by regeneration, not in-place upgrade.
- Retention: latest snapshot only; history lives in `events.jsonl`.

### Entity: change-registry.json (`openspec/.specnav/`)

- Purpose: registry of coexisting changes and the explicit `current_focus`.
- Owner: specnav-core (`specnav-lib.js` buildChangeRegistry/writeChangeRegistry).
- Fields: `changes[]` (id, stage, archived path), `current_focus`.
- Relationships: ids must match directories under `openspec/changes/`.
- Indexes: keyed by change id in memory; file order is not significant.
- Constraints: `current_focus` must name an existing change or be null; invalid ids are blockers, not silent repairs.
- Lifecycle: updated on bootstrap, focus switch, and archive.
- Migration: archive rewrites entries to `openspec/changes/archive/<id>` paths.
- Retention: permanent registry; archived entries retained as provenance.

### Entity: events.jsonl (`openspec/.specnav/`)

- Purpose: append-only audit log of hook decisions and lifecycle events.
- Owner: specnav-core (`lib.event`).
- Fields per line: `ts`, `type`, payload object (reason, paths, change).
- Relationships: references change ids and gate names; free-form payload.
- Indexes: none; consumers scan linearly.
- Constraints: append-only; malformed lines are skipped by readers.
- Lifecycle: grows monotonically during sessions.
- Migration: none; schema is line-local.
- Retention: kept for the life of the project; safe to truncate manually by the user, never by scripts.

### Entity: change artifact tree (`openspec/changes/<id>/**`)

- Purpose: the governed delivery record for one change (requirements,
  prototype, development, verify, operations artifacts).
- Owner: split by stage plugin per the module table above.
- Fields: defined per artifact by stage contracts (for example `scope.json`
  fields `schema_version`, `change_id`, `stage`, `allowed_roots[]`,
  `denied_roots[]`, `allowed_operations`, `requires_review_on[]`,
  `expires_when`).
- Relationships: `change_id` fields must equal the directory name; traceability
  matrix links changed files to requirement, task, and prototype refs.
- Indexes: directory layout is the index; contracts enumerate expected paths.
- Constraints: schema checks in contract scripts; scaffold placeholder markers
  block completion; checkbox task evidence required in `tasks.md`.
- Lifecycle: created by scaffolds, mutated during the stage, frozen by gates
  (acceptance frozen during implementation), invalidated by the stale marker.
- Migration: `openspec archive` moves the tree under `openspec/changes/archive/`
  and rewrites evidence paths via `archive-change.js`; SQL-style migrations for
  the governed product live under `development/migrations/` with manifest,
  rollback, and validation notes when a change declares database work.
- Retention: archived trees are permanent evidence; deletion is a manual user
  action outside SpecNav.

### Entity: override records (`openspec/.specnav/overrides/*.json`)

- Purpose: explicit, expiring exemptions for named gates.
- Owner: specnav-core (`override.js`).
- Fields: `schema_version`, `gate`, `reason`, `requested_by`, `created_at`, `expires_at`, optional `active_change`, `affected_path`, `command`.
- Relationships: matched against guard context (gate, change, path, command).
- Indexes: filename encodes timestamp and gate for human scanning.
- Constraints: expiry is enforced on read (`findActiveOverride`); default ttl 30 minutes.
- Lifecycle: created explicitly, pruned by `override.js prune`.
- Migration: none.
- Retention: expired records removed by prune; creation and use are mirrored into `events.jsonl`.

## Permissions & Security

- Enforcement point: PreToolUse guard denies production writes without an
  active change, `tasks.md`, and a valid `scope.json`; path scope and
  operation permissions come from `scope.json`.
- Known enforcement limits (recorded, not hidden): Bash commands without
  extractable paths pass the path gate; PostToolUse staleness only fires on
  write tools; the Codex host treats PreToolUse as a guardrail rather than a
  complete boundary. Hardening these limits is tracked as roadmap work
  (evidence ledger, tree-hash staleness).
- Dangerous command patterns (`rm -rf /`, `sudo`, `curl|sh`) are denied
  outright unless a matching override exists.
- Secrets: no credentials are stored or read by SpecNav scripts;
  `openspec/.specnav/` must never contain tokens.
- High-risk paths (auth, payments, migrations, CI, lockfiles) escalate the
  risk tier via `risk-tier.js` and require `signoff.yaml` before archive.

## Integration Boundaries

- OpenSpec CLI is the authoritative state reader for change artifacts
  (`openspecStatus`); when it fails, SpecNav reports
  `openspec-status:<error>` and blocks rather than inferring.
- CodeGraph CLI is optional per policy profile; when required by stage policy
  and missing, the codegraph guard blocks with `codegraph:*` blockers.
- Claude Code plugin cache is the deployment boundary: runtime resolution
  reads installed versions, never the source checkout.
- Git is consulted read-mostly; branch cleanup only touches SpecNav-owned
  worktrees with recorded provenance.

## Operational Constraints

- Zero-dependency Node scripts; must run on the host's Node without install
  steps.
- Hook execution must stay fast (guard is on every write/Bash call); no
  network access in hooks.
- Scripts must be idempotent: reruns regenerate snapshots and reports without
  corrupting state.
- All blocking output is a stable string identifier consumed by fixtures;
  renaming a blocker is a breaking change.
- The suite must degrade explicitly: missing plugin, missing CLI, or missing
  artifact produces a named blocker, never a silent fallback.

## Architecture Do's and Don'ts

- Do route all cross-plugin script access through runtime resolution with
  `missing-plugin` blockers.
- Do keep shared core scripts byte-identical with the Codex sibling until the
  planned monorepo lands; record intentional divergence.
- Do add fixtures in `tests/` for every new blocker or contract field.
- Don't hand-edit generated state (`workflow-state.json`, reports, ledger
  files); regenerate through scripts.
- Don't add npm dependencies to plugin scripts.
- Don't widen guard allowances (new tool matchers, new repair commands)
  without a corresponding fixture and design.md update.
