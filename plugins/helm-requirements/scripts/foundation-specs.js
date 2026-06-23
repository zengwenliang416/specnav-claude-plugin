#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const lib = require('../../helm-core/scripts/helm-lib');

const REQUIRED_FOUNDATION_SPECS = [
  {
    id: 'ui-design',
    path: 'openspec/specs/ui-design/design.md',
    requiredSections: [
      '# ',
      '## Overview',
      '## Colors',
      '## Typography',
      '## Layout',
      '## Elevation & Depth',
      '## Motion',
      '## Shapes',
      '## Components',
      '## Voice & Content',
      "## Do's and Don'ts"
    ],
    requiredFrontmatterKeys: ['version', 'name', 'description', 'colors', 'typography', 'spacing', 'rounded', 'components']
  },
  {
    id: 'system-architecture',
    path: 'openspec/specs/system-architecture/design.md',
    requiredSections: [
      '# System Architecture & Database Spec',
      '## Overview',
      '## Application Topology',
      '## Module Boundaries',
      '## Frontend Architecture',
      '## Backend Architecture',
      '## API Surface',
      '## Database Model',
      '## Permissions & Security',
      '## Integration Boundaries',
      '## Operational Constraints',
      "## Architecture Do's and Don'ts"
    ],
    requiredFrontmatterKeys: []
  },
  {
    id: 'frontend-backend-data-flow',
    path: 'openspec/specs/frontend-backend-data-flow/design.md',
    requiredSections: [
      '# Frontend-Backend Data Flow Spec',
      '## Overview',
      '## Flow Index',
      '## Boundary Contracts',
      '## State Ownership',
      '## Validation Ownership',
      '## Error & Empty States',
      '## Loading / Optimistic / Retry Behavior',
      '## End-to-End Flow Details',
      '## Async / Realtime Flows',
      "## Flow Do's and Don'ts"
    ],
    requiredFrontmatterKeys: []
  },
  {
    id: 'component-architecture',
    path: 'openspec/specs/component-architecture/design.md',
    requiredSections: [
      '# Component Architecture & Reuse Spec',
      '## Overview',
      '## Component Taxonomy',
      '## Cohesion Rules',
      '## Coupling Rules',
      '## Shared Component Extraction Rules',
      '## Component Public API Rules',
      '## State Ownership Rules',
      '## Composition Patterns',
      '## File & Naming Conventions',
      '## Testing Expectations',
      '## Refactor Triggers',
      "## Component Do's and Don'ts"
    ],
    requiredFrontmatterKeys: []
  }
];

function unique(values) {
  return Array.from(new Set(values.filter(Boolean)));
}

function normalizeNewlines(text) {
  return String(text || '').replace(/\r\n/g, '\n');
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function markdownHasSection(text, heading) {
  const normalized = normalizeNewlines(text);
  if (heading === '# ') return /^#\s+\S+/m.test(normalized);
  return new RegExp(`^${escapeRegExp(heading)}\\s*$`, 'm').test(normalized);
}

function parseFrontmatterKeys(text) {
  const normalized = normalizeNewlines(text);
  if (!normalized.startsWith('---\n')) {
    return { ok: false, keys: [], error: 'missing-frontmatter' };
  }

  const closeMatch = normalized.slice(4).match(/\n---\s*(?:\n|$)/);
  if (!closeMatch || typeof closeMatch.index !== 'number') {
    return { ok: false, keys: [], error: 'unterminated-frontmatter' };
  }

  const frontmatter = normalized.slice(4, 4 + closeMatch.index);
  const keys = [];
  for (const line of frontmatter.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    if (/^\s/.test(line)) continue;
    const match = line.match(/^([A-Za-z0-9_-]+)\s*:/);
    if (!match) {
      return { ok: false, keys: unique(keys), error: 'unparseable-frontmatter' };
    }
    keys.push(match[1]);
  }

  return { ok: true, keys: unique(keys), error: null };
}

function specById(id) {
  return REQUIRED_FOUNDATION_SPECS.find((spec) => spec.id === id) || null;
}

function validateOne(root, spec) {
  const contract = typeof spec === 'string' ? specById(spec) : spec;
  if (!contract || !contract.id || !contract.path) {
    return {
      id: contract && contract.id ? contract.id : 'unknown',
      path: contract && contract.path ? contract.path : null,
      ok: false,
      blockers: ['invalid-foundation-spec-contract'],
      missing_sections: [],
      missing_frontmatter_keys: []
    };
  }

  const file = path.join(root, contract.path);
  if (!fs.existsSync(file)) {
    return {
      id: contract.id,
      path: contract.path,
      ok: false,
      blockers: [`missing-foundation-spec:${contract.id}`],
      missing_sections: contract.requiredSections.slice(),
      missing_frontmatter_keys: contract.requiredFrontmatterKeys.slice()
    };
  }

  const text = lib.readText(file);
  const missingSections = contract.requiredSections.filter((heading) => !markdownHasSection(text, heading));
  const missingKeys = [];
  const blockers = [];
  let frontmatter_error = null;

  if (contract.requiredFrontmatterKeys.length) {
    const frontmatter = parseFrontmatterKeys(text);
    frontmatter_error = frontmatter.error;
    missingKeys.push(...contract.requiredFrontmatterKeys.filter((key) => !frontmatter.keys.includes(key)));
    if (!frontmatter.ok || missingKeys.length) blockers.push(`invalid-foundation-spec-frontmatter:${contract.id}`);
  }

  if (missingSections.length) blockers.push(`invalid-foundation-spec-sections:${contract.id}`);

  return {
    id: contract.id,
    path: contract.path,
    ok: blockers.length === 0,
    blockers: unique(blockers),
    missing_sections: missingSections,
    missing_frontmatter_keys: missingKeys,
    ...(frontmatter_error ? { frontmatter_error } : {})
  };
}

function validateFoundationSpecs(root = lib.projectRoot()) {
  const projectRoot = path.resolve(root);
  const specs = REQUIRED_FOUNDATION_SPECS.map((spec) => validateOne(projectRoot, spec));
  const blockers = specs.flatMap((spec) => spec.blockers);
  if (!fs.existsSync(lib.openspecDir(projectRoot))) blockers.unshift('openspec-missing');

  return {
    ok: blockers.length === 0,
    project_root: projectRoot,
    blockers: unique(blockers),
    specs
  };
}

function markdown(result) {
  const lines = [];
  lines.push('# Helm Foundation Specs');
  lines.push('');
  lines.push(`- project: \`${result.project_root}\``);
  lines.push(`- ok: ${result.ok}`);
  if (result.blockers.length) lines.push(`- blockers: ${result.blockers.join(', ')}`);
  lines.push('');
  lines.push('| Spec | Status | Blockers | Missing |');
  lines.push('| --- | --- | --- | --- |');
  for (const spec of result.specs) {
    const missing = [
      ...spec.missing_sections,
      ...spec.missing_frontmatter_keys.map((key) => `frontmatter:${key}`)
    ];
    lines.push(`| ${spec.id} | ${spec.ok ? 'pass' : 'blocked'} | ${spec.blockers.join('<br>') || '-'} | ${missing.join('<br>') || '-'} |`);
  }
  return `${lines.join('\n')}\n`;
}

function main() {
  const result = validateFoundationSpecs();
  process.stdout.write(process.argv.includes('--json') ? `${JSON.stringify(result, null, 2)}\n` : markdown(result));
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = { validateFoundationSpecs, validateOne, markdown };
