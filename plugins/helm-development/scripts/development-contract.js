#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const lib = require('../../helm-core/scripts/helm-lib');
const { validatePrototype } = require('../../helm-prototype/scripts/prototype-contract');

const CHANGE_ARTIFACTS = ['scope.json', 'tasks.md'];

const DEVELOPMENT_ARTIFACTS = [
  'before-dev-check.json',
  'basis.md',
  'prototype-promotion-map.json',
  'complexity-budget.json',
  'task-graph.json',
  'task-context.jsonl',
  'task-ledger.jsonl',
  'drift-check.jsonl',
  'code-owner-map.json',
  'extraction-map.json',
  'validation-log.jsonl',
  'handoff-to-verify.md'
];

const OPERATION_FIELDS = ['create', 'modify', 'delete', 'rename'];

const BRIEF_HEADINGS = [
  'Goal',
  'Parent Artifacts',
  'Vertical Slice',
  'In Scope',
  'Out Of Scope',
  'Files Allowed',
  'Interfaces / Seams',
  'Components To Create',
  'Components To Reuse',
  'Components To Extract',
  'API / Data Flow Contracts',
  'State / Error / Empty / Loading Behavior',
  'TDD Requirement',
  'Verification Commands',
  'Stop Conditions',
  'Unsafe Assumptions'
];

const HANDOFF_HEADINGS = [
  'Implemented Slices',
  'Files Changed',
  'Requirements Covered',
  'Prototype Decisions Implemented',
  'Components Created / Reused / Extracted',
  'API / Data Flow Changes',
  'Tests Added',
  'Local Validation',
  'Known Risks',
  'Items Requiring Six-Domain Verification'
];

const TASK_FILES = ['brief.md', 'context.json', 'report.md', 'spec-review.md', 'quality-review.md'];
const TASK_CONTEXT_ARRAYS = ['must_read', 'allowed_files', 'non_goals', 'expected_evidence', 'unsafe_assumptions'];
const NON_EMPTY_TASK_CONTEXT_ARRAYS = new Set(['must_read', 'allowed_files', 'non_goals', 'expected_evidence']);
const PATH_TASK_CONTEXT_ARRAYS = new Set(['must_read', 'allowed_files']);

const LAYER_ONLY_TASKS = new Set([
  'build database',
  'build the database',
  'database',
  'database layer',
  'build api',
  'build the api',
  'api',
  'api layer',
  'build ui',
  'build the ui',
  'ui',
  'ui layer'
]);

const VERTICAL_SLICE_PATTERN = /\b(?:user|users|customer|customers|admin|operator|visitor|can|view|views|see|sees|submit|submits|create|creates|update|updates|edit|edits|delete|deletes|open|opens|select|selects|search|searches|filter|filters|download|downloads|upload|uploads|receive|receives|complete|completes|checkout|login|log in|sign in|shows|display|displays|render|renders)\b/i;

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

function isCleanRelativePath(value) {
  if (!isCleanString(value)) return false;
  if (path.isAbsolute(value) || value.includes('\\') || value.includes('..')) return false;

  const segments = value.split('/');
  if (segments.some((segment) => segment === '' || segment === '.')) return false;

  return true;
}

function hasInvalidStringArrayMembers(values, pathLike = false) {
  return values.some((item) => (pathLike ? !isCleanRelativePath(item) : !isCleanString(item)));
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

function artifactPath(change, name, inDevelopment = false) {
  return path.join('openspec', 'changes', change, ...(inDevelopment ? ['development'] : []), name);
}

function artifactResult(change, name, blockers, inDevelopment = false, extra = {}) {
  return {
    name,
    path: artifactPath(change, name, inDevelopment),
    ok: blockers.length === 0,
    blockers,
    ...extra
  };
}

function realpathSync(file) {
  return (fs.realpathSync.native || fs.realpathSync)(file);
}

function isRealpathContained(root, candidate) {
  const relative = path.relative(root, candidate);
  return relative === '' || (relative !== '' && !relative.startsWith('..') && !path.isAbsolute(relative));
}

function stripListMarker(line) {
  return String(line)
    .trim()
    .replace(/^(?:[-*+]|\d+[.)])\s+/, '')
    .replace(/^\[[ xX]\]\s+/, '')
    .trim();
}

