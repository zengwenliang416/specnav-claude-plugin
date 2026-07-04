# SpecNav 优化计划（2026-07）

> 输入：本仓库系统性审计（架构 / spec-IR / 闭环 / 验证 / 协作 / 进化性七维）、
> Anthropic harness & loop engineering 方法论（官方 engineering 博客 2025-2026）、
> Claude Code 插件规范与最佳实践（code.claude.com/docs，2026 年中）。
>
> 组织原则：**确定性约束"结果"，而非约束"路径"**（Anthropic harness-design 的核心结论）。
> 验证器与状态产物老化慢，行为性 workaround 老化快 —— 投资前者，定期清理后者。

---

## 0. 方法论 → 缺口映射（为什么是这些优化）

| 方法论原则（来源） | SpecNav 现状缺口 | 对应工作项 |
| --- | --- | --- |
| Prompt 合规约 70-90%，hook 100%；硬规则必须进 hook（Anthropic: Steering Claude Code） | 门禁地基是 hook，但 payload 解析用多字段猜测，且失效时无告警 | P0.1 |
| 验证必须对 ground truth、端到端进行；agent 自评是"病态乐观者"（Anthropic: harness posts） | validation-log 证据自报；零测试执行可拿 green（已知缺口，路由 C5） | P1.* |
| 生成与评估分离，独立怀疑者评估器远比让生成者自我批判可行（Anthropic: harness-design） | spec-review / quality-review 由同一会话自评，verdict 写 markdown 无程序校验 | P2.2 |
| 完成标准必须机器可判定，且"不能靠写一段自信的总结满足"（Anthropic + Sonar） | acceptance.md 是 prose，验证靠章节引用而非可判定断言 | P2.1 |
| TDD：先提交测试作为防篡改目标（Anthropic: Claude Code best practices） | 无"测试先行 + 实现期禁改测试"约定 | P1.3 |
| 循环收敛需要硬停止条件与确定性熔断（Anthropic + community） | break-loop 的触发依赖 LLM 遵守 SKILL.md，非确定性 | P2.4 |
| 每个 scaffold 编码了"模型做不到 X"的假设，随模型升级失效；按发布周期审计（Anthropic: harness-design） | 无 scaffold 有效性度量；events.jsonl 数据无人消费 | P3.3 |
| Context 是耗散的注意力预算；progressive disclosure（Anthropic: context engineering） | SKILL.md 合计 88KB 常驻；部分超 500 行建议值 | P3.2 |
| 复杂度只在需要时增加，最简方案优先（Anthropic: Building Effective Agents） | 单行修复与大变更走同一全量流程；risk-tier 只裁剪验证域 | P3.1 |
| 插件规范：`claude plugin validate`、source 钉版本、payload 稳定字段白名单（官方 docs） | CI 无 plugin validate；hook 解析未收敛到稳定字段 | P0.3 |
| 44 文件跨仓字节级同步是 O(n) 维护税（仓库自认，路由 C10） | drift-check 是兜底不是解法 | P4.* |

---

## Phase 0 — 地基修复（1–2 周，全部低风险、可独立合入）

**目标：让"门禁失效时系统知道自己失效了"，并对齐当前插件规范。**

### P0.1 Guard 现代化 + 自检心跳
- `specnav-guard.js` 收敛到官方声明稳定的 payload 字段：`tool_name`、`tool_input.file_path`、
  `tool_input.command`、`cwd`、`session_id`。多字段猜测（`path`/`destination_path`/`target_path` 等）
  保留为 fallback 但记录 `guard:unknown-payload-shape` 事件到 events.jsonl。
