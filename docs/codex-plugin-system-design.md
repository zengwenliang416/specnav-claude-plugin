# SpecNav Codex Plugin System Design

Status: proposed design

Date: 2026-06-27

Target repository:

```text
/Volumes/zwl/AI/ai-coding/specnav-codex-plugin
```

Target GitHub repository:

```text
zengwenliang416/specnav-codex-plugin
```

## 1. Design Decision

The Codex version should be redesigned from the Claude Code plugin system, not
from the previous single-plugin Codex plan.

The Claude Code implementation is a marketplace-based plugin suite:

```text
specnav-claude-plugin/
├── .claude-plugin/marketplace.json
└── plugins/
    ├── specnav-core/
    ├── specnav-requirements/
    ├── specnav-prototype/
    ├── specnav-development/
    ├── specnav-verification/
    └── specnav-operations/
```

The Codex implementation should preserve that product architecture:

```text
specnav-codex-plugin/
├── .agents/plugins/marketplace.json
└── plugins/
    ├── specnav-core/
    ├── specnav-requirements/
    ├── specnav-prototype/
    ├── specnav-development/
    ├── specnav-verification/
    └── specnav-operations/
```

Each lifecycle stage remains a separately installable Codex plugin. This keeps
the same mental model as Claude Code:

- `specnav-core` is mandatory;
- each stage plugin owns its skills, scripts, templates, and contracts;
- cross-stage orchestration goes through core;
- missing stage plugins are reported as exact blockers;
- no fallback is allowed.

## 2. Claude-to-Codex Mapping

| Claude Code concept | Current Claude path | Codex equivalent | Target Codex path |
| --- | --- | --- | --- |
| Marketplace root | `.claude-plugin/marketplace.json` | repo/plugin marketplace | `.agents/plugins/marketplace.json` |
| Plugin manifest | `plugins/*/.claude-plugin/plugin.json` | Codex plugin manifest | `plugins/*/.codex-plugin/plugin.json` |
| Plugin skills | `plugins/*/skills/*/SKILL.md` | Codex bundled skills | `plugins/*/skills/*/SKILL.md` |
| Slash commands | `plugins/*/commands/*.md` | entry/routing skills | `plugins/*/skills/specnav-*/SKILL.md` |
| Core hooks | `plugins/specnav-core/hooks/hooks.json` | Codex plugin hooks | `plugins/specnav-core/hooks/hooks.json` |
| Hook root env | `CLAUDE_PLUGIN_ROOT` | Codex plugin root env | `PLUGIN_ROOT` |
| Plugin data env | `CLAUDE_PLUGIN_DATA` | Codex plugin data env | `PLUGIN_DATA` |
| Installed cache | `~/.claude/plugins/cache/...` | Codex cache | `~/.codex/plugins/cache/...` |
| Claude validation | `claude plugin validate` | Codex manifest/smoke fixtures | `tests/run-codex-*.sh` |

The Codex system should not carry Claude command files as first-class runtime
entry points. Any command behavior must become either a skill or a runtime CLI
script invoked by a skill.

## 3. Target Repository Layout

```text
specnav-codex-plugin/
├── .agents/
│   └── plugins/
│       └── marketplace.json
├── plugins/
│   ├── specnav-core/
│   │   ├── .codex-plugin/plugin.json
│   │   ├── hooks/
│   │   ├── skills/
│   │   ├── scripts/
│   │   ├── templates/
│   │   └── assets/
│   ├── specnav-requirements/
│   │   ├── .codex-plugin/plugin.json
│   │   ├── skills/
│   │   ├── scripts/
│   │   ├── templates/
│   │   └── assets/
│   ├── specnav-prototype/
│   │   ├── .codex-plugin/plugin.json
│   │   ├── skills/
│   │   ├── scripts/
│   │   ├── templates/
│   │   └── assets/
│   ├── specnav-development/
│   │   ├── .codex-plugin/plugin.json
│   │   ├── skills/
│   │   ├── scripts/
│   │   ├── templates/
│   │   └── assets/
│   ├── specnav-verification/
│   │   ├── .codex-plugin/plugin.json
│   │   ├── skills/
│   │   ├── scripts/
│   │   ├── templates/
│   │   └── assets/
│   └── specnav-operations/
│       ├── .codex-plugin/plugin.json
│       ├── skills/
│       ├── scripts/
│       ├── templates/
│       └── assets/
├── docs/
│   ├── design.md
│   ├── install.md
│   ├── user-journey.md
│   ├── command-skill-matrix.md
│   ├── compatibility.md
│   └── release-checklist.md
├── tests/
│   ├── run-codex-marketplace-fixtures.sh
│   ├── run-codex-plugin-fixtures.sh
│   ├── run-codex-skill-fixtures.sh
│   ├── run-codex-hook-fixtures.sh
│   ├── run-runtime-fixtures.sh
│   ├── run-stage-fixtures.sh
│   ├── run-verification-fixtures.sh
│   └── run-smoke.sh
├── README.md
├── README.zh-CN.md
├── package.json
└── LICENSE
```

