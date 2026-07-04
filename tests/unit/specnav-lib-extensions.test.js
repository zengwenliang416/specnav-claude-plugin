'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');

const lib = require('../../plugins/specnav-core/scripts/specnav-lib');

function tempDir(prefix) {
  return fs.mkdtempSync(path.join(os.tmpdir(), prefix));
}

// --- readLane ---

test('readLane: absent risk-tier.json defaults to standard', () => {
  const dir = tempDir('lane-');
  const lane = lib.readLane(dir);
  assert.equal(lane.lane, 'standard');
  assert.equal(lane.source, 'default');
});

test('readLane: malformed json defaults to standard (lanes only loosen when declared)', () => {
  const dir = tempDir('lane-');
  fs.writeFileSync(path.join(dir, 'risk-tier.json'), 'not-json');
  assert.equal(lib.readLane(dir).lane, 'standard');
});

test('readLane: explicit light lane is honored', () => {
  const dir = tempDir('lane-');
  fs.writeFileSync(path.join(dir, 'risk-tier.json'), JSON.stringify({
    tier: 'lite', lane: 'light', escalation_threshold: 5
  }));
  const lane = lib.readLane(dir);
  assert.equal(lane.lane, 'light');
  assert.equal(lane.escalation_threshold, 5);
});

test('readLane: unknown lane value falls back by tier', () => {
  const dir = tempDir('lane-');
  fs.writeFileSync(path.join(dir, 'risk-tier.json'), JSON.stringify({
    tier: 'high-risk', lane: 'turbo'
  }));
  assert.equal(lib.readLane(dir).lane, 'full');
});

// --- acceptance assertions ---

test('readAcceptanceAssertions: absent file is non-blocking', () => {
  const dir = tempDir('acc-');
  const result = lib.readAcceptanceAssertions(dir);
  assert.equal(result.present, false);
  assert.equal(result.ok, true);
});

test('readAcceptanceAssertions: valid list with evidence-backed pass', () => {
  const dir = tempDir('acc-');
  fs.writeFileSync(path.join(dir, 'acceptance.json'), JSON.stringify({
    assertions: [
      { id: 'A1', statement: 's', verify_via: 'unit', status: 'failing', evidence_ref: null },
      { id: 'A2', statement: 't', verify_via: 'e2e', status: 'passing', evidence_ref: 'verify/e2e/report.json' }
    ]
  }));
  const result = lib.readAcceptanceAssertions(dir);
  assert.equal(result.ok, true);
  assert.equal(result.assertions.length, 2);
});

test('readAcceptanceAssertions: passing without evidence, dup ids, bad enums are named blockers', () => {
  const dir = tempDir('acc-');
  fs.writeFileSync(path.join(dir, 'acceptance.json'), JSON.stringify({
    assertions: [
      { id: 'A1', statement: 's', verify_via: 'vibes', status: 'passing', evidence_ref: null },
      { id: 'A1', statement: 't', verify_via: 'unit', status: 'maybe' }
    ]
  }));
  const result = lib.readAcceptanceAssertions(dir);
  assert.equal(result.ok, false);
  assert.ok(result.blockers.includes('acceptance-json:passing-without-evidence:A1'));
  assert.ok(result.blockers.includes('acceptance-json:invalid-verify-via:A1'));
  assert.ok(result.blockers.includes('acceptance-json:duplicate-id:A1'));
  assert.ok(result.blockers.includes('acceptance-json:invalid-status:A1'));
});

test('readAcceptanceAssertions: empty assertion list is a blocker', () => {
  const dir = tempDir('acc-');
  fs.writeFileSync(path.join(dir, 'acceptance.json'), JSON.stringify({ assertions: [] }));
  assert.ok(lib.readAcceptanceAssertions(dir).blockers.includes('acceptance-json:no-assertions'));
});

test('acceptanceAssertionsDigest: status flips keep the digest, rewording changes it', () => {
  const base = [
    { id: 'A1', statement: 's', verify_via: 'unit', status: 'failing' },
    { id: 'A2', statement: 't', verify_via: 'e2e', status: 'failing' }
  ];
  const flipped = [
    { id: 'A2', statement: 't', verify_via: 'e2e', status: 'passing', evidence_ref: 'x' },
    { id: 'A1', statement: 's', verify_via: 'unit', status: 'failing' }
  ];
  const reworded = [
    { id: 'A1', statement: 's weakened', verify_via: 'unit', status: 'failing' },
    { id: 'A2', statement: 't', verify_via: 'e2e', status: 'failing' }
  ];
  assert.equal(lib.acceptanceAssertionsDigest(base), lib.acceptanceAssertionsDigest(flipped));
  assert.notEqual(lib.acceptanceAssertionsDigest(base), lib.acceptanceAssertionsDigest(reworded));
});

// --- session lock ---

function projectWithOpenspec() {
  const root = tempDir('lock-');
  fs.mkdirSync(path.join(root, 'openspec', '.specnav'), { recursive: true });
  return root;
}

test('acquireSessionLock: first session acquires, same session renews', () => {
  const root = projectWithOpenspec();
  const first = lib.acquireSessionLock(root, { sessionId: 's1' });
  assert.equal(first.acquired, true);
  assert.equal(first.reason, 'acquired');
  const renew = lib.acquireSessionLock(root, { sessionId: 's1' });
  assert.equal(renew.reason, 'renewed');
});

test('acquireSessionLock: foreign active lease blocks without evicting', () => {
  const root = projectWithOpenspec();
  lib.acquireSessionLock(root, { sessionId: 's1' });
  const second = lib.acquireSessionLock(root, { sessionId: 's2' });
  assert.equal(second.acquired, false);
  assert.equal(second.reason, 'held-by-other');
  assert.equal(lib.readSessionLock(root).session_id, 's1');
});

test('acquireSessionLock: expired lease is taken over', () => {
  const root = projectWithOpenspec();
  lib.acquireSessionLock(root, { sessionId: 'old', ttlMinutes: -1 });
  const takeover = lib.acquireSessionLock(root, { sessionId: 'new' });
  assert.equal(takeover.acquired, true);
  assert.equal(lib.readSessionLock(root).session_id, 'new');
});

test('acquireSessionLock: missing session id degrades gracefully', () => {
  const root = projectWithOpenspec();
  const result = lib.acquireSessionLock(root, {});
  assert.equal(result.acquired, false);
  assert.equal(result.reason, 'no-session-id');
});
