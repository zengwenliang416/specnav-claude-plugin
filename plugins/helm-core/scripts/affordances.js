#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const lib = require('./helm-lib');
const suite = require('./plugin-suite');

const REQUIRED_PLUGINS = [
  'helm-core',
  'helm-requirements',
  'helm-prototype',
  'helm-development',
  'helm-verification',
  'helm-operations'
];

const ACTION_PLUGINS = {
  bootstrap: ['helm-core'],
  propose: ['helm-core', 'helm-requirements'],
  design: ['helm-core', 'helm-requirements'],
  tasks: ['helm-core', 'helm-requirements'],
  implement: ['helm-core', 'helm-development'],
  fix: ['helm-core', 'helm-development', 'helm-verification'],
  verify: ['helm-core', 'helm-verification'],
  release: ['helm-core', 'helm-verification', 'helm-operations'],
  archive: ['helm-core', 'helm-verification', 'helm-operations'],
  status: ['helm-core']
};

function defaultMarketplaceRoot() {
  return path.resolve(__dirname, '../../..');
}

function buildAffordances(root, options = {}) {
  const open = lib.openspecDir(root);
  const change = lib.activeChange(root);
  const dir = lib.changeDir(root, change);
  const suiteStatus = options.suiteStatus || suite.listPlugins({
    marketplaceRoot: options.marketplaceRoot || process.env.HELM_MARKETPLACE_ROOT || defaultMarketplaceRoot()
  });
  const okPlugins = new Set((suiteStatus.plugins || []).filter((plugin) => plugin.ok).map((plugin) => plugin.name));
  const hasOpenSpec = fs.existsSync(open);
  const openspecStatus = hasOpenSpec && change ? lib.openspecStatus(root, change) : { ok: false, error: 'openspec-missing-or-no-change' };
  const openspecArtifacts = new Map(
    openspecStatus.ok
      ? (openspecStatus.status.artifacts || []).map((artifact) => [artifact.id, artifact.status])
      : []
  );
  const artifactDone = (id) => openspecArtifacts.get(id) === 'done';
  const useOpenSpec = openspecStatus.ok;
  const proposal = useOpenSpec ? artifactDone('proposal') : (dir && lib.fileExists(path.join(dir, 'proposal.md')));
  const design = useOpenSpec ? artifactDone('design') : (dir && lib.fileExists(path.join(dir, 'design.md')));
  const tasks = useOpenSpec ? artifactDone('tasks') : (dir && lib.fileExists(path.join(dir, 'tasks.md')));
  const specs = useOpenSpec ? artifactDone('specs') : (dir && fs.existsSync(path.join(dir, 'specs')));
  const scope = dir && lib.fileExists(path.join(dir, 'scope.json'));
  const risk = lib.readJson(dir && path.join(dir, 'risk-tier.json'), { tier: 'standard', source: 'default' });
  const verify = lib.readJson(dir && path.join(dir, 'verify-report.json'), null);
  const staleMarker = dir && lib.fileExists(path.join(dir, 'verify-report.stale'));
  const verifyStatus = verify ? verify.status : 'not_run';
  const verifyReportStale = !!(verify && staleMarker);
  const signoff = dir && lib.fileExists(path.join(dir, 'signoff.yaml'));
  const operations = lib.readJson(dir && path.join(dir, 'operations', 'readiness.json'), null);
  const operationsReady = !!(operations && operations.ready === true);

  const actions = [];
  const add = (id, ready, blockers = [], reversible = true) => {
    const requiredPlugins = ACTION_PLUGINS[id] || ['helm-core'];
    const pluginBlockers = requiredPlugins
      .filter((plugin) => !okPlugins.has(plugin))
      .map((plugin) => `missing-plugin:${plugin}`);
    const allBlockers = [...blockers, ...pluginBlockers];
    actions.push({
      id,
      state: ready && allBlockers.length === 0 ? 'ready' : 'blocked',
      reversible,
      required_plugins: requiredPlugins,
      blocked_by: allBlockers
    });
  };

  add('bootstrap', !hasOpenSpec, hasOpenSpec ? ['openspec-exists'] : []);
  add('propose', hasOpenSpec, hasOpenSpec ? [] : ['bootstrap']);
  add('design', !!(proposal && !design), proposal ? [] : ['proposal']);
  add('tasks', !!(design && !tasks), design ? [] : ['design']);
  add('implement', !!(tasks && (verifyStatus !== 'green' || verifyReportStale)), tasks ? [] : ['tasks']);
  add('fix', !!(tasks && verify && (verifyStatus !== 'green' || verifyReportStale)), verify ? [] : ['verify']);
  add('verify', !!tasks, tasks ? [] : ['tasks']);
  const releaseBlockers = [];
  if (!verify || verify.status !== 'green') releaseBlockers.push('verify');
  if (verifyReportStale) releaseBlockers.push('fresh-verify');
  if (risk.tier === 'high-risk' && !signoff) releaseBlockers.push('human-signoff');
  add('release', releaseBlockers.length === 0, releaseBlockers, false);
  const archiveBlockers = [...releaseBlockers];
  if (!operationsReady) archiveBlockers.push('operations');
  add('archive', archiveBlockers.length === 0, archiveBlockers, false);
  add('status', true);

  return {
    schema_version: 1,
    generated_at: new Date().toISOString(),
    project_root: root,
    required_plugins: REQUIRED_PLUGINS,
    plugin_suite: {
      ok: suiteStatus.ok,
      marketplace_root: suiteStatus.marketplace_root,
      blockers: suiteStatus.blockers || []
    },
    state_source: useOpenSpec ? 'openspec-cli' : 'filesystem',
    openspec_status: openspecStatus.ok
      ? {
          schema_name: openspecStatus.status.schemaName,
          is_complete: openspecStatus.status.isComplete,
          apply_requires: openspecStatus.status.applyRequires || []
        }
      : {
          ok: false,
          error: openspecStatus.error || 'unavailable'
        },
    active_change: change,
    risk_tier: risk.tier || 'standard',
    risk_source: risk.source || 'default',
    verify_status: verifyStatus,
    verify_report_stale: verifyReportStale,
    artifacts: {
      openspec: hasOpenSpec,
      proposal: !!proposal,
      design: !!design,
      scope: !!scope,
      tasks: !!tasks,
      specs: !!specs,
      signoff: !!signoff,
      operations_readiness: operationsReady
    },
    actions
  };
}

