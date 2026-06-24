---
name: helm-deploy
description: Use this skill when Helm release target is project-deploy and deployment mechanics, environment, commands, config, secrets, migrations, smoke checks, owner, or deploy window must be documented.
---

# Helm Deploy

## Purpose

Prepare deployment mechanics for project-deploy targets.

## Workflow

1. Use only when release target is `project-deploy`.
2. Read `references/deploy-plan.md` before writing deployment mechanics.
3. Document exact deployment mechanics before deployment.
4. Use `assets/deploy-plan.md` as the shell when the artifact is missing.
5. Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` after writing.

## Required Outputs

- `operations/deploy-plan.md`.
- Deploy shell: `assets/deploy-plan.md`.

## Stop Conditions

- Release target is not project-deploy.
- Secrets or config are unknown.
- Migration effects are unclear.
- Smoke checks cannot be named.

## Validation

- Run `node "$CLAUDE_PLUGIN_ROOT/scripts/operations-gate.js" --json` and require ok or exact blockers.
