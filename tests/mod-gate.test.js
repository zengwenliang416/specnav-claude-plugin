'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const { pathToFileURL } = require('url');

const CORE = path.resolve(__dirname, '../plugins/specnav-core');
const GUARD = path.join(CORE, 'scripts/specnav-guard.js');
const REGISTER_URL = pathToFileURL(path.join(CORE, 'hooks/register.mjs')).href;

async function loadRegister() {
  const mod = await import(REGISTER_URL);
  return mod.register;
}

function recordedHooks(register) {
  const hooks = [];
  register((event, handler) => {
    hooks.push({ event, handler });
    return { catch() {} };
  });
  return hooks;
}

function handlerFor(hooks, event) {
  const found = hooks.filter((item) => item.event === event);
  assert.equal(found.length, 1, event);
  return found[0].handler;
}

function makeDollar(overrides = {}) {
  const calls = { run: [], write: [], status: [], register: [] };
  const dollar = {
    plugin: { name: 'specnav-core', root: CORE },
    session: {
      async root() { return overrides.root || '/tmp/specnav-mod-project'; },
      async id() { return overrides.sessionId || 's-test'; }
    },
    process: {
      async run(argv, init) {
        calls.run.push({ argv, init });
        if (overrides.run) return overrides.run(argv, init);
        return { exitCode: 0, stdout: 'SpecNav: ready change=none ready=[] blockers=[]\n', stderr: '' };
      }
    },
    fs: {
      async write(file, text) {
        calls.write.push({ file, text });
        if (overrides.write) return overrides.write(file, text);
      }
    },
    ui: {
      status(text) { calls.status.push(text); }
    },
    command: {
      async register(spec) {
        calls.register.push(spec);
        if (overrides.register) return overrides.register(spec);
      }
    }
  };
  return { dollar, calls };
}

function runGuard(root, payload, env = {}) {
  const childEnv = { ...process.env, PROJECT_DIR: root, ...env };
  if (!Object.prototype.hasOwnProperty.call(env, 'SPECNAV_GATE_CALLER')) delete childEnv.SPECNAV_GATE_CALLER;
  return spawnSync(process.execPath, [GUARD], {
    cwd: root,
    input: JSON.stringify(payload),
    encoding: 'utf8',
    env: childEnv
  });
}

function missingTasksProject() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'specnav-mod-'));
  fs.mkdirSync(path.join(root, 'openspec', 'changes', 'd'), { recursive: true });
  fs.mkdirSync(path.join(root, 'openspec', '.specnav'), { recursive: true });
  fs.writeFileSync(path.join(root, 'openspec', '.specnav', 'active-change'), 'd\n');
  return root;
}

function eventCount(root, reason) {
  const file = path.join(root, 'openspec', '.specnav', 'events.jsonl');
  if (!fs.existsSync(file)) return 0;
  const needle = `"reason":"${reason}"`;
  return fs.readFileSync(file, 'utf8').split('\n').filter((line) => line.includes(needle)).length;
}

function realRun(argv, init) {
  const bin = argv[0] === 'node' ? process.execPath : argv[0];
  const result = spawnSync(bin, argv.slice(1), {
    cwd: init && init.cwd,
    input: init && init.stdin,
    encoding: 'utf8',
    env: { ...process.env, ...(init && init.env) }
  });
  if (result.error) throw result.error;
  return {
    exitCode: result.status === null ? 1 : result.status,
    stdout: result.stdout || '',
    stderr: result.stderr || ''
  };
}

