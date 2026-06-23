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

assert_active_change_only_blocker() {
  local output="$1"

  jq -e '.active_change == null' "$output" >/dev/null
  jq -e '.blockers | sort == ["active-change"]' "$output" >/dev/null
  jq -e '.blockers | map(select(startswith("missing-requirements-artifact:"))) | length == 0' "$output" >/dev/null
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

BLOCK_FRONTMATTER_PROJECT="$TMP_DIR/block-frontmatter-project"
cp -R "$HAPPY_PROJECT" "$BLOCK_FRONTMATTER_PROJECT"
cat >"$BLOCK_FRONTMATTER_PROJECT/openspec/specs/ui-design/design.md" <<'MD'
---
version: "1.0.0"
name: "UI: Design"
description: Geist's token contract # inline comments outside quotes are ignored
colors:
  # semantic tokens
  primary: #fff
  secondary: "#111"
  canvas:
    default: "{colors.primary}"
typography:
  heading-72:
    fontSize: 72px
    lineHeight: "80px"
  button-14:
    fontSize: 14px
spacing:
  sm: 8px
rounded:
  sm: 4px
components:
  - name: Button
    backgroundColor: "{colors.primary}"
    textStyle: "{typography.button-14}"
    radius: "{rounded.sm}"
    note: "token reference: {colors.canvas.default}"
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
run_json "$BLOCK_FRONTMATTER_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/block-frontmatter.json" 0
jq -e '.ok == true' "$TMP_DIR/block-frontmatter.json" >/dev/null

HEX_LITERAL_FRONTMATTER_PROJECT="$TMP_DIR/hex-literal-frontmatter-project"
cp -R "$HAPPY_PROJECT" "$HEX_LITERAL_FRONTMATTER_PROJECT"
cat >"$HEX_LITERAL_FRONTMATTER_PROJECT/openspec/specs/ui-design/design.md" <<'MD'
---
version: 1.0.0
name: UI Design
description: Test # inline comment
colors:
  primary: #fff
  secondary: #ffffff
  overlay: #ffffff12
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
run_json "$HEX_LITERAL_FRONTMATTER_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/hex-literal-frontmatter.json" 0
jq -e '.ok == true' "$TMP_DIR/hex-literal-frontmatter.json" >/dev/null

THEME_MISMATCH_PROJECT="$TMP_DIR/theme-mismatch-project"
cp -R "$BLOCK_FRONTMATTER_PROJECT" "$THEME_MISMATCH_PROJECT"
cat >"$THEME_MISMATCH_PROJECT/openspec/specs/ui-design/design.dark.md" <<'MD'
---
version: "1.0.0"
name: "UI Dark Design"
description: "Dark mode token contract"
colors:
  primary: "#000"
  canvas:
    default: "{colors.primary}"
typography:
  heading-72:
    fontSize: 72px
    lineHeight: "80px"
  button-14:
    fontSize: 14px
spacing:
  sm: 8px
rounded:
  sm: 4px
components:
  - name: Button
    backgroundColor: "{colors.primary}"
    textStyle: "{typography.button-14}"
    radius: "{rounded.sm}"
    note: "token reference: {colors.canvas.default}"
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
run_json "$THEME_MISMATCH_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/theme-mismatch.json" 2
jq -e '.blockers[] | select(. == "invalid-foundation-spec-theme-parity:ui-design")' "$TMP_DIR/theme-mismatch.json" >/dev/null

INVALID_TOKEN_REF_PROJECT="$TMP_DIR/invalid-token-ref-project"
cp -R "$BLOCK_FRONTMATTER_PROJECT" "$INVALID_TOKEN_REF_PROJECT"
perl -0pi -e 's/backgroundColor: "\{colors\.primary\}"/backgroundColor: "{colors.missing}"/' "$INVALID_TOKEN_REF_PROJECT/openspec/specs/ui-design/design.md"
run_json "$INVALID_TOKEN_REF_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/invalid-token-ref.json" 2
jq -e '.blockers[] | select(. == "invalid-foundation-spec-token-reference:ui-design")' "$TMP_DIR/invalid-token-ref.json" >/dev/null

UNREADABLE_FOUNDATION_SPEC_PROJECT="$TMP_DIR/unreadable-foundation-spec-project"
cp -R "$HAPPY_PROJECT" "$UNREADABLE_FOUNDATION_SPEC_PROJECT"
rm "$UNREADABLE_FOUNDATION_SPEC_PROJECT/openspec/specs/ui-design/design.md"
mkdir "$UNREADABLE_FOUNDATION_SPEC_PROJECT/openspec/specs/ui-design/design.md"
run_json "$UNREADABLE_FOUNDATION_SPEC_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/unreadable-foundation-spec.json" 2
jq -e '.blockers[] | select(. == "unreadable-foundation-spec:ui-design")' "$TMP_DIR/unreadable-foundation-spec.json" >/dev/null
jq -e '.blockers | index("invalid-foundation-spec-frontmatter:ui-design") == null' "$TMP_DIR/unreadable-foundation-spec.json" >/dev/null
jq -e '.blockers | index("invalid-foundation-spec-sections:ui-design") == null' "$TMP_DIR/unreadable-foundation-spec.json" >/dev/null

run_json "$HAPPY_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/happy-requirements-contract.json" 0
jq -e '.ok == true' "$TMP_DIR/happy-requirements-contract.json" >/dev/null

MISSING_ACTIVE_CHANGE_PROJECT="$TMP_DIR/missing-active-change-project"
cp -R "$HAPPY_PROJECT" "$MISSING_ACTIVE_CHANGE_PROJECT"
rm "$MISSING_ACTIVE_CHANGE_PROJECT/openspec/.helm/active-change"
run_json "$MISSING_ACTIVE_CHANGE_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/missing-active-change.json" 2
assert_active_change_only_blocker "$TMP_DIR/missing-active-change.json"

EMPTY_ACTIVE_CHANGE_PROJECT="$TMP_DIR/empty-active-change-project"
cp -R "$HAPPY_PROJECT" "$EMPTY_ACTIVE_CHANGE_PROJECT"
: >"$EMPTY_ACTIVE_CHANGE_PROJECT/openspec/.helm/active-change"
run_json "$EMPTY_ACTIVE_CHANGE_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/empty-active-change.json" 2
assert_active_change_only_blocker "$TMP_DIR/empty-active-change.json"

INVALID_ACTIVE_CHANGE_PROJECT="$TMP_DIR/invalid-active-change-project"
cp -R "$HAPPY_PROJECT" "$INVALID_ACTIVE_CHANGE_PROJECT"
printf '%s\n' '../add-dashboard' >"$INVALID_ACTIVE_CHANGE_PROJECT/openspec/.helm/active-change"
run_json "$INVALID_ACTIVE_CHANGE_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/invalid-active-change.json" 2
assert_active_change_only_blocker "$TMP_DIR/invalid-active-change.json"

MISSING_CHANGE_DIR_PROJECT="$TMP_DIR/missing-change-dir-project"
cp -R "$HAPPY_PROJECT" "$MISSING_CHANGE_DIR_PROJECT"
rm -rf "$MISSING_CHANGE_DIR_PROJECT/openspec/changes/add-dashboard"
run_json "$MISSING_CHANGE_DIR_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/missing-change-dir.json" 2
assert_active_change_only_blocker "$TMP_DIR/missing-change-dir.json"

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

EMPTY_SPEC_MAP_PROJECT="$TMP_DIR/empty-spec-map-project"
cp -R "$HAPPY_PROJECT" "$EMPTY_SPEC_MAP_PROJECT"
cat >"$EMPTY_SPEC_MAP_PROJECT/openspec/changes/add-dashboard/spec-map.json" <<'JSON'
{}
JSON
run_json "$EMPTY_SPEC_MAP_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/empty-spec-map.json" 2
jq -e '.blockers[] | select(. == "invalid-spec-map-contract:spec-map.json")' "$TMP_DIR/empty-spec-map.json" >/dev/null

INVALID_SPEC_MAP_FIELD_PROJECT="$TMP_DIR/invalid-spec-map-field-project"
cp -R "$HAPPY_PROJECT" "$INVALID_SPEC_MAP_FIELD_PROJECT"
cat >"$INVALID_SPEC_MAP_FIELD_PROJECT/openspec/changes/add-dashboard/spec-map.json" <<'JSON'
{
  "touched_specs": "ui-design",
  "unresolved_gaps": []
}
JSON
run_json "$INVALID_SPEC_MAP_FIELD_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/invalid-spec-map-field.json" 2
jq -e '.blockers[] | select(. == "invalid-spec-map-contract:spec-map.json")' "$TMP_DIR/invalid-spec-map-field.json" >/dev/null

EMPTY_SPEC_MAP_FIELDS_PROJECT="$TMP_DIR/empty-spec-map-fields-project"
cp -R "$HAPPY_PROJECT" "$EMPTY_SPEC_MAP_FIELDS_PROJECT"
cat >"$EMPTY_SPEC_MAP_FIELDS_PROJECT/openspec/changes/add-dashboard/spec-map.json" <<'JSON'
{
  "touched_specs": [],
  "ui_rules": [],
  "architecture_modules": [],
  "api_contracts": [],
  "database_entities": [],
  "permissions": [],
  "operational_constraints": [],
  "data_flows": [],
  "unresolved_gaps": []
}
JSON
run_json "$EMPTY_SPEC_MAP_FIELDS_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/empty-spec-map-fields.json" 2
jq -e '.blockers[] | select(. == "invalid-spec-map-contract:spec-map.json")' "$TMP_DIR/empty-spec-map-fields.json" >/dev/null

EMPTY_COMPONENT_IMPACT_MAP_PROJECT="$TMP_DIR/empty-component-impact-map-project"
cp -R "$HAPPY_PROJECT" "$EMPTY_COMPONENT_IMPACT_MAP_PROJECT"
cat >"$EMPTY_COMPONENT_IMPACT_MAP_PROJECT/openspec/changes/add-dashboard/component-impact-map.json" <<'JSON'
{}
JSON
run_json "$EMPTY_COMPONENT_IMPACT_MAP_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/empty-component-impact-map.json" 2
jq -e '.blockers[] | select(. == "invalid-component-impact-map-contract:component-impact-map.json")' "$TMP_DIR/empty-component-impact-map.json" >/dev/null

INVALID_COMPONENT_IMPACT_FIELD_PROJECT="$TMP_DIR/invalid-component-impact-field-project"
cp -R "$HAPPY_PROJECT" "$INVALID_COMPONENT_IMPACT_FIELD_PROJECT"
cat >"$INVALID_COMPONENT_IMPACT_FIELD_PROJECT/openspec/changes/add-dashboard/component-impact-map.json" <<'JSON'
{
  "new_components": "DashboardView",
  "unresolved_gaps": []
}
JSON
run_json "$INVALID_COMPONENT_IMPACT_FIELD_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/invalid-component-impact-field.json" 2
jq -e '.blockers[] | select(. == "invalid-component-impact-map-contract:component-impact-map.json")' "$TMP_DIR/invalid-component-impact-field.json" >/dev/null

EMPTY_COMPONENT_IMPACT_FIELDS_PROJECT="$TMP_DIR/empty-component-impact-fields-project"
cp -R "$HAPPY_PROJECT" "$EMPTY_COMPONENT_IMPACT_FIELDS_PROJECT"
cat >"$EMPTY_COMPONENT_IMPACT_FIELDS_PROJECT/openspec/changes/add-dashboard/component-impact-map.json" <<'JSON'
{
  "new_components": [],
  "reused_components": [],
  "extraction_triggers": [],
  "forbidden_dependencies": [],
  "hooks": [],
  "utilities": [],
  "services": [],
  "required_component_tests": [],
  "unresolved_gaps": []
}
JSON
run_json "$EMPTY_COMPONENT_IMPACT_FIELDS_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/empty-component-impact-fields.json" 2
jq -e '.blockers[] | select(. == "invalid-component-impact-map-contract:component-impact-map.json")' "$TMP_DIR/empty-component-impact-fields.json" >/dev/null

UNRESOLVED_GAPS_PROJECT="$TMP_DIR/invalid-unresolved-gaps-project"
cp -R "$HAPPY_PROJECT" "$UNRESOLVED_GAPS_PROJECT"
cat >"$UNRESOLVED_GAPS_PROJECT/openspec/changes/add-dashboard/component-impact-map.json" <<'JSON'
{
  "unresolved_gaps": "needs decision"
}
JSON
run_json "$UNRESOLVED_GAPS_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/invalid-unresolved-gaps.json" 2
jq -e '.blockers[] | select(. == "invalid-unresolved-gaps:component-impact-map.json")' "$TMP_DIR/invalid-unresolved-gaps.json" >/dev/null

NONEMPTY_UNRESOLVED_GAPS_PROJECT="$TMP_DIR/nonempty-unresolved-gaps-project"
cp -R "$HAPPY_PROJECT" "$NONEMPTY_UNRESOLVED_GAPS_PROJECT"
cat >"$NONEMPTY_UNRESOLVED_GAPS_PROJECT/openspec/changes/add-dashboard/spec-map.json" <<'JSON'
{
  "unresolved_gaps": ["needs decision"]
}
JSON
run_json "$NONEMPTY_UNRESOLVED_GAPS_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/nonempty-unresolved-gaps.json" 2
jq -e '.blockers[] | select(. == "unresolved-gaps:spec-map.json")' "$TMP_DIR/nonempty-unresolved-gaps.json" >/dev/null

MALFORMED_JSON_PROJECT="$TMP_DIR/malformed-json-project"
cp -R "$HAPPY_PROJECT" "$MALFORMED_JSON_PROJECT"
printf '{\n' >"$MALFORMED_JSON_PROJECT/openspec/changes/add-dashboard/spec-map.json"
run_json "$MALFORMED_JSON_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/malformed-json.json" 2
jq -e '.blockers[] | select(. == "invalid-json:spec-map.json")' "$TMP_DIR/malformed-json.json" >/dev/null

UNREADABLE_JSON_PROJECT="$TMP_DIR/unreadable-json-project"
cp -R "$HAPPY_PROJECT" "$UNREADABLE_JSON_PROJECT"
rm "$UNREADABLE_JSON_PROJECT/openspec/changes/add-dashboard/component-impact-map.json"
mkdir "$UNREADABLE_JSON_PROJECT/openspec/changes/add-dashboard/component-impact-map.json"
run_json "$UNREADABLE_JSON_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/unreadable-json.json" 2
jq -e '.blockers[] | select(. == "unreadable-requirements-artifact:component-impact-map.json")' "$TMP_DIR/unreadable-json.json" >/dev/null

UNREADABLE_MARKDOWN_PROJECT="$TMP_DIR/unreadable-markdown-project"
cp -R "$HAPPY_PROJECT" "$UNREADABLE_MARKDOWN_PROJECT"
rm "$UNREADABLE_MARKDOWN_PROJECT/openspec/changes/add-dashboard/requirements.md"
mkdir "$UNREADABLE_MARKDOWN_PROJECT/openspec/changes/add-dashboard/requirements.md"
run_json "$UNREADABLE_MARKDOWN_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/unreadable-markdown.json" 2
jq -e '.blockers[] | select(. == "unreadable-requirements-artifact:requirements.md")' "$TMP_DIR/unreadable-markdown.json" >/dev/null

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

NULLISH_FRONTMATTER_PROJECT="$TMP_DIR/nullish-frontmatter-project"
cp -R "$HAPPY_PROJECT" "$NULLISH_FRONTMATTER_PROJECT"
cat >"$NULLISH_FRONTMATTER_PROJECT/openspec/specs/ui-design/design.md" <<'MD'
---
version: ""
name: ''
description: Product interface standards
colors: null
typography: ~
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
run_json "$NULLISH_FRONTMATTER_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/nullish-frontmatter.json" 2
jq -e '.blockers[] | select(. == "invalid-foundation-spec-frontmatter:ui-design")' "$TMP_DIR/nullish-frontmatter.json" >/dev/null

NESTED_NULL_FRONTMATTER_PROJECT="$TMP_DIR/nested-null-frontmatter-project"
cp -R "$HAPPY_PROJECT" "$NESTED_NULL_FRONTMATTER_PROJECT"
cat >"$NESTED_NULL_FRONTMATTER_PROJECT/openspec/specs/ui-design/design.md" <<'MD'
---
version: 1.0.0
name: UI Design
description: Product interface standards
colors:
  primary:
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
run_json "$NESTED_NULL_FRONTMATTER_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/nested-null-frontmatter.json" 2
jq -e '.blockers[] | select(. == "invalid-foundation-spec-frontmatter:ui-design")' "$TMP_DIR/nested-null-frontmatter.json" >/dev/null
jq -e '.specs[] | select(.id == "ui-design") | .invalid_frontmatter_values[] | select(. == "colors.primary")' "$TMP_DIR/nested-null-frontmatter.json" >/dev/null

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
