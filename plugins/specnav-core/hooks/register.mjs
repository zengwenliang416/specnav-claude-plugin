// Claude Code mod for specnav-core (CLI 2.1.287+, Desktop 2.1.286+).
// This file is ESM because the repo is CommonJS. It cannot require the guard:
// the hooks module has no Node APIs, so the guard runs as a child. Settings
// hooks stay in hooks.json for older hosts and replay this child's output.

const GATED_TOOLS = new Set(['Write', 'Edit', 'MultiEdit', 'NotebookEdit', 'Bash']);
const IMMEDIATE_COMMANDS = {
  'specnav-status': 'workflow-state.js',
  'specnav-doctor': 'specnav-doctor.js'
};
const RESERVED_FIELDS = new Set(['tool', 'tool_use_id', 'agentId', 'consent']);
const TOOL_USE_ID_PATTERN = /^[\w-]{1,128}$/;
const OUTPUT_CAP = 16000;

function cap(text) {
  const value = typeof text === 'string' ? text : '';
  return value.length > OUTPUT_CAP ? value.slice(0, OUTPUT_CAP) : value;
}

function safeToolUseId(id) {
  const value = typeof id === 'string' ? id.trim() : '';
  return TOOL_USE_ID_PATTERN.test(value) ? value : '';
}

function denyReason(stderr) {
  const text = typeof stderr === 'string' ? stderr : '';
  const line = text.split('\n').find((item) => item.includes('SpecNav gate denied:'));
  if (!line) return 'SpecNav gate denied this tool call.';
  const reason = line.slice(line.indexOf('SpecNav gate denied:') + 'SpecNav gate denied:'.length).trim();
  return reason || 'SpecNav gate denied this tool call.';
}

function toolPayload(event, sessionId) {
  const toolInput = {};
  for (const key of Object.keys(event)) {
    if (RESERVED_FIELDS.has(key)) continue;
    toolInput[key] = event[key];
  }
  return {
    tool_name: event.tool,
    tool_use_id: event.tool_use_id,
    session_id: sessionId,
    tool_input: toolInput
  };
}

function firstLine(text) {
  return String(text || '').trim().split('\n')[0] || '';
}

export function register(on) {
  on('tool.call', async ($, e, next) => {
    if (!GATED_TOOLS.has(e.tool)) return next(e);
    let root;
    let sessionId;
    try {
      root = await $.session.root();
      sessionId = await $.session.id();
    } catch {
      return next(e);
    }
    let result;
    try {
      result = await $.process.run(
        ['node', `${$.plugin.root}/scripts/specnav-guard.js`],
        {
          cwd: root,
          stdin: JSON.stringify(toolPayload(e, sessionId)),
          env: { SPECNAV_GATE_CALLER: 'mod', PROJECT_DIR: root }
        }
      );
    } catch {
      return next(e);
    }
    const id = safeToolUseId(e.tool_use_id);
    if (id) {
      try {
        await $.fs.write(
          `${root}/openspec/.specnav/mod-gate-${id}.json`,
          `${JSON.stringify({
            schema: 'specnav.mod-gate.v1',
            session_id: sessionId,
            exitCode: result.exitCode,
            stdout: cap(result.stdout),
            stderr: cap(result.stderr)
          })}\n`
        );
      } catch {
        // No receipt: the settings hook evaluates this call itself.
      }
    }
    if (result.exitCode === 2) return { deny: denyReason(result.stderr) };
    return next(e);
  }).catch(() => ({ deny: 'SpecNav gate failed closed.' }));

  on('command.run', async ($, e, next) => {
    const script = IMMEDIATE_COMMANDS[e.command];
    if (!script) return next(e);
    let root;
    try {
      root = await $.session.root();
    } catch {
      return next(e);
    }
    try {
      const result = await $.process.run(
        ['node', `${$.plugin.root}/scripts/${script}`],
        { cwd: root, env: { PROJECT_DIR: root } }
      );
      const text = String(result.stdout || result.stderr || '').trim();
      return { text: text || `SpecNav ${e.command} produced no output.` };
    } catch {
      return { text: `SpecNav ${e.command} failed to start.` };
    }
  }).catch(() => ({ text: 'SpecNav command failed closed.' }));

  on('session.start', async ($, e, next) => {
    try {
      await $.command.register({
        name: 'specnav-status',
        description: 'Show the SpecNav workflow state for this project.',
        immediate: true
      });
    } catch {
      // The markdown command may already own this name. command.run still answers it.
    }
    try {
      await $.command.register({
        name: 'specnav-doctor',
        description: 'Check the SpecNav plugin suite and project wiring.',
        immediate: true
      });
    } catch {
      // The markdown command may already own this name. command.run still answers it.
    }
    try {
      const root = await $.session.root();
      const result = await $.process.run(
        ['node', `${$.plugin.root}/scripts/workflow-state.js`],
        { cwd: root, env: { PROJECT_DIR: root } }
      );
      const line = firstLine(result.stdout);
      if (line) $.ui.status(line);
    } catch {
      // The status line is advisory.
    }
    return next(e);
  });

  on('turn.complete', async ($, e, next) => {
    try {
      const root = await $.session.root();
      const result = await $.process.run(
        ['node', `${$.plugin.root}/scripts/workflow-state.js`],
        { cwd: root, env: { PROJECT_DIR: root } }
      );
      const line = firstLine(result.stdout);
      if (line) $.ui.status(line);
    } catch {
      // The status line is advisory.
    }
    return next(e);
  });

  on('prompt.context', async ($, e, next) => {
    const prior = await next(e);
    const blocks = Array.isArray(prior && prior.blocks) ? prior.blocks.slice() : [];
    let line = '';
    try {
      const root = await $.session.root();
      const result = await $.process.run(
        ['node', `${$.plugin.root}/scripts/workflow-state.js`],
        { cwd: root, env: { PROJECT_DIR: root } }
      );
      line = firstLine(result.stdout);
    } catch {
      line = '';
    }
    if (line && !blocks.some((block) => block && block.name === 'specnav')) {
      blocks.push({ name: 'specnav', text: line });
    }
    return { blocks };
  });
}