function normalizeContractText(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[`*_()[\]{}:;,.!?/\\|-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function parseMarkdownHeadings(text) {
  const lines = String(text || '').replace(/\r\n/g, '\n').split('\n');
  const headings = [];
  let fence = null;

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const fenceMatch = line.match(/^\s{0,3}(`{3,}|~{3,})/);
    if (fenceMatch) {
      const marker = fenceMatch[1][0];
      const length = fenceMatch[1].length;
      if (!fence) {
        fence = { marker, length };
      } else if (marker === fence.marker && length >= fence.length) {
        fence = null;
      }
      continue;
    }
    if (fence) continue;

    const heading = line.match(/^(#{1,6})\s+(.+?)\s*#*\s*$/);
    if (!heading) continue;
    headings.push({
      index,
      level: heading[1].length,
      label: heading[2].trim(),
      normalized: normalizeContractText(heading[2])
    });
  }

  return { lines, headings };
}

function findHeading(parsed, label) {
  const normalized = normalizeContractText(label);
  return parsed.headings.find((heading) => heading.normalized === normalized) || null;
}

function headingBodyLines(parsed, heading) {
  let end = parsed.lines.length;
  for (const next of parsed.headings) {
    if (next.index <= heading.index) continue;
    if (next.level <= heading.level) {
      end = next.index;
      break;
    }
  }
  return parsed.lines.slice(heading.index + 1, end);
}

