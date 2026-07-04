#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const lib = require('./specnav-lib');
const workflow = require('./workflow-state');
const guard = require('./specnav-guard');

function readStdinJson() {
  try {
    const input = fs.readFileSync(0, 'utf8').trim();
    return input ? JSON.parse(input) : {};
  } catch {
    return {};
  }
}

function runGuardSelfCheck(root) {
  const check = guard.selfCheck();
  if (check.ok) return { ok: true };
  const detail = check.failures.map((failure) => `${failure.case}: ${failure.reason}`).join('; ');
  lib.event(root, 'guard.selfcheck-failed', { failures: check.failures });
  return { ok: false, detail };
}

const MAX_JOURNAL_TAIL_CHARS = 600;

function startupRitual(root, state) {
  // Startup ritual: a compact, bounded state snapshot so a fresh session
  // (or one resuming after compaction) starts from recorded state instead of
  // guessing. Deliberately small — context is a budget, not a dump.
  const specnavDir = lib.specnavDir(root);
  const ritual = {
    active_change: state.active_change || null,
    ready_actions: (state.actions || [])
      .filter((action) => action.state === 'ready')
      .map((action) => action.id),
    blockers: (state.blockers || []).slice(0, 10)
  };

  const change = state.active_change;
  const changeDir = change ? lib.changeDir(root, change) : null;
  if (changeDir) {
    const acceptance = lib.readAcceptanceAssertions(changeDir);
    if (acceptance.present) {
      ritual.acceptance = {
        total: acceptance.assertions.length,
        failing: acceptance.assertions.filter((assertion) => assertion.status !== 'passing').length
      };
    }
    ritual.verify_stale = lib.fileExists(path.join(changeDir, 'verify-report.stale'));
  }

  const journalIndex = lib.readText(path.join(specnavDir, 'journal', 'index.md'));
  if (journalIndex) {
    const latest = journalIndex.match(/- latest:\s*(\S+)/);
    if (latest) {
      const tail = lib.readText(path.join(specnavDir, 'journal', latest[1]));
      if (tail) ritual.last_session_journal = tail.slice(-MAX_JOURNAL_TAIL_CHARS);
    }
  }
  return ritual;
}

function acquireLock(root, payload) {
  const sessionId = typeof payload.session_id === 'string' && payload.session_id
    ? payload.session_id
    : (process.env.CLAUDE_SESSION_ID || null);
  const result = lib.acquireSessionLock(root, { sessionId, host: 'claude' });
  if (result.acquired || result.reason === 'no-session-id') return { blocked: false, result };
  return { blocked: true, result };
}

function main() {
  const root = lib.projectRoot();
  const payload = readStdinJson();
  if (!fs.existsSync(lib.openspecDir(root))) {
    if (lib.isSpecNavProject(root)) {
      const result = {
        schema: 'specnav.sessionStart.v1',
        status: 'blocked',
        blockers: ['missing-openspec'],
        project_root: root,
        allowed_actions: [
          '/specnav-bootstrap',
          '/specnav-status',
          '/specnav-doctor'
        ],
        recommended_command: '/specnav-bootstrap'
      };
      process.stderr.write(`[specnav] missing-openspec: run /specnav-bootstrap to initialize OpenSpec for ${root} before production work.\n`);
      process.stdout.write(`${JSON.stringify(result)}\n`);
      return;
    }
    process.stdout.write(`${JSON.stringify({
      schema: 'specnav.sessionStart.v1',
      status: 'inactive',
      project_root: root
    })}\n`);
    return;
  }

  const state = workflow.writeRuntimeArtifacts(root);
  const legacyEntrypoints = lib.detectLegacyOpenSpecEntrypoints(root);
  const selfCheck = runGuardSelfCheck(root);
  const lock = acquireLock(root, payload);
  const extraBlockers = [];
  const systemMessages = [];
  if (!selfCheck.ok) {
    extraBlockers.push('guard-selfcheck-failed');
    systemMessages.push(`SpecNav guard self-check FAILED (${selfCheck.detail}). The PreToolUse gate may not be enforcing scope; do not trust gate decisions until /specnav-doctor passes.`);
  }
  if (lock.blocked) {
    extraBlockers.push('session-lock:held-by-other');
    systemMessages.push(`Another ${lock.result.lock.host} session (${lock.result.lock.session_id}) holds the SpecNav lock until ${lock.result.lock.expires_at}. Coordinate or wait for expiry; to take over deliberately, delete openspec/.specnav/session-lock and restart.`);
  }
  lib.event(root, 'session.start', { cwd: root, status: state.status, session_lock: lock.result.reason });
  process.stdout.write(`${JSON.stringify({
    schema: 'specnav.sessionStart.v1',
    status: extraBlockers.length ? 'blocked' : state.status,
    project_root: root,
    blockers: Array.from(new Set([...state.blockers, ...extraBlockers])),
    guard_selfcheck: selfCheck.ok ? 'ok' : 'failed',
    session_lock: lock.result.reason,
    ...(systemMessages.length ? { systemMessage: systemMessages.join(' ') } : {}),
    ritual: startupRitual(root, state),
    legacy_openspec_entrypoints: legacyEntrypoints,
    native_openspec_skills: 'disabled when SpecNav is active; use OpenSpec CLI only as commanded by SpecNav contracts',
    completion_rule: 'do not claim a stage complete or hand off until the owning SpecNav contract returns ok:true',
    workflow_state: 'openspec/.specnav/workflow-state.json'
  })}\n`);
}

main();
