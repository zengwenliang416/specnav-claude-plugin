---
name: helm-verify-sensory
description: Use this skill when Helm needs independent human-in-the-loop UX, accessibility, maintainability, component cohesion/coupling, performance feel, readability, or final code review beyond automated checks.
---

# Helm Verify Sensory

## Purpose

Run evidence-backed human review that automation cannot fully cover.

## Workflow

1. Stay read-only over production code and verification evidence.
2. Review readability, UX, interaction quality, accessibility, performance feel, maintainability, component cohesion and coupling.
3. Tie every finding to a file, artifact, screenshot, command, transcript, or inspection note.
4. Report unverified claims explicitly.

## Required Outputs

- `verify/sensory/reviewer-independence.md`, `review.md`, `findings.jsonl`, `report.md`, and `report.json`.

## Stop Conditions

- Independence is compromised.
- Evidence is missing.
- A finding cannot be tied to concrete evidence.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json` after writing the domain report.
