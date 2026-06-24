---
name: helm-router
description: "Intent router for the Helm spec-driven Claude Code workflow"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# Helm

Use this skill when the user asks for Helm, OpenSpec-driven workflow, change status, next action, implementation, verification, fixing verifier findings, or archiving.

## Required First Step

Before routing, require the core plugin through the suite resolver:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --json
```

If it fails, report the returned blocker and stop. Do not fall back to a monolithic core workflow.

Then run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --markdown
```

Use the result as the legal action table. Do not invent workflow state.

## Plugin Routing

- INVESTIGATE / STATUS -> stay in `helm-core`.
- DEFINE / REQUIREMENTS / REFINE -> require `helm-requirements`, then route to `/helm-requirements`.
- PROTOTYPE -> require `helm-prototype`, then route to `/helm-prototype`.
- BUILD / DEVELOPMENT / FIX -> require `helm-development`, then route to `/helm-implement`.
- CHECK / VERIFICATION -> require `helm-verification`, then route to `/helm-verify`.
- FINISH / RELEASE / ARCHIVE -> require `helm-operations`, then route to `/helm-release` or `/helm-archive`.

Run the suite check before handing off:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --plugin <target-plugin> --json
```

If the requested action is blocked, explain the blocker and offer the next ready action.
If a required plugin is missing, report the `missing-plugin:<name>` blocker and stop. Do not route to legacy core lifecycle skills.
