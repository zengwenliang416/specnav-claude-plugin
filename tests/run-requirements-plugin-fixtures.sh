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
  jq -e '.artifacts | length == 0' "$output" >/dev/null
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

  cat >"$project/openspec/specs/ui-design/marketing.light.md" <<'MD'
---
version: 1.0.0
name: Marketing Light Design
description: Marketing-facing light theme notes
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

  cat >"$project/openspec/specs/ui-design/admin.dark.md" <<'MD'
---
version: 1.0.0
name: Admin Dark Design
description: Admin-facing dark theme notes
colors:
  primary: "#111111"
typography: {}
spacing: {}
rounded: {}
components:
  - name: AdminShell
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
  "ui_rules": ["dashboard-layout"],
  "architecture_modules": ["dashboard-shell"],
  "api_contracts": [],
  "database_entities": [],
  "permissions": [],
  "operational_constraints": [],
  "data_flows": [],
  "unresolved_gaps": []
}
JSON

  cat >"$project/openspec/changes/$change/component-impact-map.json" <<'JSON'
{
  "new_components": ["DashboardView"],
  "reused_components": [],
  "extraction_triggers": [],
  "forbidden_dependencies": [],
  "hooks": [],
  "utilities": [],
  "services": [],
  "required_component_tests": ["DashboardView renders loading empty error states"],
  "unresolved_gaps": []
}
JSON
}

test -f "$REQ/scripts/foundation-specs.js"
test -f "$REQ/scripts/requirements-contract.js"
test -f "$REQ/skills/foundation-spec/SKILL.md"
test -f "$REQ/skills/requirements/SKILL.md"

grep -Fiq 'token references' "$REQ/skills/foundation-spec/SKILL.md"
grep -Fiq 'theme parity' "$REQ/skills/foundation-spec/SKILL.md"
grep -Fiq 'frontmatter values' "$REQ/skills/foundation-spec/SKILL.md"
grep -Fq 'recommended answer' "$REQ/skills/requirements/SKILL.md"
grep -Fq 'tradeoff' "$REQ/skills/requirements/SKILL.md"
grep -Fq 'decision branch' "$REQ/skills/requirements/SKILL.md"
grep -Fq 'unresolved_gaps' "$REQ/skills/requirements/SKILL.md"
grep -Fq 'foundation spec' "$REQ/skills/requirements/SKILL.md"

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
jq -e '.blockers | index("invalid-foundation-spec-theme-parity:ui-design") == null' "$TMP_DIR/happy-foundation-specs.json" >/dev/null

PLAIN_SCALAR_SUFFIX_FRONTMATTER_PROJECT="$TMP_DIR/plain-scalar-suffix-frontmatter-project"
cp -R "$HAPPY_PROJECT" "$PLAIN_SCALAR_SUFFIX_FRONTMATTER_PROJECT"
cat >"$PLAIN_SCALAR_SUFFIX_FRONTMATTER_PROJECT/openspec/specs/ui-design/design.md" <<'MD'
---
version: 1.0.0
name: UI Design {stable}
description: Product interface standards [stable]
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
run_json "$PLAIN_SCALAR_SUFFIX_FRONTMATTER_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/plain-scalar-suffix-frontmatter.json" 0
jq -e '.ok == true' "$TMP_DIR/plain-scalar-suffix-frontmatter.json" >/dev/null
jq -e '.blockers | index("invalid-foundation-spec-frontmatter:ui-design") == null' "$TMP_DIR/plain-scalar-suffix-frontmatter.json" >/dev/null

MULTI_COMPANION_PROJECT="$TMP_DIR/multi-companion-project"
cp -R "$HAPPY_PROJECT" "$MULTI_COMPANION_PROJECT"
cat >"$MULTI_COMPANION_PROJECT/openspec/specs/ui-design/marketing.light.md" <<'MD'
---
version: 1.0.0
name: Marketing Light Design
description: Marketing light theme
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
cat >"$MULTI_COMPANION_PROJECT/openspec/specs/ui-design/marketing.dark.md" <<'MD'
---
version: 1.0.0
name: Marketing Dark Design
description: Marketing dark theme
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
cat >"$MULTI_COMPANION_PROJECT/openspec/specs/ui-design/light.marketing.md" <<'MD'
---
version: 1.0.0
name: Light Marketing Design
description: Light marketing theme
colors:
  primary: "#ffffff"
