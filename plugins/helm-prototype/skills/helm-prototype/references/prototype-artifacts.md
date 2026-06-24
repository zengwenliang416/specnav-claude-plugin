# Prototype Artifact Contract

Read this before writing prototype files.

All prototype files live under:

`openspec/changes/<active-change>/prototype/`

## Core Files

- `question.md`: the exact design or behavior question.
- `prototype-manifest.json`: branch type, entry, dependencies, requirements, and
  promotion policy.
- branch code or harness: the concrete artifact the user can inspect.
- branch maps: screen map, component tree, data-flow map, or API examples.

## UI HTML Rule

UI prototypes must be runnable by opening `artifact/index.html`. They should
include:

- desktop and mobile layout behavior;
- loading, empty, error, disabled, and permission states when relevant;
- stable screen and variant labels;
- no production code edits.

## Review Rule

The prototype is not development approval. Promotion requires verifier evidence,
explicit user approval, and a handoff that names the approved branch, variant,
components, flows, risks, and required tests.