This mirrors the Claude Code suite while using Codex-native install surfaces.

## 4. Codex Marketplace

Claude uses:

```text
.claude-plugin/marketplace.json
```

Codex should use:

```text
.agents/plugins/marketplace.json
```

Target marketplace:

```json
{
  "name": "specnav-marketplace",
  "interface": {
    "displayName": "SpecNav Marketplace"
  },
  "plugins": [
    {
      "name": "specnav-core",
      "source": {
        "source": "local",
        "path": "./plugins/specnav-core"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Developer Tools"
    },
    {
      "name": "specnav-requirements",
      "source": {
        "source": "local",
        "path": "./plugins/specnav-requirements"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Developer Tools"
    },
    {
      "name": "specnav-prototype",
      "source": {
        "source": "local",
        "path": "./plugins/specnav-prototype"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Developer Tools"
    },
    {
      "name": "specnav-development",
      "source": {
        "source": "local",
        "path": "./plugins/specnav-development"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Developer Tools"
    },
    {
      "name": "specnav-verification",
      "source": {
        "source": "local",
        "path": "./plugins/specnav-verification"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Developer Tools"
    },
    {
      "name": "specnav-operations",
      "source": {
        "source": "local",
        "path": "./plugins/specnav-operations"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Developer Tools"
    }
  ]
}
```

Install shape:

```bash
codex plugin marketplace add /Volumes/zwl/AI/ai-coding/specnav-codex-plugin
codex plugin add specnav-core@specnav-marketplace
codex plugin add specnav-requirements@specnav-marketplace
codex plugin add specnav-prototype@specnav-marketplace
codex plugin add specnav-development@specnav-marketplace
codex plugin add specnav-verification@specnav-marketplace
codex plugin add specnav-operations@specnav-marketplace
```

The README should also include a one-line Codex install prompt:

```text
Codex: add this repository as a plugin marketplace, install all six SpecNav plugins, trust the core hooks with /hooks, then start with $specnav-workflow.
```

Chinese:

```text
Codex：把本仓库添加为插件 marketplace，安装六个 SpecNav 插件，用 /hooks 信任 core hook，然后从 $specnav-workflow 开始。
```

## 5. Plugin Manifests

Each stage has a Codex manifest:

```text
plugins/<plugin>/.codex-plugin/plugin.json
```

### `specnav-core`

```json
{
  "name": "specnav-core",
  "version": "0.1.0",
  "description": "Core runtime, routing, hooks, status, doctor, and suite dependency checks for SpecNav.",
  "author": {
    "name": "SpecNav Maintainers",
    "url": "https://github.com/zengwenliang416/specnav-codex-plugin"
  },
  "homepage": "https://github.com/zengwenliang416/specnav-codex-plugin",
  "repository": "https://github.com/zengwenliang416/specnav-codex-plugin",
  "license": "MIT",
  "keywords": [
    "codex",
    "openspec",
    "workflow",
    "hooks",
    "lifecycle"
  ],
  "skills": "./skills/",
  "hooks": "./hooks/hooks.json",
  "interface": {
    "displayName": "SpecNav Core",
    "shortDescription": "OpenSpec lifecycle router and guardrails for Codex",
    "longDescription": "Provides SpecNav routing, bootstrap, status, doctor, recovery, lifecycle hooks, suite dependency checks, and no-fallback OpenSpec guardrails.",
    "developerName": "SpecNav Maintainers",
    "category": "Developer Tools",
    "capabilities": [
      "Interactive",
      "Read",
      "Write"
    ],
    "defaultPrompt": [
      "Use SpecNav to inspect the next legal lifecycle action.",
      "Use SpecNav to bootstrap this project before requirements."
    ],
    "brandColor": "#10A37F",
    "composerIcon": "./assets/icon.svg",
    "logo": "./assets/logo.svg",
    "screenshots": []
  }
}
```

### Stage Plugins

Each stage plugin follows the same manifest structure, but only `specnav-core`
declares hooks.

Example:

