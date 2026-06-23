#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const lib = require('../../helm-core/scripts/helm-lib');
const { validateRequirements } = require('../../helm-requirements/scripts/requirements-contract');

const MANIFEST_SCHEMA = 'helm.prototype.manifest.v1';
const VERIFIER_SCHEMA = 'helm.prototype.verifier.v1';

const PROTOTYPE_TYPES = new Set([
  'ui-html',
  'logic-state',
  'api-contract',
  'data-flow',
  'component-seam'
]);

const APPROVED_CORE_ARTIFACTS = [
  'question.md',
  'prototype-manifest.json',
  'verifier-report.json',
  'handoff.md',
  'decision.json'
];

const GAP_SENSITIVE_FILES = [
  'screen-map.json',
  'component-tree.md',
  'data-flow-map.md',
  'handoff.md'
];

const BRANCH_REQUIREMENTS = {
  'ui-html': {
    required: 'artifact/index.html',
    kind: 'file',
    entry: (entry) => entry === 'artifact/index.html',
    entryBlocker: 'prototype-entry-mismatch:ui-html',
    gapRequired: ['screen-map.json']
  },
  'logic-state': {
    required: 'logic',
    kind: 'directory',
    entry: (entry) => entry === 'logic' || entry.startsWith('logic/'),
    entryBlocker: 'prototype-entry-mismatch:logic-state',
    gapRequired: []
  },
  'api-contract': {
    required: 'api',
    kind: 'directory',
    entry: (entry) => entry === 'api' || entry.startsWith('api/'),
    entryBlocker: 'prototype-entry-mismatch:api-contract',
    gapRequired: []
  },
  'data-flow': {
    required: 'data-flow-map.md',
    kind: 'file',
    entry: (entry) => entry === 'data-flow-map.md',
    entryBlocker: 'prototype-entry-mismatch:data-flow',
    gapRequired: ['data-flow-map.md']
  },
  'component-seam': {
    required: 'component',
    kind: 'directory',
    entry: (entry) => entry === 'component' || entry.startsWith('component/'),
    entryBlocker: 'prototype-entry-mismatch:component-seam',
    gapRequired: ['component-tree.md']
  }
};

function unique(values) {
  return Array.from(new Set(values.filter(Boolean)));
}

function isPlainObject(value) {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim() !== '';
}

function isCleanString(value) {
  return isNonEmptyString(value) && value === value.trim();
}

function hasOwn(value, property) {
  return Object.prototype.hasOwnProperty.call(value, property);
}

function hasInvalidStringArrayMembers(values) {
  return values.some((item) => !isCleanString(item));
}

function readJsonFile(file) {
  try {
    return { ok: true, value: JSON.parse(fs.readFileSync(file, 'utf8')), status: 'ok' };
  } catch (error) {
    if (error && error.code === 'ENOENT') return { ok: false, value: null, status: 'missing' };
    if (error instanceof SyntaxError) return { ok: false, value: null, status: 'invalid-json' };
    return { ok: false, value: null, status: 'unreadable' };
  }
}

function readTextFile(file) {
  try {
    return { ok: true, value: fs.readFileSync(file, 'utf8'), status: 'ok' };
  } catch (error) {
    if (error && error.code === 'ENOENT') return { ok: false, value: null, status: 'missing' };
    return { ok: false, value: null, status: 'unreadable' };
  }
}

function statKind(file) {
  try {
    const stat = fs.statSync(file);
    if (stat.isFile()) return 'file';
    if (stat.isDirectory()) return 'directory';
    return 'other';
  } catch {
    return null;
  }
}

function artifactRelativePath(change, name) {
  return path.join('openspec', 'changes', change, 'prototype', name);
}

function artifactResult(change, name, blockers, extra = {}) {
  return {
    name,
    path: artifactRelativePath(change, name),
    ok: blockers.length === 0,
    blockers,
    ...extra
  };
}

function normalizePrototypeRelativePath(value) {
  if (!isCleanString(value)) {
    return { ok: false, normalized: null, blockers: ['invalid-prototype-entry-path'] };
  }
  if (path.isAbsolute(value) || value.includes('\\')) {
    return { ok: false, normalized: null, blockers: ['invalid-prototype-entry-path'] };
  }

  const segments = value.split('/');
  if (segments.some((segment) => segment === '' || segment === '.' || segment === '..')) {
    return { ok: false, normalized: null, blockers: ['invalid-prototype-entry-path'] };
  }

  const normalized = path.posix.normalize(value);
  if (!normalized || normalized === '.' || normalized.startsWith('../') || normalized.includes('/../')) {
    return { ok: false, normalized: null, blockers: ['invalid-prototype-entry-path'] };
  }

  return { ok: true, normalized, blockers: [] };
}