function toMarkdown(table) {
  const lines = [];
  lines.push('# Helm Status');
  lines.push('');
  lines.push(`- project: \`${table.project_root}\``);
  lines.push(`- state source: \`${table.state_source}\``);
  lines.push(`- active change: \`${table.active_change || 'none'}\``);
  lines.push(`- risk tier: \`${table.risk_tier}\` (${table.risk_source})`);
  lines.push(`- verify: \`${table.verify_status}\`${table.verify_report_stale ? ' (stale)' : ''}`);
  lines.push(`- required plugins: \`${table.required_plugins.join(', ')}\``);
  lines.push('');
  lines.push('| Action | State | Required Plugins | Blockers |');
  lines.push('| --- | --- | --- | --- |');
  for (const action of table.actions) {
    lines.push(`| ${action.id} | ${action.state} | ${(action.required_plugins || []).join(', ') || '-'} | ${action.blocked_by.join(', ') || '-'} |`);
  }
  return `${lines.join('\n')}\n`;
}

function main() {
  const root = lib.projectRoot();
  const table = buildAffordances(root);
  if (process.argv.includes('--write-snapshot')) {
    lib.writeJson(path.join(lib.helmDir(root), 'affordances.json'), table);
    lib.event(root, 'affordances.write', { active_change: table.active_change });
  }
  if (process.argv.includes('--json')) {
    process.stdout.write(`${JSON.stringify(table, null, 2)}\n`);
  } else {
    process.stdout.write(toMarkdown(table));
  }
}

if (require.main === module) main();

module.exports = { buildAffordances, toMarkdown };
