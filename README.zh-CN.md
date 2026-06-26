# Helm Claude Code 插件套件

Helm 是一个基于 OpenSpec 的 Claude Code 多插件工作流套件，用来约束从需求到运维的完整工程过程：

```text
需求 -> 原型 -> 开发 -> 测试验证 -> 运维
```

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
- Requirements：`helm-foundation-specs`、`helm-requirements`
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
bash tests/run-core-runtime-fixtures.sh
bash tests/run-installed-cache-runtime-fixtures.sh
bash tests/run-smoke.sh
```

每个阶段还有独立 fixture：`requirements`、`prototype`、`development`、`verification`、`operations`。

## 设计文档

- 主工程契约：[docs/design.md](docs/design.md)
- Skill 套件重构：[docs/skill-suite-redesign.md](docs/skill-suite-redesign.md)
- Skill 资源矩阵：[docs/skill-resource-matrix.md](docs/skill-resource-matrix.md)
