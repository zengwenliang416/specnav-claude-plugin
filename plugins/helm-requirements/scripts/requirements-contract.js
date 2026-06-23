#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const lib = require('../../helm-core/scripts/helm-lib');
const foundationSpecs = require('./foundation-specs');

const REQUIRED_ARTIFACTS = [
  'requirements.md',
  'acceptance.md',
  'spec-map.json',
  'component-impact-map.json'
];

const SPEC_MAP_FIELDS = [
  'touched_specs',
  'ui_rules',
  'architecture_modules',
  'api_contracts',
  'database_entities',
  'permissions',
  'operational_constraints',
  'data_flows'
];

const COMPONENT_IMPACT_MAP_FIELDS = [
  'new_components',
  'reused_components',
  'extraction_triggers',
  'forbidden_dependencies',
  'hooks',
  'utilities',
  'services',
  'required_component_tests'
];

function unique(values) {
  return Array.from(new Set(values.filter(Boolean)));
}

function artifactPath(change, name) {
  return change ? path.join('openspec', 'changes', change, name) : path.join('openspec', 'changes', '<active-change>', name);
}

function readJsonFile(file) {
  try {
    return { ok: true, value: JSON.parse(fs.readFileSync(file, 'utf8')) };
  } catch (error) {
    if (error && error.code === 'ENOENT') return { ok: false, status: 'missing', value: null };
    if (error instanceof SyntaxError) return { ok: false, status: 'invalid-json', value: null };
    return { ok: false, status: 'unreadable', value: null };
  }
}

function readTextFile(file) {
  try {
    return { ok: true, value: fs.readFileSync(file, 'utf8') };
  } catch (_error) {
    return { ok: false, status: 'unreadable', value: null };
  }
}

function invalidChangeId(value) {
  return value.includes('/') || value.includes('\\') || value.includes('..') || /\s/.test(value);
}

function strictActiveChange(projectRoot) {
  const activeFile = path.join(lib.helmDir(projectRoot), 'active-change');

  try {
    if (!fs.statSync(activeFile).isFile()) return null;
  } catch (_error) {
    return null;
  }

  let change;
  try {
    change = fs.readFileSync(activeFile, 'utf8').trim();
  } catch (_error) {
    return null;
  }

  if (!change || invalidChangeId(change)) return null;
  return change;
}

function changeDirExists(dir) {
  if (!dir) return false;
  try {
    return fs.statSync(dir).isDirectory();
  } catch (_error) {
    return false;
  }
}

function isPlainObject(value) {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}

function validateArrayFieldContract(value, fields, blocker) {
  let hasNonEmptyArray = false;
  let invalidFieldType = false;

  for (const field of fields) {
    if (!Object.prototype.hasOwnProperty.call(value, field)) continue;
    if (!Array.isArray(value[field])) {
      invalidFieldType = true;
      continue;
    }
    if (value[field].length > 0) hasNonEmptyArray = true;
  }

  return invalidFieldType || !hasNonEmptyArray ? [blocker] : [];
}

function validateJsonArtifactContract(name, value) {
  if (name === 'spec-map.json') {
    return validateArrayFieldContract(value, SPEC_MAP_FIELDS, 'invalid-spec-map-contract:spec-map.json');
  }
  if (name === 'component-impact-map.json') {
    return validateArrayFieldContract(value, COMPONENT_IMPACT_MAP_FIELDS, 'invalid-component-impact-map-contract:component-impact-map.json');
  }
  return [];
}

function validateArtifact(dir, change, name) {
  const relativePath = artifactPath(change, name);
  const file = dir ? path.join(dir, name) : null;
  const blockers = [];

  if (!file || !fs.existsSync(file)) {
    blockers.push(`missing-requirements-artifact:${name}`);
    return {
      name,
      path: relativePath,
      ok: false,
      blockers
    };
  }

  if (!name.endsWith('.json')) {
    const text = readTextFile(file);
    if (!text.ok) {
      blockers.push(`unreadable-requirements-artifact:${name}`);
    } else if (text.value.trim().length === 0) {
      blockers.push(`empty-requirements-artifact:${name}`);
    }
    return {
      name,
      path: relativePath,
      ok: blockers.length === 0,
      blockers
    };
  }

  const parsed = readJsonFile(file);
  if (!parsed.ok) {
    blockers.push(parsed.status === 'invalid-json' ? `invalid-json:${name}` : `unreadable-requirements-artifact:${name}`);
  } else if (!isPlainObject(parsed.value)) {
    blockers.push(`invalid-json-shape:${name}`);
  } else {
    blockers.push(...validateJsonArtifactContract(name, parsed.value));
    if (Object.prototype.hasOwnProperty.call(parsed.value, 'unresolved_gaps')) {
      if (!Array.isArray(parsed.value.unresolved_gaps)) {
        blockers.push(`invalid-unresolved-gaps:${name}`);
      } else if (parsed.value.unresolved_gaps.length > 0) {
        blockers.push(`unresolved-gaps:${name}`);
      }
    }
  }

  return {
    name,
    path: relativePath,
    ok: blockers.length === 0,
    blockers
  };
}

function validateRequirements(root = lib.projectRoot()) {
  const projectRoot = path.resolve(root);
  const foundation = foundationSpecs.validateFoundationSpecs(projectRoot);
  const change = strictActiveChange(projectRoot);
  const dir = change ? lib.changeDir(projectRoot, change) : null;
  const activeChangeOk = changeDirExists(dir);
  const blockers = [];

  if (!foundation.ok) blockers.push(...foundation.blockers);
  if (!activeChangeOk) blockers.push('active-change');

  const artifacts = activeChangeOk ? REQUIRED_ARTIFACTS.map((name) => validateArtifact(dir, change, name)) : [];
  blockers.push(...artifacts.flatMap((artifact) => artifact.blockers));

  return {
    ok: blockers.length === 0,
    project_root: projectRoot,
    active_change: activeChangeOk ? change : null,
    blockers: unique(blockers),
    foundation,
    artifacts
  };
}

function markdown(result) {
  const lines = [];
  lines.push('# Helm Requirements Contract');
  lines.push('');
  lines.push(`- project: \`${result.project_root}\``);
  lines.push(`- active change: \`${result.active_change || 'none'}\``);
  lines.push(`- ok: ${result.ok}`);
  if (result.blockers.length) lines.push(`- blockers: ${result.blockers.join(', ')}`);
  lines.push('');
  lines.push('| Artifact | Status | Blockers |');
  lines.push('| --- | --- | --- |');
  for (const artifact of result.artifacts) {
    lines.push(`| ${artifact.name} | ${artifact.ok ? 'pass' : 'blocked'} | ${artifact.blockers.join('<br>') || '-'} |`);
  }
  return `${lines.join('\n')}\n`;
}

function main() {
  const result = validateRequirements();
  process.stdout.write(process.argv.includes('--json') ? `${JSON.stringify(result, null, 2)}\n` : markdown(result));
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = { validateRequirements };
