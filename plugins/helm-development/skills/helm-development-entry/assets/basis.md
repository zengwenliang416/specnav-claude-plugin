# Development Basis: {{HELM_CHANGE}}

## Requirements Reference

- `openspec/changes/{{HELM_CHANGE}}/requirements.md`
- `openspec/changes/{{HELM_CHANGE}}/acceptance.md`
- `openspec/changes/{{HELM_CHANGE}}/spec-map.json`
- `openspec/changes/{{HELM_CHANGE}}/component-impact-map.json`

## Prototype Reference

- `openspec/changes/{{HELM_CHANGE}}/prototype/handoff.md`
- `openspec/changes/{{HELM_CHANGE}}/prototype/decision.json`

## Handoff Reference

Development is allowed only after the prototype handoff and decision are valid.

## Component Architecture Constraint

Implementation must preserve high cohesion and low coupling. Any duplicated UI,
state, validation, formatting, or domain behavior that meets the extraction rule
must become a shared component, hook, utility, or service.
