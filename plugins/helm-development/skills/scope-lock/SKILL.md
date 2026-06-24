---
name: scope-lock
description: Create and enforce Helm development scope locks
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# Scope Lock

Run the development contract before touching scope artifacts:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --mode entry --json
```

Use `prototype.active_change` from the contract as the only active change source. Do not fallback to the newest change or a manually guessed change.

Create or repair `openspec/changes/<active-change>/scope.json` with:

- `schema_version: 1`
- `change_id` exactly matching the active change
- `stage: "development"`
- non-empty `allowed_roots`
- arrays for `denied_roots` and `requires_review_on`
- `allowed_operations.create`, `.modify`, `.delete`, and `.rename` as booleans
- non-empty `prototype_sources`
- `expires_when: "verification_started"`

All paths must be relative clean strings. Block absolute paths, backslashes, `..`, empty strings, and padded strings. `prototype_sources` must contain only the approved prototype source set: the `prototype/prototype-manifest.json` `entry` for the approved variant recorded in `prototype/decision.json`. It must include `openspec/changes/<active-change>/prototype/<manifest.entry>` and must not reference alternate prototype files, stale variants, handoff notes, or any other source outside that approved entry set.

Production edits are blocked outside `allowed_roots`, inside `denied_roots`, or beyond the declared operation permissions. Implementers cannot expand scope as a fallback; report `NEEDS_CONTEXT` or `BLOCKED` and stop when scope is insufficient.

After editing scope, rerun:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/development-contract.js" --mode entry --json
```

Proceed only when scope blockers are cleared.
