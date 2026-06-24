#!/usr/bin/env node
'use strict';

const BLOCKER = 'not-implemented:helm-core/helm-doctor';

function doctor() {
  return {
    ok: false,
    status: 'blocked',
    blockers: [BLOCKER],
    message: 'Helm core doctor is not implemented yet.'
  };
}

function toText(result) {
  return [
    'Helm core doctor is not implemented yet.',
    `blocker: ${result.blockers.join(', ')}`
  ].join('\n') + '\n';
}

function main() {
  const result = doctor();
  if (process.argv.includes('--json')) {
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } else {
    process.stdout.write(toText(result));
  }
  process.exit(2);
}

if (require.main === module) main();

module.exports = { doctor, toText };
