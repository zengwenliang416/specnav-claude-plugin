<p align="center">
  <img src="docs/assets/specnav-logo-readme.png" alt="SpecNav logo" width="148" height="148">
</p>

<h1 align="center">SpecNav Claude Code Plugin Suite</h1>

<p align="center">
  <strong>OpenSpec-governed delivery flow for Claude Code.</strong>
</p>

<p align="center">
  <a href="README.zh-CN.md">中文</a> ·
  <a href="#install-from-github">Install</a> ·
  <a href="#how-the-flow-works">Flow</a> ·
  <a href="#stage-atlas">Stage Atlas</a> ·
  <a href="#skills">Skills</a> ·
  <a href="docs/design.md">Design</a>
</p>

<p align="center">
  <code>bootstrap</code> -> <code>discovery</code> -> <code>requirements</code> -> <code>prototype</code> -> <code>development</code> -> <code>verification</code> -> <code>operations</code>
</p>

SpecNav turns AI coding from an open-ended chat into a file-backed software
delivery process. It uses OpenSpec artifacts, Claude Code commands, Agent
Skills, plugin hooks, and deterministic scripts to decide what is legal next,
what is blocked, and what evidence must exist before the agent can move
forward.

SpecNav means navigating development through file-backed OpenSpec contracts.

This repository is a Claude Code marketplace that ships seven installable plugins:

| Plugin | Responsibility |
| --- | --- |
| `specnav-core` | Runtime, hooks, bootstrap, status, doctor, route, recovery |
| `specnav-requirements` | Repository discovery, foundation specs, requirements questioning |
| `specnav-prototype` | Runnable prototype artifacts, prototype verification, handoff |
| `specnav-development` | Scope lock, vertical slices, fix/debug/break-loop workflows |
| `specnav-verification` | Six-domain verification and stakeholder HTML reports |
| `specnav-operations` | Release readiness, deploy, rollback, monitor, archive action |
| `specnav-codegraph` | CodeGraph policy, context, claims, impact, and evidence artifacts |

`specnav-codegraph` is a cross-cutting evidence layer. It ships with SpecNav,
but CodeGraph setup and per-project indexing remain explicit actions through
`specnav-codegraph-setup` and `specnav-codegraph-init`.

## Stage Atlas

The full lifecycle is intentionally visual: every phase has a gate, artifact
contract, and next-action boundary.

Future SpecNav diagrams should follow the project visual memory:
[docs/memory/specnav-visual-style.md](docs/memory/specnav-visual-style.md).

<p align="center">
  <img src="docs/assets/readme/en/specnav-overview-bd-2k.png" alt="SpecNav lifecycle overview" width="100%">
</p>

<table>
  <tr>
    <td width="50%">
      <strong>1. Bootstrap</strong><br>
      <img src="docs/assets/readme/en/stage-1-bootstrap-bd-2k.png" alt="SpecNav bootstrap stage">
    </td>
    <td width="50%">
      <strong>2. Discovery</strong><br>
      <img src="docs/assets/readme/en/stage-2-discovery-bd-2k.png" alt="SpecNav discovery stage">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <strong>3. Requirements</strong><br>
      <img src="docs/assets/readme/en/stage-3-requirements-bd-2k.png" alt="SpecNav requirements stage">
    </td>
    <td width="50%">
      <strong>4. Prototype</strong><br>
      <img src="docs/assets/readme/en/stage-4-prototype-bd-2k.png" alt="SpecNav prototype stage">
    </td>
  </tr>
  <tr>
    <td width="50%">
      <strong>5. Development</strong><br>
      <img src="docs/assets/readme/en/stage-5-development-bd-2k.png" alt="SpecNav development stage">
    </td>
    <td width="50%">
      <strong>6. Verification</strong><br>
      <img src="docs/assets/readme/en/stage-6-verification-bd-2k.png" alt="SpecNav verification stage">
    </td>
  </tr>
  <tr>
    <td colspan="2">
      <strong>7. Operations</strong><br>
      <img src="docs/assets/readme/en/stage-7-operations-bd-2k.png" alt="SpecNav operations stage">
    </td>
  </tr>
</table>

## Install From GitHub

Add this repository as a Claude Code marketplace, then install and enable all
seven plugins:

```bash
claude plugin marketplace add zengwenliang416/specnav-claude-plugin

claude plugin install specnav-core@specnav-marketplace
claude plugin install specnav-requirements@specnav-marketplace
claude plugin install specnav-prototype@specnav-marketplace
claude plugin install specnav-development@specnav-marketplace
claude plugin install specnav-verification@specnav-marketplace
claude plugin install specnav-operations@specnav-marketplace
claude plugin install specnav-codegraph@specnav-marketplace

claude plugin enable specnav-core@specnav-marketplace
claude plugin enable specnav-requirements@specnav-marketplace
claude plugin enable specnav-prototype@specnav-marketplace
claude plugin enable specnav-development@specnav-marketplace
claude plugin enable specnav-verification@specnav-marketplace
claude plugin enable specnav-operations@specnav-marketplace
claude plugin enable specnav-codegraph@specnav-marketplace
```

