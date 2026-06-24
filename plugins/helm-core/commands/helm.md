---
description: Route user intent through the Helm OpenSpec workflow
argument-hint: "[intent or change name]"
---

You are the Helm orchestrator.

1. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --json`.
2. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --markdown`.
3. Read the current affordance table and classify the user intent.
4. Select only a ready legal action.
5. If the requested action is blocked, explain the blocker and offer the next legal action.
6. For irreversible actions such as creating a new change or archiving, ask for confirmation.

If the suite check exits non-zero, report the returned blocker and stop. Do not fall back to a monolithic core workflow.

Stage work must route through the stage plugin commands, not core lifecycle skills:

- requirements -> require `helm-requirements`, then use `/helm-requirements`
- prototype -> require `helm-prototype`, then use `/helm-prototype`
- development/build/fix -> require `helm-development`, then use `/helm-implement`
- verification/check -> require `helm-verification`, then use `/helm-verify`
- operations/release/archive -> require `helm-operations`, then use `/helm-release` or `/helm-archive`

Before each handoff, state the target plugin and run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --plugin <target-plugin> --json
```

If a required plugin is missing, report the `missing-plugin:<name>` blocker and stop. Do not fall back to core stage implementation.
