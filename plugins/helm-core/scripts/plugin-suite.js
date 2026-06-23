#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

function readJson(file) {
  try {
    return { ok: true, value: JSON.parse(fs.readFileSync(file, 'utf8')) };
  } catch (error) {
    if (error && error.code === 'ENOENT') return { ok: false, status: 'missing' };
    if (error instanceof SyntaxError) return { ok: false, status: 'malformed' };
    return { ok: false, status: 'missing' };
  }
}

function unique(values) {
  const seen = new Set();
  return values.filter((value) => {
    if (!value || seen.has(value)) return false;
    seen.add(value);
    return true;
  });
}

function isNonEmpty(value) {
  return typeof value === 'string' && value.trim() !== '';
}

function resolveMarketplaceRoot(root) {
  return path.resolve(root || findMarketplaceRoot(process.cwd()) || process.cwd());
}

function isPathInside(parent, child) {
  const relative = path.relative(parent, child);
  return relative === '' || (!!relative && !relative.startsWith('..') && !path.isAbsolute(relative));
}

function realpathOrNull(file) {
  try {
    return fs.realpathSync.native(file);
  } catch {
    return null;
  }
}

function sourceOutsideMarketplace(marketplaceRoot, pluginRoot) {
  const resolvedMarketplaceRoot = path.resolve(marketplaceRoot);
  const resolvedPluginRoot = path.resolve(pluginRoot);
  if (!isPathInside(resolvedMarketplaceRoot, resolvedPluginRoot)) return true;

  const marketplaceReal = realpathOrNull(resolvedMarketplaceRoot) || resolvedMarketplaceRoot;
  const pluginReal = realpathOrNull(resolvedPluginRoot);
  return !!pluginReal && !isPathInside(marketplaceReal, pluginReal);
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
  const marketplaceRoot = resolveMarketplaceRoot(root);
  const marketplaceFile = path.join(marketplaceRoot, '.claude-plugin', 'marketplace.json');
  const marketplace = readJson(marketplaceFile);
  if (!marketplace.ok) {
    return {
      ok: false,
      marketplaceRoot,
      blockers: [marketplace.status === 'malformed' ? 'malformed-marketplace-json' : 'marketplace-json']
    };
  }
  if (!marketplace.value || !Array.isArray(marketplace.value.plugins)) {
    return { ok: false, marketplaceRoot, blockers: ['marketplace-json'] };
  }
  return { ok: true, marketplaceRoot, marketplace: marketplace.value };
}

function pluginRecord(marketplaceRoot, entry) {
  const source = entry.source || './';
  const root = path.resolve(marketplaceRoot, source);
  if (sourceOutsideMarketplace(marketplaceRoot, root)) {
    return {
      name: entry.name,
      source,
      root,
      version: entry.version || null,
      stage: null,
      required: false,
      commands: [],
      skills: [],
      contracts: {},
      ok: false,
      blockers: [`plugin-source-outside-marketplace:${entry.name}`]
    };
  }

  const pluginJson = readJson(path.join(root, '.claude-plugin', 'plugin.json'));
  const stage = readJson(path.join(root, 'helm-stage.json'));
  const pluginMetadata = pluginJson.ok ? pluginJson.value : null;
  const stageManifest = stage.ok ? stage.value : null;
  const blockers = [
    pluginJson.ok
      ? null
      : `${pluginJson.status === 'malformed' ? 'malformed' : 'missing'}-plugin-json:${entry.name}`,
    stage.ok
      ? null
      : `${stage.status === 'malformed' ? 'malformed' : 'missing'}-stage-manifest:${entry.name}`
  ];

  return {
    name: entry.name,
    source,
    root,
    version: entry.version || (pluginMetadata && pluginMetadata.version) || null,
    stage: stageManifest && stageManifest.stage,
    required: !!(stageManifest && stageManifest.required),
    commands: stageManifest && stageManifest.commands || [],
    skills: stageManifest && stageManifest.skills || [],
    contracts: stageManifest && stageManifest.contracts || {},
    ok: pluginJson.ok && stage.ok,
    blockers: unique(blockers)
  };
}

function listPlugins(options = {}) {
  const loaded = loadMarketplace(options.marketplaceRoot);
  if (!loaded.ok) {
    return {
      ok: false,
      blockers: unique(loaded.blockers),
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
    blockers: unique(blockers),
    plugins
  };
}

function resolvePlugin(options = {}) {
  if (!isNonEmpty(options.plugin)) {
    return {
      ok: false,
      marketplace_root: resolveMarketplaceRoot(options.marketplaceRoot),
      blockers: ['missing-argument:--plugin'],
      plugin: null
    };
  }
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
    blockers: unique(plugin.blockers),
    plugin
  };
}

function requirePlugins(options = {}) {
  const required = (options.plugins || []).filter(isNonEmpty);
  if (required.length === 0) {
    return {
      ok: false,
      marketplace_root: resolveMarketplaceRoot(options.marketplaceRoot),
      blockers: ['missing-argument:--plugin'],
      required,
      plugins: []
    };
  }
  const suite = listPlugins(options);
  const blockers = [...suite.blockers];
  for (const name of required) {
    const plugin = suite.plugins.find((item) => item.name === name);
    if (!plugin) blockers.push(`missing-plugin:${name}`);
    else blockers.push(...plugin.blockers);
  }
  return {
    ok: blockers.length === 0,
    marketplace_root: suite.marketplace_root,
    blockers: unique(blockers),
    required,
    plugins: suite.plugins.filter((item) => required.includes(item.name))
  };
}

function main() {
  const args = process.argv.slice(2);
  const command = args[0] && !args[0].startsWith('--') ? args[0] : 'list';
  const marketplaceRoot = argValue(args, '--marketplace-root');
  let result;
  if (command === 'list') {
    result = listPlugins({ marketplaceRoot });
  } else if (command === 'resolve') {
    result = resolvePlugin({ marketplaceRoot, plugin: argValue(args, '--plugin') });
  } else if (command === 'require') {
    result = requirePlugins({ marketplaceRoot, plugins: argValues(args, '--plugin') });
  } else {
    result = {
      ok: false,
      marketplace_root: resolveMarketplaceRoot(marketplaceRoot),
      blockers: [`unknown-command:${command}`]
    };
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
