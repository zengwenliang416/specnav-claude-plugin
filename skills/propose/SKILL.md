---
name: propose
description: "Create a Helm/OpenSpec change proposal and risk tier"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# Helm Propose

Create or refine `openspec/changes/<change>/proposal.md`.

1. Confirm whether this is a new change if ambiguous.
2. Create `openspec/changes/<change>/`.
3. Write proposal: problem, scope, non-goals, affected areas, acceptance intent.
4. Run risk tier analysis:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/risk-tier.js" --write "openspec/changes/<change>"
```

5. Set active change:

```bash
mkdir -p openspec/.helm
printf '%s\n' '<change>' > openspec/.helm/active-change
node "$CLAUDE_PLUGIN_ROOT/scripts/affordances.js" --write-snapshot --markdown
```