```json
{
  "name": "specnav-requirements",
  "version": "0.1.0",
  "description": "Requirements and foundation spec stage for the SpecNav OpenSpec lifecycle.",
  "author": {
    "name": "SpecNav Maintainers",
    "url": "https://github.com/zengwenliang416/specnav-codex-plugin"
  },
  "homepage": "https://github.com/zengwenliang416/specnav-codex-plugin",
  "repository": "https://github.com/zengwenliang416/specnav-codex-plugin",
  "license": "MIT",
  "keywords": [
    "codex",
    "openspec",
    "requirements",
    "specs"
  ],
  "skills": "./skills/",
  "interface": {
    "displayName": "SpecNav Requirements",
    "shortDescription": "Foundation specs and requirements negotiation for SpecNav",
    "longDescription": "Creates and validates repository discovery, UI design, system architecture, frontend-backend data flow, component architecture, requirements, acceptance criteria, spec maps, and component impact maps.",
    "developerName": "SpecNav Maintainers",
    "category": "Developer Tools",
    "capabilities": [
      "Interactive",
      "Read",
      "Write"
    ],
    "defaultPrompt": [
      "Use SpecNav requirements to prepare foundation specs before feature work."
    ],
    "brandColor": "#10A37F",
    "composerIcon": "./assets/icon.svg",
    "logo": "./assets/logo.svg",
    "screenshots": []
  }
}
```

## 6. Plugin Responsibilities

| Plugin | Owns | Must depend on |
| --- | --- | --- |
| `specnav-core` | bootstrap, router, status, doctor, recovery, hooks, suite resolution, workflow state | none |
| `specnav-requirements` | repository discovery, four foundation specs, requirements, acceptance, spec maps, component impact maps | `specnav-core` |
| `specnav-prototype` | runnable prototype, prototype verification, decision, handoff | `specnav-core`, `specnav-requirements` |
| `specnav-development` | before-dev gate, scope lock, vertical slices, task ledger, reviews, fix loop, break-loop | `specnav-core`, `specnav-requirements`, `specnav-prototype` |
| `specnav-verification` | six-domain verification, evidence index, aggregate JSON/Markdown/HTML reports, stale rerun | `specnav-core`, `specnav-development` |
| `specnav-operations` | release, install verification, update policy, compatibility, deploy, rollback, monitor, postmortem, archive | `specnav-core`, `specnav-verification` |

Each plugin must fail with:

```text
missing-plugin:<plugin-name>
```

when a required plugin is unavailable.

## 7. Skill System

Codex supports Agent Skills directly, so existing Claude skills can mostly keep
their structure:

```text
plugins/<plugin>/skills/<skill>/SKILL.md
```

Rules:

- frontmatter contains only `name` and `description`;
- skill names use `specnav-*`;
- descriptions start with clear trigger conditions;
- no `allowed-tools`;
- no Claude slash commands as required steps;
- no host-specific cache path assumptions;
- deterministic actions run scripts under the owning plugin.

Codex invocation:

```text
$specnav-workflow
$specnav-bootstrap
$specnav-requirements
$specnav-prototype
$specnav-development-entry
$specnav-verify-plan
$specnav-ops-readiness
```

Claude command mapping:

| Claude command | Codex skill |
| --- | --- |
| `/specnav` | `$specnav-workflow` |
| `/specnav-bootstrap` | `$specnav-bootstrap` |
| `/specnav-status` | `$specnav-status` |
| `/specnav-doctor` | `$specnav-doctor` |
| `/specnav-requirements` | `$specnav-requirements` |
| `/specnav-prototype` | `$specnav-prototype` |
| `/specnav-implement` | `$specnav-development-entry` then `$specnav-vertical-slices` |
| `/specnav-verify` | `$specnav-verify-plan` then six domain skills |
| `/specnav-release` | `$specnav-release-plan` |
| `/specnav-archive` | `$specnav-branch-finish` |

## 8. Hook System

Claude core hook:

```json
{
  "command": "node \"$CLAUDE_PLUGIN_ROOT/scripts/specnav-session-start.js\""
}
```

Codex core hook:

```json
{
  "command": "node \"${PLUGIN_ROOT}/scripts/specnav-session-start.js\""
}
```

Target:

```text
plugins/specnav-core/hooks/hooks.json
```

