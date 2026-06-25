#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

node - "$ROOT" <<'NODE'
const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');

const root = process.argv[2];
const pluginsDir = path.join(root, 'plugins');
const pluginNames = fs.readdirSync(pluginsDir)
  .filter((name) => name.startsWith('helm-') && fs.statSync(path.join(pluginsDir, name)).isDirectory())
  .sort();

const allowedFrontmatter = new Set(['name', 'description']);
const genericNames = new Set([
  'status',
  'doctor',
  'debug',
  'deploy',
  'monitor',
  'rollback',
  'requirements',
  'prototype',
  'release-plan',
  'update-policy',
  'update-spec',
  'before-dev',
  'scope-lock',
  'vertical-slice-tasking',
  'foundation-spec',
  'compatibility-matrix',
  'branch-finish',
  'install-verify',
  'ops-readiness',
  'postmortem',
  'using-helm',
  'helm-router',
  'break-loop',
]);

const triggerPatterns = [
  /\bUse this skill when\b/i,
  /\bUse when\b/i,
  /\bTrigger\b/i,
  /\bwhenever\b/i,
  /用户/,
  /当.*时/,
];

const errors = [];

function fail(message) {
  errors.push(message);
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function listSkillFiles(pluginDir) {
  const skillsDir = path.join(pluginDir, 'skills');
  if (!fs.existsSync(skillsDir)) return [];
  return fs.readdirSync(skillsDir)
    .filter((name) => fs.statSync(path.join(skillsDir, name)).isDirectory())
    .map((name) => path.join(skillsDir, name, 'SKILL.md'))
    .filter((file) => fs.existsSync(file))
    .sort();
}

function parseFrontmatter(content, file) {
  if (!content.startsWith('---\n')) {
    fail(`${file}: missing YAML frontmatter`);
    return null;
  }
  const end = content.indexOf('\n---', 4);
  if (end === -1) {
    fail(`${file}: unclosed YAML frontmatter`);
    return null;
  }
  const frontmatter = content.slice(4, end).trim();
  const body = content.slice(end + 4).replace(/^\n/, '');
  const data = {};
  for (const rawLine of frontmatter.split(/\n/)) {
    const line = rawLine.trimEnd();
    if (!line.trim()) continue;
    const match = line.match(/^([A-Za-z0-9_-]+):(?:\s*(.*))?$/);
    if (!match) {
      fail(`${file}: unsupported frontmatter line: ${line}`);
      continue;
    }
    const key = match[1];
    let value = match[2] || '';
    value = value.trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (data[key] !== undefined) {
      fail(`${file}: duplicate frontmatter key ${key}`);
    }
    data[key] = value;
  }
  return { data, body };
}

const checkedScripts = new Set();

function validateNodeScript(file, target, { requireHelp = false } = {}) {
  const real = path.resolve(target);
  if (checkedScripts.has(`${real}:${requireHelp}`)) return;
  checkedScripts.add(`${real}:${requireHelp}`);

  if (path.extname(real) !== '.js') return;

  const check = childProcess.spawnSync(process.execPath, ['--check', real], {
    cwd: root,
    encoding: 'utf8'
  });
  if (check.status !== 0) {
    fail(`${file}: referenced script fails node --check: ${path.relative(root, real)} ${check.stderr || check.stdout}`);
  }

  if (requireHelp) {
    const help = childProcess.spawnSync(process.execPath, [real, '--help'], {
      cwd: root,
      encoding: 'utf8'
    });
    if (help.status !== 0 || !/Usage:/i.test(`${help.stdout}\n${help.stderr}`)) {
      fail(`${file}: skill-local script must support --help: ${path.relative(root, real)}`);
    }
  }
}

function validateScriptReference(pluginName, file, scriptRef) {
  const pluginDir = path.join(pluginsDir, pluginName);
  let target;
  if (scriptRef.startsWith('../')) {
    target = path.normalize(path.join(pluginDir, scriptRef));
  } else {
    target = path.join(pluginDir, scriptRef);
  }
  if (!target.startsWith(pluginsDir) || !fs.existsSync(target)) {
    fail(`${file}: referenced script does not exist: ${scriptRef}`);
    return;
  }
  validateNodeScript(file, target, { requireHelp: scriptRef.includes('/skills/') });
}

function extractHelmRootScriptRefs(body) {
  const refs = [];
  const varToPlugin = {
    HELM_CORE_ROOT: 'helm-core',
    HELM_REQUIREMENTS_ROOT: 'helm-requirements',
    HELM_PROTOTYPE_ROOT: 'helm-prototype',
    HELM_DEVELOPMENT_ROOT: 'helm-development',
    HELM_VERIFICATION_ROOT: 'helm-verification',
    HELM_OPERATIONS_ROOT: 'helm-operations'
  };
  const pattern = /\$(HELM_[A-Z_]+_ROOT)\/[^"'\s`)]+\.js/g;
  for (const match of body.matchAll(pattern)) {
    const targetPlugin = varToPlugin[match[1]];
    if (!targetPlugin) {
      fail(`unknown Helm root variable: ${match[1]}`);
      continue;
    }
    refs.push({
      pluginName: targetPlugin,
      scriptRef: match[0].replace(`$${match[1]}/`, '')
    });
  }
  return refs;
}

function listResourceFiles(skillDir) {
  const files = [];
  for (const kind of ['references', 'assets', 'scripts']) {
    const base = path.join(skillDir, kind);
    if (!fs.existsSync(base)) continue;
    const walk = (dir) => {
      for (const name of fs.readdirSync(dir)) {
        const file = path.join(dir, name);
        const stat = fs.statSync(file);
        if (stat.isDirectory()) {
          walk(file);
        } else if (stat.isFile()) {
          files.push(path.relative(skillDir, file).split(path.sep).join('/'));
        }
      }
    };
    walk(base);
  }
  return files.sort();
}

function checkSkill(pluginName, file, declaredSkillNames) {
  const content = fs.readFileSync(file, 'utf8');
  const folderName = path.basename(path.dirname(file));
  const rel = path.relative(root, file);
  const parsed = parseFrontmatter(content, rel);
  if (!parsed) return;

  const { data, body } = parsed;
  const keys = Object.keys(data);
  for (const key of keys) {
    if (!allowedFrontmatter.has(key)) {
      fail(`${rel}: frontmatter key not allowed in Helm strict subset: ${key}`);
    }
  }
  for (const key of allowedFrontmatter) {
    if (!keys.includes(key)) {
      fail(`${rel}: missing frontmatter key ${key}`);
    }
  }

  const name = data.name || '';
  const description = data.description || '';

  if (name !== folderName) {
    fail(`${rel}: name '${name}' must match folder '${folderName}'`);
  }
  if (!/^helm-[a-z0-9]+(?:-[a-z0-9]+)*$/.test(name)) {
    fail(`${rel}: skill name must be helm-prefixed lowercase kebab-case`);
  }
  if (name.length > 64) {
    fail(`${rel}: skill name exceeds 64 characters`);
  }
  if (genericNames.has(name)) {
    fail(`${rel}: generic or legacy public skill name remains: ${name}`);
  }
  if (!declaredSkillNames.has(name)) {
    fail(`${rel}: skill is not declared in helm-stage.json`);
  }

  if (!description.trim()) {
    fail(`${rel}: description is empty`);
  }
  if (description.length > 1024) {
    fail(`${rel}: description exceeds 1024 characters`);
  }
  if (description.length < 80) {
    fail(`${rel}: description is too short for reliable triggering`);
  }
  if (!triggerPatterns.some((pattern) => pattern.test(description))) {
    fail(`${rel}: description lacks explicit trigger language`);
  }

  if (/allowed-tools:|metadata:|compatibility:|not-implemented|placeholder|This skill is not implemented yet|TODO|TBD/i.test(content)) {
    fail(`${rel}: placeholder, unsupported frontmatter, or unfinished text remains`);
  }

  const requiredSections = ['## Purpose', '## Workflow', '## Stop Conditions', '## Validation'];
  for (const section of requiredSections) {
    if (!body.includes(section)) {
      fail(`${rel}: missing required body section ${section}`);
    }
  }

  const lineCount = content.split(/\n/).length;
  if (lineCount > 500) {
    fail(`${rel}: SKILL.md exceeds 500 lines`);
  }

  const resourceRefs = body.match(/\b(?:references|assets)\/[A-Za-z0-9._/-]+/g) || [];
  for (const resourceRef of resourceRefs) {
    const target = path.join(path.dirname(file), resourceRef);
    if (!fs.existsSync(target)) {
      fail(`${rel}: referenced skill resource does not exist: ${resourceRef}`);
    }
  }

  for (const resourceFile of listResourceFiles(path.dirname(file))) {
    if (!body.includes(resourceFile)) {
      fail(`${rel}: skill resource is not explicitly referenced from SKILL.md: ${resourceFile}`);
    }
  }

  if (body.includes('$CLAUDE_PLUGIN_ROOT')) {
    fail(`${rel}: skill must not rely on CLAUDE_PLUGIN_ROOT outside hooks`);
  }

  const scriptRefs = extractHelmRootScriptRefs(body);
  for (const { pluginName: targetPlugin, scriptRef } of scriptRefs) {
    validateScriptReference(targetPlugin, rel, scriptRef);
  }
}

for (const pluginName of pluginNames) {
  const pluginDir = path.join(pluginsDir, pluginName);
  const stageFile = path.join(pluginDir, 'helm-stage.json');
  if (!fs.existsSync(stageFile)) {
    fail(`${pluginName}: missing helm-stage.json`);
    continue;
  }

  const stage = readJson(stageFile);
  const declaredSkills = new Set(stage.skills || []);

  for (const skillName of declaredSkills) {
    const skillFile = path.join(pluginDir, 'skills', skillName, 'SKILL.md');
    if (!fs.existsSync(skillFile)) {
      fail(`${pluginName}: declared skill missing: ${skillName}`);
    }
  }

  for (const skillFile of listSkillFiles(pluginDir)) {
    checkSkill(pluginName, skillFile, declaredSkills);
  }
}

if (errors.length) {
  for (const error of errors) {
    console.error(error);
  }
  process.exit(1);
}

console.log('helm skill contract fixtures ok');
NODE
