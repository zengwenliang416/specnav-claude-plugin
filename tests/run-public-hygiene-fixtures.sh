#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

node - "$ROOT" <<'NODE'
const fs = require('fs');
const path = require('path');

const root = process.argv[2];
const publicRepo = 'https://github.com/zengwenliang416/helm-claude-plugin';
const errors = [];

function fail(message) {
  errors.push(message);
}

function read(file) {
  return fs.readFileSync(path.join(root, file), 'utf8');
}

function readJson(file) {
  return JSON.parse(read(file));
}

const marketplace = readJson('.claude-plugin/marketplace.json');
const versions = new Set((marketplace.plugins || []).map((plugin) => plugin.version));
if (versions.size !== 1) fail('marketplace plugin versions are not aligned');
const currentVersion = Array.from(versions)[0];
if (!currentVersion) fail('missing marketplace version');

for (const entry of marketplace.plugins || []) {
  const pluginJson = readJson(path.join(entry.source, '.claude-plugin/plugin.json'));
  if (pluginJson.version !== currentVersion) {
    fail(`${entry.name}: plugin.json version does not match marketplace version`);
  }
  if (pluginJson.homepage !== publicRepo) {
    fail(`${entry.name}: homepage must be ${publicRepo}`);
  }
  if (pluginJson.repository !== publicRepo) {
    fail(`${entry.name}: repository must be ${publicRepo}`);
  }
}

const changelog = read('CHANGELOG.md');
if (!new RegExp(`^## ${currentVersion.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'm').test(changelog)) {
  fail(`CHANGELOG.md missing current version ${currentVersion}`);
}

const design = read('docs/design.md');
if (!design.includes(`Current implementation version: \`${currentVersion}\``)) {
  fail('docs/design.md current implementation version is stale');
}
if (!design.includes(`Completed in \`${currentVersion}\``)) {
  fail('docs/design.md missing Completed section for current version');
}

const publicDocs = [
  'README.md',
  'README.zh-CN.md',
  'docs/design.md',
  'docs/user-journey.md',
  'docs/spec-discovery.md',
  'docs/command-skill-matrix.md',
  'docs/compatibility.md',
  'docs/release-checklist.md',
  'docs/helm-plan-review.html'
];

for (const file of publicDocs) {
  const text = read(file);
  if (/\/(?:Users|Volumes)\//.test(text)) fail(`${file}: local absolute path leaked`);
}

const requiredEnglish = [
  'This is not a Kubernetes Helm chart plugin.',
  '## First Run',
  'claude plugin validate "$PWD"',
  'docs/user-journey.md',
  'docs/spec-discovery.md',
  'docs/command-skill-matrix.md'
];
for (const marker of requiredEnglish) {
  if (!read('README.md').includes(marker)) fail(`README.md missing marker: ${marker}`);
}

const requiredChinese = [
  '它不是 Kubernetes Helm chart 插件',
  '## 第一次使用',
  'claude plugin validate "$PWD"',
  'docs/user-journey.md',
  'docs/spec-discovery.md',
  'docs/command-skill-matrix.md'
];
for (const marker of requiredChinese) {
  if (!read('README.zh-CN.md').includes(marker)) fail(`README.zh-CN.md missing marker: ${marker}`);
}

function listCommandFiles(dir) {
  const files = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) files.push(...listCommandFiles(full));
    else if (entry.isFile() && full.includes(`${path.sep}commands${path.sep}`) && entry.name.endsWith('.md')) {
      files.push(full);
    }
  }
  return files;
}

for (const file of listCommandFiles(path.join(root, 'plugins'))) {
  const relative = path.relative(root, file);
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  let inBash = false;
  const bashLines = [];
  for (const line of lines) {
    if (/^```bash\s*$/.test(line)) {
      inBash = true;
      continue;
    }
    if (/^```\s*$/.test(line) && inBash) {
      inBash = false;
      continue;
    }
    if (inBash) bashLines.push(line);
  }
  const bash = bashLines.join('\n');
  if (/<[A-Za-z0-9_-][^>]*>/.test(bash)) {
    fail(`${relative}: executable bash block contains placeholder`);
  }
  if (/--plugin\s+--json/.test(bash) || /--plugin\s{2,}/.test(bash)) {
    fail(`${relative}: executable bash block contains empty --plugin`);
  }
}

if (errors.length) {
  for (const error of errors) console.error(error);
  process.exit(2);
}
NODE

echo "helm public hygiene fixtures ok"
