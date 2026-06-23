#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

function readJson(file, fallback = null) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
}

function argValues(args, name) {
  const values = [];
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === name && args[i + 1]) values.push(args[i + 1]);
  }
  return values;
}

function argValue(args, name, fallback = null) {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : fallback;
}

function findMarketplaceRoot(start) {
  let current = path.resolve(start);
  while (true) {
    if (fs.existsSync(path.join(current, '.claude-plugin', 'marketplace.json'))) return current;
    const parent = path.dirname(current);
    if (parent === current) return null;
    current = parent;
  }
}

function loadMarketplace(root) {
  const marketplaceRoot = path.resolve(root || findMarketplaceRoot(process.cwd()) || process.cwd());
  const marketplaceFile = path.join(marketplaceRoot, '.claude-plugin', 'marketplace.json');
  const marketplace = readJson(marketplaceFile, null);
  if (!marketplace || !Array.isArray(marketplace.plugins)) {
    return { ok: false, marketplaceRoot, blockers: ['marketplace-json'] };
  }
  return { ok: true, marketplaceRoot, marketplace };
}

function pluginRecord(marketplaceRoot, entry) {
  const source = entry.source || './';
  const root = path.resolve(marketplaceRoot, source);
  const pluginJson = readJson(path.join(root, '.claude-plugin', 'plugin.json'), null);
  const stage = readJson(path.join(root, 'helm-stage.json'), null);
  return {
    name: entry.name,
    source,
    root,
    version: entry.version || (pluginJson && pluginJson.version) || null,
    stage: stage && stage.stage,
    required: !!(stage && stage.required),
    commands: stage && stage.commands || [],
    skills: stage && stage.skills || [],
    contracts: stage && stage.contracts || {},
    ok: !!pluginJson && !!stage,
    blockers: [
      pluginJson ? null : `missing-plugin-json:${entry.name}`,
      stage ? null : `missing-stage-manifest:${entry.name}`
    ].filter(Boolean)
  };
}

function listPlugins(options = {}) {
  const loaded = loadMarketplace(options.marketplaceRoot);
  if (!loaded.ok) {
    return {
      ok: false,
      blockers: loaded.blockers,
      marketplace_root: loaded.marketplaceRoot,
      plugins: []
    };
  }
  const plugins = loaded.marketplace.plugins.map((entry) => pluginRecord(loaded.marketplaceRoot, entry));
  const blockers = plugins.flatMap((plugin) => plugin.blockers);
  return {
    ok: blockers.length === 0,
    marketplace_root: loaded.marketplaceRoot,
    marketplace_name: loaded.marketplace.name || null,
    blockers,
    plugins
  };
}

function resolvePlugin(options = {}) {
  const suite = listPlugins(options);
  if (!suite.ok && !suite.plugins.length) return suite;
  const plugin = suite.plugins.find((item) => item.name === options.plugin);
  if (!plugin) {
    return {
      ok: false,
      marketplace_root: suite.marketplace_root,
      blockers: [`missing-plugin:${options.plugin}`],
      plugin: null
    };
  }
  return {
    ok: plugin.ok,
    marketplace_root: suite.marketplace_root,
    blockers: plugin.blockers,
    plugin
  };
}

function requirePlugins(options = {}) {
  const suite = listPlugins(options);
  const required = options.plugins || [];
  const blockers = [...suite.blockers];
  for (const name of required) {
    const plugin = suite.plugins.find((item) => item.name === name);
    if (!plugin) blockers.push(`missing-plugin:${name}`);
    else blockers.push(...plugin.blockers);
  }
  return {
    ok: blockers.length === 0,
    marketplace_root: suite.marketplace_root,
    blockers,
    required,
    plugins: suite.plugins.filter((item) => required.includes(item.name))
  };
}

function main() {
  const args = process.argv.slice(2);
  const command = args[0] || 'list';
  const marketplaceRoot = argValue(args, '--marketplace-root');
  let result;
  if (command === 'resolve') {
    result = resolvePlugin({ marketplaceRoot, plugin: argValue(args, '--plugin') });
  } else if (command === 'require') {
    result = requirePlugins({ marketplaceRoot, plugins: argValues(args, '--plugin') });
  } else {
    result = listPlugins({ marketplaceRoot });
  }
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  process.exit(result.ok ? 0 : 2);
}

if (require.main === module) main();

module.exports = {
  findMarketplaceRoot,
  listPlugins,
  resolvePlugin,
  requirePlugins
};
