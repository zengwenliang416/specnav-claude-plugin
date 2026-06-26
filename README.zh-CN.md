# Helm Claude Code 插件套件

Helm 是一个基于 OpenSpec 的 Claude Code 多插件工作流套件，用来约束从需求到运维的完整工程过程：

```text
初始化 -> 规范发现 -> 需求 -> 原型 -> 开发 -> 测试验证 -> 运维
```

它不是 Kubernetes Helm chart 插件。“Helm” 是这个 OpenSpec 生命周期套件的名字：Claude 负责理解、解释和提出候选方案，文件化契约、Hook 和确定性脚本负责判断下一步是否合法。

这个仓库本身就是一个本地 Claude Code marketplace。每个生命周期阶段都是独立插件，`helm-core` 负责启动、路由、Hook、状态、诊断和跨插件依赖检查。

English documentation: [README.md](README.md)

## 本地安装

在仓库根目录执行：

```bash
claude plugin marketplace add "$PWD"
claude plugin install helm-core@helm-marketplace
claude plugin install helm-requirements@helm-marketplace
claude plugin install helm-prototype@helm-marketplace
claude plugin install helm-development@helm-marketplace
claude plugin install helm-verification@helm-marketplace
claude plugin install helm-operations@helm-marketplace
claude plugin enable helm-core@helm-marketplace
claude plugin enable helm-requirements@helm-marketplace
claude plugin enable helm-prototype@helm-marketplace
claude plugin enable helm-development@helm-marketplace
claude plugin enable helm-verification@helm-marketplace
claude plugin enable helm-operations@helm-marketplace
```

如果当前 Claude Code 版本的插件命令名称不同，只安装包含 `.claude-plugin/marketplace.json` 的本地 marketplace 根目录，并以 `claude plugin validate "$PWD"` 和 `claude plugin list --json` 验证。

安装或更新 commands、skills、hooks、agents 后，请启动新的 Claude Code 会话。

## 第一次使用

安装后要在目标项目里使用 Helm，不是在这个插件仓库里继续操作。

```text
1. 运行 /helm-doctor
   确认六个插件、Hook、commands、skills、OpenSpec CLI 和 installed cache 都可见。

2. 运行 /helm
   读取当前 affordance table，报告下一步合法命令。

3. 如果项目没有 OpenSpec 状态，运行 /helm-bootstrap
   这会创建 openspec/、openspec/.helm/workflow-state.json、context manifests 和项目根目录 .helm.json 标记。

4. 运行 /helm-status
   确认 active change、ready actions、blockers、risk tier 和 stale verification 状态。

5. 运行 /helm-requirements
   如果 foundation specs 缺失，Helm 会先路由到仓库规范发现和 foundation spec 修复，然后才能开始功能问需。
```

完整 walkthrough 见 [docs/user-journey.md](docs/user-journey.md)。

## 工作流模型

| 阶段 | 命令 | 读取 | 写入 | 常见 blocker | 下一步 |
| --- | --- | --- | --- | --- | --- |
| 初始化 | `/helm-bootstrap` | 插件缓存、OpenSpec CLI | `openspec/`、`.helm/`、`.helm.json` | `missing-openspec-cli`、初始化失败 | `/helm-status` |
| 规范发现 | `/helm-requirements` + `helm-repository-discovery` | 仓库文件、已有 specs | `openspec/.helm/context/repository-discovery.json` | 证据缺失、问题未确认 | `helm-foundation-specs` |
| 需求 | `/helm-requirements` | foundation specs、active change | `requirements.md`、`acceptance.md`、`spec-map.json`、`component-impact-map.json` | specs 缺失/非法、unresolved gaps | `/helm-prototype` |
| 原型 | `/helm-prototype` | requirements artifacts、设计上下文 | `prototype/` artifacts、verifier report、handoff | 上下文缺失、verifier red、未批准 | `/helm-implement` |
| 开发 | `/helm-implement` | requirements、prototype handoff、scope | `scope.json`、任务 artifacts、生产代码改动 | scope 非法、上游漂移、review 失败 | `/helm-verify` |
| 验证 | `/helm-verify` | development handoff、specs、tests | 六域 `verify/` 证据和 aggregate report | stale report、domain red、证据缺失 | `/helm-release` |
| 运维 | `/helm-release`、`/helm-archive` | green verification、git/docs/release target | `operations/` readiness 和 release artifacts | verify not green、target 不明确、ops artifact 缺失 | archive/writeback |

