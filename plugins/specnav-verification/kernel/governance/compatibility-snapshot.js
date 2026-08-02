'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const SNAPSHOT_SCHEMA = 'specnav.verification.compatibility-snapshot.v1';
const BLOCKER_LITERAL = /['"`]([a-z][a-z0-9-]*(?::[a-z0-9][a-z0-9:._/-]*)+)['"`]/gi;
const IGNORED_LITERAL_PREFIXES = Object.freeze([
  'about:',
  'data:',
  'file:',
  'http:',
  'https:',
  'node:'
]);
const REPORT_MODEL_FILES = Object.freeze([
  'kernel/reporting/report-model-builder.js',
  'kernel/reporting/report-authorities.js',
  'kernel/reporting/report-selectors.js',
  'schemas/report-model.schema.json'
]);
const ARCHITECTURE_PATTERNS = Object.freeze([
  {
    id: 'direct-kernel-internal-import',
    pattern: /require\s*\([^)]*kernel\//
  },
  {
    id: 'duplicate-kernel-service',
    pattern: /\bcreate(?:DecisionEngine|EvidenceStore|ReadingEvaluator|ReportModelBuilder|SixDomainAggregator)\b/
  },
  {
    id: 'manual-domain-aggregation',
    pattern: /\bdomain_results\s*=/
  },
  {
    id: 'manual-release-verdict',
    pattern: /\brelease\.status\s*=/
  }
]);

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map((entry) => canonicalize(entry));
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(
    Object.keys(value)
      .sort()
      .map((key) => [key, canonicalize(value[key])])
  );
}

function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

