#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const readline = require('node:readline');
const { spawnSync } = require('node:child_process');

const REPO_ROOT = path.resolve(__dirname);
const LOCAL_GITIGNORE = '.claude/settings.local.json';

const HELP = `SpecNav Claude Code 安装

这个目录是独立的 Git 仓库，remote 是 origin。发布更新用：

  git push origin main

安装七个插件时选择范围：

  node install.js --user
      用户级。当前用户的所有项目都能发现。
      记录在 ~/.claude/settings.json 的 enabledPlugins。

  node install.js --project <项目目录>
      项目级。写入该项目 .claude/settings.json。
      提交这个文件后，协作者会启用同一组插件。
      插件本体不会跟着文件下载，每个人仍要在自己的机器上执行一次。

  node install.js --local <项目目录>
      本地级。只对你、只在这个项目。
      写入 .claude/settings.local.json，并保证 Git 忽略该文件。

  node install.js
      当前终端里选择上面三种。

默认 marketplace 来源是 origin。测试本地检出时加：

  node install.js --user --source "$PWD"

装完后新开一个 Claude Code 会话。
`;

class InstallError extends Error {
  constructor(message, exitCode = 1) {
    super(message);
    this.exitCode = exitCode;
  }
}

function parseArgs(argv) {
  const args = { help: false, scope: null, project: null, source: null };
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--help' || token === '-h') {
      args.help = true;
      continue;
    }
    if (token === '--user') {
      if (args.scope) throw new InstallError('只能选择一种安装范围。', 2);
      args.scope = 'user';
      continue;
    }
    if (token === '--project' || token === '--local') {
      if (args.scope) throw new InstallError('只能选择一种安装范围。', 2);
      const value = argv[i + 1];
      if (!value || value.startsWith('--')) throw new InstallError(`${token} 需要项目目录。`, 2);
      args.scope = token.slice(2);
      args.project = value;
      i += 1;
      continue;
    }
    if (token.startsWith('--project=') || token.startsWith('--local=')) {
      if (args.scope) throw new InstallError('只能选择一种安装范围。', 2);
      const eq = token.indexOf('=');
      args.scope = token.slice(2, eq);
      args.project = token.slice(eq + 1);
      if (!args.project) throw new InstallError(`--${args.scope} 需要项目目录。`, 2);
      continue;
    }
    if (token === '--source') {
      const value = argv[i + 1];
      if (!value || value.startsWith('--')) throw new InstallError('--source 需要 Git 地址或本地目录。', 2);
      args.source = value;
      i += 1;
      continue;
    }
    throw new InstallError(`无法识别的参数: ${token}\n\n${HELP}`, 2);
  }
  return args;
}

function gitOrigin(repoRoot = REPO_ROOT) {
  const result = spawnSync('git', ['-C', repoRoot, 'remote', 'get-url', 'origin'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore']
  });
  if (result.status !== 0) return null;
  const origin = result.stdout.trim();
  return origin || null;
}

function loadSuite(repoRoot = REPO_ROOT) {
  const file = path.join(repoRoot, '.claude-plugin', 'marketplace.json');
  const marketplace = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!marketplace.name || !Array.isArray(marketplace.plugins) || marketplace.plugins.length === 0) {
    throw new InstallError(`marketplace 缺少插件: ${file}`);
  }
  return {
    marketplace: marketplace.name,
    plugins: marketplace.plugins.map((plugin) => {
      if (!plugin.name) throw new InstallError('marketplace 里有未命名插件。');
      return plugin.name;
    })
  };
}

function normalizeSource(value) {
  if (!value || /[\s]/.test(value)) throw new InstallError(`marketplace 来源无效: ${value || ''}`);
  if (value.startsWith('/') || value.startsWith('./') || value.startsWith('../') || value.startsWith('~')) {
    const expanded = value.startsWith('~')
      ? path.join(os.homedir(), value.slice(1))
      : value;
    return path.resolve(expanded);
  }
  return value;
}

function marketplaceSource(explicit, repoRoot = REPO_ROOT) {
  return normalizeSource(explicit || gitOrigin(repoRoot) || repoRoot);
}

function realDirectory(input) {
  if (!input || !String(input).trim()) throw new InstallError('需要项目目录。', 2);
  const resolved = path.resolve(input);
  if (!fs.existsSync(resolved)) throw new InstallError(`项目目录不存在: ${resolved}`);
  const stat = fs.lstatSync(resolved);
  if (stat.isSymbolicLink()) throw new InstallError(`项目目录是符号链接，已拒绝: ${resolved}`);
  if (!stat.isDirectory()) throw new InstallError(`不是目录: ${resolved}`);
  const real = fs.realpathSync(resolved);
  if (real === fs.realpathSync(REPO_ROOT)) {
    throw new InstallError('不能把插件安装进插件仓库自身。请指定要使用 SpecNav 的项目。');
  }
  return real;
}