- 阻断方式从裸 exit code 迁移到结构化 JSON 输出：
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"<blocker id + 修复指引>"}}`。
  理由：reason 会回流给模型，deny 变成可自纠错信号（"failures are verbose"原则）。
- 审计所有 hook 脚本的退出码：**规范中只有 exit 2 阻断，exit 1 不阻断**。逐个确认无"以为 exit 1 会拦"的暗雷。
- **自检心跳**：SessionStart 时用合成 PreToolUse payload 走一遍 guard 解析路径，
  失败则通过 `systemMessage` 大声告警并在 affordances 中加 `guard-selfcheck-failed` blocker。
- 验收：新增 fixture `run-guard-selfcheck-fixtures.sh`；现有 guard fixtures 全绿。

### P0.2 PostToolUse stale 标记降级
- `specnav-post-tool.js` 写 `verify-report.stale` 失败时：不再硬失败阻塞后续编辑，
  改为 `systemMessage` 警告 + 在 doctor 中登记修复项（`doctor:stale-marker-unwritable`）。
- 理由：记账操作的失败权重不应高于业务操作；PostToolUse 本身不可阻断（规范），硬失败只制造噪音。

### P0.3 规范合规 CI
- CI 增加 `claude plugin validate .`（marketplace 根）——官方校验 manifest schema、
  frontmatter、hooks.json 语法。
- `marketplace.json` 中 source 显式钉 `version`（已统一 0.4.9，补齐 schema 字段即可）。
- 修复已 pin 的 C4 缺陷（`globLikeMatch` prefix-fallback 扩权），同批合入。

### P0.4 单写者契约显式化
- `.specnav/session-lock`：`{session_id, host: "claude"|"codex", acquired_at, ttl_minutes}`。
  SessionStart 获取租约；发现活跃租约且非本会话 → blocker `session-lock:held-by-other` + 接管指引。
- 成本极低，消除 Claude/Codex 双工具并发的静默 last-writer-wins。
- 验收：新增 lock fixture（获取 / 冲突 / 过期接管三分支）。

---

## Phase 1 — 证据执行化（2–4 周，= 路线图 C5，第一优先级）

**目标：把"声称"变"实证"。这是当前 green 报告可信度的最大缺口——
门禁 schema 的精密度远超其输入的可信度（"强 schema、弱 ground truth"失衡）。**

### P1.1 evidence-runner
- 新脚本 `plugins/specnav-verification/scripts/evidence-runner.js`：
  重放 `validation-log.jsonl` 中的 command，退出码 + stdout/stderr 摘要（截断落盘、上下文只留 head/tail）
  由**系统**写入回执（`recorded_by: "specnav-evidence-runner"`）。
- validation-log schema 升 v2：区分 `attestation: "self-reported" | "system-executed"`。
  handoff 门禁要求关键任务至少一条 system-executed pass；纯自报证据使 receipt 置信降为 C。
- 不可重放的证据（sensory 人审、外部环境）保留自报通道，但强制 `caveat` 字段并降级。

### P1.2 unit 域硬化
- 修复已知缺口："seed 项目无 test script → 检查降级 warn → 零测试执行可 green"。
  新规则：unit 域 green 必须携带执行回执（测试框架输出、pass/fail 计数）；
  无可执行测试 → 域判 `blocked`（环境类 blocker），不是 warn。
- e2e 域同理：green 需要运行时证据（playwright/curl transcript 路径入 receipt）。

### P1.3 防篡改测试约定（TDD 对齐）
- development 阶段新约定：任务的测试文件在实现前提交（tasks.md 中测试任务先行）；
  实现期 `scope.json.denied_roots` 自动包含该任务已提交的测试路径
  （从 task `context.json.test_paths` 派生）。
- guard 拒绝实现期改测试；确需修改走 override（带 reason、入审计日志）——
  篡改从"静默"变"显式且留痕"。

### P1.4 验收
- lifecycle-walkthrough fixture 更新：零测试场景必须 blocked 而非 green；
  自报-only 场景 receipt 必须为 C 级；篡改测试场景必须被 guard 拦截。

---

## Phase 2 — 循环收敛工程（约 1 个月，依赖 Phase 1 的证据层）

**目标：把三个真实回路（任务内双审、验证→开发反向流、熔断）的"判据"从 LLM 自律升级为确定性。**

### P2.1 acceptance 机器可判定化
- `acceptance.md`（prose）旁生成 `acceptance.json`：断言列表
  `{id, statement, verify_via: "unit"|"e2e"|"static"|"sensory", status: "failing"|"passing", evidence_ref}`。
- 初始化时全部 `failing`；实现过程只允许翻转 `status`，禁止删改断言
  （guard 层校验：acceptance.json 的断言集合 hash 在 development 期冻结）。
- 理由：Anthropic 长程 harness 的核心做法——用 JSON 而非 markdown 存完成标准，
  因为"模型会重写 markdown"；"谁有权宣布循环结束"必须是机器可查的。
- verification 的 traceability-matrix 从"章节引用"升级为"断言 ID 引用"。

### P2.2 生成/评估分离
- 已定义但闲置的 `verifier` agent 转为强制路径：spec-review 与 quality-review
  通过 `context: fork` + `agent: verifier` 的 skill 在**隔离上下文**中执行
  （fork 的子代理拿不到实现会话的自我说服历史）。
- verifier 的 SKILL 指令按"怀疑者"校准（默认不通过，需证据引用才 approve）——
  对齐"独立评估器比让生成者自我批判可行"。
- verdict 从 markdown prose 改为结构化输出（approved 必须附 acceptance.json 断言引用），
  contract 脚本校验引用有效性。

### P2.3 diff 驱动最小重验集
- 新脚本：`git diff` + `traceability-matrix.json` → 计算失效断言集 → 推导需重跑的最小域集合。
- `specnav-verify-rerun` 消费该输出，替代"人/LLM 凭感觉选域"。

### P2.4 确定性熔断
- `development-contract.js` 读 `task-ledger.jsonl`：同一任务同一 blocker 连续 N 次（默认 3）
  → 自动产出 `loop-detected:<task>` blocker，实现动作转 blocked，只放行 break-loop 路径。
- break-loop 的**触发**变确定性；**分类与升级**仍由 LLM 完成（这正确地划分了机器与模型的分工）。

### P2.5 会话启动仪式
- SessionStart hook 利用规范能力（exit 0 stdout → 注入上下文）输出：
  当前 change、阶段、上次会话 journal 尾部、失效断言计数、smoke 状态。
- 对齐"每个新会话先读状态、先冒烟、不在坏地基上开工"；也缓解 compaction 后的状态失忆。
- 可选：PreCompact hook 注入 workflow-state 摘要，保护压缩后的关键状态。

---

## Phase 3 — 减重与反过度脚手架（与 Phase 2 并行，持续性工作）

**目标：对齐 bitter lesson——每个 gate 都是"模型做不到"的假设，需要度量与退役机制。**

### P3.1 risk-tier 升级为全流程路由器
- 现有 `risk-tier.js`（只裁剪验证域）扩展为流程裁剪：
  - **light lane**（文档、单文件低风险 fix）：跳过 prototype、双审合一、二域验证（static + unit）；
  - **standard / full lane**：现行为。
- 分层判据保持确定性（路径触发器已存在）；防博弈：同一 change 累计 diff 超阈值自动升 tier。
- 这是采用阻力的最大解药——现成杠杆，拉满即可。

### P3.2 Skill 层规范化审计
- 全部 120 个 SKILL.md 过一遍规范检查表：
  - body ≤ 500 行，超出部分移入 `references/`（progressive disclosure，按需加载）；
  - `description` + `when_to_use` ≤ 1536 字符且首句写触发场景（决定自动调用命中率）;
  - 危险动作 skill（archive、release、override）加 `disable-model-invocation: true`（仅用户可触发）；
  - 补 `allowed-tools`，减少权限弹窗；评估 `paths` 字段做文件范围自动加载。
- 用官方 skill-creator 的 eval 流程给核心 skill（requirements、fix、break-loop）建基线评测：
  同一 prompt 有/无 skill 对照，度量指令遵循率——首次让"35% 提示层约束"变得可测。

### P3.3 Scaffold 有效性度量（hill-climbing loop）
- 新工具 `scripts/gate-effectiveness.js`：聚合 events.jsonl →
  每个 gate 的触发频率、误杀率代理（触发后 override 率）、放行后下游 red 率。
- 决策规则：override 率高的 gate 是错的 gate（改判据或降级为 warn）；
  从不触发的 gate 是死重（候选退役）。
- 制度化：每次主模型版本升级后跑一次报告，作为 scaffold 退役评审的输入——
  "行为性 workaround 随模型升级清理，验证器与状态产物保留"。

### P3.4 新 hook 事件的克制采用
- 值得用：`Stop`（turn 结束时检查未落账的 ledger 写入，可 block 续跑）、
  `PostToolUseFailure`（失败分类直接入 blocker-classification）。
- 明确不用：agent-type hooks（官方标注 experimental）、
  `UserPromptSubmit` 全量注入 affordances（上下文税，SessionStart + 按需 status 足够）。

---

## Phase 4 — 结构性重构（1–2 月，= 路线图 C10，在 Phase 0-2 稳定后启动）

**目标：消除 44 文件跨仓复制税，为内核质量加固创造条件。**

### P4.1 Kernel 抽取
- monorepo：`packages/specnav-kernel`（状态机、契约、guard、affordances、lib，约 14K 行）
  + 每宿主薄适配层（Claude / Codex 各约当前 17 个白名单分歧文件的体量）。
- 迁移期用官方 marketplace `renames` 字段（≥v2.1.193）平滑改名；
  `git-subdir` source 支持 monorepo 内插件分发，无需破坏"从仓库安装"模式。
- kernel 引入 TypeScript + 单测（当前单测仅覆盖 specnav-lib 一个文件 19 用例，重构安全网过薄）。
- 完成后整体退役 `run-core-drift-check.sh` + `shared-core-manifest.json`。

### P4.2 插件间依赖声明
- `plugin.json` 的 `dependencies` 字段 2026 年中仍不稳定（官方 issue 未关）——
  暂不采用；在各插件 README + doctor 检查中显式声明共装要求（现状已有 `missing-plugin:<name>`，保留）。
- `defaultEnabled` 补齐；核心插件 `strict: true` 统一。

### P4.3 Codex 侧决策点（前置条件，非工作项）
- 在 P4.1 动工前回答：Codex 侧三个月内是否投产？
  否 → 冻结 codex 仓（archive + 保留设计文档），kernel 抽取只服务单宿主，成本减半；
  是 → kernel 抽取必须先行，绝不在双仓复制模式下继续加功能。

---

## Phase 5 — 知识回流（可选，Phase 1-3 落地后再评估）

- archive 时提炼：break-loop 失败分类聚合、requirements 决策先例、验证 red 热点
  → `openspec/knowledge/`，requirements/verify skill 以 advisory（非 gate）身份注入。
- 明确标注为建议层并带 TTL 与证据引用——与"无状态可复现"哲学的张力用
  "knowledge 永不参与门禁判定"来化解。
- 机器本地跨项目沉淀可用 `${CLAUDE_PLUGIN_DATA}`（官方持久目录，插件更新后保留）。

---

## 反清单：明确不做的事

1. **不加新的强制阶段或第七验证域** —— 在 P3.3 度量证明现有 gate 有效性之前，冻结门禁扩张。
2. **不在门禁判定中引入 LLM judge** —— LLM 验证只做 advisory（P2.2 的 verifier 输出仍需
   deterministic contract 复核结构），"失败的构建是事实，观点只是起点"。
3. **不做 hook 内 spawn agent**（规范不支持）、不依赖 experimental agent hooks。
4. **不预加载知识/上下文** —— 一切走 progressive disclosure。
5. **不在 C10 之前给双仓加任何新共享文件**。

## 依赖与顺序

```
P0(地基) ──→ P1(证据执行化) ──→ P2(循环收敛)
   │                                 │
   └──→ P3(减重/度量, 并行) ←────────┘
                 │
        P4(kernel, 待 P0-P2 稳定 + Codex 决策)
                 │
        P5(知识回流, 可选)
```

## 每阶段完成判据（机器可查）

| 阶段 | 判据 |
| --- | --- |
| P0 | guard 自检 fixture 绿；`claude plugin validate` 入 CI 且绿；lock fixture 三分支绿 |
| P1 | 零测试场景 blocked；自报-only receipt = C；测试篡改被 guard 拦截（均有 fixture） |
| P2 | acceptance.json 断言冻结 fixture 绿；连续失败 3 次自动 loop-detected；最小重验集脚本对 fixture diff 输出正确域集 |
| P3 | 120 skill 全部过规范检查表；gate-effectiveness 报告可从 events.jsonl 生成；light lane 走通 lifecycle fixture |
| P4 | drift-check 退役；kernel 单测覆盖核心契约脚本；双仓 CI 简化为单仓 |