function isPlaceholder(value) {
  const cleaned = stripListMarker(value)
    .toLowerCase()
    .replace(/^[`*_()[\]{}:;,.!?\\|]+|[`*_()[\]{}:;,.!?\\|]+$/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  if (!cleaned || /^-+$/.test(cleaned)) return true;
  return new Set(['n/a', 'na', 'none', 'not applicable']).has(cleaned);
}

function isSubstantiveLine(line) {
  const value = stripListMarker(line);
  return value !== ''
    && !/^#{1,6}\s+/.test(value)
    && !/\b(?:TODO|TBD|unresolved|gap)\b/i.test(value)
    && !isPlaceholder(value);
}

function hasSubstantiveBody(parsed, heading) {
  return headingBodyLines(parsed, heading).some((line) => isSubstantiveLine(line));
}

function firstSubstantiveValue(parsed, heading) {
  const line = headingBodyLines(parsed, heading).find((item) => isSubstantiveLine(item));
  return line ? stripListMarker(line).replace(/^`+|`+$/g, '').trim() : null;
}

function validateRequiredHeadings(text, headings, blockerPrefix) {
  const parsed = parseMarkdownHeadings(text);
  const blockers = [];

  for (const heading of headings) {
    const match = findHeading(parsed, heading);
    if (!match) {
      blockers.push(`${blockerPrefix}:missing-heading:${heading}`);
      continue;
    }
    if (!hasSubstantiveBody(parsed, match)) blockers.push(`${blockerPrefix}:empty-heading:${heading}`);
  }

  return blockers;
}

function validateScope(projectRoot, changeDir, activeChange) {
  const name = 'scope.json';
  const parsed = readJsonFile(path.join(changeDir, name));
  const blockers = [];

  if (!parsed.ok) {
    blockers.push(parsed.status === 'invalid-json' ? `invalid-json:${name}` : `missing-development-artifact:${name}`);
    return artifactResult(activeChange, name, blockers);
  }
  if (!isPlainObject(parsed.value)) {
    blockers.push(`invalid-json-shape:${name}`);
    return artifactResult(activeChange, name, blockers);
  }

  const scope = parsed.value;
  if (scope.schema_version !== 1) blockers.push('invalid-scope-contract:schema_version');
  if (scope.change_id !== activeChange) blockers.push('invalid-scope-contract:change_id');
  if (scope.stage !== 'development') blockers.push('invalid-scope-contract:stage');
  if (scope.expires_when !== 'verification_started') blockers.push('invalid-scope-contract:expires_when');

  for (const field of ['allowed_roots', 'prototype_sources']) {
    if (!Array.isArray(scope[field]) || scope[field].length === 0) {
      blockers.push(`invalid-scope-contract:${field}`);
    } else if (hasInvalidStringArrayMembers(scope[field], true)) {
      blockers.push(`invalid-scope-path:${field}`);
    }
  }

  for (const field of ['denied_roots', 'requires_review_on']) {
    if (!Array.isArray(scope[field])) {
      blockers.push(`invalid-scope-contract:${field}`);
    } else if (hasInvalidStringArrayMembers(scope[field], true)) {
      blockers.push(`invalid-scope-path:${field}`);
    }
  }

  if (!isPlainObject(scope.allowed_operations)) {
    blockers.push('invalid-scope-contract:allowed_operations');
  } else {
    for (const field of OPERATION_FIELDS) {
      if (typeof scope.allowed_operations[field] !== 'boolean') {
        blockers.push(`invalid-scope-contract:allowed_operations.${field}`);
      }
    }
  }

  if (Array.isArray(scope.prototype_sources)) {
    const prefix = `openspec/changes/${activeChange}/prototype/`;
    const prototypeRoot = path.resolve(projectRoot, prefix);
    let prototypeRealpath = null;
    try {
      prototypeRealpath = realpathSync(prototypeRoot);
    } catch {
      blockers.push('unreadable-prototype-source-root');
    }

    for (const source of scope.prototype_sources) {
      if (!isCleanRelativePath(source) || !source.startsWith(prefix) || source === prefix) {
        blockers.push(`invalid-prototype-source:${source || '<empty>'}`);
        continue;
      }

      const candidate = path.resolve(projectRoot, source);
      const relative = path.relative(prototypeRoot, candidate);
      if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) {
        blockers.push(`invalid-prototype-source:${source}`);
        continue;
      }
      if (!fs.existsSync(candidate)) {
        blockers.push(`missing-prototype-source:${source}`);
        continue;
      }
      if (prototypeRealpath) {
        try {
          const candidateRealpath = realpathSync(candidate);
          if (!isRealpathContained(prototypeRealpath, candidateRealpath)) {
            blockers.push(`prototype-source-escape:${source}`);
          }
        } catch {
          blockers.push(`unreadable-prototype-source:${source}`);
        }
      }
    }
  }

  return artifactResult(activeChange, name, unique(blockers), false, {
    allowed_roots: Array.isArray(scope.allowed_roots) ? scope.allowed_roots.length : 0,
    prototype_sources: Array.isArray(scope.prototype_sources) ? scope.prototype_sources.length : 0
  });
}

function normalizeTaskBullet(value) {
  return normalizeContractText(value).replace(/\bthe\b/g, ' ').replace(/\s+/g, ' ').trim();
}

function validateTasksMarkdown(changeDir, activeChange) {
  const name = 'tasks.md';
  const file = path.join(changeDir, name);
  const text = readTextFile(file);
  const blockers = [];

  if (!text.ok) {
    blockers.push(`missing-development-artifact:${name}`);
    return artifactResult(activeChange, name, blockers);
  }
  if (text.value.trim() === '') blockers.push(`empty-development-artifact:${name}`);

  const bullets = text.value
    .split(/\r?\n/)
    .map((line) => line.match(/^\s*(?:[-*+]|\d+[.)])\s+(.+?)\s*$/))
    .filter(Boolean)
    .map((match) => stripListMarker(match[1]))
    .filter(Boolean);

  if (bullets.length === 0) blockers.push('tasks-md:no-bullets');

  let verticalSlices = 0;
  for (const bullet of bullets) {
    const normalized = normalizeTaskBullet(bullet);
    if (LAYER_ONLY_TASKS.has(normalized)) {
      blockers.push(`tasks-md:layer-only:${normalized}`);
      continue;
    }
    if (!VERTICAL_SLICE_PATTERN.test(bullet)) {
      blockers.push(`tasks-md:not-user-visible:${normalized}`);
      continue;
    }
    verticalSlices += 1;
  }

  if (verticalSlices === 0) blockers.push('tasks-md:no-vertical-slice');

  return artifactResult(activeChange, name, unique(blockers), false, { bullet_count: bullets.length });
}