完整命令和 skill 矩阵见 [docs/command-skill-matrix.md](docs/command-skill-matrix.md)。

## Spec Discovery

需求阶段不能从空 prompt 开始。Helm 会先检查四个 foundation specs：

- `openspec/specs/ui-design/design.md`
- `openspec/specs/system-architecture/design.md`
- `openspec/specs/frontend-backend-data-flow/design.md`
- `openspec/specs/component-architecture/design.md`

如果它们缺失或不完整，Helm 必须先发现仓库事实、列出推断约定、向用户确认缺口，然后才能写入或修复 foundation specs。Discovery 证据不能绕过 `foundation-specs.js` gate。详见 [docs/spec-discovery.md](docs/spec-discovery.md)。

## 插件职责

- `helm-core`：核心运行时、路由、Hook、状态、诊断、跨插件依赖检查。
- `helm-requirements`：四个 foundation specs、问需、验收标准、`spec-map.json`、`component-impact-map.json`。
- `helm-prototype`：可运行原型、原型验证、用户确认、开发交接。
- `helm-development`：开发入口、scope lock、垂直切片任务、开发交接。
- `helm-verification`：六类测试验证：真实性、静态、单元、红队、E2E、体感审计。
- `helm-operations`：发布、安装验证、更新策略、兼容性、分支收尾、部署、回滚、监控、复盘、归档前检查。

## Public Skills

所有公开 skills 都采用 Agent Skills 严格子集：

- frontmatter 只保留 `name` 和 `description`；
- `name` 必须使用 `helm-*` 前缀；
- `description` 必须写明触发场景；
- 不使用 `allowed-tools`、`metadata` 或 `compatibility`；
- 缺少 OpenSpec、插件、状态文件或 required artifact 时直接报告 blocker，不走 fallback。

主要 skills：

- Core：`helm-workflow`、`helm-bootstrap`、`helm-route`、`helm-status`、`helm-doctor`、`helm-debug`、`helm-recovery`
- Requirements：`helm-repository-discovery`、`helm-foundation-specs`、`helm-requirements`
- Prototype：`helm-prototype`、`helm-prototype-verify`、`helm-prototype-handoff`
- Development：`helm-development-entry`、`helm-scope-lock`、`helm-vertical-slices`
- Verification：`helm-verify-plan`、`helm-verify-facticity`、`helm-verify-static`、`helm-verify-unit`、`helm-verify-redteam`、`helm-verify-e2e`、`helm-verify-sensory`
- Operations：`helm-ops-readiness`、`helm-release-plan`、`helm-install-verify`、`helm-update-policy`、`helm-compatibility-matrix`、`helm-branch-finish`、`helm-deploy`、`helm-rollback`、`helm-monitor`、`helm-postmortem`、`helm-update-spec`

## 常用检查

```bash
bash tests/run-plugin-validate-fixtures.sh
bash tests/run-skill-contract-fixtures.sh
bash tests/run-skill-resource-fixtures.sh
bash tests/run-plugin-suite-layout-fixtures.sh
bash tests/run-plugin-suite-resolver-fixtures.sh
bash tests/run-public-hygiene-fixtures.sh
bash tests/run-core-runtime-fixtures.sh
bash tests/run-installed-cache-runtime-fixtures.sh
bash tests/run-smoke.sh
```

每个阶段还有独立 fixture：`requirements`、`prototype`、`development`、`verification`、`operations`。

## 设计文档

- 主工程契约：[docs/design.md](docs/design.md)
- 首次使用路径：[docs/user-journey.md](docs/user-journey.md)
- Spec Discovery 契约：[docs/spec-discovery.md](docs/spec-discovery.md)
- Command / Skill 矩阵：[docs/command-skill-matrix.md](docs/command-skill-matrix.md)
- 兼容性矩阵：[docs/compatibility.md](docs/compatibility.md)
- 发布检查清单：[docs/release-checklist.md](docs/release-checklist.md)
- Skill 套件重构：[docs/skill-suite-redesign.md](docs/skill-suite-redesign.md)
- Skill 资源矩阵：[docs/skill-resource-matrix.md](docs/skill-resource-matrix.md)
