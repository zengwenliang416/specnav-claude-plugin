# Verification Plan: {{HELM_CHANGE}}

## Verification Scope

- Active change: `{{HELM_CHANGE}}`
- Development handoff: `openspec/changes/{{HELM_CHANGE}}/development/handoff-to-verify.md`

## Required Domains

1. Facticity
2. Static
3. Unit
4. Redteam
5. E2E
6. Sensory

## Evidence Plan

- Direct repository evidence beats summaries.
- Every green verdict requires command, file, runtime, screenshot, trace, or
  review evidence.
- Missing evidence is a blocker, not a warning.
