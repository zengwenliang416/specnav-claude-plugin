---
name: status
description: "Show active Helm/OpenSpec state and next legal actions"
allowed-tools:
  - Bash
  - Read
---

# Helm Status

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/workflow-state.js" --json
```

If this exits non-zero or returns `not-implemented:helm-core/workflow-state`, report the blocker and exit status explicitly. Do not hide the placeholder exit 2 and do not infer cross-plugin state.

Then run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --markdown
```

Report:

- active change
- risk tier
- verify status
- stale report state
- ready actions
- blockers

When workflow state is blocked, present affordances as the legal-action surface only, not as a workflow-state fallback.