typography: {}
spacing: {}
rounded: {}
components:
  - name: MarketingCard
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
cat >"$MULTI_COMPANION_PROJECT/openspec/specs/ui-design/dark.marketing.md" <<'MD'
---
version: 1.0.0
name: Dark Marketing Design
description: Dark marketing theme
colors:
  primary: "#000000"
typography: {}
spacing: {}
rounded: {}
components:
  - name: MarketingCard
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
run_json "$MULTI_COMPANION_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/multi-companion.json" 0
jq -e '.ok == true' "$TMP_DIR/multi-companion.json" >/dev/null
jq -e '.blockers | index("invalid-foundation-spec-theme-parity:ui-design") == null' "$TMP_DIR/multi-companion.json" >/dev/null

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
jq -e '.blockers | index("invalid-foundation-spec-theme-parity:ui-design") == null' "$TMP_DIR/block-frontmatter.json" >/dev/null

SINGLE_QUOTE_ESCAPE_FRONTMATTER_PROJECT="$TMP_DIR/single-quote-escape-frontmatter-project"
cp -R "$HAPPY_PROJECT" "$SINGLE_QUOTE_ESCAPE_FRONTMATTER_PROJECT"
cat >"$SINGLE_QUOTE_ESCAPE_FRONTMATTER_PROJECT/openspec/specs/ui-design/design.md" <<'MD'
---
version: 1.0.0
name: 'Bob''s UI Design'
description: 'Bob''s #1 design system'
colors: {primary: 'Bob''s #1, primary tone', accent: '#111111'}
typography: {body: 'Bob''s #1, readable type'}
spacing: {sm: 8px}
rounded: {sm: 4px}
components: ['Bob''s #1, component note', {name: Button, note: 'Bob''s #1, inline component'}]
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
run_json "$SINGLE_QUOTE_ESCAPE_FRONTMATTER_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/single-quote-escape-frontmatter.json" 0
jq -e '.ok == true' "$TMP_DIR/single-quote-escape-frontmatter.json" >/dev/null
jq -e '.blockers | index("invalid-foundation-spec-frontmatter:ui-design") == null' "$TMP_DIR/single-quote-escape-frontmatter.json" >/dev/null
jq -e '.blockers | index("invalid-foundation-spec-theme-parity:ui-design") == null' "$TMP_DIR/single-quote-escape-frontmatter.json" >/dev/null

UNESCAPED_SINGLE_QUOTE_FRONTMATTER_PROJECT="$TMP_DIR/unescaped-single-quote-frontmatter-project"
cp -R "$HAPPY_PROJECT" "$UNESCAPED_SINGLE_QUOTE_FRONTMATTER_PROJECT"
cat >"$UNESCAPED_SINGLE_QUOTE_FRONTMATTER_PROJECT/openspec/specs/ui-design/design.md" <<'MD'
---
version: 1.0.0
name: 'Bob's UI Design'
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
run_json "$UNESCAPED_SINGLE_QUOTE_FRONTMATTER_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/unescaped-single-quote-frontmatter.json" 2
jq -e '.blockers[] | select(. == "invalid-foundation-spec-frontmatter:ui-design")' "$TMP_DIR/unescaped-single-quote-frontmatter.json" >/dev/null