function validatePromotionMap(developmentDir, activeChange) {
  const name = 'prototype-promotion-map.json';
  const parsed = readJsonFile(path.join(developmentDir, name));
  const blockers = [];

  if (!parsed.ok) {
    blockers.push(parsed.status === 'invalid-json' ? `invalid-json:${name}` : `missing-development-artifact:${name}`);
    return artifactResult(activeChange, name, blockers, true);
  }
  if (!isPlainObject(parsed.value)) {
    blockers.push(`invalid-json-shape:${name}`);
    return artifactResult(activeChange, name, blockers, true);
  }

  const value = parsed.value;
  if (value.schema_version !== 1) blockers.push('invalid-promotion-map:schema_version');
  if (value.promotion_policy !== 'reimplement_under_development_gate') {
    blockers.push('invalid-promotion-map:promotion_policy');
  }

  for (const field of ['allowed_to_copy', 'must_reimplement', 'blocked_direct_copies']) {
    if (!Array.isArray(value[field]) || value[field].length === 0 || hasInvalidStringArrayMembers(value[field])) {
      blockers.push(`invalid-promotion-map:${field}`);
    }
  }

  return artifactResult(activeChange, name, unique(blockers), true);
}

function validateBeforeDevCheck(developmentDir, activeChange) {
  const name = 'before-dev-check.json';
  const parsed = readJsonFile(path.join(developmentDir, name));
  const blockers = [];

  if (!parsed.ok) {
    blockers.push(parsed.status === 'invalid-json' ? `invalid-json:${name}` : `missing-development-artifact:${name}`);
    return artifactResult(activeChange, name, blockers, true);
  }
  if (!isPlainObject(parsed.value)) {
    blockers.push(`invalid-json-shape:${name}`);
    return artifactResult(activeChange, name, blockers, true);
  }

  const value = parsed.value;
  const change = value.active_change || value.change_id;
  if (change !== activeChange) blockers.push('invalid-before-dev-check:active_change');

  const passed = value.ok === true
    || value.pass === true
    || ['ok', 'pass', 'passed'].includes(String(value.status || '').toLowerCase());
  if (!passed) blockers.push('invalid-before-dev-check:status');

  return artifactResult(activeChange, name, unique(blockers), true);
}

function validateBasis(developmentDir, activeChange) {
  const name = 'basis.md';
  const text = readTextFile(path.join(developmentDir, name));
  const blockers = [];

  if (!text.ok) {
    blockers.push(`missing-development-artifact:${name}`);
    return artifactResult(activeChange, name, blockers, true);
  }
  if (text.value.trim() === '') blockers.push(`empty-development-artifact:${name}`);

  const normalized = normalizeContractText(text.value);
  if (!normalized.includes('requirements')) blockers.push('invalid-basis:requirements-reference');
  if (!normalized.includes('prototype')) blockers.push('invalid-basis:prototype-reference');
  if (!normalized.includes('handoff')) blockers.push('invalid-basis:handoff-reference');

  return artifactResult(activeChange, name, unique(blockers), true);
}

function hasObjectSubstance(value) {
  if (isCleanString(value)) return true;
  if (typeof value === 'number' && Number.isFinite(value)) return true;
  if (value === true) return true;
  if (Array.isArray(value)) return value.some((item) => hasObjectSubstance(item));
  if (isPlainObject(value)) return Object.values(value).some((item) => hasObjectSubstance(item));
  return false;
}