function stableDigest(value) {
  return sha256(canonicalJson(value));
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function assertDirectory(root, blockerId) {
  let resolved;
  try {
    resolved = fs.realpathSync(root);
  } catch {
    throw new Error(blockerId);
  }
  if (!fs.statSync(resolved).isDirectory()) {
    throw new Error(blockerId);
  }
  return resolved;
}

function listFiles(root, predicate = () => true) {
  const files = [];
  for (const entry of fs.readdirSync(root, {
    recursive: true,
    withFileTypes: true
  })) {
    if (!entry.isFile()) continue;
    const file = path.join(entry.parentPath, entry.name);
    const relative = path.relative(root, file).split(path.sep).join('/');
    if (predicate(relative)) files.push(relative);
  }
  return files.sort();
}

function fileDigest(root, relative) {
  return sha256(fs.readFileSync(path.join(root, relative)));
}

function digestFiles(root, files) {
  const records = files.map((relative) => ({
    path: relative,
    sha256: fileDigest(root, relative)
  }));
  return {
    digest: stableDigest(records),
    files: records
  };
}

function kernelIdentity(pluginRoot) {
  const metadataFile = path.join(pluginRoot, 'kernel/metadata.js');
  delete require.cache[require.resolve(metadataFile)];
  const metadata = require(metadataFile);
  return Object.freeze({
    name: metadata.name,
    version: metadata.version,
    api_version: metadata.apiVersion,
    contract_version: metadata.contractVersion,
    contract_digest: metadata.contractDigest
  });
}

function schemaSnapshot(pluginRoot) {
  const schemaRoot = path.join(pluginRoot, 'schemas');
  const files = fs.readdirSync(schemaRoot)
    .filter((name) => name.endsWith('.schema.json'))
    .sort();
  return Object.freeze(Object.fromEntries(
    files.map((name) => [name, fileDigest(schemaRoot, name)])
  ));
}

function blockerRegistry(pluginRoot) {
  const kernelRoot = path.join(pluginRoot, 'kernel');
  const files = listFiles(kernelRoot, (relative) => relative.endsWith('.js'));
  const ids = new Set();
  for (const relative of files) {
    const source = fs.readFileSync(path.join(kernelRoot, relative), 'utf8');
    for (const match of source.matchAll(BLOCKER_LITERAL)) {
      const id = match[1];
      if (
        !IGNORED_LITERAL_PREFIXES.some((prefix) => id.startsWith(prefix))
      ) {
        ids.add(id);
      }
    }
  }
  const sorted = [...ids].sort();
  return Object.freeze({
    digest: stableDigest(sorted),
    ids: Object.freeze(sorted)
  });
}

function fixtureSnapshot(pluginRoot, fixtureRoot) {
  const manifest = readJson(path.join(fixtureRoot, 'manifest.json'));
  const canonicalModule = path.join(
    pluginRoot,
    'kernel/cases/canonical.js'
  );
  delete require.cache[require.resolve(canonicalModule)];
  const { canonicalValue } = require(canonicalModule);
  const records = [];
  for (const group of ['positive', 'negative']) {
    for (const entry of manifest[group] || []) {
      records.push({
        group,
        entity_type: entry.entity_type,
        file: entry.file,
        expected_field: entry.expected_field || null,
        value: canonicalValue(readJson(path.join(fixtureRoot, entry.file)))
      });
    }
  }
  records.sort((left, right) => (
    left.group.localeCompare(right.group)
    || left.entity_type.localeCompare(right.entity_type)
    || left.file.localeCompare(right.file)
  ));
  return Object.freeze({
    digest: stableDigest(records),
    record_count: records.length
  });
}

function reportModelSnapshot(pluginRoot, fixtureRoot) {
  const files = digestFiles(pluginRoot, REPORT_MODEL_FILES);
  const fixture = readJson(path.join(
    fixtureRoot,
    'positive/report-model.json'
  ));
  return Object.freeze({
    digest: stableDigest({
      generator_sources: files.files,
      normalized_fixture: fixture
    }),
    generator_sources: Object.freeze(files.files)
  });
}

function architectureSnapshot(pluginRoot, hostFiles) {
  const files = [...new Set(hostFiles || [])].sort();
  const records = [];
  const violations = [];
  for (const relative of files) {
    const file = path.join(pluginRoot, relative);
    if (!fs.existsSync(file) || !fs.statSync(file).isFile()) {
      violations.push({
        file: relative,
        rule: 'host-file-missing'
      });
      continue;
    }
    const source = fs.readFileSync(file, 'utf8');
    records.push({
      path: relative,
      sha256: sha256(source)
    });
    for (const rule of ARCHITECTURE_PATTERNS) {
      if (rule.pattern.test(source)) {
        violations.push({
          file: relative,
          rule: rule.id
        });
      }
    }
  }
  violations.sort((left, right) => (
    left.file.localeCompare(right.file)
    || left.rule.localeCompare(right.rule)
  ));
  return Object.freeze({
    digest: stableDigest(records),
    files: Object.freeze(records),
    violations: Object.freeze(violations)
  });
}

function manifestSnapshot(pluginRoot, manifestFile, actualKernel) {
  if (!manifestFile) {
    return Object.freeze({
      present: false,
      blockers: Object.freeze([]),
      host_files: Object.freeze([])
    });
  }
  const manifest = readJson(manifestFile);
  const blockers = [];
  const claimedKernel = manifest.kernel || {};
  if (
    claimedKernel.name !== actualKernel.name
    || claimedKernel.version !== actualKernel.version
    || claimedKernel.api_version !== actualKernel.api_version
    || claimedKernel.contract_version !== actualKernel.contract_version
    || claimedKernel.contract_digest !== actualKernel.contract_digest
  ) {
    blockers.push('manifest-kernel-identity-mismatch');
  }
  const files = Array.isArray(manifest.files)
    ? [...manifest.files].sort()
    : [];
  const missing = files.filter((relative) => (
    !fs.existsSync(path.join(pluginRoot, relative))
  ));
  if (missing.length > 0) {
    blockers.push('manifest-file-missing');
  } else if (typeof manifest.source_tree_digest === 'string') {
    const records = files.map((relative) => (
      `${relative}\0${fileDigest(pluginRoot, relative)}`
    ));
    if (sha256(records.join('\n')) !== manifest.source_tree_digest) {
      blockers.push('manifest-tree-mismatch');
    }
  }
  const hostFiles = Array.isArray(manifest.host_files)
    ? manifest.host_files
      .map((entry) => entry?.target)
      .filter((entry) => typeof entry === 'string')
      .sort()
    : [];
  return Object.freeze({
    present: true,
    schema: manifest.schema || null,
    blockers: Object.freeze(blockers.sort()),
    host_files: Object.freeze(hostFiles)
  });
}

function createCompatibilitySnapshot(options = {}) {
  const host = typeof options.host === 'string' && options.host
    ? options.host
    : 'unknown';
  const pluginRoot = assertDirectory(
    path.resolve(options.pluginRoot || ''),
    `verification-drift:plugin-root-missing:${host}`
  );
  const fixtureRoot = assertDirectory(
    path.resolve(options.fixtureRoot || ''),
    `verification-drift:fixture-root-missing:${host}`
  );
  const kernel = kernelIdentity(pluginRoot);
  const manifest = manifestSnapshot(
    pluginRoot,
    options.manifestFile ? path.resolve(options.manifestFile) : null,
    kernel
  );
  const hostFiles = options.hostFiles?.length
    ? options.hostFiles
    : manifest.host_files;
  return Object.freeze({
    schema: SNAPSHOT_SCHEMA,
    host,
    kernel,
    schemas: schemaSnapshot(pluginRoot),
    blocker_registry: blockerRegistry(pluginRoot),
    fixtures: fixtureSnapshot(pluginRoot, fixtureRoot),
    report_model: reportModelSnapshot(pluginRoot, fixtureRoot),
    architecture: architectureSnapshot(pluginRoot, hostFiles),
    manifest
  });
}

module.exports = {
  SNAPSHOT_SCHEMA,
  createCompatibilitySnapshot
};
