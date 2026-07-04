'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { analyze, toMarkdown } = require('../../plugins/specnav-core/scripts/gate-effectiveness');

function projectWithEvents(lines) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'gate-eff-test-'));
  fs.mkdirSync(path.join(root, 'openspec', '.specnav'), { recursive: true });
  fs.writeFileSync(
    path.join(root, 'openspec', '.specnav', 'events.jsonl'),
    lines.map((line) => JSON.stringify(line)).join('\n') + '\n'
  );
  return root;
}

test('analyze: override rate and signals computed per gate', () => {
  const events = [];
  for (let i = 0; i < 6; i += 1) events.push({ type: 'hook.deny', payload: { reason: 'scope' } });
  for (let i = 0; i < 4; i += 1) events.push({ type: 'hook.override', payload: { gate: 'scope' } });
  for (let i = 0; i < 6; i += 1) events.push({ type: 'hook.deny', payload: { reason: 'dangerous-command' } });
  const report = analyze(projectWithEvents(events));

  const scope = report.gates.find((row) => row.gate === 'scope');
  assert.equal(scope.denies, 6);
  assert.equal(scope.overrides, 4);
  assert.equal(scope.override_rate, 0.4);
  assert.equal(scope.signal, 'review-criteria');

  const danger = report.gates.find((row) => row.gate === 'dangerous-command');
  assert.equal(danger.override_rate, 0);
  assert.equal(danger.signal, 'healthy');
});

test('analyze: majority-overridden gate flags candidate-wrong-gate', () => {
  const events = [];
  for (let i = 0; i < 3; i += 1) events.push({ type: 'hook.deny', payload: { reason: 'g' } });
  for (let i = 0; i < 5; i += 1) events.push({ type: 'hook.override', payload: { gate: 'g' } });
  const report = analyze(projectWithEvents(events));
  assert.equal(report.gates[0].signal, 'candidate-wrong-gate');
});

test('analyze: small samples flagged insufficient', () => {
  const report = analyze(projectWithEvents([
    { type: 'hook.warn', payload: { reason: 'requires-review' } }
  ]));
  assert.equal(report.gates[0].signal, 'insufficient-sample');
});

test('analyze: red verify after allows counts as false-negative signal', () => {
  const report = analyze(projectWithEvents([
    { type: 'hook.allow', payload: { reason: 'within-scope' } },
    { type: 'verify', payload: { status: 'red' } },
    { type: 'hook.allow', payload: { reason: 'within-scope' } },
    { type: 'verify', payload: { status: 'green' } }
  ]));
  assert.equal(report.totals.red_verifies_after_allows, 1);
  assert.equal(report.totals.verifies, 2);
});

test('analyze: missing events file yields empty report, no crash', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'gate-eff-empty-'));
  fs.mkdirSync(path.join(root, 'openspec', '.specnav'), { recursive: true });
  const report = analyze(root);
  assert.equal(report.events_analyzed, 0);
  assert.deepEqual(report.gates, []);
});

test('analyze: malformed jsonl lines are skipped', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'gate-eff-bad-'));
  fs.mkdirSync(path.join(root, 'openspec', '.specnav'), { recursive: true });
  fs.writeFileSync(
    path.join(root, 'openspec', '.specnav', 'events.jsonl'),
    'not-json\n{"type":"hook.deny","payload":{"reason":"scope"}}\n'
  );
  const report = analyze(root);
  assert.equal(report.events_analyzed, 1);
});

test('toMarkdown: renders a table with gate rows', () => {
  const md = toMarkdown(analyze(projectWithEvents([
    { type: 'hook.deny', payload: { reason: 'scope' } }
  ])));
  assert.ok(md.includes('| scope |'));
  assert.ok(md.includes('Decision rules'));
});
