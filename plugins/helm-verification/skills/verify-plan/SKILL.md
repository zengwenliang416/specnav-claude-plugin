---
name: verify-plan
description: Create the Helm six-domain verification plan
allowed-tools:
  - Read
  - Write
  - Bash
---

# Verify Plan

Run the development handoff gate first:

```bash
node "$CLAUDE_PLUGIN_ROOT/../helm-development/scripts/development-contract.js" --mode handoff --json
```

If development is blocked, stop and route to the exact owning development artifact. Do not create placeholder verification evidence.

Write the verification plan and shared evidence contracts under `openspec/changes/<active-change>/verify/`:

- `plan.md`
- `plan.json`
- `evidence-index.jsonl`
- `traceability-matrix.json`
- `blocker-classification.jsonl`
- `receipt.md`
- `receipt.json`
- `root-cause-checks.jsonl`
- `behavior-evals/scenarios.json`
- `behavior-evals/report.md`
- `behavior-evals/report.json`

`plan.json` must require all six domains: `facticity`, `static`, `unit`, `redteam`, `e2e`, and `sensory`. Risk tier changes depth and commands, not domain coverage.

Run:

```bash
node "$CLAUDE_PLUGIN_ROOT/scripts/verify-domains.js" validate --json
```
