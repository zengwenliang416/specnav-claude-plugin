'use strict';

const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const {
  codeInventorySha
} = require('../evidence/repository-fingerprint');

const MAX_OUTPUT = 64 * 1024 * 1024;
const HOSTS = Object.freeze(['claude-code', 'codex', 'codefree-o']);

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(
    Object.keys(value).sort().map((key) => [key, canonicalize(value[key])])
  );
}

function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

function blocker(id, artifact = null, detail = null) {
  return { id, artifact, detail };
}

function executable(file, id) {
  const real = fs.realpathSync(file);
  const stat = fs.lstatSync(real);
  if (!stat.isFile() || stat.isSymbolicLink()) throw new Error(id);
  return Object.freeze({
    path: real,
    sha256: sha256(fs.readFileSync(real))
  });
}

function toolchain() {
  const gitPath = process.platform === 'win32'
    ? null
    : '/usr/bin/git';
  const bashPath = process.platform === 'win32'
    ? null
    : '/bin/bash';
  const npmPath = path.resolve(
    path.dirname(process.execPath),
    '../lib/node_modules/npm/bin/npm-cli.js'
  );
  const sandboxPath = process.platform === 'darwin'
    ? '/usr/bin/sandbox-exec'
    : ['/usr/bin/bwrap', '/bin/bwrap'].find((entry) => fs.existsSync(entry));
  if (!gitPath || !bashPath) {
    throw new Error('verification-host-launcher:platform-unsupported');
  }
  if (!fs.existsSync(npmPath)) {
    throw new Error('verification-host-launcher:npm-unavailable');
  }
  if (!sandboxPath) {
    throw new Error('verification-host-launcher:sandbox-unavailable');
  }
  return Object.freeze({
    node: executable(process.execPath, 'verification-host-launcher:node-invalid'),
    git: executable(gitPath, 'verification-host-launcher:git-invalid'),
    bash: executable(bashPath, 'verification-host-launcher:bash-invalid'),
    npm: executable(npmPath, 'verification-host-launcher:npm-invalid'),
    sandbox: executable(
      sandboxPath,
      'verification-host-launcher:sandbox-unavailable'
    )
  });
}

function sanitizedEnvironment(root, tmp, extra = {}) {
  const env = {
    HOME: path.join(tmp, 'home'),
    TMPDIR: path.join(tmp, 'tmp'),
    TEMP: path.join(tmp, 'tmp'),
    TMP: path.join(tmp, 'tmp'),
    PATH: `${path.dirname(process.execPath)}:/usr/bin:/bin`,
    LANG: 'C.UTF-8',
    LC_ALL: 'C.UTF-8',
    TZ: 'UTC',
    GIT_CONFIG_NOSYSTEM: '1',
    GIT_TERMINAL_PROMPT: '0',
    GIT_ASKPASS: '/usr/bin/false',
    SSH_ASKPASS: '/usr/bin/false',
    NODE_OPTIONS: '--no-addons',
    SPECNAV_HOST_PROOF_ROOT: root,
    ...extra
  };
  fs.mkdirSync(env.HOME, { recursive: true, mode: 0o700 });
  fs.mkdirSync(env.TMPDIR, { recursive: true, mode: 0o700 });
  return env;
}

function spawn(argv, options = {}) {
  const startedAt = new Date().toISOString();
  const executableRealpath = fs.realpathSync(argv[0]);
  const before = fs.statSync(executableRealpath);
  const executableSha256 = sha256(fs.readFileSync(executableRealpath));
  const result = spawnSync(argv[0], argv.slice(1), {
    cwd: options.cwd,
    env: options.env,
    encoding: null,
    maxBuffer: MAX_OUTPUT,
    timeout: options.timeoutMs
  });
  const after = fs.statSync(executableRealpath);
  const executableChanged = before.dev !== after.dev
    || before.ino !== after.ino
    || before.size !== after.size
    || before.mtimeMs !== after.mtimeMs
    || executableSha256 !== sha256(fs.readFileSync(executableRealpath));
  return {
    id: options.id,
    argv,
    executable_realpath: executableRealpath,
    executable_sha256: executableSha256,
    started_at: startedAt,
    completed_at: new Date().toISOString(),
    exit_status: result.status,
    signal: result.signal,
    stdout: Buffer.isBuffer(result.stdout) ? result.stdout : Buffer.alloc(0),
    stderr: Buffer.isBuffer(result.stderr) ? result.stderr : Buffer.alloc(0),
    error: executableChanged
      ? 'verification-host-launcher:executable-changed-during-run'
      : result.error
      ? (result.error instanceof Error ? result.error.message : String(result.error))
      : null
  };
}