test('register wires the mod events', async () => {
  const register = await loadRegister();
  const hooks = recordedHooks(register);
  assert.deepEqual(hooks.map((item) => item.event), [
    'tool.call',
    'command.run',
    'session.start',
    'turn.complete',
    'prompt.context'
  ]);

  const { dollar, calls } = makeDollar();
  let started = false;
  await handlerFor(hooks, 'session.start')(dollar, {}, () => { started = true; return { cwd: '/tmp' }; });
  assert.equal(started, true);
  assert.deepEqual(calls.register.map((spec) => spec.name), ['specnav-status', 'specnav-doctor']);
  assert.equal(calls.register.every((spec) => spec.immediate === true), true);
  assert.equal(calls.status.length, 1);
  assert.match(calls.status[0], /^SpecNav: ready/);
  assert.equal(calls.run[0].argv.some((arg) => arg === '--json'), false);
  assert.match(calls.run[0].argv[1], /workflow-state\.js$/);

  const status = await handlerFor(hooks, 'command.run')(
    dollar,
    { command: 'specnav-status', args: '' },
    () => { throw new Error('status must not fall through'); }
  );
  assert.match(status.text, /^SpecNav: ready/);
  assert.match(calls.run.at(-1).argv[1], /workflow-state\.js$/);
  assert.equal(calls.run.at(-1).argv.includes('--json'), false);

  const doctor = await handlerFor(hooks, 'command.run')(
    dollar,
    { command: 'specnav-doctor', args: '' },
    () => { throw new Error('doctor must not fall through'); }
  );
  assert.match(doctor.text, /^SpecNav: ready/);
  assert.match(calls.run.at(-1).argv[1], /specnav-doctor\.js$/);

  let fellThrough = false;
  await handlerFor(hooks, 'command.run')(dollar, { command: 'specnav', args: '' }, () => { fellThrough = true; });
  assert.equal(fellThrough, true);

  let turned = false;
  await handlerFor(hooks, 'turn.complete')(dollar, {}, () => { turned = true; });
  assert.equal(turned, true);
  assert.ok(calls.status.length >= 2);

  const context = await handlerFor(hooks, 'prompt.context')(
    dollar,
    {},
    async () => ({ blocks: [{ name: 'claudeMd', text: 'keep' }], instructionFiles: [{ path: 'CLAUDE.md' }] })
  );
  assert.deepEqual(context.blocks.map((block) => block.name), ['claudeMd', 'specnav']);
  assert.equal(context.instructionFiles, undefined);
  assert.match(context.blocks[1].text, /^SpecNav: ready/);
});

test('gated tool exit 2 denies without next and writes the receipt', async () => {
  const register = await loadRegister();
  const hooks = recordedHooks(register);
  const { dollar, calls } = makeDollar({
    root: '/work/app',
    sessionId: 's-deny',
    run() {
      return {
        exitCode: 2,
        stdout: '{"hookSpecificOutput":{"permissionDecision":"deny"}}\n',
        stderr: 'SpecNav gate denied: [dangerous-command] blocked\n'
      };
    }
  });
  let nexted = false;
  const result = await handlerFor(hooks, 'tool.call')(
    dollar,
    { tool: 'Bash', tool_use_id: 'toolu_deny_1', command: 'rm -rf /' },
    () => { nexted = true; }
  );
  assert.equal(nexted, false);
  assert.deepEqual(result, { deny: '[dangerous-command] blocked' });
  assert.equal(calls.write.length, 1);
  assert.equal(calls.write[0].file, '/work/app/openspec/.specnav/mod-gate-toolu_deny_1.json');
  const receipt = JSON.parse(calls.write[0].text);
  assert.equal(receipt.schema, 'specnav.mod-gate.v1');
  assert.equal(receipt.session_id, 's-deny');
  assert.equal(receipt.exitCode, 2);
  assert.equal(calls.run[0].init.env.SPECNAV_GATE_CALLER, 'mod');
  assert.equal(calls.run[0].init.stdin.includes('"tool_use_id":"toolu_deny_1"'), true);
});

test('gated tool exit 0 calls next and writes an allow receipt', async () => {
  const register = await loadRegister();
  const hooks = recordedHooks(register);
  const { dollar, calls } = makeDollar({
    root: '/work/app',
    sessionId: 's-allow',
    run() {
      return { exitCode: 0, stdout: '{"systemMessage":"SpecNav gate warning: missing"}\n', stderr: '' };
    }
  });
  let forwarded = null;
  const event = { tool: 'Write', tool_use_id: 'toolu_allow_1', file_path: 'src/app.ts', content: 'x' };
  const result = await handlerFor(hooks, 'tool.call')(dollar, event, (value) => { forwarded = value; return 'continued'; });
  assert.equal(result, 'continued');
  assert.equal(forwarded, event);
  const receipt = JSON.parse(calls.write[0].text);
  assert.equal(receipt.exitCode, 0);
  assert.match(receipt.stdout, /SpecNav gate warning/);
});

