---
name: postmortem
description: Record required operational learning after failures or risk events
allowed-tools:
  - Read
  - Bash
  - Write
---

# Postmortem

Write this when verification, release, deploy, rollback, security, data, availability, or repeated failure evidence requires a postmortem.

Write:

- `operations/postmortem.md`

Include trigger, root cause, impact, mitigation, follow-up, and whether the learning must be written back to OpenSpec.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```