function requireSuccess(result, id, detail = null) {
  if (result.exit_status !== 0 || result.error || result.signal) {
    const error = new Error(id);
    error.blockers = [blocker(
      id,
      result.argv.join(' '),
      detail || result.error || result.signal || result.exit_status
    )];
    throw error;
  }
}

function assertConfinedDirectory(root, relative, id) {
  const rootReal = fs.realpathSync(root);
  let current = rootReal;
  for (const segment of relative.split('/')) {
    if (!segment || segment === '.' || segment === '..') throw new Error(id);
    current = path.join(current, segment);
    const stat = fs.lstatSync(current);
    if (stat.isSymbolicLink()) throw new Error(id);
  }
  const real = fs.realpathSync(current);
  const fromRoot = path.relative(rootReal, real);
  if (
    !fs.statSync(real).isDirectory()
    || fromRoot.startsWith('..')
    || path.isAbsolute(fromRoot)
  ) {
    throw new Error(id);
  }
  return real;
}

function sandboxPrefix(
  tools,
  allowedRoots,
  writableRoots,
  allowNetwork = false
) {
  if (process.platform === 'darwin') {
    const literals = [
      '/System',
      '/usr',
      '/bin',
      '/dev',
      ...allowedRoots
    ].map((entry) => `(subpath ${JSON.stringify(entry)})`).join(' ');
    const writable = writableRoots
      .map((entry) => `(subpath ${JSON.stringify(entry)})`)
      .join(' ');
    const profile = [
      '(version 1)',
      '(deny default)',
      '(allow process*)',
      '(allow sysctl-read)',
      `(allow file-read* ${literals})`,
      `(allow file-write* ${writable})`,
      ...(allowNetwork ? ['(allow network-outbound)'] : [])
    ].join(' ');
    return {
      executable: tools.sandbox,
      argv: [tools.sandbox.path, '-p', profile],
      policy_sha256: sha256(profile)
    };
  }
  if (process.platform === 'linux') {
    const argv = [
      tools.sandbox.path,
      '--unshare-all',
      '--die-with-parent',
      '--new-session',
      '--proc',
      '/proc',
      '--dev',
      '/dev',
      '--ro-bind',
      '/usr',
      '/usr',
      '--ro-bind',
      '/bin',
      '/bin'
    ];
    for (const candidate of ['/lib', '/lib64']) {
      if (fs.existsSync(candidate)) {
        argv.push('--ro-bind', candidate, candidate);
      }
    }
    const writable = new Set(writableRoots);
    for (const root of allowedRoots) {
      if (!writable.has(root)) argv.push('--ro-bind', root, root);
    }
    for (const root of writableRoots) argv.push('--bind', root, root);
    if (allowNetwork) argv.push('--share-net');
    return {
      executable: tools.sandbox,
      argv,
      policy_sha256: sha256(canonicalJson(argv.slice(1)))
    };
  }
  throw new Error('verification-host-launcher:platform-unsupported');
}

