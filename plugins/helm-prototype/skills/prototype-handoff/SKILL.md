---
name: prototype-handoff
description: Record Helm prototype approval or not-required decision and development handoff
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Prototype Handoff

Run the contract before handoff:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json
```

If requirements, manifest, branch code, entry path, or verifier status is blocked, report the exact blockers and stop. Do not create fallback decisions or mark unverified prototype code approved.

Write `prototype/handoff.md` with the development handoff:

- approved prototype branch and variant when applicable;
- screens or flows to implement;
- components to create;
- components to reuse;
- components, hooks, utilities, or services to extract;
- API contracts;
- data flows;
- state, loading, empty, error, disabled, and permission behavior;
- out-of-scope items;
- required tests;
- open risks.

`handoff.md` is gap-sensitive and must not contain TODO, TBD, unresolved, or gap as unresolved words.

Write `prototype/decision.json`. Only an explicit user approval may set:

```text
{
  "status": "approved",
  "prototype_code": "required_present",
  "prototype_type": "<manifest type>",
  "approved_variant": "<variant or n/a>",
  "promotion": "requires_development_gate",
  "blocked_reasons": []
}
```

If the user explicitly decides prototype code is not required, write:

```text
{
  "status": "not_required",
  "reason": "<concrete user-approved reason>"
}
```

Do not use `approved` without user approval. Do not use `not_required` without a concrete reason.

After writing `handoff.md` and `decision.json`, run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json
```

Proceed to development only when the contract returns `"ok": true`.