Validate the marketplace if you are working from a local checkout:

```bash
claude plugin validate "$PWD"
```

Start a fresh Claude Code session after installing or updating commands, skills,
hooks, agents, or scripts. Existing sessions may not see newly installed
capabilities.

## Local Development Install

From a local checkout:

```bash
git clone https://github.com/zengwenliang416/specnav-claude-plugin.git
cd specnav-claude-plugin

claude plugin marketplace add "$PWD"

claude plugin install specnav-core@specnav-marketplace
claude plugin install specnav-requirements@specnav-marketplace
claude plugin install specnav-prototype@specnav-marketplace
claude plugin install specnav-development@specnav-marketplace
claude plugin install specnav-verification@specnav-marketplace
claude plugin install specnav-operations@specnav-marketplace
claude plugin install specnav-codegraph@specnav-marketplace
```

## First Run

Run SpecNav in the target project, not inside this plugin repository.

```text
1. /specnav-doctor
   Check installed plugins, hooks, commands, skills, OpenSpec CLI, and cache
   visibility.

2. /specnav
   Read the current affordance table and report the next legal command.

3. /specnav-bootstrap
   Use this only when the project does not yet have OpenSpec state.

4. /specnav-status
   Inspect active change, ready actions, blockers, risk tier, and stale
   verification state.

5. /specnav-requirements
   Start requirements only after OpenSpec and required foundation specs exist.
```

## CodeGraph Evidence Layer

CodeGraph is a code-evidence source, not a replacement for OpenSpec or tests.
SpecNav requires CodeGraph `1.1.6` or newer when a stage policy requires code
evidence.

CodeGraph setup is explicit:

```text
1. specnav-codegraph-setup
   Check or repair Claude Code MCP wiring for CodeGraph.

2. specnav-codegraph-init
   Run project-local CodeGraph initialization only when the user explicitly
   asks for indexing.

3. specnav-codegraph-status
   Report CLI version, MCP visibility, project index, staleness, and policy.
```

During development and verification, SpecNav writes:

```text
openspec/changes/<change>/codegraph/claims-map.json
openspec/changes/<change>/codegraph/evidence-query-plan.json
openspec/changes/<change>/codegraph/evidence.jsonl
openspec/changes/<change>/codegraph/evidence-index.json
openspec/changes/<change>/codegraph/claims-report.json
```

The execution chain is:

```text
claims-map.json
  -> evidence-query-plan.json
  -> codegraph explore
  -> evidence.jsonl
  -> evidence-index.json
  -> claims-report.json
  -> stage gate
```

If CodeGraph is missing, too old, unindexed, stale, or pointed at the wrong
worktree, required stages block with a concrete `codegraph:*` blocker. There is
no fallback evidence for code-backed claims.

## How The Flow Works

| Stage | Entry | Required evidence | Next gate |
| --- | --- | --- | --- |
| Bootstrap | `/specnav-bootstrap` | `openspec/`, `.specnav/`, `.specnav.json`, workflow state | project can report legal commands |
| Discovery | `/specnav-requirements` plus `specnav-repository-discovery` | read-only repo evidence and context manifest | foundation specs can be created or repaired |
| Requirements | `specnav-foundation-specs`, `/specnav-requirements` | four foundation specs, requirements, acceptance criteria, spec map, component impact map | prototype is allowed |
| Prototype | `/specnav-prototype`, `specnav-prototype-verify`, `specnav-prototype-handoff` | runnable prototype, verification report, approval/handoff notes | development is allowed |
| Development | `/specnav-implement`, `specnav-scope-lock`, `specnav-vertical-slices` | scope lock, checkbox tasks, implementation evidence, review/fix loop | verification is allowed |
| Verification | `/specnav-verify` plus six domain skills | facticity, static, unit, redteam, E2E, sensory evidence, aggregate report, HTML report | release planning is allowed |
| Operations | `/specnav-release`, `/specnav-archive`, deploy/rollback/archive skills | release target, readiness, rollback, monitor, archive receipt | change can be archived |

## Foundation Spec Gate

Requirements do not begin from feature brainstorming. SpecNav first checks for
four project-level foundation specs:

1. UI design spec, following the project design-system format.
2. Frontend/backend architecture and database design spec.
3. Frontend/backend interaction and data-flow spec.
4. Component architecture constraint spec.

The fourth spec makes high cohesion and low coupling explicit. Repeated UI,
logic, domain utilities, or cross-feature behavior must be extracted into
stable shared components when it forms a reusable unit. Shared components must
declare ownership, props/contracts, state boundaries, and allowed dependencies.

