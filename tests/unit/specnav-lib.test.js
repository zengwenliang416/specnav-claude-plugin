'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const lib = require('../../plugins/specnav-core/scripts/specnav-lib');

function tempProject(build) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'specnav-lib-test-'));
  build(root);
  return root;
}

function write(root, rel, content) {
  const file = path.join(root, rel);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
}

test('globLikeMatch: exact file path', () => {
  assert.equal(lib.globLikeMatch('src/app.js', 'src/app.js'), true);
  assert.equal(lib.globLikeMatch('src/app.js', 'src/other.js'), false);
});

test('globLikeMatch: single star stays within one segment', () => {
  assert.equal(lib.globLikeMatch('src/*.js', 'src/app.js'), true);
  assert.equal(lib.globLikeMatch('src/*.js', 'src/nested/app.js'), false);
});

test('globLikeMatch: double star crosses segments', () => {
  assert.equal(lib.globLikeMatch('src/**', 'src/nested/deep/app.js'), true);
  assert.equal(lib.globLikeMatch('src/ui/**', 'src/ui/button.tsx'), true);
  assert.equal(lib.globLikeMatch('src/ui/**', 'src/api/handler.ts'), false);
});

test('globLikeMatch: trailing ** matches children but not the bare root', () => {
  assert.equal(lib.globLikeMatch('docs/**', 'docs/readme.md'), true);
  assert.equal(lib.globLikeMatch('docs/**', 'docs'), false);
});

test('globLikeMatch: regex metacharacters in paths are treated literally', () => {
  assert.equal(lib.globLikeMatch('a+b/(c)/**', 'a+b/(c)/d.txt'), true);
  assert.equal(lib.globLikeMatch('a.b', 'axb'), false);
});

// KNOWN DEFECT (pinned, not endorsed): the startsWith fallback intended for
// trailing-** patterns applies to every pattern, so an exact allowed root
// also admits any path it prefixes. This widens scope.json enforcement in
// specnav-guard. Fix is out of scope for upgrade-c0 (plugins/** is denied);
// routed to the guard-hardening change (C4). These assertions pin the
// current behavior so the fix must consciously flip them.
test('globLikeMatch: KNOWN DEFECT - exact pattern also prefix-matches longer paths', () => {
  assert.equal(lib.globLikeMatch('src/app.js', 'src/app.jsx'), true);
  assert.equal(lib.globLikeMatch('src/ui', 'src/ui-private/secret.ts'), true);
});

test('parseScope: extracts bullet entries under the File scope heading only', () => {
  const design = [
    '# Design',
    '',
    '## Approach',
    '- not a scope entry',
    '',
    '## File scope',
    '- `src/ui/**`',
    '* tests/ui/**',
    '',
    '## Risks',
    '- also not a scope entry'
  ].join('\n');
  assert.deepEqual(lib.parseScope(design), ['src/ui/**', 'tests/ui/**']);
});

test('parseScope: returns empty list when no File scope section exists', () => {
  assert.deepEqual(lib.parseScope('# Design\n\n## Approach\n- something\n'), []);
});

test('readFileScope: missing scope.json is a named blocker', () => {
  const root = tempProject(() => {});
  const scope = lib.readFileScope(root);
  assert.equal(scope.ok, false);
  assert.deepEqual(scope.blockers, ['missing-scope-json']);
});

test('readFileScope: invalid JSON is distinguished from missing', () => {
  const root = tempProject((r) => write(r, 'scope.json', '{not-json'));
  const scope = lib.readFileScope(root);
  assert.equal(scope.ok, false);
  assert.deepEqual(scope.blockers, ['invalid-scope-json']);
});

test('readFileScope: allowed_roots/denied_roots map to include/exclude', () => {
  const root = tempProject((r) => write(r, 'scope.json', JSON.stringify({
    allowed_roots: ['src/**', 'tests/**'],
    denied_roots: ['src/private/**'],
    allowed_operations: { create: true, delete: false },
    requires_review_on: ['src/shared/**', '  ']
  })));
  const scope = lib.readFileScope(root);
  assert.equal(scope.ok, true);
  assert.deepEqual(scope.include, ['src/**', 'tests/**']);
  assert.deepEqual(scope.exclude, ['src/private/**']);
  assert.deepEqual(scope.operations, { create: true, delete: false });
  assert.deepEqual(scope.reviewRequired, ['src/shared/**']);
});