Codex hook config:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${PLUGIN_ROOT}/scripts/specnav-session-start.js\"",
            "statusMessage": "Loading SpecNav context"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node \"${PLUGIN_ROOT}/scripts/specnav-user-prompt-submit.js\"",
            "timeout": 15
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash|apply_patch|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${PLUGIN_ROOT}/scripts/specnav-guard.js\"",
            "timeout": 15,
            "statusMessage": "Checking SpecNav gates"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash|apply_patch|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${PLUGIN_ROOT}/scripts/specnav-post-tool.js\"",
            "timeout": 20
          }
        ]
      }
    ]
  }
}
```

Hook behavior:

- `SessionStart`: inject SpecNav lifecycle and no-fallback policy.
- `UserPromptSubmit`: if `openspec/` is missing, inject bootstrap guidance.
- `PreToolUse`: block production edits in SpecNav-managed projects when gates fail.
- `PostToolUse`: update workflow state and stale verification markers.

Codex hook trust is explicit. README must tell users to run:

```text
/hooks
```

after install and trust the `specnav-core` hooks.

## 9. Runtime Resolution

The Claude suite resolves sibling plugins from Claude installed cache. Codex must
resolve from Codex plugin cache.

Resolution order:

1. explicit environment variable for tests:

   ```text
   SPECNAV_<PLUGIN>_ROOT
   ```

2. current plugin root:

   ```text
   PLUGIN_ROOT
   ```

3. sibling Codex cache roots:

   ```text
   ~/.codex/plugins/cache/<marketplace>/<plugin>/<version>/
   ```

4. source-tree sibling roots:

   ```text
   <repo>/plugins/<plugin>/
   ```

5. fail with:

   ```text
   missing-plugin:<plugin-name>
   ```

Do not resolve from:

```text
~/.claude/plugins/cache
CLAUDE_PLUGIN_ROOT
.claude-plugin/plugin.json
```

Codex may set `CLAUDE_PLUGIN_ROOT` for compatibility, but the SpecNav Codex
implementation must not depend on it.

## 10. Lifecycle Gates

The Codex plugin system preserves the Claude lifecycle:

```text
bootstrap -> spec discovery -> requirements -> prototype -> development -> verification -> operations
```

### Bootstrap

Owned by `specnav-core`.

Creates:

```text
openspec/
.specnav.json
openspec/.specnav/workflow-state.json
```

### Spec Discovery and Requirements

Owned by `specnav-requirements`.

Requires:

```text
openspec/specs/ui-design/design.md
openspec/specs/system-architecture/design.md
openspec/specs/frontend-backend-data-flow/design.md
openspec/specs/component-architecture/design.md
```

Then writes:

```text
openspec/changes/<change>/requirements.md
openspec/changes/<change>/acceptance.md
openspec/changes/<change>/spec-map.json
openspec/changes/<change>/component-impact-map.json
```

### Prototype

Owned by `specnav-prototype`.

Writes runnable prototype artifacts and a user approval handoff:

```text
openspec/changes/<change>/prototype/
```

### Development

Owned by `specnav-development`.

Writes:

```text
openspec/changes/<change>/development/
```

Includes before-dev, scope lock, vertical slices, task ledger, review loop, fix
loop, and break-loop.

### Verification

Owned by `specnav-verification`.

Writes:

```text
openspec/changes/<change>/verify/
openspec/changes/<change>/verify-report.json
openspec/changes/<change>/verify-report.md
openspec/changes/<change>/verify-report.html
```

Six domains:

```text
facticity
static
unit
redteam
e2e
sensory
```

HTML report style:

- cream canvas;
- coral accent;
- dark navy surfaces;
- serif display headings;
- humanist sans body;
- stakeholder-readable layout.

### Operations

Owned by `specnav-operations`.

Writes:

```text
openspec/changes/<change>/operations/
```

Covers release, install verification, update policy, compatibility, deploy,
rollback, monitor, postmortem, update-spec, branch finish, and archive.

## 11. No-Fallback Policy

Every Codex plugin must keep the same no-fallback policy as the Claude suite.

If a required dependency, OpenSpec command, artifact, state file, hook, skill,
or plugin is missing, SpecNav reports the exact blocker and stops.

Allowed actions while blocked:

- doctor/status;
- bootstrap;
- OpenSpec artifact repair;
- read-only discovery;
- docs-only edits that do not touch production code.

Not allowed:

- infer missing specs from chat history;
- continue development without foundation specs;
- mark prototype approved without decision artifact;
- mark development complete with failed review;
- aggregate verification without all six domains;
- release without green verification.

## 12. README Model

Both README files must explain Codex installation in the same practical style as
the Claude README.

English:

```text
SpecNav for Codex is a six-plugin OpenSpec lifecycle suite. Add this repository as a Codex marketplace, install all six plugins, trust the specnav-core hooks with /hooks, then start from $specnav-workflow in the target project.
```

Chinese:

```text
SpecNav for Codex 是一个六插件 OpenSpec 生命周期套件。把本仓库添加为 Codex marketplace，安装六个插件，用 /hooks 信任 specnav-core hooks，然后在目标项目里从 $specnav-workflow 开始。
```

README sections:

- Overview
- Install Locally
- Install From GitHub
- First Run
- Hook Trust
- Workflow Model
- Plugin Layout
- Public Skills
- Useful Checks
- Design Notes

## 13. Tests

Codex suite tests:

```text
tests/run-codex-marketplace-fixtures.sh
tests/run-codex-plugin-fixtures.sh
tests/run-codex-skill-fixtures.sh
tests/run-codex-hook-fixtures.sh
tests/run-plugin-suite-resolver-fixtures.sh
tests/run-core-runtime-fixtures.sh
tests/run-requirements-plugin-fixtures.sh
tests/run-prototype-plugin-fixtures.sh
tests/run-development-plugin-fixtures.sh
tests/run-verification-plugin-fixtures.sh
tests/run-operations-plugin-fixtures.sh
tests/run-public-hygiene-fixtures.sh
tests/run-smoke.sh
```

Required checks:

- marketplace parses;
- all six plugin entries exist;
- every plugin has `.codex-plugin/plugin.json`;
- every manifest path starts with `./`;
- every manifest path exists;
- every skill has valid Agent Skills frontmatter;
- no skill requires Claude slash commands;
- no script depends on `CLAUDE_PLUGIN_ROOT`;
- hooks use `PLUGIN_ROOT`;
- hook JSON parses;
- hook scripts syntax-check;
- suite resolver finds installed and source sibling plugins;
- all lifecycle contracts fail closed;
- verification writes JSON, Markdown, and HTML.

Full test:

```bash
for test_script in tests/run-*.sh; do
  bash "$test_script"