function validateSubstantiveObjectArtifact(developmentDir, activeChange, name) {
  const parsed = readJsonFile(path.join(developmentDir, name));
  const blockers = [];

  if (!parsed.ok) {
    blockers.push(parsed.status === 'invalid-json' ? `invalid-json:${name}` : `missing-development-artifact:${name}`);
    return artifactResult(activeChange, name, blockers, true);
  }
  if (!isPlainObject(parsed.value)) {
    blockers.push(`invalid-json-shape:${name}`);
    return artifactResult(activeChange, name, blockers, true);
  }

  const payloadKeys = Object.keys(parsed.value).filter((key) => key !== 'schema_version');
  if (payloadKeys.length === 0 || !payloadKeys.some((key) => hasObjectSubstance(parsed.value[key]))) {
    blockers.push(`empty-object-contract:${name}`);
  }

  return artifactResult(activeChange, name, unique(blockers), true);
}

function parseJsonl(file, name) {
  const text = readTextFile(file);
  const blockers = [];
  const entries = [];

  if (!text.ok) {
    blockers.push(`missing-development-artifact:${name}`);
    return { blockers, entries };
  }

  const lines = text.value.split(/\r?\n/);
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index].trim();
    if (!line) continue;
    try {
      const entry = JSON.parse(line);
      if (!isPlainObject(entry)) {
        blockers.push(`invalid-jsonl-shape:${name}:${index + 1}`);
      } else {
        entries.push(entry);
      }
    } catch {
      blockers.push(`invalid-jsonl:${name}:${index + 1}`);
    }
  }

  if (entries.length === 0 && blockers.length === 0) blockers.push(`empty-jsonl:${name}`);
  return { blockers, entries };
}

function validateTaskContextLog(developmentDir, activeChange) {
  const name = 'task-context.jsonl';
  const result = parseJsonl(path.join(developmentDir, name), name);
  return artifactResult(activeChange, name, unique(result.blockers), true, { entries: result.entries.length });
}

function validateTaskLedger(developmentDir, activeChange, taskIds) {
  const name = 'task-ledger.jsonl';
  const result = parseJsonl(path.join(developmentDir, name), name);
  const blockers = [...result.blockers];

  for (const taskId of taskIds) {
    const statuses = new Set(
      result.entries
        .filter((entry) => entry.task === taskId || entry.task_id === taskId)
        .map((entry) => entry.status)
        .filter((status) => typeof status === 'string')
    );

    for (const required of ['spec_review_passed', 'quality_review_passed', 'complete']) {
      if (!statuses.has(required)) blockers.push(`task-ledger-missing-status:${taskId}:${required}`);
    }
  }

  return artifactResult(activeChange, name, unique(blockers), true, { entries: result.entries.length });
}

function validateDriftCheck(developmentDir, activeChange) {
  const name = 'drift-check.jsonl';
  const result = parseJsonl(path.join(developmentDir, name), name);
  const blockers = [...result.blockers];

  result.entries.forEach((entry, index) => {
    if (entry.blocking === true) {
      blockers.push(`blocking-drift:${entry.task || entry.task_id || index + 1}`);
    }
  });

  return artifactResult(activeChange, name, unique(blockers), true, { entries: result.entries.length });
}

function validateValidationLog(developmentDir, activeChange) {
  const name = 'validation-log.jsonl';
  const result = parseJsonl(path.join(developmentDir, name), name);
  const blockers = [...result.blockers];
  const hasPass = result.entries.some((entry) => {
    const status = String(entry.status || '').toLowerCase();
    return entry.ok === true || status === 'pass' || status === 'passed';
  });

  if (!hasPass) blockers.push('validation-log:no-pass');

  return artifactResult(activeChange, name, unique(blockers), true, { entries: result.entries.length });
}

