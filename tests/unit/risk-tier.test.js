'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { classify } = require('../../plugins/specnav-core/scripts/risk-tier');

test('classify: docs-only paths route to the light lane', () => {
  const result = classify(['docs/readme.md', 'CHANGELOG.md']);
  assert.equal(result.tier, 'lite');
  assert.equal(result.lane, 'light');
  assert.equal(result.escalation_threshold, 10);
  assert.ok(result.reason.length > 0);
});

test('classify: src paths route to the standard lane', () => {
  const result = classify(['src/ui/button.tsx']);
  assert.equal(result.tier, 'standard');
  assert.equal(result.lane, 'standard');
});

test('classify: high-risk triggers route to the full lane with named triggers', () => {
  const result = classify(['src/auth/login.ts']);
  assert.equal(result.tier, 'high-risk');
  assert.equal(result.lane, 'full');
  assert.ok(result.triggers.includes('src/auth/login.ts'));
  assert.ok(result.reason.includes('src/auth/login.ts'));
});

test('classify: one high-risk path escalates the whole change', () => {
  const result = classify(['docs/readme.md', 'migrations/001-init.sql']);
  assert.equal(result.lane, 'full');
});

test('classify: lockfiles are high-risk', () => {
  assert.equal(classify(['package.json']).tier, 'high-risk');
  assert.equal(classify(['pnpm-lock.yaml']).tier, 'high-risk');
});

test('classify: empty path list defaults to light', () => {
  assert.equal(classify([]).lane, 'light');
});
