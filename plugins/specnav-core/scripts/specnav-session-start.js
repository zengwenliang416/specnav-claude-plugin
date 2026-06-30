#!/usr/bin/env node
'use strict';

const fs = require('fs');
const lib = require('./specnav-lib');
const workflow = require('./workflow-state');

function main() {
  const root = lib.projectRoot();
  if (!fs.existsSync(lib.openspecDir(root))) {
    if (lib.isSpecNavProject(root)) {
      const result = {
        schema: 'specnav.sessionStart.v1',
        status: 'blocked',
        blockers: ['missing-openspec'],
        project_root: root,
        allowed_actions: [
          '/specnav-bootstrap',
          '/specnav-status',
          '/specnav-doctor'
        ],
        recommended_command: '/specnav-bootstrap'
      };
      process.stderr.write(`[specnav] missing-openspec: run /specnav-bootstrap to initialize OpenSpec for ${root} before production work.\n`);
      process.stdout.write(`${JSON.stringify(result)}\n`);
      return;
    }
    process.stdout.write(`${JSON.stringify({
      schema: 'specnav.sessionStart.v1',
      status: 'inactive',
      project_root: root
    })}\n`);
    return;
  }

  const state = workflow.writeRuntimeArtifacts(root);
  const legacyEntrypoints = lib.detectLegacyOpenSpecEntrypoints(root);
  lib.event(root, 'session.start', { cwd: root, status: state.status });
  process.stdout.write(`${JSON.stringify({
    schema: 'specnav.sessionStart.v1',
    status: state.status,
    project_root: root,
    blockers: state.blockers,
    legacy_openspec_entrypoints: legacyEntrypoints,
    native_openspec_skills: 'disabled when SpecNav is active; use OpenSpec CLI only as commanded by SpecNav contracts',
    completion_rule: 'do not claim a stage complete or hand off until the owning SpecNav contract returns ok:true',
    workflow_state: 'openspec/.specnav/workflow-state.json'
  })}\n`);
}

main();
