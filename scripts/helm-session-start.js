#!/usr/bin/env node
'use strict';

const fs = require('fs');
const lib = require('./helm-lib');

function main() {
  const root = lib.projectRoot();
  if (fs.existsSync(lib.openspecDir(root))) {
    lib.event(root, 'session.start', { cwd: root });
  }
}

main();
