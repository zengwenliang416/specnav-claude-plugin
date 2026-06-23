---
name: prototype-verify
description: Verify Helm prototype code and write the verifier report
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# Prototype Verify

Run the contract before verification:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json
```

If the contract is blocked by requirements, missing branch code, invalid manifest fields, or an unsafe entry path, stop and report the exact blockers. Do not use fallback artifacts, generic demos, or a different change.

Verify the runnable prototype entry declared in `prototype/prototype-manifest.json`:

- `ui-html`: open `artifact/index.html`, check desktop and mobile layouts, variants, tweaks, and important loading, empty, error, disabled, and permission states where relevant.
- `logic-state`: run the `logic/` entry and confirm every action exposes observable state.
- `api-contract`: validate schemas and concrete request, response, and error examples in `api/`.
- `data-flow`: verify the flow harness or narrated transitions in `data-flow-map.md`.
- `component-seam`: verify the proposed public API, reuse path, extraction impact, and test expectations in `component/`.

Write `prototype/verifier-report.json` with this schema:

```text
{
  "schema": "helm.prototype.verifier.v1",
  "status": "green",
  "checked_entry": "<manifest entry>",
  "checks": []
}
```

Use `status: "green"` only when the required code exists and runs for the selected branch. Use `status: "red"` or `status: "blocked"` when verification fails or required context is missing; those statuses intentionally block approval.

After writing `verifier-report.json`, run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/prototype-contract.js" --json
```

If the contract is still blocked, report the blockers and stop. Do not proceed to handoff until verification blockers are resolved or recorded as blocked.
