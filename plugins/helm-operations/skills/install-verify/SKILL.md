---
name: install-verify
description: Verify Helm plugin installation and host exposure
allowed-tools:
  - Read
  - Bash
  - Write
---

# Install Verify

Resolve the marketplace root and plugin root from marketplace metadata. Run the plugin's doctor or structural install checks from the plugin root, not from the target project directory.

Write:

- `operations/install-verification.json`

The artifact must record host, plugin name, plugin source, command, workspace support, config status, discovery root check, reload requirement, and `ok: true` only with direct evidence.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json
```
