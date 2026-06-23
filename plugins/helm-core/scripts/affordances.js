#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const lib = require('./helm-lib');

function buildAffordances(root) {
  const open = lib.openspecDir(root);
  const change = lib.activeChange(root);
  const dir = lib.changeDir(root, change);
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

  const actions = [];
  const add = (id, ready, blockers = [], reversible = true) => {
    actions.push({ id, state: ready ? 'ready' : 'blocked', reversible, blocked_by: blockers });
  };

  add('bootstrap', !hasOpenSpec, hasOpenSpec ? ['openspec-exists'] : []);
  add('propose', hasOpenSpec, hasOpenSpec ? [] : ['bootstrap']);
  add('design', !!(proposal && !design), proposal ? [] : ['proposal']);
  add('tasks', !!(design && !tasks), design ? [] : ['design']);
  add('implement', !!(tasks && (verifyStatus !== 'green' || verifyReportStale)), tasks ? [] : ['tasks']);
  add('fix', !!(tasks && verify && (verifyStatus !== 'green' || verifyReportStale)), verify ? [] : ['verify']);
  add('verify', !!tasks, tasks ? [] : ['tasks']);
  const archiveBlockers = [];
  if (!verify || verify.status !== 'green') archiveBlockers.push('verify');
  if (verifyReportStale) archiveBlockers.push('fresh-verify');
  if (risk.tier === 'high-risk' && !signoff) archiveBlockers.push('human-signoff');
  add('archive', archiveBlockers.length === 0, archiveBlockers, false);
  add('status', true);

  return {
    schema_version: 1,
    generated_at: new Date().toISOString(),
    project_root: root,
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
      signoff: !!signoff
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
  lines.push('');
  lines.push('| Action | State | Blockers |');
  lines.push('| --- | --- | --- |');
  for (const action of table.actions) {
    lines.push(`| ${action.id} | ${action.state} | ${action.blocked_by.join(', ') || '-'} |`);
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
