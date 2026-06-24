---
name: helm-verify-redteam
description: Use this skill when Helm must run destructive, adversarial, injection, permission, boundary, abuse, resilience, fuzzing, or hostile-input checks for a completed change.
---

# Helm Verify Redteam

## Purpose

Probe security, robustness, and abuse cases missed by normal tests.

## Workflow

1. Read plan, architecture specs, data-flow specs, permissions, and development handoff.
2. Design probes appropriate to risk tier.
3. Classify each failure in `verify/root-cause-checks.jsonl` before routing fixes.
4. Record destructive test evidence without touching real data unless explicitly approved.

## Required Outputs

- `verify/redteam/threat-model.md`, `probes.jsonl`, `report.md`, and `report.json`.

## Stop Conditions

- Probes would touch real data without approval.
- Required environment is unavailable.
- Root cause cannot be classified.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json` after writing the domain report.
