#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const lib = require('./helm-lib');
const suite = require('./plugin-suite');
const workflow = require('./workflow-state');

function argValue(args, name, fallback = null) {
  const index = args.indexOf(name);
  const value = index >= 0 ? args[index + 1] : null;
  return value && !value.startsWith('--') ? value : fallback;
}

function defaultPluginRoot() {
  return path.resolve(__dirname, '..');
}

function defaultMarketplaceRoot(pluginRoot = defaultPluginRoot()) {
  return path.resolve(pluginRoot, '../..');
}

function check(name, ok, detail = '') {
  return { name, status: ok ? 'pass' : 'fail', ok, detail };
}

function doctor(options = {}) {
  const pluginRoot = path.resolve(options.pluginRoot || defaultPluginRoot());
  const marketplaceRoot = path.resolve(options.marketplaceRoot || defaultMarketplaceRoot(pluginRoot));
  const targetRoot = process.env.PROJECT_DIR ? path.resolve(process.env.PROJECT_DIR) : null;
  const suiteStatus = suite.listPlugins({ marketplaceRoot });
  const checks = [];

  checks.push(check('plugin-root', fs.existsSync(path.join(pluginRoot, '.claude-plugin', 'plugin.json')), pluginRoot));
  checks.push(check('marketplace-root', fs.existsSync(path.join(marketplaceRoot, '.claude-plugin', 'marketplace.json')), marketplaceRoot));
  checks.push(check('plugin-suite', suiteStatus.ok, suiteStatus.blockers.join(', ') || 'ok'));
  checks.push(check('hooks', fs.existsSync(path.join(pluginRoot, 'hooks', 'hooks.json')), 'plugins/helm-core/hooks/hooks.json'));
  checks.push(check('core-runtime', fs.existsSync(path.join(pluginRoot, 'scripts', 'plugin-suite.js')) && fs.existsSync(path.join(pluginRoot, 'scripts', 'workflow-state.js')), 'core scripts'));
  checks.push(check('commands', fs.existsSync(path.join(pluginRoot, 'commands', 'helm.md')), 'helm command'));
  const openspecCli = lib.runCommand('command -v openspec', { cwd: marketplaceRoot, timeoutMs: 10000 });
  checks.push(check('openspec-cli', openspecCli.ok, openspecCli.ok ? openspecCli.stdout.trim() : (openspecCli.stderr || 'openspec not found')));
  if (targetRoot) {
    const helmDir = lib.helmDir(targetRoot);
    const hasOpenSpec = fs.existsSync(lib.openspecDir(targetRoot));
    checks.push(check('target-openspec', hasOpenSpec, targetRoot));
    if (hasOpenSpec) {
      checks.push(check('workflow-state-file', fs.existsSync(path.join(helmDir, 'workflow-state.json')), 'openspec/.helm/workflow-state.json'));
      const contextOk = workflow.CONTEXT_MANIFESTS.every(([, fileName]) => {
        const file = path.join(helmDir, 'context', fileName);
        return fs.existsSync(file) && fs.readFileSync(file, 'utf8').trim() !== '';
      });
      checks.push(check('context-manifests', contextOk, 'openspec/.helm/context/*.jsonl'));
      checks.push(check('journal', fs.existsSync(path.join(helmDir, 'journal', 'index.md')), 'openspec/.helm/journal/index.md'));
    }
  }

  const blockers = checks.filter((item) => !item.ok).map((item) => item.name);
  return {
    schema_version: 1,
    generated_at: new Date().toISOString(),
    ok: blockers.length === 0,
    status: blockers.length === 0 ? 'ready' : 'blocked',
    plugin_root: pluginRoot,
    marketplace_root: marketplaceRoot,
    target_root: targetRoot,
    blockers,
    checks,
    suite: suiteStatus
  };
}

function toText(result) {
  const lines = [];
  lines.push('# Helm Doctor');
  lines.push('');
  lines.push(`- status: ${result.status}`);
  lines.push(`- plugin_root: ${result.plugin_root}`);
  lines.push(`- marketplace_root: ${result.marketplace_root}`);
  lines.push(`- blockers: ${result.blockers.join(', ') || '-'}`);
  lines.push('');
  lines.push('| Check | Status | Detail |');
  lines.push('| --- | --- | --- |');
  for (const item of result.checks) {
    lines.push(`| ${item.name} | ${item.status} | ${item.detail || '-'} |`);
  }
  return `${lines.join('\n')}\n`;
}

function main() {
  const args = process.argv.slice(2);
  const result = doctor({
    marketplaceRoot: argValue(args, '--marketplace-root', null),
    pluginRoot: argValue(args, '--plugin-root', null)
  });
  if (args.includes('--json')) process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  else process.stdout.write(toText(result));
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = { doctor, toText };