done
```

## 14. Implementation Plan

### Phase 0: Create Codex repository

Create:

```text
/Volumes/zwl/AI/ai-coding/specnav-codex-plugin
```

Initialize:

```bash
git init
```

Add:

```text
README.md
README.zh-CN.md
docs/design.md
.agents/plugins/marketplace.json
```

### Phase 1: Create six Codex plugin manifests

Add:

```text
plugins/specnav-core/.codex-plugin/plugin.json
plugins/specnav-requirements/.codex-plugin/plugin.json
plugins/specnav-prototype/.codex-plugin/plugin.json
plugins/specnav-development/.codex-plugin/plugin.json
plugins/specnav-verification/.codex-plugin/plugin.json
plugins/specnav-operations/.codex-plugin/plugin.json
```

### Phase 2: Port skills

Copy and revise Claude skills:

```text
plugins/<plugin>/skills/
```

Remove Claude command assumptions and replace command entry points with Codex
skill invocation language.

### Phase 3: Port runtime scripts

Move deterministic scripts into each owning plugin:

```text
plugins/<plugin>/scripts/
```

Replace resolver logic with Codex cache/source sibling resolution.

### Phase 4: Port hooks

Only `specnav-core` owns hooks.

Rewrite:

```text
specnav-session-start.js
specnav-user-prompt-submit.js
specnav-guard.js
specnav-post-tool.js
```

Use `PLUGIN_ROOT` and Codex hook schemas.

### Phase 5: Port templates and assets

Move stage artifact shells to:

```text
plugins/<plugin>/templates/
plugins/<plugin>/assets/
```

Keep skill-local assets under skill folders only when they are specific to one
skill.

### Phase 6: Tests and local install smoke

Run:

```bash
codex plugin marketplace add /Volumes/zwl/AI/ai-coding/specnav-codex-plugin
codex plugin list --marketplace specnav-marketplace --available --json
codex plugin add specnav-core@specnav-marketplace --json
```

Then install the remaining five plugins and verify `$specnav-workflow` appears
in a fresh Codex session.

## 15. Release Policy

Version the Codex suite independently from Claude:

```text
0.1.0 Codex marketplace + six plugin manifests + install smoke
0.2.0 core hooks + bootstrap + doctor + status
0.3.0 requirements + foundation specs
0.4.0 prototype + development
0.5.0 verification + HTML report
0.6.0 operations
1.0.0 full lifecycle stable
```

Release requirements:

- all tests pass;
- local Codex install smoke passes;
- README and README.zh-CN are updated;
- compatibility doc names exact Codex version tested;
- no Claude primary entry points remain in Codex docs.

## 16. Next Action

If this design is accepted, start by creating:

```text
/Volumes/zwl/AI/ai-coding/specnav-codex-plugin
```

Then implement Phase 0 and Phase 1 before moving any runtime logic.