function validateHandoffToVerify(developmentDir, activeChange) {
  const name = 'handoff-to-verify.md';
  const text = readTextFile(path.join(developmentDir, name));
  const blockers = [];

  if (!text.ok) {
    blockers.push(`missing-development-artifact:${name}`);
    return artifactResult(activeChange, name, blockers, true);
  }
  if (text.value.trim() === '') blockers.push(`empty-development-artifact:${name}`);
  blockers.push(...validateRequiredHeadings(text.value, HANDOFF_HEADINGS, 'invalid-handoff-to-verify'));

  return artifactResult(activeChange, name, unique(blockers), true);
}

function validateTaskBrief(taskDir, relativeTaskPath) {
  const name = 'brief.md';
  const text = readTextFile(path.join(taskDir, name));
  const blockers = [];

  if (!text.ok) {
    blockers.push(`missing-task-artifact:${name}`);
    return { name, path: path.join(relativeTaskPath, name), ok: false, blockers };
  }
  if (text.value.trim() === '') blockers.push(`empty-task-artifact:${name}`);
  blockers.push(...validateRequiredHeadings(text.value, BRIEF_HEADINGS, 'invalid-task-brief'));

  return { name, path: path.join(relativeTaskPath, name), ok: blockers.length === 0, blockers: unique(blockers) };
}

function validateTaskContext(taskDir, relativeTaskPath, taskId) {
  const name = 'context.json';
  const parsed = readJsonFile(path.join(taskDir, name));
  const blockers = [];

  if (!parsed.ok) {
    blockers.push(parsed.status === 'invalid-json' ? `invalid-json:${name}` : `missing-task-artifact:${name}`);
    return { name, path: path.join(relativeTaskPath, name), ok: false, blockers };
  }
  if (!isPlainObject(parsed.value)) {
    blockers.push(`invalid-json-shape:${name}`);
    return { name, path: path.join(relativeTaskPath, name), ok: false, blockers };
  }

  const value = parsed.value;
  if (!isCleanString(value.task_id) || value.task_id !== taskId) blockers.push('invalid-task-context:task_id');
  if (!isCleanString(value.goal)) blockers.push('invalid-task-context:goal');
  if (!isCleanString(value.stop_condition)) blockers.push('invalid-task-context:stop_condition');

  for (const field of TASK_CONTEXT_ARRAYS) {
    if (!Array.isArray(value[field])) {
      blockers.push(`invalid-task-context:${field}`);
      continue;
    }
    if (NON_EMPTY_TASK_CONTEXT_ARRAYS.has(field) && value[field].length === 0) {
      blockers.push(`invalid-task-context:${field}`);
      continue;
    }
    if (hasInvalidStringArrayMembers(value[field], PATH_TASK_CONTEXT_ARRAYS.has(field))) {
      blockers.push(`invalid-task-context:${field}`);
    }
  }

  return { name, path: path.join(relativeTaskPath, name), ok: blockers.length === 0, blockers: unique(blockers) };
}

function validateReport(taskDir, relativeTaskPath) {
  const name = 'report.md';
  const text = readTextFile(path.join(taskDir, name));
  const blockers = [];

  if (!text.ok) {
    blockers.push(`missing-task-artifact:${name}`);
    return { name, path: path.join(relativeTaskPath, name), ok: false, blockers };
  }
  if (text.value.trim() === '') blockers.push(`empty-task-artifact:${name}`);

  const parsed = parseMarkdownHeadings(text.value);
  const statusHeading = findHeading(parsed, 'Status');
  if (!statusHeading) {
    blockers.push('invalid-task-report:missing-status');
  } else {
    const status = firstSubstantiveValue(parsed, statusHeading);
    if (!['DONE', 'DONE_WITH_CONCERNS'].includes(status)) {
      blockers.push('invalid-task-report:status');
    }
    if (status === 'DONE_WITH_CONCERNS') {
      const concernHeading = parsed.headings.find((heading) => {
        const normalized = heading.normalized;
        return normalized.includes('concern') || normalized.includes('adjudication');
      });
      if (!concernHeading || !hasSubstantiveBody(parsed, concernHeading)) {
        blockers.push('invalid-task-report:concerns-adjudication');
      }
    }
  }

  for (const heading of ['TDD Evidence', 'Verification Commands']) {
    const match = findHeading(parsed, heading);
    if (!match) {
      blockers.push(`invalid-task-report:missing-heading:${heading}`);
      continue;
    }
    if (!hasSubstantiveBody(parsed, match)) blockers.push(`invalid-task-report:empty-heading:${heading}`);
  }

  return { name, path: path.join(relativeTaskPath, name), ok: blockers.length === 0, blockers: unique(blockers) };
}

