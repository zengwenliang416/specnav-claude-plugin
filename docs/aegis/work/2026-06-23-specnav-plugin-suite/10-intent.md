# SpecNav plugin suite implementation - Intent

## TaskIntentDraft

- Requested outcome: Implement the approved SpecNav Claude Code multi-plugin suite plan with subagent-driven task execution.
- Goal: Implement the approved SpecNav Claude Code multi-plugin suite plan with subagent-driven task execution.
- Success evidence:
- Task commits, fixture outputs, review reports, and final smoke checks demonstrate the plugin suite matches the approved plan.
- Stop condition: Stop only for explicit blockers such as missing design authority, failing required checks that cannot be fixed locally, or user direction change.
- Non-goals:
- Do not implement unrelated product features outside the approved SpecNav plugin suite design.
- Scope: SpecNav Claude Code plugin marketplace repository: multi-plugin layout, suite resolver, runtime path updates, stage plugins, tests, docs, and release gates.
- Change kinds:
- feature
- Risk hints:
- Repository structure move can break command, hook, test, and docs paths; stage plugin tasks must fail explicitly without fallback.

## BaselineReadSetHint

- docs/superpowers/plans/2026-06-23-specnav-plugin-suite-implementation.md
- docs/design.md

## ImpactStatementDraft

- Compatibility boundary: Existing SpecNav fixtures and command semantics must be either migrated or explicitly updated.
- Affected layers:
- Claude Code plugin marketplace layout and SpecNav runtime scripts
- Owners:
- Codex main controller with fresh subagents per task
- Invariants:
- No fallback behavior; missing prerequisites must fail explicitly with blockers.
- specnav-core owns shared runtime and hooks; stage plugins own their own stage contracts.
- Non-goals:
- Do not implement unrelated product features outside the approved SpecNav plugin suite design.

These records are Method Pack drafts / hints, not authoritative runtime decisions.
