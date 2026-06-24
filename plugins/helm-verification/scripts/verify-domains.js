#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const lib = require('../../helm-core/scripts/helm-lib');
const { validateDevelopment } = require('../../helm-development/scripts/development-contract');

const DOMAINS = ['facticity', 'static', 'unit', 'redteam', 'e2e', 'sensory'];
const VERDICTS = new Set(['green', 'red', 'blocked']);
const BLOCKER_CLASSES = new Set([
  'tool-unavailable',
  'env-auth',
  'env-runtime',
  'contract-regression',
  'insufficient-evidence',
  'product-ambiguity',
  'scope-drift'
]);
const DOMAIN_REPORT_HEADINGS = [
  'Domain',
  'Verdict',
  'Inputs Reviewed',
  'Evidence',
  'Commands Run',
  'Findings',
  'Required Fixes',
  'Residual Risk',
  'Follow-up Domain Routing'
];
const INDEPENDENCE_HEADINGS = [
  'Inputs Allowed',
  'Inputs Excluded',
  'Controller Claims Ignored',
  'Files Reviewed',
  'Evidence References',
  'Cannot Verify From Provided Evidence'
];

function unique(values) {
  return Array.from(new Set(values.filter(Boolean)));
}

function isPlainObject(value) {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}

function isCleanString(value) {
  return typeof value === 'string' && value.trim() !== '' && value === value.trim();
}

function readJsonFile(file) {
  try {
    return { ok: true, value: JSON.parse(fs.readFileSync(file, 'utf8')), status: 'ok' };
  } catch (error) {
    if (error && error.code === 'ENOENT') return { ok: false, value: null, status: 'missing' };
    if (error instanceof SyntaxError) return { ok: false, value: null, status: 'invalid-json' };
    return { ok: false, value: null, status: 'unreadable' };
  }
}

function readTextFile(file) {
  try {
    return { ok: true, value: fs.readFileSync(file, 'utf8'), status: 'ok' };
  } catch (error) {
    if (error && error.code === 'ENOENT') return { ok: false, value: null, status: 'missing' };
    return { ok: false, value: null, status: 'unreadable' };
  }
}

function artifactPath(change, name) {
  return path.join('openspec', 'changes', change, 'verify', name);
}

function artifactResult(change, name, blockers, extra = {}) {
  return {
    name,
    path: artifactPath(change, name),
    ok: blockers.length === 0,
    blockers: unique(blockers),
    ...extra
  };
}

function parseJsonl(file, name, allowEmpty = false) {
  const text = readTextFile(file);
  const blockers = [];
  const entries = [];

  if (!text.ok) return { blockers: [`missing-verify-artifact:${name}`], entries };

  const lines = text.value.split(/\r?\n/);
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index].trim();
    if (!line) continue;
    try {
      const entry = JSON.parse(line);
      if (!isPlainObject(entry)) blockers.push(`invalid-jsonl-shape:${name}:${index + 1}`);
      else entries.push(entry);
    } catch {
      blockers.push(`invalid-jsonl:${name}:${index + 1}`);
    }
  }

  if (!allowEmpty && entries.length === 0 && blockers.length === 0) blockers.push(`empty-jsonl:${name}`);
  return { blockers, entries };
}

