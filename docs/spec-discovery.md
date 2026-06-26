# Spec Discovery and Negotiation

Spec discovery is SpecNav's step 0 for project-specific rules. It runs before
requirements grilling when foundation specs are missing, incomplete, stale, or
not grounded in current repository evidence.

Discovery is advisory evidence. It never bypasses `foundation-specs.js`.

## Purpose

SpecNav must distinguish:

- **Facts**: directly observed repository evidence.
- **Inferred conventions**: likely rules derived from multiple files.
- **User decisions**: rules explicitly confirmed by the user.
- **Open questions**: decisions SpecNav cannot safely infer.

Only user-confirmed decisions and direct facts should become durable foundation
spec rules.

## Inputs

Repository discovery may read:

- `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, `AGENTS.md`
- `.claude/rules/**`, `docs/**`
- package and framework files such as `package.json`, `tsconfig.json`,
  `vite.config.*`, `next.config.*`
- source directories such as `src/**`, `app/**`, `pages/**`, `components/**`,
  `hooks/**`, `services/**`, `utils/**`
- API, database, schema, migration, route, and test files
- `.github/workflows/**` and other CI/deploy configuration

Discovery must ignore generated and cache directories such as `.git`, `.next`,
`.turbo`, `node_modules`, `dist`, `build`, and `coverage`.

## Outputs

The machine report lives at:

```text
openspec/.specnav/context/repository-discovery.json
```

Required shape:

```json
{
  "schema": "specnav.repositoryDiscovery.v1",
  "project_root": "/abs/project",
  "generated_at": "ISO-8601",
  "discovery_path": "openspec/.specnav/context/repository-discovery.json",
  "ignored_dirs": [".git", ".next", ".turbo", "build", "coverage", "dist", "node_modules"],
  "evidence": [],
  "findings": [],
  "conflicts": [],
  "open_items": []
}
```

Every finding must have evidence references, confidence, a type, and a target
foundation spec section when it proposes a spec update.

`repository-discovery-contract.js` validates this shape. It rejects malformed
JSON, absolute or escaping evidence paths, missing evidence references, unknown
foundation spec IDs, and confidence values outside `0..1`.

## Negotiation Rules

- A single file can establish a fact but usually cannot establish a convention.
- A convention with medium or low confidence must become an open question.
- Conflicting evidence must become a conflict plus a user question.
- Discovery may propose wording for foundation specs, but the user or a direct
  repository fact must own the decision.
- Discovery output is stale when repository evidence changes materially; rerun
  discovery before using an old report for foundation-spec repair.

## Foundation Specs

Discovery feeds these specs:

- `ui-design`
- `system-architecture`
- `frontend-backend-data-flow`
- `component-architecture`

The final gate remains:

```bash
node "$SPECNAV_REQUIREMENTS_ROOT/scripts/foundation-specs.js" --json
```

If that command reports blockers, requirements grilling remains blocked.
