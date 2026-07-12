# Decision: L3 annotations and Act-promotion ship advisory-by-default

- Status: **CLOSED — decided 2026-07-12**
- Owner: repository owner (Zengwenliang0416)
- Scope: `0.5.2` — L3 AI-facing annotation layer + Act -> capability promotion loop
- Source: PDCA "AI harness" engineering practice (得物推荐 AICon talk, 2026), mapped
  against SpecNav's existing surface and `docs/optimization-plan-2026-07.md`.

## The question

The talk contributes two ideas SpecNav did not already cover better:

1. An **L3 code-comment layer** — anchor comments on code seams that raise agent
   retrieval accuracy (the talk measured 52% -> 91% on simple tasks).
2. An **Act -> reusable capability** loop — a resolved bad case should leave
   behind a check the next occurrence hits automatically, not just prose.

The talk implies enforcing both as hard gates. Should SpecNav do that?

## Decision

**No. Both ship advisory-by-default, with enforcement as a deliberate per-project
opt-in.** Neither adds a new mandatory stage or verification domain.

- L3: the `ai-annotation-policy` foundation spec is optional and absent by
  default. `anchor-scan.js` always reports coverage and emits `anchor.coverage`,
  but only blocks (`anchor-uncovered:<file>`, plus the `anchor_refs` traceability
  requirement) when the policy declares `enforcement: gate`.
- Act-promotion: a `promoted_checks[]` `candidate` never blocks archive. It
  becomes enforceable only after a dry-run + generalization + human signoff
  (`admitted`), and the guard enforces the resulting rule only when the rule file
  declares `enforcement: gate`.

## Why

SpecNav's own optimization plan sets three constraints this decision honors:

- Anti-list #1: **freeze new mandatory gates until P3.3 measures effectiveness.**
  Advisory-first + `anchor.coverage` / `promotion.*` events feeding
  `gate-effectiveness.js` is exactly "measure before you gate."
- Anti-list #2: **no LLM judge in gate decisions.** Both features are
  deterministic (glob scans, JSON-shape checks, data-declared guard rules).
- Phase 5: **distilled knowledge is advisory, never a gate.** A promoted check
  that *does* gate is a deliberate step beyond P5, so its admission is gated
  itself — reusing the prototype `may_promote` pattern — and defaults off.

Enforcement mechanisms reuse existing models rather than inventing new ones: the
`promoted-check` guard rule mirrors the `frozen-tests` data-declared guard and is
overridable through the standard override files.

## Consequences

- Projects that ignore both features see zero behavior change.
- A project opts into L3 gating by creating the policy and setting
  `enforcement: gate`; into promotion enforcement by admitting a rule with
  `enforcement: gate`.
- `gate-effectiveness.js` now reports promotion lifecycle and anchor-coverage
  trends, so a noisy opt-in gate is visible and retirable like any other gate.