function resolvePrototypePath(prototypeDir, relativePath) {
  const normalized = normalizePrototypeRelativePath(relativePath);
  if (!normalized.ok) return { ok: false, file: null, normalized: null, blockers: normalized.blockers };

  const file = path.resolve(prototypeDir, normalized.normalized);
  const base = path.resolve(prototypeDir);
  const relative = path.relative(base, file);
  if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) {
    return { ok: false, file: null, normalized: normalized.normalized, blockers: ['invalid-prototype-entry-path'] };
  }

  return { ok: true, file, normalized: normalized.normalized, blockers: [] };
}

function validateTextArtifact(prototypeDir, change, name, options = {}) {
  const file = path.join(prototypeDir, name);
  const text = readTextFile(file);
  const blockers = [];

  if (!text.ok) {
    blockers.push(text.status === 'missing' ? `missing-prototype-artifact:${name}` : `unreadable-prototype-artifact:${name}`);
    return artifactResult(change, name, blockers);
  }
  if (options.nonEmpty !== false && text.value.trim() === '') {
    blockers.push(`empty-prototype-artifact:${name}`);
  }
  if (options.gapSensitive && /\b(?:TODO|TBD|unresolved|gap)\b/i.test(text.value)) {
    blockers.push(`unresolved-prototype-gap:${name}`);
  }

  return artifactResult(change, name, blockers);
}

function validateGapSensitiveFiles(prototypeDir, change, requiredNames) {
  const artifacts = [];
  const blockers = [];
  const names = unique([...GAP_SENSITIVE_FILES, ...requiredNames]);

  for (const name of names) {
    const file = path.join(prototypeDir, name);
    const exists = fs.existsSync(file);
    if (!exists && requiredNames.includes(name)) {
      const artifactBlockers = [`missing-prototype-artifact:${name}`];
      artifacts.push(artifactResult(change, name, artifactBlockers));
      blockers.push(...artifactBlockers);
      continue;
    }
    if (!exists) continue;

    const artifact = validateTextArtifact(prototypeDir, change, name, { gapSensitive: true, nonEmpty: false });
    artifacts.push(artifact);
    blockers.push(...artifact.blockers);
  }

  return { artifacts, blockers };
}

function validateStringArrayField(value, field, options = {}) {
  if (!Array.isArray(value[field])) return [`invalid-prototype-manifest:${field}`];
  if (hasInvalidStringArrayMembers(value[field])) return [`invalid-prototype-manifest:${field}`];
  if (options.nonEmpty && value[field].length === 0) return [`invalid-prototype-manifest:${field}`];
  return [];
}

function validateManifest(prototypeDir, change) {
  const name = 'prototype-manifest.json';
  const file = path.join(prototypeDir, name);
  const parsed = readJsonFile(file);
  const blockers = [];
  let manifest = null;
  let entry = null;
  let prototypeType = null;
  const nestedArtifacts = [];

  if (!parsed.ok) {
    blockers.push(parsed.status === 'invalid-json' ? `invalid-json:${name}` : `missing-prototype-artifact:${name}`);
    return { artifact: artifactResult(change, name, blockers), blockers, manifest, entry, prototypeType, artifacts: nestedArtifacts };
  }
  if (!isPlainObject(parsed.value)) {
    blockers.push(`invalid-json-shape:${name}`);
    return { artifact: artifactResult(change, name, blockers), blockers, manifest, entry, prototypeType, artifacts: nestedArtifacts };
  }

  manifest = parsed.value;
  prototypeType = manifest.type;

  if (manifest.schema !== MANIFEST_SCHEMA) blockers.push('invalid-prototype-manifest:schema');
  if (!isCleanString(manifest.version) && manifest.schema_version !== 1 && manifest.schema_version !== '1') {
    blockers.push('invalid-prototype-manifest:version');
  }
  if (!PROTOTYPE_TYPES.has(manifest.type)) blockers.push('invalid-prototype-manifest:type');
  if (!isCleanString(manifest.mock_strategy)) blockers.push('invalid-prototype-manifest:mock_strategy');
  if (typeof manifest.touches_real_data !== 'boolean') blockers.push('invalid-prototype-manifest:touches_real_data');
  if (typeof manifest.may_promote !== 'boolean') blockers.push('invalid-prototype-manifest:may_promote');
  if (!isCleanString(manifest.promotion_requirement)) blockers.push('invalid-prototype-manifest:promotion_requirement');

  blockers.push(...validateStringArrayField(manifest, 'dependencies'));
  blockers.push(...validateStringArrayField(manifest, 'referenced_foundation_specs', { nonEmpty: true }));
  blockers.push(...validateStringArrayField(manifest, 'referenced_requirements', { nonEmpty: true }));

  const entryPath = resolvePrototypePath(prototypeDir, manifest.entry);
  blockers.push(...entryPath.blockers);
  if (entryPath.ok) {
    entry = entryPath.normalized;
    if (!fs.existsSync(entryPath.file)) blockers.push('missing-prototype-entry');
  }

  const branch = BRANCH_REQUIREMENTS[manifest.type];
  if (branch) {
    const branchPath = path.join(prototypeDir, branch.required);
    const kind = statKind(branchPath);
    const branchBlockers = [];
    if (kind !== branch.kind) branchBlockers.push(`missing-prototype-branch-artifact:${branch.required}`);
    nestedArtifacts.push(artifactResult(change, branch.required, branchBlockers, { expected_kind: branch.kind }));
    blockers.push(...branchBlockers);
    if (entry && !branch.entry(entry)) blockers.push(branch.entryBlocker);
  }

  return {
    artifact: artifactResult(change, name, blockers, { prototype_type: prototypeType, entry }),
    blockers,
    manifest,
    entry,
    prototypeType,
    artifacts: nestedArtifacts
  };
}

