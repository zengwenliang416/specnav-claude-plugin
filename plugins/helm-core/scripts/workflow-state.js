#!/usr/bin/env node
'use strict';

const path = require('path');
const lib = require('./helm-lib');
const affordances = require('./affordances');
const suite = require('./plugin-suite');

function argValue(args, name, fallback = null) {
  const index = args.indexOf(name);
  const value = index >= 0 ? args[index + 1] : null;
  return value && !value.startsWith('--') ? value : fallback;
}

function defaultMarketplaceRoot() {
  return path.resolve(__dirname, '../../..');
}

function workflowState(root = lib.projectRoot(), options = {}) {
  const marketplaceRoot = options.marketplaceRoot || process.env.HELM_MARKETPLACE_ROOT || defaultMarketplaceRoot();
  const pluginSuite = suite.listPlugins({ marketplaceRoot });
  const table = affordances.buildAffordances(root, { suiteStatus: pluginSuite });
  const blockers = [];
  if (!pluginSuite.ok) blockers.push(...pluginSuite.blockers);

  return {
    schema_version: 1,
    generated_at: new Date().toISOString(),
    ok: blockers.length === 0,
    status: blockers.length === 0 ? 'ready' : 'blocked',
    project_root: root,
    active_change: table.active_change,
    marketplace_root: pluginSuite.marketplace_root || marketplaceRoot,
    blockers,
    plugin_suite: pluginSuite,
    required_plugins: table.required_plugins,
    actions: table.actions,
    affordances: table
  };
}

function toText(result) {
  const lines = [];
  lines.push('# Helm Workflow State');
  lines.push('');
  lines.push(`- project: ${result.project_root}`);
  lines.push(`- active_change: ${result.active_change || 'none'}`);
  lines.push(`- status: ${result.status}`);
  lines.push(`- marketplace_root: ${result.marketplace_root}`);
  lines.push(`- blockers: ${result.blockers.join(', ') || '-'}`);
  lines.push('');
  lines.push('| Action | State | Required Plugins | Blockers |');
  lines.push('| --- | --- | --- | --- |');
  for (const action of result.actions) {
    lines.push(`| ${action.id} | ${action.state} | ${(action.required_plugins || []).join(', ') || '-'} | ${action.blocked_by.join(', ') || '-'} |`);
  }
  return `${lines.join('\n')}\n`;
}

function main() {
  const args = process.argv.slice(2);
  const root = lib.projectRoot(process.argv);
  const result = workflowState(root, {
    marketplaceRoot: argValue(args, '--marketplace-root', null)
  });
  if (args.includes('--write')) {
    lib.writeJson(path.join(lib.helmDir(root), 'workflow-state.json'), result);
    lib.event(root, 'workflow-state.write', { active_change: result.active_change, status: result.status });
  }
  if (args.includes('--json')) process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  else process.stdout.write(toText(result));
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = { workflowState, toText };
