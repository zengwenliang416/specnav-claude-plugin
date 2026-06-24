---
name: verify-sensory
description: Run independent human-in-the-loop UX and maintainability verification
allowed-tools:
  - Read
  - Bash
  - Write
---

# Verify Sensory

The sensory reviewer is read-only over production code and verification evidence. Implementer reports and controller summaries are claims, not proof.

Review readability, interaction quality, performance feel, accessibility, maintainability, component cohesion/coupling, and user experience. Every finding needs a file, command, artifact, screenshot, transcript, or manual inspection note.

Write:

- `verify/sensory/reviewer-independence.md`
- `verify/sensory/review.md`
- `verify/sensory/findings.jsonl`
- `verify/sensory/report.md`
- `verify/sensory/report.json`

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json
```
