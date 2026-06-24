#!/usr/bin/env node
'use strict';

const fs = require('fs');
const lib = require('./helm-lib');
const workflow = require('./workflow-state');

function main() {
  const root = lib.projectRoot();
  if (!fs.existsSync(lib.openspecDir(root))) {
    const result = {
      schema: 'helm.sessionStart.v1',
      status: 'blocked',
      blockers: ['missing-openspec'],
      project_root: root,
      allowed_actions: [
        '/helm-bootstrap',
        '/helm-status',
        '/helm-doctor'
      ],
      recommended_command: '/helm-bootstrap'
    };
    process.stderr.write(`[helm] missing-openspec: run /helm-bootstrap to initialize OpenSpec for ${root} before production work.\n`);
    process.stdout.write(`${JSON.stringify(result)}\n`);
    return;
  }

  const state = workflow.writeRuntimeArtifacts(root);
  lib.event(root, 'session.start', { cwd: root, status: state.status });
  process.stdout.write(`${JSON.stringify({
    schema: 'helm.sessionStart.v1',
    status: state.status,
    project_root: root,
    blockers: state.blockers,
    workflow_state: 'openspec/.helm/workflow-state.json'
  })}\n`);
}

main();