function validateVerdictFile(taskDir, relativeTaskPath, name) {
  const text = readTextFile(path.join(taskDir, name));
  const blockers = [];
  const type = name === 'spec-review.md' ? 'spec-review' : 'quality-review';

  if (!text.ok) {
    blockers.push(`missing-task-artifact:${name}`);
    return { name, path: path.join(relativeTaskPath, name), ok: false, blockers };
  }
  if (text.value.trim() === '') blockers.push(`empty-task-artifact:${name}`);

  const parsed = parseMarkdownHeadings(text.value);
  const verdictHeading = findHeading(parsed, 'Verdict');
  if (!verdictHeading) {
    blockers.push(`invalid-${type}:missing-verdict`);
  } else {
    const verdict = firstSubstantiveValue(parsed, verdictHeading);
    if (verdict !== 'approved') blockers.push(`invalid-${type}:verdict`);
  }

  return { name, path: path.join(relativeTaskPath, name), ok: blockers.length === 0, blockers: unique(blockers) };
}

function validateTaskDir(developmentDir, activeChange, dirName) {
  const taskDir = path.join(developmentDir, 'tasks', dirName);
  const relativeTaskPath = artifactPath(activeChange, path.join('tasks', dirName), true);
  const blockers = [];
  const artifacts = [];

  if (!/^[0-9]{3}-[a-z0-9]+(?:-[a-z0-9]+)*$/.test(dirName)) {
    blockers.push(`invalid-task-dir-name:${dirName}`);
  }

  const validators = [
    () => validateTaskBrief(taskDir, relativeTaskPath),
    () => validateTaskContext(taskDir, relativeTaskPath, dirName),
    () => validateReport(taskDir, relativeTaskPath),
    () => validateVerdictFile(taskDir, relativeTaskPath, 'spec-review.md'),
    () => validateVerdictFile(taskDir, relativeTaskPath, 'quality-review.md')
  ];

  for (const validate of validators) {
    const result = validate();
    artifacts.push(result);
    blockers.push(...result.blockers);
  }

  for (const file of TASK_FILES) {
    if (!artifacts.some((artifact) => artifact.name === file)) {
      blockers.push(`missing-task-artifact:${file}`);
    }
  }

  return {
    task_id: dirName,
    path: relativeTaskPath,
    ok: blockers.length === 0,
    blockers: unique(blockers),
    artifacts
  };
}

function listTaskDirs(developmentDir) {
  const tasksDir = path.join(developmentDir, 'tasks');
  try {
    return fs.readdirSync(tasksDir)
      .filter((name) => statKind(path.join(tasksDir, name)) === 'directory')
      .sort();
  } catch {
    return null;
  }
}

