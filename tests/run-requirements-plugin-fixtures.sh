#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REQ="$ROOT/plugins/helm-requirements"
PROJECT="$ROOT/tests/fixtures/simple-project"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

run_json() {
  local project="$1"
  local script="$2"
  local output="$3"
  local expected_status="$4"
  local status

  set +e
  PROJECT_DIR="$project" node "$script" --json >"$output"
  status=$?
  set -e
  [[ "$status" == "$expected_status" ]]
}

write_happy_project() {
  local project="$1"
  local change="add-dashboard"

  mkdir -p \
    "$project/openspec/.helm" \
    "$project/openspec/specs/ui-design" \
    "$project/openspec/specs/system-architecture" \
    "$project/openspec/specs/frontend-backend-data-flow" \
    "$project/openspec/specs/component-architecture" \
    "$project/openspec/changes/$change"

  printf '%s\n' "$change" >"$project/openspec/.helm/active-change"

  cat >"$project/openspec/specs/ui-design/design.md" <<'MD'
---
version: 1.0.0
name: UI Design
description: Product interface standards
colors: {}
typography: {}
spacing: {}
rounded: {}
components: []
---
# UI Design

## Overview
## Colors
## Typography
## Layout
## Elevation & Depth
## Motion
## Shapes
## Components
## Voice & Content
## Do's and Don'ts
MD

  cat >"$project/openspec/specs/system-architecture/design.md" <<'MD'
# System Architecture & Database Spec

## Overview
## Application Topology
## Module Boundaries
## Frontend Architecture
## Backend Architecture
## API Surface
## Database Model
## Permissions & Security
## Integration Boundaries
## Operational Constraints
## Architecture Do's and Don'ts
MD

  cat >"$project/openspec/specs/frontend-backend-data-flow/design.md" <<'MD'
# Frontend-Backend Data Flow Spec

## Overview
## Flow Index
## Boundary Contracts
## State Ownership
## Validation Ownership
## Error & Empty States
## Loading / Optimistic / Retry Behavior
## End-to-End Flow Details
## Async / Realtime Flows
## Flow Do's and Don'ts
MD

  cat >"$project/openspec/specs/component-architecture/design.md" <<'MD'
# Component Architecture & Reuse Spec

## Overview
## Component Taxonomy
## Cohesion Rules
## Coupling Rules
## Shared Component Extraction Rules
## Component Public API Rules
## State Ownership Rules
## Composition Patterns
## File & Naming Conventions
## Testing Expectations
## Refactor Triggers
## Component Do's and Don'ts
MD

  cat >"$project/openspec/changes/$change/requirements.md" <<'MD'
# Requirements

- Add a dashboard view backed by the existing application shell.
MD

  cat >"$project/openspec/changes/$change/acceptance.md" <<'MD'
# Acceptance

- Dashboard renders with loading, empty, and error states covered.
MD

  cat >"$project/openspec/changes/$change/spec-map.json" <<'JSON'
{
  "touched_specs": ["ui-design", "system-architecture"],
  "unresolved_gaps": []
}
JSON

  cat >"$project/openspec/changes/$change/component-impact-map.json" <<'JSON'
{
  "new_components": ["DashboardView"],
  "reused_components": [],
  "unresolved_gaps": []
}
JSON
}

test -f "$REQ/scripts/foundation-specs.js"
test -f "$REQ/scripts/requirements-contract.js"
test -f "$REQ/skills/foundation-spec/SKILL.md"
test -f "$REQ/skills/requirements/SKILL.md"

grep -q 'helm-requirements' "$REQ/commands/helm-requirements.md"
grep -Fq 'node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require' "$REQ/commands/helm-requirements.md"
grep -Fq -- '--marketplace-root "$CLAUDE_PLUGIN_ROOT/../.."' "$REQ/commands/helm-requirements.md"

mkdir -p "$TMP_DIR/external-project"
set +e
(
  cd "$TMP_DIR/external-project"
  export CLAUDE_PLUGIN_ROOT="$REQ"
  node "$CLAUDE_PLUGIN_ROOT/../helm-core/scripts/plugin-suite.js" require --marketplace-root "$CLAUDE_PLUGIN_ROOT/../.." --plugin helm-core --plugin helm-requirements --json
) >"$TMP_DIR/external-plugin-suite-require.json"
STATUS=$?
set -e
[[ "$STATUS" == "0" ]]
jq -e '.ok == true' "$TMP_DIR/external-plugin-suite-require.json" >/dev/null
jq -e '.plugins | length == 2' "$TMP_DIR/external-plugin-suite-require.json" >/dev/null
jq -e '.plugins[] | select(.name == "helm-core" and .ok == true)' "$TMP_DIR/external-plugin-suite-require.json" >/dev/null
jq -e '.plugins[] | select(.name == "helm-requirements" and .ok == true)' "$TMP_DIR/external-plugin-suite-require.json" >/dev/null

set +e
PROJECT_DIR="$PROJECT" node "$REQ/scripts/foundation-specs.js" --json >"$TMP_DIR/foundation-specs.json"
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.ok == false' "$TMP_DIR/foundation-specs.json" >/dev/null
jq -e '.blockers[] | select(. == "missing-foundation-spec:ui-design")' "$TMP_DIR/foundation-specs.json" >/dev/null