INLINE_UNESCAPED_SINGLE_QUOTE_FRONTMATTER_PROJECT="$TMP_DIR/inline-unescaped-single-quote-frontmatter-project"
cp -R "$HAPPY_PROJECT" "$INLINE_UNESCAPED_SINGLE_QUOTE_FRONTMATTER_PROJECT"
cat >"$INLINE_UNESCAPED_SINGLE_QUOTE_FRONTMATTER_PROJECT/openspec/specs/ui-design/design.md" <<'MD'
---
version: 1.0.0
name: UI Design
description: Product interface standards
colors: {}
typography: {}
spacing: {}
rounded: {}
components: [{name: Button, note: 'Bob's inline component'}]
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
run_json "$INLINE_UNESCAPED_SINGLE_QUOTE_FRONTMATTER_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/inline-unescaped-single-quote-frontmatter.json" 2
jq -e '.blockers[] | select(. == "invalid-foundation-spec-frontmatter:ui-design")' "$TMP_DIR/inline-unescaped-single-quote-frontmatter.json" >/dev/null

UNCLOSED_INLINE_FRONTMATTER_PROJECT="$TMP_DIR/unclosed-inline-frontmatter-project"
cp -R "$HAPPY_PROJECT" "$UNCLOSED_INLINE_FRONTMATTER_PROJECT"
cat >"$UNCLOSED_INLINE_FRONTMATTER_PROJECT/openspec/specs/ui-design/design.md" <<'MD'
---
version: 1.0.0
name: UI Design
description: Product interface standards
colors: [brand
typography: {body: system
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
run_json "$UNCLOSED_INLINE_FRONTMATTER_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/unclosed-inline-frontmatter.json" 2
jq -e '.blockers[] | select(. == "invalid-foundation-spec-frontmatter:ui-design")' "$TMP_DIR/unclosed-inline-frontmatter.json" >/dev/null

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
  accent: #abcd
  alpha: #000f
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

INLINE_HEX_ARRAY_FRONTMATTER_PROJECT="$TMP_DIR/inline-hex-array-frontmatter-project"
cp -R "$HAPPY_PROJECT" "$INLINE_HEX_ARRAY_FRONTMATTER_PROJECT"
cat >"$INLINE_HEX_ARRAY_FRONTMATTER_PROJECT/openspec/specs/ui-design/design.md" <<'MD'
---
version: 1.0.0
name: UI Design
description: Test # inline comment
colors: [#fff, #abcd, #000f, #ffffffff] # palette comment
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
run_json "$INLINE_HEX_ARRAY_FRONTMATTER_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/inline-hex-array-frontmatter.json" 0
jq -e '.ok == true' "$TMP_DIR/inline-hex-array-frontmatter.json" >/dev/null

INLINE_HEX_OBJECT_FRONTMATTER_PROJECT="$TMP_DIR/inline-hex-object-frontmatter-project"
cp -R "$HAPPY_PROJECT" "$INLINE_HEX_OBJECT_FRONTMATTER_PROJECT"
cat >"$INLINE_HEX_OBJECT_FRONTMATTER_PROJECT/openspec/specs/ui-design/design.md" <<'MD'
---
version: 1.0.0
name: UI Design
description: Test # inline comment
colors: {primary: #fff, accent: #abcd, alpha: #000f, overlay: #ffffffff} # palette comment
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
run_json "$INLINE_HEX_OBJECT_FRONTMATTER_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/inline-hex-object-frontmatter.json" 0
jq -e '.ok == true' "$TMP_DIR/inline-hex-object-frontmatter.json" >/dev/null

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

COMPANION_BAD_FRONTMATTER_PROJECT="$TMP_DIR/companion-bad-frontmatter-project"
cp -R "$HAPPY_PROJECT" "$COMPANION_BAD_FRONTMATTER_PROJECT"
cat >"$COMPANION_BAD_FRONTMATTER_PROJECT/openspec/specs/ui-design/design.dark.md" <<'MD'
---
version: 1.0.0
name: UI Dark Design
description: Dark mode token contract
colors: [
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
run_json "$COMPANION_BAD_FRONTMATTER_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/companion-bad-frontmatter.json" 2
jq -e '.blockers[] | select(. == "invalid-foundation-spec-frontmatter:ui-design")' "$TMP_DIR/companion-bad-frontmatter.json" >/dev/null
jq -e '.specs[] | select(.id == "ui-design") | .missing_frontmatter_keys | map(select(startswith("design.dark.md:"))) | length == 0' "$TMP_DIR/companion-bad-frontmatter.json" >/dev/null
jq -e '.specs[] | select(.id == "ui-design") | .frontmatter_errors[] | select(. == "design.dark.md:unparseable-frontmatter")' "$TMP_DIR/companion-bad-frontmatter.json" >/dev/null

NAMED_THEME_MISMATCH_PROJECT="$TMP_DIR/named-theme-mismatch-project"
cp -R "$BLOCK_FRONTMATTER_PROJECT" "$NAMED_THEME_MISMATCH_PROJECT"
cp "$NAMED_THEME_MISMATCH_PROJECT/openspec/specs/ui-design/design.md" "$NAMED_THEME_MISMATCH_PROJECT/openspec/specs/ui-design/Light-Theme.md"
cat >"$NAMED_THEME_MISMATCH_PROJECT/openspec/specs/ui-design/dark-theme.md" <<'MD'
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
run_json "$NAMED_THEME_MISMATCH_PROJECT" "$REQ/scripts/foundation-specs.js" "$TMP_DIR/named-theme-mismatch.json" 2
jq -e '.blockers[] | select(. == "invalid-foundation-spec-theme-parity:ui-design")' "$TMP_DIR/named-theme-mismatch.json" >/dev/null

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

PADDED_ACTIVE_CHANGE_PROJECT="$TMP_DIR/padded-active-change-project"
cp -R "$HAPPY_PROJECT" "$PADDED_ACTIVE_CHANGE_PROJECT"
printf '%s' ' add-dashboard ' >"$PADDED_ACTIVE_CHANGE_PROJECT/openspec/.helm/active-change"
run_json "$PADDED_ACTIVE_CHANGE_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/padded-active-change.json" 2
assert_active_change_only_blocker "$TMP_DIR/padded-active-change.json"

DOT_ACTIVE_CHANGE_PROJECT="$TMP_DIR/dot-active-change-project"
cp -R "$HAPPY_PROJECT" "$DOT_ACTIVE_CHANGE_PROJECT"
cp "$DOT_ACTIVE_CHANGE_PROJECT/openspec/changes/add-dashboard/requirements.md" "$DOT_ACTIVE_CHANGE_PROJECT/openspec/changes/requirements.md"
cp "$DOT_ACTIVE_CHANGE_PROJECT/openspec/changes/add-dashboard/acceptance.md" "$DOT_ACTIVE_CHANGE_PROJECT/openspec/changes/acceptance.md"
cp "$DOT_ACTIVE_CHANGE_PROJECT/openspec/changes/add-dashboard/spec-map.json" "$DOT_ACTIVE_CHANGE_PROJECT/openspec/changes/spec-map.json"
cp "$DOT_ACTIVE_CHANGE_PROJECT/openspec/changes/add-dashboard/component-impact-map.json" "$DOT_ACTIVE_CHANGE_PROJECT/openspec/changes/component-impact-map.json"
printf '%s\n' '.' >"$DOT_ACTIVE_CHANGE_PROJECT/openspec/.helm/active-change"
run_json "$DOT_ACTIVE_CHANGE_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/dot-active-change.json" 2
assert_active_change_only_blocker "$TMP_DIR/dot-active-change.json"

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

MISSING_TOUCHED_SPECS_PROJECT="$TMP_DIR/missing-touched-specs-project"
cp -R "$HAPPY_PROJECT" "$MISSING_TOUCHED_SPECS_PROJECT"
cat >"$MISSING_TOUCHED_SPECS_PROJECT/openspec/changes/add-dashboard/spec-map.json" <<'JSON'
{
  "ui_rules": ["layout:grid"],
  "unresolved_gaps": []
}
JSON
run_json "$MISSING_TOUCHED_SPECS_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/missing-touched-specs.json" 2
jq -e '.blockers[] | select(. == "invalid-spec-map-contract:spec-map.json")' "$TMP_DIR/missing-touched-specs.json" >/dev/null

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

EMPTY_SPEC_MAP_MEMBER_PROJECT="$TMP_DIR/empty-spec-map-member-project"
cp -R "$HAPPY_PROJECT" "$EMPTY_SPEC_MAP_MEMBER_PROJECT"
cat >"$EMPTY_SPEC_MAP_MEMBER_PROJECT/openspec/changes/add-dashboard/spec-map.json" <<'JSON'
{
  "touched_specs": [""],
  "ui_rules": ["dashboard-layout"],
  "architecture_modules": ["dashboard-shell"],
  "api_contracts": [],
  "database_entities": [],
  "permissions": [],
  "operational_constraints": [],
  "data_flows": [],
  "unresolved_gaps": []
}
JSON
run_json "$EMPTY_SPEC_MAP_MEMBER_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/empty-spec-map-member.json" 2
jq -e '.blockers[] | select(. == "invalid-spec-map-contract:spec-map.json")' "$TMP_DIR/empty-spec-map-member.json" >/dev/null

PADDED_TOUCHED_SPEC_PROJECT="$TMP_DIR/padded-touched-spec-project"
cp -R "$HAPPY_PROJECT" "$PADDED_TOUCHED_SPEC_PROJECT"
cat >"$PADDED_TOUCHED_SPEC_PROJECT/openspec/changes/add-dashboard/spec-map.json" <<'JSON'
{
  "touched_specs": [" ui-design "],
  "ui_rules": ["dashboard-layout"],
  "architecture_modules": ["dashboard-shell"],
  "api_contracts": [],
  "database_entities": [],
  "permissions": [],
  "operational_constraints": [],
  "data_flows": [],
  "unresolved_gaps": []
}
JSON
run_json "$PADDED_TOUCHED_SPEC_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/padded-touched-spec.json" 2
jq -e '.blockers[] | select(. == "invalid-spec-map-contract:spec-map.json")' "$TMP_DIR/padded-touched-spec.json" >/dev/null

PADDED_SPEC_MAP_MEMBER_PROJECT="$TMP_DIR/padded-spec-map-member-project"
cp -R "$HAPPY_PROJECT" "$PADDED_SPEC_MAP_MEMBER_PROJECT"
cat >"$PADDED_SPEC_MAP_MEMBER_PROJECT/openspec/changes/add-dashboard/spec-map.json" <<'JSON'
{
  "touched_specs": ["ui-design"],
  "ui_rules": [" dashboard-layout "],
  "architecture_modules": [],
  "api_contracts": [],
  "database_entities": [],
  "permissions": [],
  "operational_constraints": [],
  "data_flows": [],
  "unresolved_gaps": []
}
JSON
run_json "$PADDED_SPEC_MAP_MEMBER_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/padded-spec-map-member.json" 2
jq -e '.blockers[] | select(. == "invalid-spec-map-contract:spec-map.json")' "$TMP_DIR/padded-spec-map-member.json" >/dev/null

UNKNOWN_TOUCHED_SPEC_PROJECT="$TMP_DIR/unknown-touched-spec-project"
cp -R "$HAPPY_PROJECT" "$UNKNOWN_TOUCHED_SPEC_PROJECT"
cat >"$UNKNOWN_TOUCHED_SPEC_PROJECT/openspec/changes/add-dashboard/spec-map.json" <<'JSON'
{
  "touched_specs": ["unknown-spec"],
  "ui_rules": ["dashboard-layout"],
  "architecture_modules": ["dashboard-shell"],
  "api_contracts": [],
  "database_entities": [],
  "permissions": [],
  "operational_constraints": [],
  "data_flows": [],
  "unresolved_gaps": []
}
JSON
run_json "$UNKNOWN_TOUCHED_SPEC_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/unknown-touched-spec.json" 2
jq -e '.blockers[] | select(. == "invalid-spec-map-contract:spec-map.json")' "$TMP_DIR/unknown-touched-spec.json" >/dev/null

MISSING_SPEC_MAP_FIELD_PROJECT="$TMP_DIR/missing-spec-map-field-project"
cp -R "$HAPPY_PROJECT" "$MISSING_SPEC_MAP_FIELD_PROJECT"
cat >"$MISSING_SPEC_MAP_FIELD_PROJECT/openspec/changes/add-dashboard/spec-map.json" <<'JSON'
{
  "touched_specs": ["ui-design"],
  "ui_rules": ["layout:grid"],
  "architecture_modules": [],
  "api_contracts": [],
  "database_entities": [],
  "permissions": [],
  "operational_constraints": [],
  "unresolved_gaps": []
}
JSON
run_json "$MISSING_SPEC_MAP_FIELD_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/missing-spec-map-field.json" 2
jq -e '.blockers[] | select(. == "invalid-spec-map-contract:spec-map.json")' "$TMP_DIR/missing-spec-map-field.json" >/dev/null

EMPTY_TOUCHED_SPECS_WITH_OTHER_FIELDS_PROJECT="$TMP_DIR/empty-touched-specs-with-other-fields-project"
cp -R "$HAPPY_PROJECT" "$EMPTY_TOUCHED_SPECS_WITH_OTHER_FIELDS_PROJECT"
cat >"$EMPTY_TOUCHED_SPECS_WITH_OTHER_FIELDS_PROJECT/openspec/changes/add-dashboard/spec-map.json" <<'JSON'
{
  "touched_specs": [],
  "ui_rules": ["layout:grid"],
  "unresolved_gaps": []
}
JSON
run_json "$EMPTY_TOUCHED_SPECS_WITH_OTHER_FIELDS_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/empty-touched-specs-with-other-fields.json" 2
jq -e '.blockers[] | select(. == "invalid-spec-map-contract:spec-map.json")' "$TMP_DIR/empty-touched-specs-with-other-fields.json" >/dev/null

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

MISSING_SPEC_UNRESOLVED_GAPS_PROJECT="$TMP_DIR/missing-spec-unresolved-gaps-project"
cp -R "$HAPPY_PROJECT" "$MISSING_SPEC_UNRESOLVED_GAPS_PROJECT"
cat >"$MISSING_SPEC_UNRESOLVED_GAPS_PROJECT/openspec/changes/add-dashboard/spec-map.json" <<'JSON'
{
  "touched_specs": ["ui-design"],
  "ui_rules": ["layout:grid"],
  "architecture_modules": [],
  "api_contracts": [],
  "database_entities": [],
  "permissions": [],
  "operational_constraints": [],
  "data_flows": []
}
JSON
run_json "$MISSING_SPEC_UNRESOLVED_GAPS_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/missing-spec-unresolved-gaps.json" 2
jq -e '.blockers[] | select(. == "invalid-unresolved-gaps:spec-map.json")' "$TMP_DIR/missing-spec-unresolved-gaps.json" >/dev/null

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

INVALID_COMPONENT_IMPACT_MEMBER_PROJECT="$TMP_DIR/invalid-component-impact-member-project"
cp -R "$HAPPY_PROJECT" "$INVALID_COMPONENT_IMPACT_MEMBER_PROJECT"
cat >"$INVALID_COMPONENT_IMPACT_MEMBER_PROJECT/openspec/changes/add-dashboard/component-impact-map.json" <<'JSON'
{
  "new_components": [null],
  "reused_components": [],
  "extraction_triggers": [],
  "forbidden_dependencies": [],
  "hooks": [],
  "utilities": [],
  "services": [],
  "required_component_tests": ["DashboardView renders loading empty error states"],
  "unresolved_gaps": []
}
JSON
run_json "$INVALID_COMPONENT_IMPACT_MEMBER_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/invalid-component-impact-member.json" 2
jq -e '.blockers[] | select(. == "invalid-component-impact-map-contract:component-impact-map.json")' "$TMP_DIR/invalid-component-impact-member.json" >/dev/null

BLANK_COMPONENT_IMPACT_MEMBER_PROJECT="$TMP_DIR/blank-component-impact-member-project"
cp -R "$HAPPY_PROJECT" "$BLANK_COMPONENT_IMPACT_MEMBER_PROJECT"
cat >"$BLANK_COMPONENT_IMPACT_MEMBER_PROJECT/openspec/changes/add-dashboard/component-impact-map.json" <<'JSON'
{
  "new_components": ["   "],
  "reused_components": [],
  "extraction_triggers": [],
  "forbidden_dependencies": [],
  "hooks": [],
  "utilities": [],
  "services": [],
  "required_component_tests": ["DashboardView renders loading empty error states"],
  "unresolved_gaps": []
}
JSON
run_json "$BLANK_COMPONENT_IMPACT_MEMBER_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/blank-component-impact-member.json" 2
jq -e '.blockers[] | select(. == "invalid-component-impact-map-contract:component-impact-map.json")' "$TMP_DIR/blank-component-impact-member.json" >/dev/null

PADDED_COMPONENT_IMPACT_MEMBER_PROJECT="$TMP_DIR/padded-component-impact-member-project"
cp -R "$HAPPY_PROJECT" "$PADDED_COMPONENT_IMPACT_MEMBER_PROJECT"
cat >"$PADDED_COMPONENT_IMPACT_MEMBER_PROJECT/openspec/changes/add-dashboard/component-impact-map.json" <<'JSON'
{
  "new_components": [" DashboardView "],
  "reused_components": [],
  "extraction_triggers": [],
  "forbidden_dependencies": [],
  "hooks": [],
  "utilities": [],
  "services": [],
  "required_component_tests": ["DashboardView renders loading empty error states"],
  "unresolved_gaps": []
}
JSON
run_json "$PADDED_COMPONENT_IMPACT_MEMBER_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/padded-component-impact-member.json" 2
jq -e '.blockers[] | select(. == "invalid-component-impact-map-contract:component-impact-map.json")' "$TMP_DIR/padded-component-impact-member.json" >/dev/null

MISSING_COMPONENT_IMPACT_FIELD_PROJECT="$TMP_DIR/missing-component-impact-field-project"
cp -R "$HAPPY_PROJECT" "$MISSING_COMPONENT_IMPACT_FIELD_PROJECT"
cat >"$MISSING_COMPONENT_IMPACT_FIELD_PROJECT/openspec/changes/add-dashboard/component-impact-map.json" <<'JSON'
{
  "new_components": ["DashboardView"],
  "reused_components": [],
  "extraction_triggers": [],
  "forbidden_dependencies": [],
  "hooks": [],
  "utilities": [],
  "services": [],
  "unresolved_gaps": []
}
JSON
run_json "$MISSING_COMPONENT_IMPACT_FIELD_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/missing-component-impact-field.json" 2
jq -e '.blockers[] | select(. == "invalid-component-impact-map-contract:component-impact-map.json")' "$TMP_DIR/missing-component-impact-field.json" >/dev/null

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

MISSING_COMPONENT_UNRESOLVED_GAPS_PROJECT="$TMP_DIR/missing-component-unresolved-gaps-project"
cp -R "$HAPPY_PROJECT" "$MISSING_COMPONENT_UNRESOLVED_GAPS_PROJECT"
cat >"$MISSING_COMPONENT_UNRESOLVED_GAPS_PROJECT/openspec/changes/add-dashboard/component-impact-map.json" <<'JSON'
{
  "new_components": ["DashboardView"],
  "reused_components": [],
  "extraction_triggers": [],
  "forbidden_dependencies": [],
  "hooks": [],
  "utilities": [],
  "services": [],
  "required_component_tests": []
}
JSON
run_json "$MISSING_COMPONENT_UNRESOLVED_GAPS_PROJECT" "$REQ/scripts/requirements-contract.js" "$TMP_DIR/missing-component-unresolved-gaps.json" 2
jq -e '.blockers[] | select(. == "invalid-unresolved-gaps:component-impact-map.json")' "$TMP_DIR/missing-component-unresolved-gaps.json" >/dev/null

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