function ensureLocalGitignore(project) {
  const file = path.join(project, '.gitignore');
  if (fs.existsSync(file) && fs.lstatSync(file).isSymbolicLink()) return 'skip-symlink';
  const text = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  const covered = text.split('\n').some((row) => {
    const trimmed = row.trim();
    return trimmed === LOCAL_GITIGNORE || trimmed === '.claude/' || trimmed === '.claude/*' || trimmed === '.claude/**';
  });
  if (covered) return 'present';
  const prefix = text === '' || text.endsWith('\n') ? text : `${text}\n`;
  fs.writeFileSync(file, `${prefix}${LOCAL_GITIGNORE}\n`);
  return 'added';
}

function runClaude(args, cwd) {
  const result = spawnSync('claude', args, {
    cwd,
    encoding: 'utf8',
    env: process.env,
    stdio: ['ignore', 'pipe', 'pipe']
  });
  if (result.error) throw new InstallError(`无法运行 claude: ${result.error.message}`);
  const output = `${result.stdout || ''}${result.stderr || ''}`;
  return { status: result.status, output };
}

function acceptClaude(result, pattern, action) {
  if (result.status === 0) return;
  if (pattern.test(result.output)) return;
  throw new InstallError(`${action} 失败。\n${result.output.trim()}`);
}

function installSuite(options = {}) {
  const repoRoot = options.repoRoot || REPO_ROOT;
  const scope = options.scope;
  if (!['user', 'project', 'local'].includes(scope)) throw new InstallError(`未知安装范围: ${scope}`, 2);
  const suite = options.suite || loadSuite(repoRoot);
  const source = marketplaceSource(options.source, repoRoot);
  let cwd = repoRoot;
  let gitignore = null;
  if (scope === 'project' || scope === 'local') {
    cwd = realDirectory(options.project);
    if (scope === 'local') gitignore = ensureLocalGitignore(cwd);
  }
  const run = options.run || runClaude;
  const added = run(['plugin', 'marketplace', 'add', '--scope', scope, source], cwd);
  process.stdout.write(added.output || '');
  acceptClaude(added, /already/i, '添加 marketplace');
  for (const name of suite.plugins) {
    const id = `${name}@${suite.marketplace}`;
    const installed = run(['plugin', 'install', id, '--scope', scope, '--yes'], cwd);
    process.stdout.write(installed.output || '');
    acceptClaude(installed, /already installed/i, `安装 ${id}`);
    const enabled = run(['plugin', 'enable', id, '--scope', scope], cwd);
    process.stdout.write(enabled.output || '');
    acceptClaude(enabled, /already enabled/i, `启用 ${id}`);
  }
  const where = scope === 'user'
    ? '用户级安装完成。记录在当前用户的 ~/.claude/settings.json。'
    : scope === 'project'
      ? `项目级安装完成。启用记录在 ${path.join(cwd, '.claude', 'settings.json')}。提交该文件后协作者会启用这些插件，每人仍需在自己的机器上安装一次。`
      : `本地级安装完成。启用记录在 ${path.join(cwd, '.claude', 'settings.local.json')}。`;
  process.stdout.write(`${where}\n新开一个 Claude Code 会话后可用。\n`);
  return { scope, cwd, source, marketplace: suite.marketplace, plugins: suite.plugins, gitignore };
}

function ask(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

async function promptScope() {
  process.stdout.write('安装范围:\n  1) 用户级，这台机器上的所有项目\n  2) 项目级，写入项目并给协作者\n  3) 本地级，只对你、只在这个项目\n');
  const choice = await ask('选择 [1/2/3]: ');
  if (choice === '1') return { scope: 'user', project: null };
  if (choice === '2' || choice === '3') {
    const project = await ask('项目目录: ');
    if (!project) throw new InstallError('需要项目目录。', 2);
    return { scope: choice === '2' ? 'project' : 'local', project };
  }
  throw new InstallError('请选择 1、2 或 3。', 2);
}

async function main(argv = process.argv.slice(2)) {
  const args = parseArgs(argv);
  if (args.help) {
    process.stdout.write(HELP);
    return 0;
  }
  let scope = args.scope;
  let project = args.project;
  if (!scope) {
    if (!process.stdin.isTTY) throw new InstallError(HELP, 2);
    const choice = await promptScope();
    scope = choice.scope;
    project = choice.project;
  }
  installSuite({ scope, project, source: args.source });
  return 0;
}

if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = error.exitCode || 1;
  });
}

module.exports = {
  HELP,
  parseArgs,
  gitOrigin,
  loadSuite,
  marketplaceSource,
  ensureLocalGitignore,
  installSuite,
  realDirectory
};
