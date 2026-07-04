'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const guard = require('../../plugins/specnav-core/scripts/specnav-guard');

test('normalizePayload: stable fields extract without fallback flags', () => {
  const result = guard.normalizePayload({
    tool_name: 'Write',
    tool_input: { file_path: 'src/a.ts', content: 'x' }
  });
  assert.equal(result.tool, 'Write');
  assert.deepEqual(result.paths, ['src/a.ts']);
  assert.deepEqual(result.fallback_fields, []);
});

test('normalizePayload: notebook_path is a stable field', () => {
  const result = guard.normalizePayload({
    tool_name: 'NotebookEdit',
    tool_input: { notebook_path: 'nb/analysis.ipynb' }
  });
  assert.deepEqual(result.paths, ['nb/analysis.ipynb']);
  assert.deepEqual(result.fallback_fields, []);
});

test('normalizePayload: bash command extracted, no paths', () => {
  const result = guard.normalizePayload({
    tool_name: 'Bash',
    tool_input: { command: 'npm test' }
  });
  assert.equal(result.command, 'npm test');
  assert.deepEqual(result.paths, []);
});

test('normalizePayload: fallback fields are collected AND reported', () => {
  const result = guard.normalizePayload({
    tool_name: 'Write',
    tool_input: { target_path: 'src/b.ts' }
  });
  assert.deepEqual(result.paths, ['src/b.ts']);
  assert.ok(result.fallback_fields.includes('target_path'));
});

test('normalizePayload: nested edits arrays are traversed', () => {
  const result = guard.normalizePayload({
    tool_name: 'MultiEdit',
    tool_input: {
      file_path: 'src/a.ts',
      edits: [{ file_path: 'src/hidden.ts', old_string: 'x', new_string: 'y' }]
    }
  });
  assert.ok(result.paths.includes('src/a.ts'));
  assert.ok(result.paths.includes('src/hidden.ts'));
  assert.ok(result.fallback_fields.some((field) => field.startsWith('nested:')));
});

test('normalizePayload: empty and malformed input degrade to empty result', () => {
  assert.deepEqual(guard.normalizePayload({}).paths, []);
  assert.deepEqual(guard.normalizePayload({ tool_input: null }).paths, []);
  assert.equal(guard.normalizePayload({ tool_input: { command: 42 } }).command, '');
});

test('selfCheck: passes against the real normalizePayload', () => {
  const result = guard.selfCheck();
  assert.equal(result.ok, true);
  assert.deepEqual(result.failures, []);
});

test('selfCheck: detects a broken normalizer', () => {
  const result = guard.selfCheck({ normalize: () => null });
  assert.equal(result.ok, false);
  assert.equal(result.failures.length, 3);
});

test('selfCheck: detects a throwing normalizer', () => {
  const result = guard.selfCheck({ normalize: () => { throw new Error('payload shape changed'); } });
  assert.equal(result.ok, false);
  assert.ok(result.failures[0].reason.includes('payload shape changed'));
});

test('pathAllowedByScope: include/exclude precedence', () => {
  const scope = { include: ['src/**'], exclude: ['src/private/**'] };
  assert.equal(guard.pathAllowedByScope(scope, 'src/app.ts').ok, true);
  assert.equal(guard.pathAllowedByScope(scope, 'src/private/key.ts').ok, false);
  assert.equal(guard.pathAllowedByScope(scope, 'docs/readme.md').ok, false);
  assert.equal(guard.pathAllowedByScope({ include: [], exclude: [] }, 'src/app.ts').reason, 'missing-allowed-roots');
});
