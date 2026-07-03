# Frontend-Backend Data Flow Spec

## Overview

The project archetype is cli-plugin. The "frontend" is the Claude Code
conversation surface (user prompts, slash commands, hook-injected context) and
the "backend" is the Node script layer plus file-backed state under
`openspec/`. A "flow" here is one governed round trip: user intent → command
or hook → script execution → state mutation → rendered response. Flows are
identified as FLOW-<NAME> and each declares its trigger, request, response,
validation, error handling, retry/idempotency, and rollback behavior.

## Flow Index

| Flow id | Name | Entry |
| --- | --- | --- |
| FLOW-SESSION-START | Session state injection | SessionStart hook |
| FLOW-GUARD-WRITE | Production write gating | PreToolUse hook |
| FLOW-STALE-MARK | Verification staleness marking | PostToolUse hook |
| FLOW-ROUTE | Intent routing | `/specnav` command |
| FLOW-BOOTSTRAP | OpenSpec initialization | `/specnav-bootstrap` |
| FLOW-VERIFY-AGGREGATE | Six-domain aggregate verdict | `/specnav-verify` |
| FLOW-ARCHIVE | Change archive | `/specnav-archive` |

## Boundary Contracts

- Hook boundary: stdin JSON (`tool_name`, `tool_input`) → exit code 0/1/2 plus
  stderr message; guard messages are user-visible denials.
- Command boundary: Bash blocks inside command markdown resolve installed
  plugin roots, then call scripts with `--json`.
- Script boundary: single JSON object on stdout (`ok`, `blockers[]`, fields);
  exit code mirrors `ok`. Blocker identifiers are stable strings.
- State boundary: scripts are the only writers of generated state
  (`openspec/.specnav/**`, `verify/**` reports); skills write authored
  artifacts (specs, requirements, briefs).

## State Ownership

- Conversation surface owns nothing durable; it renders script output.
- specnav-core owns `openspec/.specnav/**` (workflow state, registry, events,
  journal, overrides).
- Stage plugins own their change subtrees (see system architecture module
  table).
- The user owns authored markdown decisions; scripts must not overwrite
  authored content silently (scaffolds skip existing files unless `--force`).

## Validation Ownership

- Input validation for hook payloads lives in `specnav-guard.js`
  (`normalizePayload`, path extraction, scope matching).
- Artifact validation lives in stage contract scripts
  (`requirements-contract.js`, `prototype-contract.js`,
  `development-contract.js`, `verify-domains.js`, `operations-gate.js`).
- Foundation spec validation lives in `foundation-specs.js` and runs before
  requirements questioning.
- Validation is always server-side (script-side); the conversation surface
  never self-certifies. A skill claiming completion without `ok:true` violates
  the session completion rule injected at session start.

## Error & Empty States

- Every blocked flow returns named blockers; the surface must show them
  verbatim (`missing-openspec`, `active-change`, `scope`, `stale-verify-report`).
- Empty project (no `openspec/`): all production flows collapse to the
  bootstrap affordance; status and doctor remain readable.
- Empty change set: `active-change` blocker with candidates list; the fix is
  creating or focusing a change, never inferring one.
- Missing tool (OpenSpec CLI, CodeGraph CLI): explicit
  `missing-openspec-cli` / `codegraph:*` blockers; no degraded silent mode.

## Loading / Optimistic / Retry Behavior

- All flows are synchronous CLI executions; there is no optimistic UI. The
  surface reports state only after the script exits.
- Retry policy: flows are safe to rerun because scripts are idempotent
  (regenerating snapshots, skipping existing scaffold targets); retry after a
  denial requires fixing the named blocker or creating an explicit override,
  not repeating the identical call (`retry` without change is a loop signal
  routed to debug/break-loop skills).
- Idempotency keys: change id + artifact path; `openspec archive` is the one
  non-idempotent transition and is confirmation-gated.
- Long operations (openspec init, test commands) carry timeouts
  (`SPECNAV_TEST_TIMEOUT_MS`, 120s default) and surface timeout as failure,
  not as success.

## End-to-End Flow Details

### FLOW-SESSION-START

- User trigger: opening a Claude Code session in a governed project.
- Request: SessionStart hook invokes `specnav-session-start.js` (no stdin payload used).
- Response: JSON state line (status, blockers, completion rule) injected into context; runtime artifacts rewritten.
- Validation: openspec presence, marker file, legacy entrypoint detection.
- Error: missing openspec → blocked state naming `/specnav-bootstrap` as the only recommended action.
- Retry/idempotency: reruns rewrite the same snapshot; journal gains a new session entry.
- Rollback: none needed; snapshot regeneration is the recovery.

