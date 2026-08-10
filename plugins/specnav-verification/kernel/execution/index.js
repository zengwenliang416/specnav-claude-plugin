'use strict';

const {
  createExecutionOrchestrator
} = require('./orchestrator');
const {
  createEventSequence
} = require('./event-sequence');
const {
  evaluateMidsceneOracle
} = require('./midscene-oracle');
const {
  createHostProofLauncher
} = require('./host-proof-launcher');

module.exports = Object.freeze({
  createEventSequence,
  createExecutionOrchestrator,
  createHostProofLauncher,
  evaluateMidsceneOracle
});