test('readFileScope: empty allowed_roots blocks with missing-scope-allowed-roots', () => {
  const root = tempProject((r) => write(r, 'scope.json', JSON.stringify({ allowed_roots: [] })));
  const scope = lib.readFileScope(root);
  assert.equal(scope.ok, false);
  assert.ok(scope.blockers.includes('missing-scope-allowed-roots'));
});

test('activeChangeState: no changes yields active-change blocker', () => {
  const root = tempProject((r) => {
    fs.mkdirSync(path.join(r, 'openspec', 'changes'), { recursive: true });
  });
  const state = lib.activeChangeState(root);
  assert.equal(state.change, null);
  assert.equal(state.source, 'no-active-change');
  assert.deepEqual(state.blockers, ['active-change']);
});

test('activeChangeState: a single change is inferred', () => {
  const root = tempProject((r) => {
    fs.mkdirSync(path.join(r, 'openspec', 'changes', 'only-change'), { recursive: true });
  });
  const state = lib.activeChangeState(root);
  assert.equal(state.change, 'only-change');
  assert.equal(state.source, 'single-change');
  assert.deepEqual(state.blockers, []);
});

test('activeChangeState: multiple changes without focus are ambiguous', () => {
  const root = tempProject((r) => {
    fs.mkdirSync(path.join(r, 'openspec', 'changes', 'change-a'), { recursive: true });
    fs.mkdirSync(path.join(r, 'openspec', 'changes', 'change-b'), { recursive: true });
  });
  const state = lib.activeChangeState(root);
  assert.equal(state.change, null);
  assert.equal(state.source, 'ambiguous');
  assert.deepEqual(state.blockers, ['ambiguous-change']);
  assert.deepEqual(state.candidates.sort(), ['change-a', 'change-b']);
});

test('activeChangeState: active-change file wins over inference', () => {
  const root = tempProject((r) => {
    fs.mkdirSync(path.join(r, 'openspec', 'changes', 'change-a'), { recursive: true });
    fs.mkdirSync(path.join(r, 'openspec', 'changes', 'change-b'), { recursive: true });
    write(r, 'openspec/.specnav/active-change', 'change-b\n');
  });
  const state = lib.activeChangeState(root);
  assert.equal(state.change, 'change-b');
  assert.equal(state.source, 'active-change-file');
});

test('activeChangeState: stale active-change file pointing nowhere blocks', () => {
  const root = tempProject((r) => {
    fs.mkdirSync(path.join(r, 'openspec', 'changes', 'change-a'), { recursive: true });
    write(r, 'openspec/.specnav/active-change', 'deleted-change\n');
  });
  const state = lib.activeChangeState(root);
  assert.equal(state.change, null);
  assert.deepEqual(state.blockers, ['active-change']);
});

test('activeChangeState: explicit option beats files and inference', () => {
  const root = tempProject((r) => {
    fs.mkdirSync(path.join(r, 'openspec', 'changes', 'change-a'), { recursive: true });
    fs.mkdirSync(path.join(r, 'openspec', 'changes', 'change-b'), { recursive: true });
  });
  const state = lib.activeChangeState(root, { change: 'change-a' });
  assert.equal(state.change, 'change-a');
  assert.equal(state.source, 'argument');
});

test('activeChangeState: explicit unknown change blocks instead of falling back', () => {
  const root = tempProject((r) => {
    fs.mkdirSync(path.join(r, 'openspec', 'changes', 'change-a'), { recursive: true });
  });
  const state = lib.activeChangeState(root, { change: 'nope' });
  assert.equal(state.change, null);
  assert.equal(state.source, 'explicit');
  assert.deepEqual(state.blockers, ['active-change']);
});
