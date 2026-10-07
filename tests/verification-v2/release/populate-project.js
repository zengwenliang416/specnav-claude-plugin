#!/usr/bin/env node
'use strict';

const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const kernel = require('../../../plugins/specnav-verification/kernel');
const {
  createCaseApprovalValidator,
  createCasePlanner,
  createCaseSnapshotWriter
} = require('../../../plugins/specnav-verification/kernel/cases');
const {
  loadRuntimeLock
} = require('../../../plugins/specnav-verification/kernel/runtime/lock-manifest');
const {
  doctorRuntime
} = require('../../../plugins/specnav-verification/kernel/runtime/doctor');
const {
  userProviderFile,
  userRuntimeBase
} = require('../../../plugins/specnav-verification/kernel/runtime/scope-resolver');
const {
  createTrustedFactAuthority
} = require('../../../plugins/specnav-verification/kernel/repair');
const {
  mergeIntegrityResults
} = require('../../../plugins/specnav-verification/kernel/pipeline/production-runner');
const {
  HOST_DESCRIPTORS,
  OFFICIAL_HOST_REPOSITORIES,
  REQUIRED_HOSTS,
  hostProofRunnerSourceDigest,
  managedFixtureManifestDigest
} = require('../../../plugins/specnav-operations/scripts/verification-v2-host-contract');
const { readySchemaRegistry } = require('../contracts/cross-reference/test-helpers');

const REPOSITORY_ROOT = path.resolve(__dirname, '../../..');
const HOST_WORKSPACE = path.join(os.tmpdir(), 'specnav-claude-host-checkouts');

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(
    Object.keys(value).sort().map((key) => [key, canonicalize(value[key])])
  );
}

function canonicalJson(value) {
  return JSON.stringify(canonicalize(value));
}

function executable(file) {
  const real = fs.realpathSync(file);
  return {
    path: real,
    sha256: sha256(fs.readFileSync(real))
  };
}