set +e
PROJECT_DIR="$PROJECT" node "$REQ/scripts/requirements-contract.js" --json >"$TMP_DIR/requirements-contract.json"
STATUS=$?
set -e
[[ "$STATUS" == "2" ]]
jq -e '.ok == false' "$TMP_DIR/requirements-contract.json" >/dev/null

HAPPY_PROJECT="$TMP_DIR/happy-project"
write_happy_project "$HAPPY_PROJECT"

run_json "$HAPPY_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/happy-foundation-specs.json" 0
jq -e '.ok == true' "$TMP_DIR/happy-foundation-specs.json" >/dev/null

run_json "$HAPPY_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/happy-requirements-contract.json" 0
jq -e '.ok == true' "$TMP_DIR/happy-requirements-contract.json" >/dev/null

EMPTY_ARTIFACT_PROJECT="$TMP_DIR/empty-artifact-project"
cp -R "$HAPPY_PROJECT" "$EMPTY_ARTIFACT_PROJECT"
printf ' \n\t\n' >"$EMPTY_ARTIFACT_PROJECT/openspec/changes/add-dashboard/requirements.md"
: >"$EMPTY_ARTIFACT_PROJECT/openspec/changes/add-dashboard/acceptance.md"
run_json "$EMPTY_ARTIFACT_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/empty-artifacts.json" 2
jq -e '.blockers[] | select(. == "empty-requirements-artifact:requirements.md")' "$TMP_DIR/empty-artifacts.json" >/dev/null
jq -e '.blockers[] | select(. == "empty-requirements-artifact:acceptance.md")' "$TMP_DIR/empty-artifacts.json" >/dev/null

for shape in null '[]' 42 '"bad"'; do
  SHAPE_PROJECT="$TMP_DIR/json-shape-${shape//[^A-Za-z0-9]/_}"
  cp -R "$HAPPY_PROJECT" "$SHAPE_PROJECT"
  printf '%s\n' "$shape" >"$SHAPE_PROJECT/openspec/changes/add-dashboard/spec-map.json"
  run_json "$SHAPE_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/json-shape-${shape//[^A-Za-z0-9]/_}.json" 2
  jq -e '.blockers[] | select(. == "invalid-json-shape:spec-map.json")' "$TMP_DIR/json-shape-${shape//[^A-Za-z0-9]/_}.json" >/dev/null
done

UNRESOLVED_GAPS_PROJECT="$TMP_DIR/invalid-unresolved-gaps-project"
cp -R "$HAPPY_PROJECT" "$UNRESOLVED_GAPS_PROJECT"
cat >"$UNRESOLVED_GAPS_PROJECT/openspec/changes/add-dashboard/component-impact-map.json" <<'JSON'
{
  "unresolved_gaps": "needs decision"
}
JSON
run_json "$UNRESOLVED_GAPS_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/invalid-unresolved-gaps.json" 2
jq -e '.blockers[] | select(. == "invalid-unresolved-gaps:component-impact-map.json")' "$TMP_DIR/invalid-unresolved-gaps.json" >/dev/null

BAD_FRONTMATTER_PROJECT="$TMP_DIR/bad-frontmatter-project"
cp -R "$HAPPY_PROJECT" "$BAD_FRONTMATTER_PROJECT"
cat >"$BAD_FRONTMATTER_PROJECT/openspec/specs/ui-design/design.md" <<'MD'
---
version:
name:
description: Product interface standards
colors: [
typography: {}
spacing: {}
rounded: {}
components: [
---
# UI Design

## Overview
## Colors
## Typography
## Layout
## Elevation & Depth
## Motion
## Shapes
## Components
## Voice & Content
## Do's and Don'ts
MD
run_json "$BAD_FRONTMATTER_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/bad-frontmatter.json" 2
jq -e '.blockers[] | select(. == "invalid-foundation-spec-frontmatter:ui-design")' "$TMP_DIR/bad-frontmatter.json" >/dev/null

FENCED_HEADING_PROJECT="$TMP_DIR/fenced-heading-project"
cp -R "$HAPPY_PROJECT" "$FENCED_HEADING_PROJECT"
cat >"$FENCED_HEADING_PROJECT/openspec/specs/system-architecture/design.md" <<'MD'
# System Architecture & Database Spec

## Overview
## Application Topology
## Module Boundaries
## Frontend Architecture
## Backend Architecture

```md
## API Surface
```

## Database Model
## Permissions & Security
## Integration Boundaries
## Operational Constraints
## Architecture Do's and Don'ts
MD
run_json "$FENCED_HEADING_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/fenced-heading.json" 2
jq -e '.blockers[] | select(. == "invalid-foundation-spec-sections:system-architecture")' "$TMP_DIR/fenced-heading.json" >/dev/null
jq -e '.specs[] | select(.id == "system-architecture") | .missing_sections[] | select(. == "## API Surface")' "$TMP_DIR/fenced-heading.json" >/dev/null

echo "helm requirements plugin fixtures ok"