function validateDevelopment(root = lib.projectRoot()) {
  const projectRoot = path.resolve(root);
  const prototype = validatePrototype(projectRoot);

  if (!prototype.ok) {
    const activeChange = prototype.active_change || null;
    const changeDir = activeChange ? lib.changeDir(projectRoot, activeChange) : null;
    return {
      ok: false,
      project_root: projectRoot,
      active_change: activeChange,
      change_dir: changeDir,
      development_dir: changeDir ? path.join(changeDir, 'development') : null,
      blockers: unique(['prototype-blocked', ...(prototype.blockers || []).map((blocker) => `prototype:${blocker}`)]),
      prototype,
      artifacts: [],
      tasks: []
    };
  }

  const activeChange = prototype.active_change;
  const changeDir = lib.changeDir(projectRoot, activeChange);
  const developmentDir = path.join(changeDir, 'development');
  const artifacts = [];
  const tasks = [];
  const blockers = [];

  artifacts.push(validateScope(projectRoot, changeDir, activeChange));
  artifacts.push(validateTasksMarkdown(changeDir, activeChange));
  artifacts.push(validateBeforeDevCheck(developmentDir, activeChange));
  artifacts.push(validateBasis(developmentDir, activeChange));
  artifacts.push(validatePromotionMap(developmentDir, activeChange));

  for (const name of ['complexity-budget.json', 'task-graph.json', 'code-owner-map.json', 'extraction-map.json']) {
    artifacts.push(validateSubstantiveObjectArtifact(developmentDir, activeChange, name));
  }

  const taskDirs = listTaskDirs(developmentDir);
  if (taskDirs === null) {
    blockers.push('missing-development-tasks-dir');
  } else if (taskDirs.length === 0) {
    blockers.push('missing-development-task-dir');
  } else {
    for (const dirName of taskDirs) tasks.push(validateTaskDir(developmentDir, activeChange, dirName));
  }

  const taskIds = tasks.map((task) => task.task_id);
  artifacts.push(validateTaskContextLog(developmentDir, activeChange));
  artifacts.push(validateTaskLedger(developmentDir, activeChange, taskIds));
  artifacts.push(validateDriftCheck(developmentDir, activeChange));
  artifacts.push(validateValidationLog(developmentDir, activeChange));
  artifacts.push(validateHandoffToVerify(developmentDir, activeChange));

  for (const name of CHANGE_ARTIFACTS) {
    if (!artifacts.some((artifact) => artifact.name === name)) {
      artifacts.push(artifactResult(activeChange, name, [`missing-development-artifact:${name}`]));
    }
  }
  for (const name of DEVELOPMENT_ARTIFACTS) {
    if (!artifacts.some((artifact) => artifact.name === name)) {
      artifacts.push(artifactResult(activeChange, name, [`missing-development-artifact:${name}`], true));
    }
  }

  blockers.push(...artifacts.flatMap((artifact) => artifact.blockers));
  blockers.push(...tasks.flatMap((task) => task.blockers));

  return {
    ok: blockers.length === 0,
    project_root: projectRoot,
    active_change: activeChange,
    change_dir: changeDir,
    development_dir: developmentDir,
    blockers: unique(blockers),
    prototype,
    artifacts,
    tasks
  };
}

function markdown(result) {
  const lines = [];
  lines.push('# Helm Development Contract');
  lines.push('');
  lines.push(`- project: \`${result.project_root}\``);
  lines.push(`- active change: \`${result.active_change || 'none'}\``);
  lines.push(`- change dir: \`${result.change_dir || 'none'}\``);
  lines.push(`- development dir: \`${result.development_dir || 'none'}\``);
  lines.push(`- ok: ${result.ok}`);
  if (result.blockers.length) lines.push(`- blockers: ${result.blockers.join(', ')}`);
  lines.push('');
  lines.push('| Artifact | Status | Blockers |');
  lines.push('| --- | --- | --- |');
  for (const artifact of result.artifacts) {
    lines.push(`| ${artifact.name} | ${artifact.ok ? 'pass' : 'blocked'} | ${artifact.blockers.join('<br>') || '-'} |`);
  }
  lines.push('');
  lines.push('| Task | Status | Blockers |');
  lines.push('| --- | --- | --- |');
  for (const task of result.tasks) {
    lines.push(`| ${task.task_id} | ${task.ok ? 'pass' : 'blocked'} | ${task.blockers.join('<br>') || '-'} |`);
  }
  return `${lines.join('\n')}\n`;
}

function main() {
  const result = validateDevelopment();
  process.stdout.write(process.argv.includes('--json') ? `${JSON.stringify(result, null, 2)}\n` : markdown(result));
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = { validateDevelopment };