function hostToolchain() {
  const npmPath = path.resolve(
    path.dirname(fs.realpathSync(process.execPath)),
    '../lib/node_modules/npm/bin/npm-cli.js'
  );
  const sandboxPath = process.platform === 'darwin'
    ? '/usr/bin/sandbox-exec'
    : ['/usr/bin/bwrap', '/bin/bwrap'].find((entry) => fs.existsSync(entry));
  if (!sandboxPath || !fs.existsSync(npmPath)) {
    throw new Error('verification-fixture:toolchain-unavailable');
  }
  return {
    node: executable(process.execPath),
    git: executable('/usr/bin/git'),
    bash: executable('/bin/bash'),
    npm: executable(npmPath),
    sandbox: executable(sandboxPath)
  };
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function git(root, args) {
  const result = spawnSync('git', args, {
    cwd: root,
    encoding: 'utf8',
    maxBuffer: 32 * 1024 * 1024
  });
  if (result.status !== 0) {
    throw new Error(
      result.stderr.trim() || `git ${args.join(' ')} failed`
    );
  }
  return result.stdout;
}

function ensureFixtureRepository(root) {
  if (!fs.existsSync(path.join(root, '.git'))) {
    const ignoreFile = path.join(root, '.gitignore');
    const current = fs.existsSync(ignoreFile)
      ? fs.readFileSync(ignoreFile, 'utf8')
      : '';
    const lines = current.split(/\r?\n/).filter(Boolean);
    if (!lines.includes('/openspec/')) lines.push('/openspec/');
    fs.writeFileSync(ignoreFile, `${lines.join('\n')}\n`);
    git(root, ['init', '--quiet']);
    git(root, ['config', 'user.name', 'SpecNav Fixture']);
    git(root, ['config', 'user.email', 'specnav-fixture@example.invalid']);
    git(root, ['config', 'commit.gpgsign', 'false']);
    git(root, ['add', '.gitignore']);
    git(root, ['commit', '--quiet', '-m', 'test: initialize fixture repository']);
  }
  const status = git(root, [
    'status',
    '--porcelain=v1',
    '--untracked-files=all'
  ]);
  if (status.trim() !== '') {
    throw new Error(`verification-fixture:dirty-worktree:${status.trim()}`);
  }
}

function ensureUserRuntimeSelection(root) {
  writeJson(path.join(root, '.specnav', 'config.json'), {
    schema: 'specnav.project-config.v1',
    verification: {
      runtime_scope: 'user'
    }
  });
  fs.writeFileSync(
    path.join(root, '.specnav', '.gitignore'),
    'runtime/\nsecrets/\n'
  );
  git(root, ['add', '.specnav/config.json', '.specnav/.gitignore']);
  const staged = git(root, ['diff', '--cached', '--name-only']);
  if (staged.trim()) {
    git(root, [
      'commit',
      '--quiet',
      '-m',
      'test: select user verification runtime'
    ]);
  }
}

function currentFingerprints(root, snapshot, runtimeStatus, runtimeAuthority) {
  const repositoryInventory = git(root, ['ls-tree', '-r', 'HEAD']);
  const testInventory = git(root, [
    'ls-tree',
    '-r',
    'HEAD',
    '--',
    'tests',
    'plugins/specnav-verification'
  ]);
  return {
    inventory: repositoryInventory,
    case_snapshot_hash: snapshot.snapshot_hash,
    code_sha: kernel.codeInventorySha(repositoryInventory),
    test_sha: crypto.createHash('sha256')
      .update(testInventory)
      .update(snapshot.snapshot_hash)
      .digest('hex'),
    environment_hash: crypto.createHash('sha256')
      .update(JSON.stringify({
        platform: process.platform,
        arch: process.arch,
        node: process.version,
        runtime_version: runtimeStatus.runtime_version,
        runtime_root: runtimeStatus.runtime_root,
        runtime_authority_hash: runtimeAuthority.digest,
        kernel_version: kernel.metadata.version
      }))
      .digest('hex'),
    runtime_version: runtimeStatus.runtime_version,
    kernel_version: kernel.metadata.version
  };
}

function testCase(change, caseId) {
  return {
    schema: 'specnav.verification.test-case.v1',
    id: caseId,
    change_id: change,
    requirement_ids: ['REQ-1'],
    acceptance_ids: ['AC-1'],
    title: 'Operations release proof',
    goal: 'Prove the complete six-domain release and archive contract.',
    actor: 'release-owner',
    priority: 'P0',
    preconditions: [],
    steps: [{
      id: 'step-1',
      action: 'Run the release proof fixture.',
      expected: 'All six domains produce deterministic readings.',
      assertion_ids: ['assertion-1']
    }],
    assertions: [{
      id: 'assertion-1',
      statement: 'The fixture returns a complete proof.',
      expected: true,
      oracle: {
        type: 'structured_comparison',
        human_signoff_allowed: false
      },
      evidence_kinds: ['structured_comparison']
    }],
    domains: Object.fromEntries(kernel.SIX_DOMAINS.map((domain) => [
      domain,
      {
        mode: 'required',
        assertion_ids: ['assertion-1'],
        runner: 'command'
      }
    ])),
    runner: {
      kind: 'command',
      timeout_ms: 1000,
      entrypoint: 'node',
      args: ['fixture.js'],
      cwd: '.',
      env_keys: [],
      requires_midscene: false
    },
    evidence_policy: {
      allowed_kinds: ['structured_comparison'],
      required_kinds: ['structured_comparison'],
      retain_on_failure: true,
      content_addressed: true
    },
    status: 'ready',
    created_at: '2026-08-02T00:00:00Z'
  };
}

function reading(change, caseId, domain, fingerprints) {
  return {
    schema: 'specnav.verification.reading.v1',
    id: `reading-${domain}`,
    change_id: change,
    run_id: 'run-release',
    case_id: caseId,
    attempt_id: 'attempt-release',
    step_id: 'step-1',
    assertion_id: 'assertion-1',
    domain,
    expected: true,
    actual: true,
    oracle: {
      type: 'structured_comparison',
      owner: 'command-runner',
      deterministic: true
    },
    evidence_ids: [`evidence-${domain}`],
    verdict: 'pass',
    recorded_at: '2026-08-02T00:00:02Z',
    code_sha: fingerprints.code_sha,
    test_sha: fingerprints.test_sha
  };
}

function evidenceContent(evidenceId) {
  return `${JSON.stringify({ evidence_id: evidenceId, result: 'pass' })}\n`;
}

function evidence(change, caseId, source, fingerprints) {
  const content = evidenceContent(source.evidence_ids[0]);
  return {
    schema: 'specnav.verification.evidence.v1',
    id: source.evidence_ids[0],
    kind: 'structured_comparison',
    path: `objects/${source.evidence_ids[0]}.json`,
    sha256: crypto.createHash('sha256').update(content).digest('hex'),
    size: Buffer.byteLength(content),
    producer: 'command-runner',
    captured_at: '2026-08-02T00:00:01Z',
    change_id: change,
    run_id: source.run_id,
    case_id: caseId,
    attempt_id: source.attempt_id,
    step_id: source.step_id,
    assertion_id: source.assertion_id,
    code_sha: source.code_sha,
    test_sha: source.test_sha,
    environment_hash: fingerprints.environment_hash,
    runtime_version: fingerprints.runtime_version,
    kernel_version: fingerprints.kernel_version,
    redaction: {
      status: 'not_required',
      redacted_fields: []
    },
    domain: source.domain
  };
}

function officialHostLock() {
  const commits = {
    codex: 'a'.repeat(40),
    'claude-code': 'b'.repeat(40),
    'codefree-o': 'c'.repeat(40),
    dsh: 'd'.repeat(40)
  };
  const lock = {
    schema: 'specnav.verification.cross-host-lock.v1',
    source_host: 'codex',
    source: {
      repository: OFFICIAL_HOST_REPOSITORIES.codex.repository,
      ref: OFFICIAL_HOST_REPOSITORIES.codex.ref,
      commit: commits.codex,
      plugin_path: HOST_DESCRIPTORS.codex.plugin,
      manifest_path: HOST_DESCRIPTORS.codex.manifest
    },
    hosts: {},
    generated_at: '2026-08-02T00:00:00Z',
    fallback_used: false
  };
  for (const host of REQUIRED_HOSTS) {
    if (host === 'codex') continue;
    lock.hosts[host] = {
      repository: OFFICIAL_HOST_REPOSITORIES[host].repository,
      ref: OFFICIAL_HOST_REPOSITORIES[host].ref,
      commit: commits[host],
      plugin_path: HOST_DESCRIPTORS[host].plugin,
      manifest_path: HOST_DESCRIPTORS[host].manifest
    };
  }
  return { lock, commits };
}

function authorityDigest(lockSha, commits, snapshots, comparison) {
  return sha256(canonicalJson({
    lock_sha256: lockSha,
    commits,
    repositories: Object.fromEntries(REQUIRED_HOSTS.map((host) => [
      host,
      OFFICIAL_HOST_REPOSITORIES[host].repository
    ])),
    heads: commits,
    snapshots,
    comparison
  }));
}

function populateProject(projectRoot, change) {
  const root = path.resolve(projectRoot);
  const changeDir = path.join(root, 'openspec', 'changes', change);
  const verifyDir = path.join(changeDir, 'verify');
  const verifyV2 = path.join(verifyDir, 'v2');
  const opsDir = path.join(changeDir, 'operations');
  fs.mkdirSync(verifyV2, { recursive: true });
  fs.mkdirSync(opsDir, { recursive: true });
  const caseId = `case-${change}`;
  const approvalId = `approval-${change}`;
  const reviewerId = 'reviewer-release';
  const reviewer = { id: reviewerId, kind: 'human' };
  const schemaRegistry = readySchemaRegistry();
  const requirements = [{
    id: 'REQ-1',
    statement: 'The release proof uses current approved requirements.'
  }];
  const acceptance = [{
    id: 'AC-1',
    statement: 'All six domains and release provenance pass.'
  }];
  const plan = createCasePlanner({ schemaRegistry }).plan({
    changeId: change,
    requirements,
    acceptance,
    cases: [testCase(change, caseId)]
  });
  if (!plan.ok) throw new Error(JSON.stringify(plan.blockers));
  const snapshotResult = createCaseSnapshotWriter({ schemaRegistry }).create({
    plan,
    createdAt: '2026-08-02T00:00:00Z',
    createdBy: reviewer
  });
  if (!snapshotResult.ok) throw new Error(JSON.stringify(snapshotResult.blockers));
  const snapshot = snapshotResult.snapshot;
  const approval = {
    schema: 'specnav.verification.case-approval.v1',
    id: approvalId,
    change_id: change,
    snapshot_id: snapshot.id,
    snapshot_hash: snapshot.snapshot_hash,
    decision: 'approved',
    reviewer,
    decided_at: '2026-08-02T00:00:01Z'
  };
  const approvalState = createCaseApprovalValidator({ schemaRegistry })
    .assertExecutionApproved({
      snapshot,
      approval,
      currentRequirements: plan.requirements,
      currentAcceptance: plan.acceptance,
      expectedReviewerId: reviewerId
    });
  if (!approvalState.ok) throw new Error(JSON.stringify(approvalState.blockers));

  ensureFixtureRepository(root);
  ensureUserRuntimeSelection(root);
  const lock = loadRuntimeLock();
  const runtimeBase = userRuntimeBase();
  const runtimeStatus = doctorRuntime({
    requestedVersion: lock.runtime_version,
    environment: {
      nodeVersion: process.version,
      platform: process.platform,
      arch: process.arch,
      kernel: {
        name: kernel.metadata.name,
        version: kernel.metadata.version,
        apiVersion: kernel.metadata.apiVersion,
        contractVersion: kernel.metadata.contractVersion,
        contractDigest: kernel.metadata.contractDigest
      }
    },
    providerEnvironment: {},
    requiresMidscene: false,
    runtimeBase,
    runtimeScope: 'user',
    scopeSelectionSource: 'project-config',
    providerScope: 'user',
    providerSource: 'scope-file',
    providerFile: userProviderFile()
  });
  if (!runtimeStatus.ok) throw new Error(JSON.stringify(runtimeStatus.blockers));
  const runtimeResolution = kernel.createRuntimeAuthority({ projectRoot: root })
    .resolve(runtimeStatus);
  if (!runtimeResolution.ok || !runtimeResolution.signingKey) {
    throw new Error(JSON.stringify(runtimeResolution.blockers));
  }
  const fingerprints = currentFingerprints(
    root,
    snapshot,
    runtimeResolution.runtimeStatus,
    runtimeResolution.authority
  );
  const storedFingerprints = {
    case_snapshot_hash: fingerprints.case_snapshot_hash,
    code_sha: fingerprints.code_sha,
    test_sha: fingerprints.test_sha,
    environment_hash: fingerprints.environment_hash,
    runtime_version: fingerprints.runtime_version,
    kernel_version: fingerprints.kernel_version
  };
  const trustedFactAuthority = createTrustedFactAuthority({
    schemaRegistry,
    key: runtimeResolution.signingKey,
    clock: () => '2026-08-02T00:00:03Z'
  });
  const readings = kernel.SIX_DOMAINS.map((domain) => (
    reading(change, caseId, domain, storedFingerprints)
  ));
  const evidenceEntries = readings.map((entry) => (
    evidence(change, caseId, entry, storedFingerprints)
  )).sort((left, right) => (
    left.captured_at.localeCompare(right.captured_at)
      || left.id.localeCompare(right.id)
  ));
  const run = {
    schema: 'specnav.verification.run.v1',
    id: 'run-release',
    change_id: change,
    case_snapshot_id: snapshot.id,
    case_snapshot_hash: snapshot.snapshot_hash,
    case_ids: [caseId],
    ...storedFingerprints,
    status: 'passed',
    created_at: '2026-08-02T00:00:01Z',
    started_at: '2026-08-02T00:00:01Z',
    completed_at: '2026-08-02T00:00:02Z',
    kind: 'initial',
    origin_run_id: null,
    parent_run_id: null,
    parent_attempt_id: null,
    failure_id: null
  };
  const attempt = {
    schema: 'specnav.verification.attempt.v1',
    id: 'attempt-release',
    run_id: run.id,
    change_id: change,
    case_id: caseId,
    case_snapshot_hash: snapshot.snapshot_hash,
    kind: 'initial',
    sequence: 1,
    runner: 'command',
    code_sha: storedFingerprints.code_sha,
    test_sha: storedFingerprints.test_sha,
    scenario_hash: '5'.repeat(64),
    environment_hash: storedFingerprints.environment_hash,
    browser_project: 'none',
    test_data_snapshot: '6'.repeat(64),
    runtime_version: storedFingerprints.runtime_version,
    kernel_version: storedFingerprints.kernel_version,
    status: 'passed',
    started_at: run.started_at,
    completed_at: run.completed_at,
    exit_status: 0,
    parent_attempt_id: null
  };
  const evidenceFacts = evidenceEntries.map((entry) => ({
    evidence_id: entry.id,
    integrity: 'intact',
    freshness: 'fresh',
    exists: true,
    hash_match: true,
    size_match: true,
    producer_recognized: true,
    store_record_match: true,
    binding_match: true,
    path_safe: true
  })).sort((left, right) => left.evidence_id.localeCompare(right.evidence_id));
  const attemptIntegrity = {
    ok: true,
    facts: {
      summary: {
        evidence_count: evidenceFacts.length,
        integrity: 'intact',
        freshness: 'fresh'
      },
      evidence: evidenceFacts
    },
    blockers: []
  };
  const runIntegrity = mergeIntegrityResults([attemptIntegrity]);
  const rawBytes = Buffer.from(
    `${evidenceEntries.map((entry) => JSON.stringify(entry)).join('\n')}\n`
  );
  const evidenceIndex = {
    schema: 'specnav.verification.evidence-index.v1',
    index_version: evidenceEntries.length,
    change_id: change,
    generated_at: '2026-08-02T00:00:01Z',
    source_raw: 'raw.jsonl',
    source_digest: sha256(rawBytes),
    record_count: evidenceEntries.length,
    entries: evidenceEntries
  };
  const generationStore = kernel.createVerificationArtifactStore({
    changeRoot: changeDir,
    root: verifyDir
  });
  const generationAuthority = kernel.createVerificationGenerationAuthority({
    schemaRegistry,
    key: runtimeResolution.signingKey,
    clock: () => '2026-08-02T00:00:00.500Z'
  });
  const generationState = {
    change_id: change,
    reviewer_id: reviewerId,
    snapshot_id: snapshot.id,
    snapshot_hash: snapshot.snapshot_hash,
    parent_generation_id: null,
    fingerprints: storedFingerprints,
    historical_break_loop_failure_ids: [],
    collections: {
      runs: [],
      attempts: [],
      executions: [],
      readings: [],
      failures: [],
      repair_links: [],
      evidence: [],
      transition_proposals: [],
      transition_receipts: [],
      attempt_facts: []
    }
  };
  const generationReview = generationAuthority.prepare(generationState);
  if (!generationReview.ok) throw new Error(JSON.stringify(generationReview.blockers));
  const generationActivation = generationAuthority.append(
    generationStore,
    generationReview.review,
    generationState,
    true
  );
  if (!generationActivation.ok) {
    throw new Error(JSON.stringify(generationActivation.blockers));
  }
  const activeGeneration = generationActivation.value;
  run.generation_id = activeGeneration.id;

  writeJson(path.join(verifyV2, 'runtime-status.json'), runtimeStatus);
  writeJson(path.join(verifyV2, 'requirements-source.json'), plan.requirements);
  writeJson(path.join(verifyV2, 'acceptance-source.json'), plan.acceptance);
  writeJson(path.join(verifyV2, 'case-snapshot.json'), snapshot);
  writeJson(path.join(verifyV2, 'case-approval.json'), approval);
  writeJson(path.join(verifyV2, 'runs.json'), [run]);
  writeJson(path.join(verifyV2, 'attempts.json'), [attempt]);
  writeJson(path.join(verifyV2, 'readings.json'), readings);
  writeJson(path.join(verifyV2, 'failures.json'), []);
  writeJson(path.join(verifyV2, 'repair-links.json'), []);
  writeJson(path.join(verifyV2, 'executions.json'), []);
  for (const name of [
    'transition-proposals.jsonl',
    'transition-receipts.jsonl',
    'attempt-facts.jsonl'
  ]) {
    fs.writeFileSync(path.join(verifyV2, name), '');
  }
  const runDir = path.join(verifyDir, 'runs', run.id);
  writeJson(path.join(runDir, 'integrity.json'), runIntegrity);
  writeJson(
    path.join(runDir, 'attempts', attempt.id, 'integrity.json'),
    attemptIntegrity
  );
  fs.writeFileSync(path.join(runDir, 'failures.jsonl'), '');
  fs.mkdirSync(path.join(verifyDir, 'evidence'), { recursive: true });
  fs.writeFileSync(path.join(verifyDir, 'evidence', 'raw.jsonl'), rawBytes);
  for (const entry of evidenceEntries) {
    const objectFile = path.join(verifyDir, 'evidence', entry.path);
    fs.mkdirSync(path.dirname(objectFile), { recursive: true });
    fs.writeFileSync(objectFile, evidenceContent(entry.id));
  }
  writeJson(path.join(verifyDir, 'evidence', 'index.json'), evidenceIndex);

  const canonical = kernel.createVerificationArtifactPipeline({
    kernel,
    schemaRegistry,
    changeRoot: changeDir,
    verificationRoot: verifyDir,
    snapshot,
    approval,
    currentFingerprints: storedFingerprints,
    activeGeneration,
    trustedFactAuthority,
    clock: () => '2026-08-02T00:00:03Z',
    secrets: [],
    policyVersion: 'verification-v2.0'
  }).build();
  if (!canonical.ok) throw new Error(JSON.stringify(canonical.blockers));

  writeJson(path.join(verifyV2, 'migration-status.json'), {
    schema: 'specnav.verification.migration-status.v1',
    change_id: change,
    required: false,
    legacy_artifacts: [],
    source_inventory_digest: 'c'.repeat(64),
    scanned_at: '2026-08-02T00:00:00Z',
    fallback_used: false
  });

  const releaseBindings = {
    change_id: change,
    release_gate_id: canonical.release_gate.id,
    archive_gate_id: canonical.archive_gate.id,
    gate_input_sha256: sha256(fs.readFileSync(path.join(verifyV2, 'gate-input.json'))),
    evidence_index_digest: evidenceIndex.source_digest
  };
  const hostLock = officialHostLock();
  const lockValidation = schemaRegistry.validate('cross-host-lock', hostLock.lock);
  if (!lockValidation.ok) throw new Error(JSON.stringify(lockValidation.blockers));
  const runId = 'host-proof-fixture';
  const runRoot = `operations/host-proof-runs/${runId}`;
  const lockPath = `${runRoot}/cross-host-lock.json`;
  writeJson(path.join(changeDir, lockPath), lockValidation.value);
  const lockBytes = fs.readFileSync(path.join(changeDir, lockPath));
  const lockSha = sha256(lockBytes);
  const snapshots = Object.fromEntries(REQUIRED_HOSTS.map((host) => [
    host,
    sha256(`snapshot:${host}`)
  ]));
  const comparison = sha256('host-comparison');
  const commits = Object.fromEntries(REQUIRED_HOSTS.map((host) => [
    host,
    hostLock.commits[host]
  ]));
  const hostAuthorityDigest = authorityDigest(
    lockSha,
    commits,
    snapshots,
    comparison
  );
  const toolchain = hostToolchain();
  const runnerSourceSha256 = hostProofRunnerSourceDigest(REPOSITORY_ROOT);
  const runnerIdentitySha256 = kernel.createHostRunnerIdentity(
    runnerSourceSha256,
    toolchain
  );
  const fixtureManifestSha256 = managedFixtureManifestDigest(path.join(
    REPOSITORY_ROOT,
    'plugins/specnav-verification/assets/contract-fixtures'
  ));
  const fixtureSnapshotDigest = sha256('managed-fixture-snapshot');
  const checkoutRoots = Object.fromEntries(REQUIRED_HOSTS.map((host) => [
    host,
    path.join(HOST_WORKSPACE, host)
  ]));
  let commandSequence = 0;

  function hostCommand(host, id, argv, stdoutValue = null, sandboxed = false) {
    const index = commandSequence;
    commandSequence += 1;
    const stdoutPath = `${runRoot}/${host}-${index + 1}.stdout.log`;
    const stderrPath = `${runRoot}/${host}-${index + 1}.stderr.log`;
    const stdout = Buffer.from(stdoutValue ?? `completed ${id}\n`);
    const stderr = Buffer.alloc(0);
    fs.mkdirSync(path.dirname(path.join(changeDir, stdoutPath)), { recursive: true });
    fs.writeFileSync(path.join(changeDir, stdoutPath), stdout);
    fs.writeFileSync(path.join(changeDir, stderrPath), stderr);
    const startedAt = new Date(Date.parse('2026-08-02T00:00:05Z') + index * 1000)
      .toISOString();
    const sandbox = sandboxed
      ? kernel.createHostSandboxPlan({
        toolchain,
        allowedRoots: [
          ...REQUIRED_HOSTS.map((candidate) => checkoutRoots[candidate]),
          ...(id === 'runtime-doctor' ? [runtimeResolution.runtimeRoot] : []),
          path.dirname(path.dirname(toolchain.node.path))
        ],
        writableRoots: [
          path.join(HOST_WORKSPACE, '.runtime', host),
          ...(id === 'dependency-install' ? [checkoutRoots[host]] : [])
        ],
        pathAliases: [{ path: HOST_WORKSPACE, identity: '$WORKSPACE' }],
        allowNetwork: id === 'dependency-install'
      })
      : null;
    return {
      id,
      argv,
      executable_realpath: argv[0],
      executable_sha256: sha256(fs.readFileSync(argv[0])),
      sandbox_executable_realpath: sandbox?.executable.path || null,
      sandbox_executable_sha256: sandbox?.executable.sha256 || null,
      sandbox_policy_sha256: sandbox?.policy_sha256 || null,
      sandbox_argv: sandbox?.argv || null,
      exit_status: 0,
      signal: null,
      stdout_sha256: sha256(stdout),
      stderr_sha256: sha256(stderr),
      stdout_path: stdoutPath,
      stderr_path: stderrPath,
      started_at: startedAt,
      completed_at: new Date(Date.parse(startedAt) + 500).toISOString()
    };
  }

  function lockedRepository(host) {
    return host === 'codex' ? hostLock.lock.source : hostLock.lock.hosts[host];
  }

  function hostCommands(host) {
    const locked = lockedRepository(host);
    const rootPath = checkoutRoots[host];
    const commands = [
      hostCommand(host, 'remote-ref', [
        toolchain.git.path,
        'ls-remote',
        '--refs',
        locked.repository,
        locked.ref
      ], `${locked.commit}\t${locked.ref}\n`),
      hostCommand(host, 'checkout-init', [
        toolchain.git.path,
        '-c',
        'core.hooksPath=/dev/null',
        'init',
        '--quiet'
      ]),
      hostCommand(host, 'checkout-remote', [
        toolchain.git.path,
        '-c',
        'core.hooksPath=/dev/null',
        'remote',
        'add',
        'origin',
        locked.repository
      ]),
      hostCommand(host, 'checkout-fetch', [
        toolchain.git.path,
        '-c',
        'core.hooksPath=/dev/null',
        'fetch',
        '--quiet',
        '--depth=1',
        'origin',
        locked.ref
      ]),
      hostCommand(host, 'checkout-detach', [
        toolchain.git.path,
        '-c',
        'core.hooksPath=/dev/null',
        'checkout',
        '--quiet',
        '--detach',
        locked.commit
      ]),
      hostCommand(host, 'checkout-head', [
        toolchain.git.path,
        'rev-parse',
        'HEAD^{commit}'
      ], `${locked.commit}\n`)
    ];
    if (host === 'codex') {
      commands.push(hostCommand(host, 'checkout-tree', [
        toolchain.git.path,
        'ls-tree',
        '-r',
        'HEAD'
      ], fingerprints.inventory));
    }
    if (host === 'codefree-o' || host === 'dsh') {
      commands.push(hostCommand(host, 'dependency-install', [
        toolchain.npm.path,
        'ci',
        '--ignore-scripts',
        '--no-audit',
        '--no-fund'
      ], null, true));
    }
    const probe = path.join(
      checkoutRoots.codex,
      hostLock.lock.source.plugin_path,
      'scripts',
      'verification-runtime.js'
    );
    commands.push(
      hostCommand(host, 'runtime-doctor', [
        toolchain.node.path,
        probe,
        'doctor',
        '--version',
        runtimeResolution.authority.runtime_version,
        '--project',
        rootPath,
        '--root',
        path.dirname(runtimeResolution.authority.runtime_root),
        '--json'
      ], null, true),
      hostCommand(host, 'host-smoke', [
        toolchain.bash.path,
        path.join(rootPath, 'tests', 'run-smoke.sh')
      ], null, true)
    );
    return commands;
  }

  const hosts = REQUIRED_HOSTS.map((host) => {
    const receiptPath = `${runRoot}/${host}.receipt.json`;
    const locked = lockedRepository(host);
    const commands = hostCommands(host);
    const execution = {
      schema: 'specnav.verification.host-execution.v1',
      change_id: change,
      run_id: runId,
      host,
      status: 'passed',
      repository: locked.repository,
      ref: locked.ref,
      commit: locked.commit,
      host_lock_sha256: lockSha,
      ...releaseBindings,
      runtime_authority_digest: runtimeResolution.authority.digest,
      host_authority_digest: hostAuthorityDigest,
      source_snapshot_digest: snapshots[host],
      runner_identity_sha256: runnerIdentitySha256,
      runner_source_sha256: runnerSourceSha256,
      environment_sha256: sha256('host-proof-environment'),
      fixture_snapshot_digest: fixtureSnapshotDigest,
      fixture_manifest_sha256: fixtureManifestSha256,
      observations: {
        advertised_commit: locked.commit,
        checkout_head: locked.commit,
        source_code_inventory_sha: host === 'codex' ? fingerprints.code_sha : null,
        package_lock_sha256: host === 'codefree-o' || host === 'dsh'
          ? sha256('synthetic-package-lock')
          : null
      },
      commands,
      blocker: null,
      started_at: commands[0].started_at,
      completed_at: commands.at(-1).completed_at
    };
    const executionValidation = schemaRegistry.validate('host-execution', execution);
    if (!executionValidation.ok) {
      throw new Error(JSON.stringify(executionValidation.blockers));
    }
    const executionEnvelope = trustedFactAuthority.seal(
      'host_execution',
      executionValidation.value,
      {
        failure_id: runId,
        change_id: change,
        run_id: runId,
        case_id: host
      }
    );
    const envelopePath = `${runRoot}/${host}.execution-envelope.json`;
    writeJson(path.join(changeDir, envelopePath), executionEnvelope);
    const receipt = {
      schema: 'specnav.verification.host-install-receipt.v1',
      host,
      ...releaseBindings,
      host_lock_sha256: lockSha,
      runtime_authority_digest: runtimeResolution.authority.digest,
      runner_identity_sha256: runnerIdentitySha256,
      runner_source_sha256: runnerSourceSha256,
      source_snapshot_digest: snapshots[host],
      fixture_snapshot_digest: fixtureSnapshotDigest,
      fixture_manifest_sha256: fixtureManifestSha256,
      repository: locked.repository,
      ref: locked.ref,
      commit: locked.commit,
      remote_commit_reachable: true,
      checkout_realpath: checkoutRoots[host],
      plugin_realpath: path.join(checkoutRoots[host], locked.plugin_path),
      clean_checkout: true,
      plugin_discovered: true,
      runtime_ready: true,
      checks: [
        {
          id: 'plugin-discovery',
          status: 'pass',
          evidence: 'The expected plugin path exists.'
        },
        {
          id: 'remote-commit-reachability',
          status: 'pass',
          evidence: 'The locked commit is reachable.'
        },
        {
          id: 'runtime-doctor',
          status: 'pass',
          evidence: 'The runtime doctor completed.'
        },
        {
          id: 'host-smoke',
          status: 'pass',
          evidence: 'The host smoke command completed.'
        }
      ],
      execution: {
        commands: commands.map((command) => ({
          argv: command.argv,
          exit_status: command.exit_status,
          stdout_sha256: command.stdout_sha256,
          stderr_sha256: command.stderr_sha256,
          stdout_path: command.stdout_path,
          stderr_path: command.stderr_path
        })),
        environment_sha256: execution.environment_sha256,
        started_at: execution.started_at,
        completed_at: execution.completed_at
      },
      execution_envelope_path: envelopePath,
      execution_envelope_sha256: sha256(
        fs.readFileSync(path.join(changeDir, envelopePath))
      ),
      attestation: 'system-executed',
      fallback_used: false,
      recorded_at: '2026-08-02T00:00:05Z'
    };
    const receiptValidation = schemaRegistry.validate('host-install-receipt', receipt);
    if (!receiptValidation.ok) {
      throw new Error(JSON.stringify(receiptValidation.blockers));
    }
    const receiptFile = path.join(changeDir, receiptPath);
    writeJson(receiptFile, receiptValidation.value);
    return {
      host,
      receipt_path: receiptPath,
      receipt_sha256: sha256(fs.readFileSync(receiptFile)),
      commit: receipt.commit
    };
  });
  const indexPath = `${runRoot}/host-installation-index.json`;
  writeJson(path.join(changeDir, indexPath), {
    schema: 'specnav.verification.host-installation-index.v1',
    change_id: change,
    host_lock_sha256: lockSha,
    hosts,
    fallback_used: false
  });
  const compatibilityPath = `${runRoot}/cross-host-compatibility.json`;
  writeJson(path.join(changeDir, compatibilityPath), {
    schema: 'specnav.verification.cross-host-release-result.v1',
    ...releaseBindings,
    host_lock_sha256: lockSha,
    authority_digest: hostAuthorityDigest,
    comparison_digest: comparison,
    ok: true,
    hosts: hosts.map((entry) => ({
      host: entry.host,
      commit: entry.commit,
      snapshot_digest: snapshots[entry.host],
      receipt_sha256: entry.receipt_sha256
    })),
    kernel_version: canonical.gate_input.kernel_version,
    blockers: [],
    fallback_used: false,
    recorded_at: '2026-08-02T00:00:06Z'
  });
  const pointer = {
    schema: 'specnav.verification.host-proof-pointer.v1',
    change_id: change,
    run_id: runId,
    generation: 1,
    previous_pointer: null,
    host_lock_sha256: lockSha,
    runtime_authority_digest: runtimeResolution.authority.digest,
    lock: { path: lockPath, sha256: lockSha },
    index: {
      path: indexPath,
      sha256: sha256(fs.readFileSync(path.join(changeDir, indexPath)))
    },
    compatibility: {
      path: compatibilityPath,
      sha256: sha256(fs.readFileSync(path.join(changeDir, compatibilityPath)))
    },
    published_at: '2026-08-02T00:00:06Z',
    fallback_used: false
  };
  const pointerValidation = schemaRegistry.validate('host-proof-pointer', pointer);
  if (!pointerValidation.ok) throw new Error(JSON.stringify(pointerValidation.blockers));
  writeJson(
    path.join(changeDir, `${runRoot}/host-proof-pointer.json`),
    pointerValidation.value
  );
  writeJson(path.join(opsDir, 'host-proof-current.json'), pointerValidation.value);
}

if (require.main === module) {
  const [projectRoot, change] = process.argv.slice(2);
  if (!projectRoot || !change) {
    process.stderr.write('Usage: populate-project.js <project-root> <change>\n');
    process.exit(2);
  }
  populateProject(projectRoot, change);
}

module.exports = { populateProject };