function validateVerifier(prototypeDir, change) {
  const name = 'verifier-report.json';
  const file = path.join(prototypeDir, name);
  const parsed = readJsonFile(file);
  const blockers = [];
  let verifier = null;

  if (!parsed.ok) {
    blockers.push(parsed.status === 'invalid-json' ? `invalid-json:${name}` : `missing-prototype-artifact:${name}`);
    return { artifact: artifactResult(change, name, blockers), blockers, verifier };
  }
  if (!isPlainObject(parsed.value)) {
    blockers.push(`invalid-json-shape:${name}`);
    return { artifact: artifactResult(change, name, blockers), blockers, verifier };
  }

  verifier = parsed.value;
  if (verifier.schema !== VERIFIER_SCHEMA) blockers.push('invalid-prototype-verifier:schema');
  if (verifier.status !== 'green') blockers.push(`prototype-verifier-not-green:${verifier.status || 'missing'}`);

  return {
    artifact: artifactResult(change, name, blockers, { status: verifier.status || null }),
    blockers,
    verifier
  };
}

function validateDecisionShape(decision, prototypeType) {
  const blockers = [];

  if (decision.status === 'not_required') {
    if (!isNonEmptyString(decision.reason)) blockers.push('invalid-prototype-decision:not_required-reason');
    return blockers;
  }

  if (decision.status !== 'approved') {
    blockers.push(`invalid-prototype-decision-status:${decision.status || 'missing'}`);
    return blockers;
  }

  if (decision.prototype_code !== 'required_present') blockers.push('invalid-prototype-decision:prototype_code');
  if (decision.prototype_type !== prototypeType) blockers.push('invalid-prototype-decision:prototype_type');
  if (decision.promotion !== 'requires_development_gate') blockers.push('invalid-prototype-decision:promotion');
  if (!Array.isArray(decision.blocked_reasons) || decision.blocked_reasons.length !== 0) {
    blockers.push('invalid-prototype-decision:blocked_reasons');
  }

  return blockers;
}

function validateDecision(prototypeDir, change, prototypeType = null) {
  const name = 'decision.json';
  const file = path.join(prototypeDir, name);
  const parsed = readJsonFile(file);
  const blockers = [];
  let decision = null;

  if (!parsed.ok) {
    blockers.push(parsed.status === 'invalid-json' ? `invalid-json:${name}` : `missing-prototype-artifact:${name}`);
    return { artifact: artifactResult(change, name, blockers), blockers, decision };
  }
  if (!isPlainObject(parsed.value)) {
    blockers.push(`invalid-json-shape:${name}`);
    return { artifact: artifactResult(change, name, blockers), blockers, decision };
  }

  decision = parsed.value;
  blockers.push(...validateDecisionShape(decision, prototypeType));

  return {
    artifact: artifactResult(change, name, blockers, { status: decision.status || null }),
    blockers,
    decision
  };
}

