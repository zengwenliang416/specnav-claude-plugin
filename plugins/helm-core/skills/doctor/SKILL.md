---
name: doctor
description: "Run Helm core diagnostics"
allowed-tools:
  - Bash
---

# Helm Doctor

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/helm-doctor.js" --json
```

If it exits non-zero or returns `not-implemented:helm-core/helm-doctor`, report the blocker and exit status explicitly. Do not provide fallback diagnostics until the owning implementation task replaces this placeholder.