If any foundation spec is missing, SpecNav blocks feature requirements and
guides the user to create or repair the missing spec. There is no fallback.

## Verification Model

The verification stage has six independent test domains:

| Domain | Purpose |
| --- | --- |
| Facticity / authenticity | Compare specs, claims, generated artifacts, and real system state |
| Static analysis | Run lint/type/style/structure checks before runtime testing |
| Unit testing | Validate smallest behavior units and edge cases |
| Red teaming | Probe destructive, adversarial, unsafe, or malformed paths |
| End-to-end testing | Validate real user flows across UI, services, and persistence |
| Sensory / UX audit | Human-in-the-loop review for readability, interaction, performance, and feel |

`specnav-html-report` turns verification evidence into a reviewable stakeholder
HTML report. A green report must be evidence-backed, current, and linked to the
artifacts it validates.

## No Fallback Contract

SpecNav does not silently continue when required state is missing. If a required
dependency, plugin, OpenSpec command, artifact, state file, context manifest, or
verification tool is unavailable, the dependent action is blocked with a
specific reason.

Allowed while blocked:

- `/specnav-doctor`
- `/specnav-status`
- `/specnav-bootstrap`
- read-only discovery
- OpenSpec artifact repair
- docs-only edits that do not touch production code

## Archive Contract

Archive is an explicit operation, not a passive status.

After readiness is green, run `/specnav-archive`. The archive action normalizes
`tasks.md`, requires completed checkbox tasks, runs `openspec validate`, runs
`openspec archive`, updates SpecNav change focus, rewrites archived evidence
paths, and writes `operations/archive-receipt.json` inside the archived change.

Plain bullets in `tasks.md` are not completion evidence. Tasks must use:

```markdown
- [ ] Not done yet
- [x] Completed with evidence
```

## Skills

Core:

```text
specnav-workflow
specnav-bootstrap
specnav-route
specnav-status
specnav-doctor
specnav-debug
specnav-recovery
```

Requirements:

```text
specnav-repository-discovery
specnav-foundation-specs
specnav-requirements
```

Prototype:

```text
specnav-prototype
specnav-prototype-verify
specnav-prototype-handoff
```

Development:

```text
specnav-development-entry
specnav-scope-lock
specnav-vertical-slices
specnav-fix
specnav-debug
specnav-break-loop
```

Verification:

```text
specnav-verify-plan
specnav-verify-facticity
specnav-verify-static
specnav-verify-unit
specnav-verify-redteam
specnav-verify-e2e
specnav-verify-sensory
specnav-verify-rerun
specnav-html-report
```

Operations:

```text
specnav-ops-readiness
specnav-release-plan
specnav-install-verify
specnav-update-policy
specnav-compatibility-matrix
specnav-branch-finish
specnav-deploy
specnav-rollback
specnav-monitor
specnav-postmortem
specnav-update-spec
```

## Repository Layout

```text
.claude-plugin/marketplace.json           Claude Code marketplace manifest
plugins/specnav-core/                     runtime, router, hooks, commands, status, doctor
plugins/specnav-requirements/             discovery, foundation specs, requirements
plugins/specnav-prototype/                runnable prototype and handoff
plugins/specnav-development/              scope lock and vertical-slice implementation
plugins/specnav-verification/             six-domain verification and HTML report
plugins/specnav-operations/               release, deploy, rollback, archive
plugins/specnav-codegraph/                CodeGraph policy and evidence layer
docs/design.md                            system design
docs/assets/readme/                       README stage diagrams
docs/memory/specnav-visual-style.md       diagram style prompt memory
tests/                                    fixture and smoke tests
```

## Checks

Validate the marketplace:

```bash
claude plugin validate "$PWD"
```

Run the smoke check:

```bash
bash tests/run-smoke.sh
```

Targeted checks:

```bash
bash tests/run-plugin-validate-fixtures.sh
bash tests/run-skill-contract-fixtures.sh
bash tests/run-skill-resource-fixtures.sh
bash tests/run-plugin-suite-layout-fixtures.sh
bash tests/run-plugin-suite-resolver-fixtures.sh
bash tests/run-public-hygiene-fixtures.sh
bash tests/run-core-runtime-fixtures.sh
bash tests/run-installed-cache-runtime-fixtures.sh
```

## References

- [System design](docs/design.md)
- [First-run user journey](docs/user-journey.md)
- [Spec discovery contract](docs/spec-discovery.md)
- [Command and skill matrix](docs/command-skill-matrix.md)
- [Visual style memory](docs/memory/specnav-visual-style.md)
- [Claude Code marketplace manifest](.claude-plugin/marketplace.json)
- [4K transparent logo](docs/assets/specnav-logo-4k.png)