function validateApprovedPrototype(prototypeDir, change) {
  const artifacts = [];
  const blockers = [];

  const question = validateTextArtifact(prototypeDir, change, 'question.md');
  artifacts.push(question);
  blockers.push(...question.blockers);

  const manifest = validateManifest(prototypeDir, change);
  artifacts.push(manifest.artifact, ...manifest.artifacts);
  blockers.push(...manifest.blockers);

  const gapCheck = validateGapSensitiveFiles(
    prototypeDir,
    change,
    manifest.prototypeType && BRANCH_REQUIREMENTS[manifest.prototypeType]
      ? BRANCH_REQUIREMENTS[manifest.prototypeType].gapRequired
      : []
  );
  artifacts.push(...gapCheck.artifacts);
  blockers.push(...gapCheck.blockers);

  const verifier = validateVerifier(prototypeDir, change);
  artifacts.push(verifier.artifact);
  blockers.push(...verifier.blockers);

  const decision = validateDecision(prototypeDir, change, manifest.prototypeType);
  artifacts.push(decision.artifact);
  blockers.push(...decision.blockers);

  for (const artifactName of APPROVED_CORE_ARTIFACTS) {
    if (!artifacts.some((artifact) => artifact.name === artifactName)) {
      const artifactBlockers = [`missing-prototype-artifact:${artifactName}`];
      artifacts.push(artifactResult(change, artifactName, artifactBlockers));
      blockers.push(...artifactBlockers);
    }
  }

  return {
    artifacts,
    blockers,
    manifest: manifest.manifest,
    verifier: verifier.verifier,
    decision: decision.decision
  };
}

function validateNotRequiredPrototype(prototypeDir, change, decisionResult) {
  const artifacts = [decisionResult.artifact];
  const blockers = [...decisionResult.blockers];
  const handoff = validateTextArtifact(prototypeDir, change, 'handoff.md', { gapSensitive: true });
  artifacts.push(handoff);
  blockers.push(...handoff.blockers);

  return {
    artifacts,
    blockers,
    manifest: null,
    verifier: null,
    decision: decisionResult.decision
  };
}

function validatePrototype(root = lib.projectRoot()) {
  const projectRoot = path.resolve(root);
  const requirements = validateRequirements(projectRoot);

  if (!requirements.ok) {
    return {
      ok: false,
      project_root: projectRoot,
      active_change: requirements.active_change || null,
      prototype_dir: null,
      blockers: unique(['requirements-blocked', ...requirements.blockers.map((blocker) => `requirements:${blocker}`)]),
      requirements,
      artifacts: []
    };
  }

  const activeChange = requirements.active_change;
  const prototypeDir = path.join(projectRoot, 'openspec', 'changes', activeChange, 'prototype');
  const blockers = [];
  let artifacts = [];
  let manifest = null;
  let verifier = null;
  let decision = null;

  if (statKind(prototypeDir) !== 'directory') {
    blockers.push('missing-prototype-dir');
    artifacts = APPROVED_CORE_ARTIFACTS.map((name) => artifactResult(activeChange, name, [`missing-prototype-artifact:${name}`]));
    return {
      ok: false,
      project_root: projectRoot,
      active_change: activeChange,
      prototype_dir: prototypeDir,
      blockers: unique([...blockers, ...artifacts.flatMap((artifact) => artifact.blockers)]),
      requirements,
      artifacts
    };
  }

  const decisionResult = validateDecision(prototypeDir, activeChange);
  if (decisionResult.decision && decisionResult.decision.status === 'not_required') {
    const result = validateNotRequiredPrototype(prototypeDir, activeChange, decisionResult);
    artifacts = result.artifacts;
    blockers.push(...result.blockers);
    decision = result.decision;
  } else {
    const result = validateApprovedPrototype(prototypeDir, activeChange);
    artifacts = result.artifacts;
    blockers.push(...result.blockers);
    manifest = result.manifest;
    verifier = result.verifier;
    decision = result.decision;
  }

  return {
    ok: blockers.length === 0,
    project_root: projectRoot,
    active_change: activeChange,
    prototype_dir: prototypeDir,
    blockers: unique(blockers),
    requirements,
    artifacts,
    manifest: manifest ? {
      schema: manifest.schema || null,
      version: manifest.version || manifest.schema_version || null,
      type: manifest.type || null,
      entry: manifest.entry || null
    } : null,
    verifier: verifier ? {
      schema: verifier.schema || null,
      status: verifier.status || null
    } : null,
    decision: decision ? {
      status: decision.status || null,
      prototype_type: hasOwn(decision, 'prototype_type') ? decision.prototype_type : null
    } : null
  };
}

function markdown(result) {
  const lines = [];
  lines.push('# Helm Prototype Contract');
  lines.push('');
  lines.push(`- project: \`${result.project_root}\``);
  lines.push(`- active change: \`${result.active_change || 'none'}\``);
  lines.push(`- prototype dir: \`${result.prototype_dir || 'none'}\``);
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
  const result = validatePrototype();
  process.stdout.write(process.argv.includes('--json') ? `${JSON.stringify(result, null, 2)}\n` : markdown(result));
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = { validatePrototype };
