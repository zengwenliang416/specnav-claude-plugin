---
description: Initialize OpenSpec for the current project and unblock Helm lifecycle work
argument-hint: "[optional project path]"
---

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/helm-bootstrap.js" --json
```

If it exits non-zero, report the emitted blockers and exit status explicitly. Do not run requirements, implementation, verification, or operations commands until bootstrap reports `ok: true`.

After successful bootstrap, tell the user the next legal calls:

- `/helm-status`
- `/helm-requirements`