function normalizeHeading(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[`*_()[\]{}:;,.!?/\\|-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function hasHeading(text, heading) {
  const wanted = normalizeHeading(heading);
  return String(text || '')
    .split(/\r?\n/)
    .some((line) => {
      const match = line.match(/^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$/);
      return match && normalizeHeading(match[1]) === wanted;
    });
}

function validateTextHeadings(verifyDir, change, name, headings, prefix) {
  const text = readTextFile(path.join(verifyDir, name));
  const blockers = [];
  if (!text.ok) return artifactResult(change, name, [`missing-verify-artifact:${name}`]);
  if (text.value.trim() === '') blockers.push(`empty-verify-artifact:${name}`);
  for (const heading of headings) {
    if (!hasHeading(text.value, heading)) blockers.push(`${prefix}:missing-heading:${heading}`);
  }
  return artifactResult(change, name, blockers);
}

function validatePlan(verifyDir, change) {
  const name = 'plan.json';
  const parsed = readJsonFile(path.join(verifyDir, name));
  const blockers = [];

  if (!parsed.ok) return artifactResult(change, name, [parsed.status === 'invalid-json' ? `invalid-json:${name}` : `missing-verify-artifact:${name}`]);
  if (!isPlainObject(parsed.value)) return artifactResult(change, name, [`invalid-json-shape:${name}`]);

  const plan = parsed.value;
  if (plan.schema_version !== 1) blockers.push('invalid-verify-plan:schema_version');
  if (plan.change_id !== change) blockers.push('invalid-verify-plan:change_id');
  if (!isCleanString(plan.risk_tier)) blockers.push('invalid-verify-plan:risk_tier');
  if (!Array.isArray(plan.required_domains)) blockers.push('invalid-verify-plan:required_domains');
  else {
    for (const domain of DOMAINS) {
      if (!plan.required_domains.includes(domain)) blockers.push(`verify-plan:missing-domain:${domain}`);
    }
  }
  for (const field of ['inputs', 'changed_files', 'commands', 'manual_reviews']) {
    if (!Array.isArray(plan[field])) blockers.push(`invalid-verify-plan:${field}`);
  }

  return artifactResult(change, name, blockers, { required_domains: plan.required_domains || [] });
}

function validateEvidenceIndex(verifyDir, change) {
  const name = 'evidence-index.jsonl';
  const result = parseJsonl(path.join(verifyDir, name), name);
  const blockers = [...result.blockers];
  result.entries.forEach((entry, index) => {
    if (!isCleanString(entry.id)) blockers.push(`invalid-evidence-index:id:${index + 1}`);
    if (!isCleanString(entry.kind)) blockers.push(`invalid-evidence-index:kind:${index + 1}`);
    if (!isCleanString(entry.domain) || !DOMAINS.includes(entry.domain)) blockers.push(`invalid-evidence-index:domain:${index + 1}`);
  });
  return artifactResult(change, name, blockers, { entries: result.entries.length });
}

function validateTraceability(verifyDir, change) {
  const name = 'traceability-matrix.json';
  const parsed = readJsonFile(path.join(verifyDir, name));
  const blockers = [];
  if (!parsed.ok) return artifactResult(change, name, [parsed.status === 'invalid-json' ? `invalid-json:${name}` : `missing-verify-artifact:${name}`]);
  if (!isPlainObject(parsed.value)) return artifactResult(change, name, [`invalid-json-shape:${name}`]);

  const trace = parsed.value;
  if (trace.schema_version !== 1) blockers.push('invalid-traceability:schema_version');
  if (trace.change_id !== change) blockers.push('invalid-traceability:change_id');
  if (!Array.isArray(trace.entries) || trace.entries.length === 0) blockers.push('invalid-traceability:entries');
  if (!Array.isArray(trace.unmapped_changes)) blockers.push('invalid-traceability:unmapped_changes');
  else if (trace.unmapped_changes.length > 0) blockers.push('traceability-unmapped-changes');
  if (Array.isArray(trace.entries)) {
    trace.entries.forEach((entry, index) => {
      if (!isPlainObject(entry) || !isCleanString(entry.changed_file)) blockers.push(`invalid-traceability-entry:changed_file:${index + 1}`);
      for (const field of ['requirement_refs', 'task_refs', 'prototype_refs', 'foundation_spec_refs', 'verification_domains']) {
        if (!Array.isArray(entry && entry[field]) || entry[field].length === 0) blockers.push(`invalid-traceability-entry:${field}:${index + 1}`);
      }
    });
  }
  return artifactResult(change, name, blockers);
}

function validateBlockers(verifyDir, change) {
  const name = 'blocker-classification.jsonl';
  const result = parseJsonl(path.join(verifyDir, name), name, true);
  const blockers = [...result.blockers];
  result.entries.forEach((entry, index) => {
    if (!isCleanString(entry.domain) || !DOMAINS.includes(entry.domain)) blockers.push(`invalid-blocker-classification:domain:${index + 1}`);
    if (!isCleanString(entry.blocker_class) || !BLOCKER_CLASSES.has(entry.blocker_class)) blockers.push(`invalid-blocker-classification:blocker_class:${index + 1}`);
    if (entry.status === 'unresolved') blockers.push(`unresolved-verification-blocker:${entry.domain || index + 1}`);
  });
  return artifactResult(change, name, blockers, { entries: result.entries.length });
}

function validateReceipt(verifyDir, change) {
  const name = 'receipt.json';
  const parsed = readJsonFile(path.join(verifyDir, name));
  const blockers = [];
  if (!parsed.ok) return artifactResult(change, name, [parsed.status === 'invalid-json' ? `invalid-json:${name}` : `missing-verify-artifact:${name}`]);
  if (!isPlainObject(parsed.value)) return artifactResult(change, name, [`invalid-json-shape:${name}`]);
  const receipt = parsed.value;
  if (receipt.schema_version !== 1) blockers.push('invalid-receipt:schema_version');
  if (receipt.change_id !== change) blockers.push('invalid-receipt:change_id');
  if (receipt.result !== 'green') blockers.push('invalid-receipt:result');
  for (const field of ['covered_scope', 'uncovered_scope', 'residual_risk']) {
    if (!Array.isArray(receipt[field])) blockers.push(`invalid-receipt:${field}`);
  }
  if (Array.isArray(receipt.covered_scope) && receipt.covered_scope.length === 0) blockers.push('invalid-receipt:covered_scope');
  if (Array.isArray(receipt.uncovered_scope) && receipt.uncovered_scope.length > 0) blockers.push('receipt-uncovered-scope');
  if (Array.isArray(receipt.residual_risk) && receipt.residual_risk.length > 0 && receipt.confidence === 'A') blockers.push('receipt-confidence-overclaim');
  if (!['A', 'B', 'C'].includes(receipt.confidence)) blockers.push('invalid-receipt:confidence');
  return artifactResult(change, name, blockers);
}

function validateDomainReport(verifyDir, change, domain) {
  const name = `${domain}/report.json`;
  const parsed = readJsonFile(path.join(verifyDir, name));
  const blockers = [];
  if (!parsed.ok) return artifactResult(change, name, [parsed.status === 'invalid-json' ? `invalid-json:${name}` : `missing-verify-artifact:${name}`]);
  if (!isPlainObject(parsed.value)) return artifactResult(change, name, [`invalid-json-shape:${name}`]);

  const report = parsed.value;
  if (report.schema_version !== 1) blockers.push(`invalid-domain-report:${domain}:schema_version`);
  if (report.domain !== domain) blockers.push(`invalid-domain-report:${domain}:domain`);
  if (!VERDICTS.has(report.verdict)) blockers.push(`invalid-domain-report:${domain}:verdict`);
  if (report.required !== true) blockers.push(`invalid-domain-report:${domain}:required`);
  for (const field of ['evidence', 'commands', 'findings', 'required_fixes', 'residual_risk']) {
    if (!Array.isArray(report[field])) blockers.push(`invalid-domain-report:${domain}:${field}`);
  }
  if (report.verdict !== 'green') blockers.push(`${domain}-not-green`);
  if (Array.isArray(report.required_fixes) && report.required_fixes.length > 0) blockers.push(`${domain}-required-fixes`);
  if (report.blocker_class !== null && report.blocker_class !== undefined && !BLOCKER_CLASSES.has(report.blocker_class)) {
    blockers.push(`invalid-domain-report:${domain}:blocker_class`);
  }
  return artifactResult(change, name, blockers, { verdict: report.verdict || null });
}

function validateUnitRubric(verifyDir, change) {
  const name = 'unit/test-quality-rubric.json';
  const parsed = readJsonFile(path.join(verifyDir, name));
  const blockers = [];
  if (!parsed.ok) return artifactResult(change, name, [parsed.status === 'invalid-json' ? `invalid-json:${name}` : `missing-verify-artifact:${name}`]);
  if (!isPlainObject(parsed.value)) return artifactResult(change, name, [`invalid-json-shape:${name}`]);
  const rubric = parsed.value;
  if (rubric.schema_version !== 1) blockers.push('invalid-test-quality-rubric:schema_version');
  if (!isPlainObject(rubric.checks)) blockers.push('invalid-test-quality-rubric:checks');
  else {
    for (const [key, value] of Object.entries(rubric.checks)) {
      if (value !== true) blockers.push(`unit-test-quality-blocking:${key}`);
    }
  }
  if (!Array.isArray(rubric.findings)) blockers.push('invalid-test-quality-rubric:findings');
  else if (rubric.findings.length > 0) blockers.push('unit-test-quality-findings');
  return artifactResult(change, name, blockers);
}

function validateBehaviorEvals(verifyDir, change) {
  const artifacts = [];
  const scenarios = readJsonFile(path.join(verifyDir, 'behavior-evals/scenarios.json'));
  const scenarioBlockers = [];
  const scenarioIds = [];
  if (!scenarios.ok) scenarioBlockers.push(scenarios.status === 'invalid-json' ? 'invalid-json:behavior-evals/scenarios.json' : 'missing-verify-artifact:behavior-evals/scenarios.json');
  else if (!isPlainObject(scenarios.value) || scenarios.value.schema_version !== 1 || !Array.isArray(scenarios.value.scenarios)) {
    scenarioBlockers.push('invalid-behavior-evals:scenarios');
  } else {
    scenarios.value.scenarios.forEach((scenario, index) => {
      if (!isPlainObject(scenario)) {
        scenarioBlockers.push(`invalid-behavior-evals:scenario:${index + 1}`);
        return;
      }
      if (!isCleanString(scenario.id)) scenarioBlockers.push(`invalid-behavior-evals:scenario-id:${index + 1}`);
      else scenarioIds.push(scenario.id);
      if (!isCleanString(scenario.prompt)) scenarioBlockers.push(`invalid-behavior-evals:scenario-prompt:${scenario.id || index + 1}`);
      if (!Array.isArray(scenario.expected) || scenario.expected.length === 0 || scenario.expected.some((item) => !isCleanString(item))) {
        scenarioBlockers.push(`invalid-behavior-evals:scenario-expected:${scenario.id || index + 1}`);
      }
    });
    if (scenarioIds.length === 0) scenarioBlockers.push('invalid-behavior-evals:no-scenarios');
  }
  artifacts.push(artifactResult(change, 'behavior-evals/scenarios.json', scenarioBlockers));

  const report = readJsonFile(path.join(verifyDir, 'behavior-evals/report.json'));
  const reportBlockers = [];
  if (!report.ok) reportBlockers.push(report.status === 'invalid-json' ? 'invalid-json:behavior-evals/report.json' : 'missing-verify-artifact:behavior-evals/report.json');
  else if (!isPlainObject(report.value) || report.value.schema_version !== 1 || report.value.status !== 'green') {
    reportBlockers.push('invalid-behavior-evals:report');
  } else {
    const covered = Array.isArray(report.value.scenarios) ? report.value.scenarios : [];
    if (covered.some((item) => !isCleanString(item))) reportBlockers.push('invalid-behavior-evals:report-scenarios');
    for (const id of scenarioIds) {
      if (!covered.includes(id)) reportBlockers.push(`behavior-eval-scenario-not-reported:${id}`);
    }
    if (Array.isArray(report.value.unresolved_blockers) && report.value.unresolved_blockers.length > 0) {
      reportBlockers.push('behavior-eval-unresolved-blockers');
    }
  }
  artifacts.push(artifactResult(change, 'behavior-evals/report.json', reportBlockers));
  const transcriptBlockers = [];
  const transcriptsDir = path.join(verifyDir, 'behavior-evals/transcripts');
  for (const id of scenarioIds) {
    const markdown = path.join(transcriptsDir, `${id}.md`);
    const json = path.join(transcriptsDir, `${id}.json`);
    const markdownText = readTextFile(markdown);
    const jsonText = readTextFile(json);
    const transcriptText = markdownText.ok ? markdownText.value : (jsonText.ok ? jsonText.value : '');
    if (transcriptText.trim() === '') {
      transcriptBlockers.push(`missing-behavior-eval-transcript:${id}`);
    } else if (/<decision-required>|\b(?:TODO|TBD)\b/i.test(transcriptText)) {
      transcriptBlockers.push(`placeholder-behavior-eval-transcript:${id}`);
    }
  }
  artifacts.push(artifactResult(change, 'behavior-evals/transcripts', transcriptBlockers));
  artifacts.push(validateTextHeadings(verifyDir, change, 'behavior-evals/report.md', ['Scenarios', 'Transcripts', 'Result'], 'invalid-behavior-evals-report'));
  return artifacts;
}

function validateVerify(root = lib.projectRoot()) {
  const projectRoot = path.resolve(root);
  const development = validateDevelopment(projectRoot, { mode: 'handoff' });
  const change = development.active_change || lib.activeChange(projectRoot);
  const changeDir = change ? lib.changeDir(projectRoot, change) : null;
  const verifyDir = changeDir ? path.join(changeDir, 'verify') : null;
  const artifacts = [];
  const blockers = [];

  if (!development.ok) blockers.push('development-blocked', ...development.blockers.map((blocker) => `development:${blocker}`));
  if (!change || !changeDir || !fs.existsSync(changeDir)) blockers.push('active-change');

  if (verifyDir) {
    artifacts.push(validateTextHeadings(verifyDir, change, 'plan.md', ['Verification Scope', 'Required Domains', 'Evidence Plan'], 'invalid-verify-plan-md'));
    artifacts.push(validatePlan(verifyDir, change));
    artifacts.push(validateEvidenceIndex(verifyDir, change));
    artifacts.push(validateTraceability(verifyDir, change));
    artifacts.push(validateBlockers(verifyDir, change));
    artifacts.push(validateTextHeadings(verifyDir, change, 'receipt.md', ['Covered Scope', 'Uncovered Scope', 'Residual Risk', 'Confidence'], 'invalid-receipt-md'));
    artifacts.push(validateReceipt(verifyDir, change));
    artifacts.push(...validateBehaviorEvals(verifyDir, change));
    for (const domain of DOMAINS) {
      artifacts.push(validateTextHeadings(verifyDir, change, `${domain}/report.md`, DOMAIN_REPORT_HEADINGS, `invalid-domain-report-md:${domain}`));
      artifacts.push(validateDomainReport(verifyDir, change, domain));
    }
    artifacts.push(validateUnitRubric(verifyDir, change));
    artifacts.push(validateTextHeadings(verifyDir, change, 'sensory/reviewer-independence.md', INDEPENDENCE_HEADINGS, 'invalid-reviewer-independence'));
    artifacts.push(artifactResult(change, 'root-cause-checks.jsonl', parseJsonl(path.join(verifyDir, 'root-cause-checks.jsonl'), 'root-cause-checks.jsonl', true).blockers));
  }

  blockers.push(...artifacts.flatMap((artifact) => artifact.blockers));

  return {
    ok: blockers.length === 0,
    project_root: projectRoot,
    active_change: change || null,
    change_dir: changeDir,
    verify_dir: verifyDir,
    blockers: unique(blockers),
    development,
    artifacts
  };
}

function writeAggregate(root = lib.projectRoot()) {
  const projectRoot = path.resolve(root);
  const validation = validateVerify(projectRoot);
  const verifyDir = validation.verify_dir;
  const verdict = validation.ok ? 'green' : 'red';
  const report = {
    schema_version: 1,
    generated_at: new Date().toISOString(),
    active_change: validation.active_change,
    verdict,
    blockers: validation.blockers,
    required_domains: DOMAINS,
    artifacts: validation.artifacts.map((artifact) => ({
      name: artifact.name,
      path: artifact.path,
      ok: artifact.ok,
      blockers: artifact.blockers
    }))
  };

  if (verifyDir) {
    lib.writeJson(path.join(verifyDir, 'aggregate-report.json'), report);
    const lines = [
      '# Helm Aggregate Verification Report',
      '',
      `- active_change: ${report.active_change || 'none'}`,
      `- verdict: ${report.verdict}`,
      `- blockers: ${report.blockers.join(', ') || '-'}`,
      '',
      '| Artifact | Status | Blockers |',
      '| --- | --- | --- |',
      ...report.artifacts.map((artifact) => `| ${artifact.name} | ${artifact.ok ? 'pass' : 'blocked'} | ${artifact.blockers.join('<br>') || '-'} |`)
    ];
    fs.writeFileSync(path.join(verifyDir, 'aggregate-report.md'), `${lines.join('\n')}\n`);
    lib.writeJson(path.join(validation.change_dir, 'verify-report.json'), {
      schema_version: 1,
      generated_at: report.generated_at,
      active_change: report.active_change,
      status: verdict,
      aggregate: report
    });
    fs.writeFileSync(path.join(validation.change_dir, 'verify-report.md'), `${lines.join('\n')}\n`);
    if (verdict === 'green') {
      try {
        fs.unlinkSync(path.join(validation.change_dir, 'verify-report.stale'));
      } catch {}
    }
    lib.event(projectRoot, 'verify.aggregate', { active_change: report.active_change, verdict });
  }
  return report;
}

function markdown(result) {
  const lines = [];
  lines.push('# Helm Verification Domains');
  lines.push('');
  lines.push(`- project: \`${result.project_root}\``);
  lines.push(`- active change: \`${result.active_change || 'none'}\``);
  lines.push(`- verify dir: \`${result.verify_dir || 'none'}\``);
  lines.push(`- ok: ${result.ok}`);
  if (result.blockers.length) lines.push(`- blockers: ${result.blockers.join(', ')}`);
  lines.push('');
  lines.push('| Artifact | Status | Blockers |');
  lines.push('| --- | --- | --- |');
  for (const artifact of result.artifacts) {
    lines.push(`| ${artifact.name} | ${artifact.ok ? 'pass' : 'blocked'} | ${artifact.blockers.join('<br>') || '-'} |`);
  }
  return `${lines.join('\n')}\n`;
}

function main() {
  const args = process.argv.slice(2);
  const command = args.find((arg) => !arg.startsWith('--')) || 'validate';
  if (!['validate', 'aggregate'].includes(command)) {
    const result = {
      ok: false,
      project_root: path.resolve(lib.projectRoot()),
      active_change: null,
      change_dir: null,
      verify_dir: null,
      blockers: [`unknown-command:${command}`],
      artifacts: []
    };
    process.stdout.write(args.includes('--json') ? `${JSON.stringify(result, null, 2)}\n` : markdown(result));
    process.exit(2);
  }
  const result = command === 'aggregate' ? writeAggregate() : validateVerify();
  process.stdout.write(args.includes('--json') ? `${JSON.stringify(result, null, 2)}\n` : (command === 'aggregate' ? `${JSON.stringify(result, null, 2)}\n` : markdown(result)));
  process.exit((result.ok === false || result.verdict === 'red') ? 2 : 0);
}

if (require.main === module) main();

module.exports = { DOMAINS, validateVerify, writeAggregate };
