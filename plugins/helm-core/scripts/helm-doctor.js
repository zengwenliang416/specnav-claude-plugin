#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const suite = require('./plugin-suite');

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
  const suiteStatus = suite.listPlugins({ marketplaceRoot });
  const checks = [];

  checks.push(check('plugin-root', fs.existsSync(path.join(pluginRoot, '.claude-plugin', 'plugin.json')), pluginRoot));
  checks.push(check('marketplace-root', fs.existsSync(path.join(marketplaceRoot, '.claude-plugin', 'marketplace.json')), marketplaceRoot));
  checks.push(check('plugin-suite', suiteStatus.ok, suiteStatus.blockers.join(', ') || 'ok'));
  checks.push(check('hooks', fs.existsSync(path.join(pluginRoot, 'hooks', 'hooks.json')), 'plugins/helm-core/hooks/hooks.json'));
  checks.push(check('core-runtime', fs.existsSync(path.join(pluginRoot, 'scripts', 'plugin-suite.js')) && fs.existsSync(path.join(pluginRoot, 'scripts', 'workflow-state.js')), 'core scripts'));
  checks.push(check('commands', fs.existsSync(path.join(pluginRoot, 'commands', 'helm.md')), 'helm command'));

  const blockers = checks.filter((item) => !item.ok).map((item) => item.name);
  return {
    schema_version: 1,
    generated_at: new Date().toISOString(),
    ok: blockers.length === 0,
    status: blockers.length === 0 ? 'ready' : 'blocked',
    plugin_root: pluginRoot,
    marketplace_root: marketplaceRoot,
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
