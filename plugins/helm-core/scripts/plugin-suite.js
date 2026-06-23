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
    return { ok: false, status: 'unreadable' };
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

function isObject(value) {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}

function valueBlocker(status, kind, name) {
  if (status === 'malformed') return `malformed-${kind}:${name}`;
  if (status === 'unreadable') return `unreadable-${kind}:${name}`;
  return `missing-${kind}:${name}`;
}

function marketplaceBlocker(status) {
  if (status === 'malformed') return 'malformed-marketplace-json';
  if (status === 'unreadable') return 'unreadable-marketplace-json';
  return 'missing-marketplace-json';
}

function isValidStageManifest(value) {
  return isObject(value)
    && isNonEmpty(value.stage)
    && (!Object.prototype.hasOwnProperty.call(value, 'commands') || Array.isArray(value.commands))
    && (!Object.prototype.hasOwnProperty.call(value, 'skills') || Array.isArray(value.skills))
    && (!Object.prototype.hasOwnProperty.call(value, 'contracts') || isObject(value.contracts));
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
    if (args[i] === name && isNonEmpty(args[i + 1]) && !args[i + 1].startsWith('--')) values.push(args[i + 1]);
  }
  return values;
}

function argValue(args, name, fallback = null) {
  const index = args.indexOf(name);
  const value = index >= 0 ? args[index + 1] : null;
  return isNonEmpty(value) && !value.startsWith('--') ? value : fallback;
}

function parseArgs(args) {
  const command = args[0] && !args[0].startsWith('--') ? args[0] : 'list';
  const values = {
    '--marketplace-root': [],
    '--plugin': []
  };
  const occurrences = {
    '--marketplace-root': 0,
    '--plugin': 0
  };
  const blockers = [];

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (i === 0 && arg === command && !arg.startsWith('--')) continue;
    if (arg === '--json') continue;
    if (!Object.prototype.hasOwnProperty.call(values, arg)) continue;
    occurrences[arg] += 1;

    const value = args[i + 1];
    if (!isNonEmpty(value) || value.startsWith('--')) {
      blockers.push(`missing-argument:${arg}`);
      continue;
    }
    values[arg].push(value);
    i += 1;
  }

  if (command === 'resolve' && occurrences['--plugin'] > 1) {
    blockers.push('duplicate-argument:--plugin');
  }

  return {
    command,
    marketplaceRoot: values['--marketplace-root'].length
      ? values['--marketplace-root'][values['--marketplace-root'].length - 1]
      : null,
    plugins: values['--plugin'],
    plugin: values['--plugin'].length ? values['--plugin'][values['--plugin'].length - 1] : null,
    blockers: unique(blockers)
  };
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
      blockers: [marketplaceBlocker(marketplace.status)]
    };
  }
  if (!isObject(marketplace.value) || !Array.isArray(marketplace.value.plugins)) {
    return { ok: false, marketplaceRoot, blockers: ['invalid-marketplace-json'] };
  }
  return { ok: true, marketplaceRoot, marketplace: marketplace.value };
}

function pluginRecord(marketplaceRoot, entry, index) {
  if (!entry || typeof entry !== 'object' || Array.isArray(entry)) {
    return {
      name: null,
      source: null,
      root: null,
      version: null,
      stage: null,
      required: false,
      commands: [],
      skills: [],
      contracts: {},
      ok: false,
      blockers: [`invalid-plugin-entry:${index}`]
    };
  }

  const name = isNonEmpty(entry.name) ? entry.name.trim() : null;
  const source = isNonEmpty(entry.source) ? entry.source.trim() : null;
  const entryBlockers = [];
  if (!name) entryBlockers.push(`missing-plugin-name:${index}`);
  if (name && !source) entryBlockers.push(`missing-plugin-source:${name}`);

  if (entryBlockers.length) {
    return {
      name,
      source,
      root: source ? path.resolve(marketplaceRoot, source) : null,
      version: entry.version || null,
      stage: null,
      required: false,
      commands: [],
      skills: [],
      contracts: {},
      ok: false,
      blockers: unique(entryBlockers)
    };
  }

  const root = path.resolve(marketplaceRoot, source);
  if (sourceOutsideMarketplace(marketplaceRoot, root)) {
    return {
      name,
      source,
      root,
      version: entry.version || null,
      stage: null,
      required: false,
      commands: [],
      skills: [],
      contracts: {},
      ok: false,
      blockers: [`plugin-source-outside-marketplace:${name}`]
    };
  }

  const pluginJson = readJson(path.join(root, '.claude-plugin', 'plugin.json'));
  const stage = readJson(path.join(root, 'helm-stage.json'));
  const pluginMetadataValid = pluginJson.ok && isObject(pluginJson.value);
  const stageManifestValid = stage.ok && isValidStageManifest(stage.value);
  const pluginMetadata = pluginMetadataValid ? pluginJson.value : null;
  const stageManifest = stageManifestValid ? stage.value : null;
  const blockers = [
    pluginJson.ok
      ? (pluginMetadataValid ? null : `invalid-plugin-json:${name}`)
      : valueBlocker(pluginJson.status, 'plugin-json', name),
    stage.ok
      ? (stageManifestValid ? null : `invalid-stage-manifest:${name}`)
      : valueBlocker(stage.status, 'stage-manifest', name)
  ];

  return {
    name,
    source,
    root,
    version: entry.version || (pluginMetadata && pluginMetadata.version) || null,
    stage: stageManifest && stageManifest.stage,
    required: !!(stageManifest && stageManifest.required),
    commands: stageManifest ? (stageManifest.commands || []) : null,
    skills: stageManifest ? (stageManifest.skills || []) : null,
    contracts: stageManifest ? (stageManifest.contracts || {}) : null,
    ok: pluginMetadataValid && stageManifestValid,
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
  const plugins = loaded.marketplace.plugins.map((entry, index) => pluginRecord(loaded.marketplaceRoot, entry, index));
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
  const cli = parseArgs(args);
  const { command, marketplaceRoot } = cli;
  let result;
  if (cli.blockers.length) {
    result = {
      ok: false,
      marketplace_root: resolveMarketplaceRoot(marketplaceRoot),
      blockers: cli.blockers
    };
  } else if (command === 'list') {
    result = listPlugins({ marketplaceRoot });
  } else if (command === 'resolve') {
    result = resolvePlugin({ marketplaceRoot, plugin: cli.plugin });
  } else if (command === 'require') {
    result = requirePlugins({ marketplaceRoot, plugins: cli.plugins });
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
