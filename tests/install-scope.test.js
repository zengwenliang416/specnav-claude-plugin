'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const {
  parseArgs,
  loadSuite,
  marketplaceSource,
  ensureLocalGitignore,
  installSuite
} = require('../install.js');

const repo = path.resolve(__dirname, '..');
const installer = path.join(repo, 'install.js');

function tempDir() {
  return fs.mkdtempSync(path.join('/private/tmp', 'specnav-claude-install-'));
}

test('flags select one Claude scope', () => {
  assert.equal(parseArgs(['--user']).scope, 'user');
  assert.equal(parseArgs(['--project', '/work/app']).project, '/work/app');
  assert.equal(parseArgs(['--local=/work/app']).scope, 'local');
  assert.equal(parseArgs(['--user', '--source', '/tmp/plugin']).source, '/tmp/plugin');
  assert.throws(() => parseArgs(['--user', '--project', '/work/app']), /一种安装范围/);
  assert.throws(() => parseArgs(['--local']), /项目目录/);
});

test('suite lists every marketplace plugin and origin is the default source', () => {
  const suite = loadSuite(repo);
  assert.equal(suite.marketplace, 'specnav-marketplace');
  assert.deepEqual(suite.plugins, [
    'specnav-core',
    'specnav-requirements',
    'specnav-prototype',
    'specnav-development',
    'specnav-verification',
    'specnav-operations',
    'specnav-codegraph'
  ]);
  assert.equal(marketplaceSource(null, repo), 'https://github.com/zengwenliang416/specnav-claude-plugin.git');
  assert.equal(marketplaceSource('/tmp/local-market', repo), '/tmp/local-market');
});

test('local scope gitignore covers settings.local.json once', () => {
  const project = tempDir();
  try {
    fs.writeFileSync(path.join(project, '.gitignore'), 'node_modules/\n');
    assert.equal(ensureLocalGitignore(project), 'added');
    assert.equal(ensureLocalGitignore(project), 'present');
    assert.equal(fs.readFileSync(path.join(project, '.gitignore'), 'utf8').match(/settings\.local\.json/g).length, 1);
  } finally {
    fs.rmSync(project, { recursive: true, force: true });
  }
});

test('non-interactive install requires a scope', () => {
  const result = spawnSync(process.execPath, [installer], { encoding: 'utf8', input: '\n' });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /--user/);
});

test('user install commands cover marketplace, all plugins, and enable', () => {
  const bin = tempDir();
  const log = path.join(bin, 'claude.log');
  fs.writeFileSync(path.join(bin, 'claude'), `#!/bin/sh\nprintf '%s\\n' "$*" >> ${JSON.stringify(log)}\nexit 0\n`);
  fs.chmodSync(path.join(bin, 'claude'), 0o755);
  try {
    const result = spawnSync(process.execPath, [installer, '--user'], {
      encoding: 'utf8',
      env: { ...process.env, PATH: `${bin}${path.delimiter}${process.env.PATH}` }
    });
    assert.equal(result.status, 0, result.stderr);
    const text = fs.readFileSync(log, 'utf8');
    assert.match(text, /plugin marketplace add --scope user https:\/\/github.com\/zengwenliang416\/specnav-claude-plugin.git/);
    for (const name of loadSuite(repo).plugins) {
      assert.match(text, new RegExp(`plugin install ${name}@specnav-marketplace --scope user --yes`));
      assert.match(text, new RegExp(`plugin enable ${name}@specnav-marketplace --scope user`));
    }
  } finally {
    fs.rmSync(bin, { recursive: true, force: true });
  }
});

test('project install rejects the plugin repo and a symlink', () => {
  assert.throws(() => installSuite({ scope: 'project', project: repo, source: repo, run() {
    throw new Error('claude should not run');
  } }), /插件仓库自身/);
  const root = tempDir();
  const outside = tempDir();
  try {
    const link = path.join(root, 'linked');
    fs.symlinkSync(outside, link);
    assert.throws(() => installSuite({ scope: 'local', project: link, source: repo, run() {
      throw new Error('claude should not run');
    } }), /符号链接/);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
    fs.rmSync(outside, { recursive: true, force: true });
  }
});

test('project install enables the whole suite without touching user Claude settings', { timeout: 180000 }, () => {
  const project = tempDir();
  const home = tempDir();
  const userSettings = path.join(os.homedir(), '.claude', 'settings.json');
  const before = fs.readFileSync(userSettings, 'utf8');
  try {
    fs.writeFileSync(path.join(project, 'README.md'), 'app\n');
    const result = spawnSync(process.execPath, [installer, '--project', project, '--source', repo], {
      encoding: 'utf8',
      env: { ...process.env, CLAUDE_CONFIG_DIR: home }
    });
    assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
    const settings = JSON.parse(fs.readFileSync(path.join(project, '.claude', 'settings.json'), 'utf8'));
    for (const name of loadSuite(repo).plugins) {
      assert.equal(settings.enabledPlugins[`${name}@specnav-marketplace`], true);
    }
    assert.equal(settings.extraKnownMarketplaces['specnav-marketplace'].source.path, repo);
    const again = spawnSync(process.execPath, [installer, '--project', project, '--source', repo], {
      encoding: 'utf8',
      env: { ...process.env, CLAUDE_CONFIG_DIR: home }
    });
    assert.equal(again.status, 0, `${again.stdout}\n${again.stderr}`);
    assert.equal(fs.readFileSync(userSettings, 'utf8'), before);
  } finally {
    if (fs.readFileSync(userSettings, 'utf8') !== before) fs.writeFileSync(userSettings, before);
    fs.rmSync(project, { recursive: true, force: true });
    fs.rmSync(home, { recursive: true, force: true });
  }
});
