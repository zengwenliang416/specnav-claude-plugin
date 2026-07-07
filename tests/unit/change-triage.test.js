const assert = require('node:assert/strict');
const test = require('node:test');

const { extractPathsFromIntent, splitPaths, triageChange } = require('../../plugins/specnav-core/scripts/change-triage');

test('splitPaths accepts comma and newline separated paths', () => {
  assert.deepEqual(splitPaths('README.md,docs/a.md\nsrc/a.ts'), ['README.md', 'docs/a.md', 'src/a.ts']);
});

test('extractPathsFromIntent finds common path tokens', () => {
  assert.deepEqual(extractPathsFromIntent('fix typo in `docs/readme.md` and src/button.tsx'), ['docs/readme.md', 'src/button.tsx']);
});

test('docs and copy changes route to the light lane', () => {
  const result = triageChange({ intent: 'fix typo in README copy', paths: ['README.md'] });
  assert.equal(result.lane, 'light');
  assert.equal(result.tier, 'lite');
  assert.deepEqual(result.verification_domains, ['static', 'unit']);
  assert.ok(result.skipped_gates.includes('runnable-prototype'));
});

test('feature work routes to the standard lane', () => {
  const result = triageChange({ intent: 'add payroll overview page', paths: ['src/pages/payroll.tsx'] });
  assert.equal(result.lane, 'standard');
});

test('security and API work routes to the full lane', () => {
  const result = triageChange({ intent: 'fix auth API permission bug', paths: ['src/auth/login.ts'] });
  assert.equal(result.lane, 'full');
  assert.equal(result.tier, 'high-risk');
});