function createHostProofLauncher(options = {}) {
  const tools = options.toolchain || toolchain();
  const spawnCommand = options.spawnCommand || spawn;
  const clock = options.clock || (() => new Date().toISOString());
  const launcherFile = fs.realpathSync(__filename);
  const runnerSourceSha256 = sha256(fs.readFileSync(launcherFile));
  const runnerIdentity = sha256(Buffer.concat([
    Buffer.from(runnerSourceSha256),
    Buffer.from(canonicalJson(tools))
  ]));

  function execute(argv, config) {
    return spawnCommand(argv, config);
  }

  function prepare(lock) {
    const workspace = fs.mkdtempSync(
      path.join(os.tmpdir(), 'specnav-host-proof-')
    );
    const roots = {};
    const setup = {};
    const observations = {};
    try {
      for (const host of HOSTS) {
        const repository = host === 'codex' ? lock.source : lock.hosts[host];
        const root = path.join(workspace, host);
        fs.mkdirSync(root, { recursive: true, mode: 0o700 });
        const env = sanitizedEnvironment(root, workspace);
        const commands = [];
        const lsRemote = execute([
          tools.git.path,
          'ls-remote',
          '--refs',
          repository.repository,
          repository.ref
        ], {
          id: 'remote-ref',
          cwd: workspace,
          env,
          timeoutMs: 180000
        });
        commands.push(lsRemote);
        requireSuccess(
          lsRemote,
          `verification-host-launcher:remote-ref-unreachable:${host}`
        );
        const advertised = lsRemote.stdout.toString('utf8').trim().split(/\s+/)[0];
        if (advertised !== repository.commit) {
          const error = new Error(
            `verification-host-launcher:remote-ref-commit-mismatch:${host}`
          );
          error.blockers = [blocker(
            error.message,
            repository.ref,
            { expected: repository.commit, actual: advertised || null }
          )];
          throw error;
        }
        for (const [id, argv] of [
          ['checkout-init', [
            tools.git.path,
            '-c',
            'core.hooksPath=/dev/null',
            'init',
            '--quiet'
          ]],
          ['checkout-remote', [
            tools.git.path,
            '-c',
            'core.hooksPath=/dev/null',
            'remote',
            'add',
            'origin',
            repository.repository
          ]],
          ['checkout-fetch', [
            tools.git.path,
            '-c',
            'core.hooksPath=/dev/null',
            'fetch',
            '--quiet',
            '--depth=1',
            'origin',
            repository.ref
          ]],
          ['checkout-detach', [
            tools.git.path,
            '-c',
            'core.hooksPath=/dev/null',
            'checkout',
            '--quiet',
            '--detach',
            repository.commit
          ]]
        ]) {
          const result = execute(argv, {
            id,
            cwd: root,
            env,
            timeoutMs: 180000
          });
          commands.push(result);
          requireSuccess(
            result,
            `verification-host-launcher:${id}-failed:${host}`
          );
        }
        const head = execute([
          tools.git.path,
          'rev-parse',
          'HEAD^{commit}'
        ], {
          id: 'checkout-head',
          cwd: root,
          env,
          timeoutMs: 60000
        });
        commands.push(head);
        requireSuccess(
          head,
          `verification-host-launcher:checkout-head-failed:${host}`
        );
        if (head.stdout.toString('utf8').trim() !== repository.commit) {
          throw new Error(
            `verification-host-launcher:checkout-head-mismatch:${host}`
          );
        }
        const observation = {
          advertised_commit: advertised,
          checkout_head: head.stdout.toString('utf8').trim(),
          source_code_inventory_sha: null,
          package_lock_sha256: null
        };
        if (host === 'codex') {
          const tree = execute([
            tools.git.path,
            'ls-tree',
            '-r',
            'HEAD'
          ], {
            id: 'checkout-tree',
            cwd: root,
            env,
            timeoutMs: 60000
          });
          commands.push(tree);
          requireSuccess(
            tree,
            `verification-host-launcher:checkout-tree-failed:${host}`
          );
          observation.source_code_inventory_sha = codeInventorySha(
            tree.stdout.toString('utf8')
          );
        }
        if (host === 'codefree-o') {
          const packageLockFile = path.join(root, 'package-lock.json');
          const packageLockBytes = fs.readFileSync(packageLockFile);
          const packageLock = JSON.parse(packageLockBytes.toString('utf8'));
          for (const [packagePath, entry] of Object.entries(
            packageLock.packages || {}
          )) {
            if (!packagePath || !entry?.resolved) continue;
            let resolved;
            try {
              resolved = new URL(entry.resolved);
            } catch {
              throw new Error(
                'verification-host-launcher:package-lock-source-invalid:codefree-o'
              );
            }
            if (
              resolved.protocol !== 'https:'
              || resolved.hostname !== 'registry.npmjs.org'
              || typeof entry.integrity !== 'string'
              || !entry.integrity.startsWith('sha512-')
            ) {
              throw new Error(
                'verification-host-launcher:package-lock-source-invalid:codefree-o'
              );
            }
          }
          observation.package_lock_sha256 = sha256(packageLockBytes);
        }
        assertConfinedDirectory(
          root,
          repository.plugin_path,
          `verification-host-launcher:plugin-path-unsafe:${host}`
        );
        roots[host] = fs.realpathSync(root);
        setup[host] = commands;
        observations[host] = observation;
      }
      return {
        ok: true,
        workspace,
        roots,
        setup,
        observations,
        runner_identity_sha256: runnerIdentity,
        runner_source_sha256: runnerSourceSha256,
        toolchain: tools,
        blockers: []
      };
    } catch (error) {
      fs.rmSync(workspace, { recursive: true, force: true });
      return {
        ok: false,
        workspace: null,
        roots: {},
        setup: {},
        observations: {},
        runner_identity_sha256: runnerIdentity,
        runner_source_sha256: runnerSourceSha256,
        toolchain: tools,
        blockers: Array.isArray(error.blockers)
          ? error.blockers
          : [blocker(
              error instanceof Error ? error.message : String(error)
            )]
      };
    }
  }

  function run(host, argv, context) {
    const writable = path.join(context.workspace, '.runtime', host);
    fs.mkdirSync(writable, { recursive: true, mode: 0o700 });
    const allowedRoots = [
      ...Object.values(context.roots),
      ...(context.allowRuntime === true ? [context.runtimeRoot] : []),
      ...(context.trustedRoots || []),
      path.dirname(path.dirname(tools.node.path))
    ];
    const writableRoots = [
      writable,
      ...(context.allowCheckoutWrite === true
        ? [context.roots[host]]
        : [])
    ];
    const sandbox = sandboxPrefix(
      tools,
      allowedRoots,
      writableRoots,
      context.allowNetwork === true
    );
    const env = sanitizedEnvironment(context.roots[host], writable, {
      SPECNAV_CODEX_ROOT: context.roots.codex,
      SPECNAV_CLAUDE_ROOT: context.roots['claude-code'],
      SPECNAV_CODEFREE_O_ROOT: context.roots['codefree-o']
    });
    const result = execute([...sandbox.argv, ...argv], {
      id: context.id,
      cwd: context.roots[host],
      env,
      timeoutMs: context.timeoutMs || 1800000
    });
    return {
      ...result,
      argv,
      executable_realpath: fs.realpathSync(argv[0]),
      executable_sha256: sha256(fs.readFileSync(fs.realpathSync(argv[0]))),
      sandbox_executable_realpath: sandbox.executable.path,
      sandbox_executable_sha256: sandbox.executable.sha256,
      sandbox_policy_sha256: sandbox.policy_sha256
    };
  }

  function cleanup(prepared) {
    if (prepared?.workspace) {
      fs.rmSync(prepared.workspace, { recursive: true, force: true });
    }
  }

  function environmentDigest(prepared, runtimeAuthority) {
    return sha256(canonicalJson({
      platform: process.platform,
      arch: process.arch,
      node: process.version,
      runner_identity_sha256: runnerIdentity,
      runtime_authority_digest: runtimeAuthority.digest,
      toolchain: tools,
      roots: Object.fromEntries(HOSTS.map((host) => [
        host,
        prepared.roots[host]
      ]))
    }));
  }

  return Object.freeze({
    cleanup,
    clock,
    environmentDigest,
    prepare,
    run,
    runnerIdentity,
    runnerSourceSha256,
    toolchain: tools
  });
}

module.exports = {
  HOSTS,
  createHostProofLauncher,
  sanitizedEnvironment
};
