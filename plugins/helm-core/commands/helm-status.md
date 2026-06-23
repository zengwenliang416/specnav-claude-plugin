---
description: Show Helm workflow status for the active OpenSpec change
argument-hint: "[optional project path]"
---

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/workflow-state.js" --json
```

If `workflow-state.js` exits non-zero or returns `not-implemented:helm-core/workflow-state`, report that blocker and the exit status explicitly. Do not hide the placeholder exit 2 and do not infer cross-plugin state.

Then run the affordance surface for current legal actions:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --markdown
```

Summarize active change, risk tier, verify status, stale report state, ready actions, and blockers. If workflow state is blocked, label the affordance output as affordances only, not a full workflow-state fallback.