test('a non-gated tool does not spawn the guard', async () => {
  const register = await loadRegister();
  const hooks = recordedHooks(register);
  const { dollar, calls } = makeDollar();
  let forwarded = null;
  const event = { tool: 'Read', tool_use_id: 'toolu_read_1', file_path: 'src/app.ts' };
  await handlerFor(hooks, 'tool.call')(dollar, event, (value) => { forwarded = value; });
  assert.equal(forwarded, event);
  assert.equal(calls.run.length, 0);
  assert.equal(calls.write.length, 0);
});

test('a real guard hit is replayed once by the settings hook', async () => {
  const root = missingTasksProject();
  try {
    const register = await loadRegister();
    const hooks = recordedHooks(register);
    const { dollar, calls } = makeDollar({
      root,
      sessionId: 's-replay',
      run: realRun,
      write(file, text) {
        fs.writeFileSync(file, text);
      }
    });
    let nexted = false;
    await handlerFor(hooks, 'tool.call')(
      dollar,
      { tool: 'Write', tool_use_id: 'toolu_replay_1', file_path: 'src/app.ts', content: 'x' },
      () => { nexted = true; }
    );
    assert.equal(nexted, true);
    assert.equal(calls.run[0].init.env.SPECNAV_GATE_CALLER, 'mod');
    assert.equal(calls.run[0].init.env.PROJECT_DIR, root);
    assert.equal(eventCount(root, 'missing-tasks'), 1);
    const receiptPath = path.join(root, 'openspec', '.specnav', 'mod-gate-toolu_replay_1.json');
    const receipt = JSON.parse(fs.readFileSync(receiptPath, 'utf8'));
    assert.equal(receipt.exitCode, 0);
    assert.match(receipt.stdout, /SpecNav gate warning/);

    const replay = runGuard(root, {
      session_id: 's-replay',
      tool_use_id: 'toolu_replay_1',
      tool_name: 'Write',
      tool_input: { file_path: 'src/app.ts', content: 'x' }
    });
    assert.equal(replay.status, 0);
    assert.match(replay.stdout, /SpecNav gate warning/);
    assert.equal(eventCount(root, 'missing-tasks'), 1);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('mod caller does not create openspec in an unmanaged project', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'specnav-mod-plain-'));
  try {
    const result = runGuard(root, {
      tool_use_id: 'toolu_plain_1',
      tool_name: 'Write',
      tool_input: { file_path: 'src/a.ts', content: 'x' }
    }, { SPECNAV_GATE_CALLER: 'mod' });
    assert.equal(result.status, 0);
    assert.equal(fs.existsSync(path.join(root, 'openspec')), false);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('a mismatched session and an unsafe tool id do not replay', () => {
  const root = missingTasksProject();
  try {
    const receiptPath = path.join(root, 'openspec', '.specnav', 'mod-gate-toolu_other_1.json');
    fs.writeFileSync(receiptPath, `${JSON.stringify({
      schema: 'specnav.mod-gate.v1',
      session_id: 'other-session',
      exitCode: 0,
      stdout: 'REPLAYED\n',
      stderr: ''
    })}\n`);
    fs.writeFileSync(path.join(root, 'openspec', 'not-safe.json'), `${JSON.stringify({
      schema: 'specnav.mod-gate.v1',
      exitCode: 0,
      stdout: 'TRAVERSED\n',
      stderr: ''
    })}\n`);

    const mismatched = runGuard(root, {
      session_id: 's-replay',
      tool_use_id: 'toolu_other_1',
      tool_name: 'Write',
      tool_input: { file_path: 'src/app.ts', content: 'x' }
    });
    assert.equal(mismatched.stdout.includes('REPLAYED'), false);
    assert.match(mismatched.stdout, /SpecNav gate warning/);

    const unsafe = runGuard(root, {
      session_id: 's-unsafe',
      tool_use_id: '../not-safe',
      tool_name: 'Write',
      tool_input: { file_path: 'src/app.ts', content: 'x' }
    });
    assert.equal(unsafe.stdout.includes('TRAVERSED'), false);
    assert.match(unsafe.stdout, /missing-tasks/);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
