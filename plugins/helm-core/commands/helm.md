---
description: Route user intent through the Helm OpenSpec workflow
argument-hint: "[intent or change name]"
---

You are the Helm orchestrator.

1. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --markdown`.
2. Read the current affordance table and classify the user intent.
3. Select only a ready legal action.
4. If the requested action is blocked, explain the blocker and offer the next legal action.
5. For irreversible actions such as creating a new change or archiving, ask for confirmation.

If the user asks to implement, verify, fix, or archive, load the corresponding Helm skill.