### FLOW-GUARD-WRITE

- User trigger: any Write/Edit/MultiEdit/NotebookEdit/Bash tool call.
- Request: hook stdin payload with tool name and input.
- Response: exit 0 (allow), 1 (warn), 2 (deny) with stderr reason; event appended.
- Validation: dangerous command patterns, legacy entrypoints, openspec presence, active change, `tasks.md`, `scope.json` include/exclude/operations, review-required patterns, override matching.
- Error: denial message names the exact blocker and the repair path.
- Retry/idempotency: pure function of payload and current state; identical retry yields identical verdict until state changes.
- Rollback: not applicable (the gate prevents the mutation instead).

### FLOW-STALE-MARK

- User trigger: completing any write tool call while a `verify-report.json` exists.
- Request: PostToolUse hook invokes `specnav-post-tool.js`.
- Response: `verify-report.stale` written with a timestamp; `verify.stale` event.
- Validation: only the existence of the report is checked; marking is unconditional by design.
- Error: absence of a change dir exits silently (nothing to invalidate).
- Retry/idempotency: rewriting the marker is harmless; latest timestamp wins.
- Rollback: the marker is cleared only by a green aggregate rerun, never by hand (documented in verify-rerun skill).

### FLOW-ROUTE

- User trigger: `/specnav <intent>` or ambiguous lifecycle request.
- Request: `specnav-route.js --intent "<text>" --json`.
- Response: route JSON (target plugin, command, skill, blockers, confirmation_required, no_fallback).
- Validation: suite availability, affordance state, foundation validation when routing to foundation.
- Error: non-empty blockers mean the surface reports them and stops; no fallback routing.
- Retry/idempotency: pure computation over current state.
- Rollback: none; routing mutates nothing.

### FLOW-BOOTSTRAP

- User trigger: `/specnav-bootstrap` in an uninitialized project.
- Request: `specnav-bootstrap.js --json [project-dir]`.
- Response: `openspec/` tree created via OpenSpec CLI, runtime artifacts written, marker file ensured.
- Validation: openspec CLI presence; init exit status; resulting directory existence.
- Error: `missing-openspec-cli`, `openspec-init-failed` with captured stdout/stderr.
- Retry/idempotency: already-initialized projects short-circuit to `already-initialized`.
- Rollback: manual removal of `openspec/` (user action); bootstrap never deletes.

### FLOW-VERIFY-AGGREGATE

- User trigger: `/specnav-verify` after development handoff.
- Request: development handoff gate, six domain skill passes writing `verify/<domain>/report.*`, then `verify-domains.js aggregate --json`.
- Response: aggregate JSON + markdown + HTML reports; top-level `verify-report.json`; stale marker cleared only on green.
- Validation: full artifact contract (plan, evidence index, traceability, user test case gate, runtime evidence, domain reports, receipt, behavior evals) plus codegraph stage guard.
- Error: red verdict lists every blocker; blocked domains require an explicit blocker class.
- Retry/idempotency: rerun after fixes uses verify-rerun (affected domain plus downstream) and re-aggregates.
- Rollback: verification writes only report artifacts; recovery is regeneration.

### FLOW-ARCHIVE

- User trigger: `/specnav-archive` with confirmation.
- Request: task normalization, archive gate, `openspec validate`, `openspec archive`, registry/focus update, evidence path rewrite, receipt generation.
- Response: change moved under `openspec/changes/archive/`, `archive-log.jsonl` transition recorded.
- Validation: green fresh verify report, operations readiness, checkbox task evidence, required sign-off by risk tier, update-spec resolution.
- Error: any gate failure blocks before `openspec archive` executes; partial archive is not permitted.
- Retry/idempotency: gates are rerunnable; the archive move itself runs once and is confirmation-gated because rollback is manual.
- Rollback: restoring an archived tree is a manual git operation; the flow records provenance to make that possible.

## Async / Realtime Flows

None. All flows are synchronous command executions within a session; SpecNav
has no server, websocket, queue, or background job. Long-running child
processes (openspec init, test commands) are awaited with explicit timeouts.
The only cross-session propagation is file state read at the next
SessionStart.

## Flow Do's and Don'ts

- Do surface blocker identifiers verbatim; they are the API between scripts and conversation.
- Do rerun contracts after every fix; a green claim without a fresh `ok:true` is a protocol violation.
- Do keep every new flow synchronous and file-backed unless this spec is amended first.
- Don't clear `verify-report.stale` by hand or bypass the aggregate.
- Don't add hidden retries around a denied gate; loop signals route to debug/break-loop.
- Don't let a skill write generated state paths; scripts own them.
