# Plan-Orchestrate Result

**Plan**: `docs/plans/2026-09-18-auto-test-framework-hardening-plan.md`
**Lang (orchestrate reviewer)**: `flutter`
**System under test**: `Flutter/Dart + Erlang/OTP + Cowboy`
**Harness implementation**: `Python stdlib + shell`
**ECC mode**: `plugin`
**Steps**: 8
**Scope**: `all`

> 严格按 Step 1 -> Step 8 串行执行。每步 PASS、本地提交并核对证据后才能启动下一步；不 push。
> 为节省 Token，首个 agent 读取计划对应 Step 和拥有文件，后续 agent 只读取 HANDOFF、diff、失败证据和必要源码。

## 单个 ZCODE 会话（推荐）

将下面整段作为一个全新 ZCODE 会话的首条消息。不需要再逐条粘贴后文的 8 条 `/ecc:orchestrate` 命令。

```text
你是本任务的唯一 Coordinator 和执行者。工作目录固定为 /Users/leeyi/project/imboy.pub/imboyapp，计划唯一真源是 docs/plans/2026-09-18-auto-test-framework-hardening-plan.md。被测系统是 Flutter/Dart 客户端 + ../imboy 的 Erlang/OTP/Cowboy 后端；测试控制面只用 Python stdlib + shell。

目标：在这一个会话内严格按 Step 1 -> Step 8 串行执行。不要让我逐步再粘贴提示词，也不要在安全的本地步骤之间等待确认。每步必须先通过该 Step 的 Acceptance IDs、产生可复现证据并做独立本地提交，然后才继续下一步。任一步 PARTIAL/BLOCKED/FAIL 都立即停止，不跳步，不把 BLOCKED/SKIP/PLANNED 当 PASS。

启动时：
1. 完整读取计划、当前及父级 AGENTS.md/CLAUDE.md，确认 git 根。分别记录 App HEAD/dirty state 和 Backend HEAD/dirty state；后端只读，不修改、启停、迁移或写数据。
2. 盘点已有改动并视为他人所有；不 reset/clean/stash/restore，不覆盖、不吸收无关 diff。如果与本计划拥有文件冲突且无法无损兼容，按停止条件报告。
3. 创建或恢复唯一 RUN_ROOT=test/auto_test/reports/hardening-<UTC>，保存 coordinator.json，只记录 step、base_sha、acceptance、command、exit_code、evidence path/hash、verdict、commit。恢复时继续原 RUN_ROOT，不另建一份运行状态。

每个 Step 使用同一个循环：
1. 只读取计划中当前 Step、其依赖、拥有边界、Acceptance 和 Out of scope；按需用 rg/find 定位直接调用者，不全仓重复扫描。Step 1 对现有 App/Backend 实现只读，仅可新增匿名 machine-event 夹具和基线证据。
2. 先写或确认能失败的最小测试，再做根因级最小修复；优先复用已有 helper、Flutter machine events 和 Python stdlib，不新增第三方依赖，不修改 Flutter 产品业务逻辑或现有集成测试业务断言。
3. 运行当前 Step 的定向测试和所有对应 Acceptance；记录完整命令、退出码、摘要、证据路径及 SHA-256。无执行证据不得 PASS。
4. 审查 diff 的正确性、fail-closed、脱敏、兼容性和范围。只 stage 当前 Step 拥有文件，使用 leeyi <leeyisoft@qq.com> 作者/提交者创建独立本地提交；不使用 git add -A，不 push。
5. 按计划第 12 节写入简短交付记录，更新 coordinator.json。只有 verdict=PASS 才继续下一 Step。

强制人工门：H1_DEVICE、H2_REMOTE、H2_BACKEND_MUTATION、H3_EXTERNAL_IMPACT、H4_VISUAL_UPLOAD、H5_BASELINE_REPLACE、H6_RELEASE 全部未授权。不操作真实设备，不访问远程/生产后端，不使用真实账号、联系方式或用户数据，不联系或影响第三方，不上传截图，不替换基线，不 push/发布/部署。命中人工门时，输出门 ID、阻断原因、需要的用户输入和下一条安全命令，然后停止；不用环境变量、旧对话或历史 PASS 代替本轮授权。

Token 约束：不读全量页面台账、完整 task_state 或历史 reports；先用确定性脚本生成集合差和摘要。PASS 不进行 AI 重分析。失败时最多读取 6 个直接相关源文件、120 行日志、最近一次 PASS 摘要和本次 diff；先报首个可复现根因，不粘贴完整日志。

Step 8 必须在当前 HEAD 上将统一 gate 连续运行两次，两次都退出 0，第二次不得产生 diff。最终输出：App/Backend HEAD、Step 1-8 verdict/提交、ATF-001..ATF-703 证据索引、双跑 gate 退出码、dirty/untracked 归属、未执行的设备/远程/视觉/外部验收，以及总结论 PASS/PARTIAL/BLOCKED。未执行外部验收时，不得声称产品 E2E PASS。
```

## Steps overview

| # | Title | Tags | Chain |
|---|---|---|---|
| 1 | 当前事实、夹具和边界基线 | test, review | `ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:code-reviewer` |
| 2 | 截图采集和目标配置修复 | impl, test, security | `ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:security-reviewer` |
| 3 | 结构化结果和唯一 target | impl, test | `ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer` |
| 4 | requirements 与外部影响门 | impl, security | `ecc:tdd-guide,ecc:flutter-reviewer,ecc:security-reviewer` |
| 5 | catalog、双向发现和 impact | impl, test | `ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer` |
| 6 | 状态、证据和缓存迁移 | refactor, migration | `ecc:architect,ecc:refactor-cleaner,ecc:tdd-guide,ecc:flutter-reviewer` |
| 7 | CI 和统一自动验收入口 | impl, test, build | `ecc:tdd-guide,ecc:e2e-runner,ecc:build-error-resolver,ecc:flutter-reviewer` |
| 8 | 当前 HEAD 最终验收 | test, review | `ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:code-reviewer` |

---

## Step 1 - 当前事实、夹具和边界基线

**Intent**: 对现有实现只读地冻结当前资产和缺陷基线，仅新增不含凭证的 machine-event 夹具与证据；不启动设备、Flutter 测试或网络。
**Tags**: test, review
**Chain rationale**: `tdd-guide` 约束夹具可验证性，`e2e-runner` 校验事件语义，Flutter 与通用 reviewer 复核当前事实和边界。

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:code-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-1] 在 /Users/leeyi/project/imboy.pub/imboyapp 执行 Step 1：只读核对 App 与 ../imboy 后端的 AGENTS/CLAUDE、HEAD、dirty state，统计25 specs及 integration/page/ledger 漂移；仅新增五类匿名 flutter machine-event 夹具与基线证据，不启动 Flutter、设备、Erlang 节点或网络。保留并行改动。Acceptance: ATF-001 两仓事实完整；ATF-002 夹具可由 stdlib 解析且无凭证；ATF-003 外部动作未执行。Out of scope: 修框架、改 App/Backend 产品代码、更新台账状态。"
```

## Step 2 - 截图采集和目标配置修复

**Intent**: 用最小 TDD 修复截图成功路径和父子进程目标配置漂移，并复核外部目标安全门。
**Tags**: impl, test, security
**Chain rationale**: TDD 先固定两个已知回归；`e2e-runner` 检查采集行为；Flutter reviewer 检查命令构造；security reviewer 关闭目标绕过风险。

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:security-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-2] 串行执行 Step 2；仅拥有 capture 脚本、auto_test capture/命令构造代码及其 stdlib 测试。先用 mock 复现成功截图后的未定义变量和父子目标漂移，再做最小修复；run/capture 必须共享最终 APP/API/WS 配置，日志不得泄露凭证，远程/缺条件须在启动子进程前 BLOCKED。Acceptance: ATF-101 双 checkpoint 成功；ATF-102 父子目标一致且错配 fail closed；ATF-103 远程/缺设备/缺凭证不启动进程。Out of scope: 真机、视觉基线、Flutter 业务测试。"
```

## Step 3 - 结构化结果和唯一 target

**Intent**: 以 Flutter machine events 代替退出码判定，并把执行粒度收敛到唯一 target。
**Tags**: impl, test
**Chain rationale**: `tdd-guide` 固定状态矩阵，`e2e-runner` 验证 runner 行为，Flutter reviewer 复核实现和兼容性。

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-3] 串行执行 Step 3；用 Step 1 machine-event 夹具先写失败测试，再让 runner 解析 flutter test --machine，输出 PASS/PASS_WITH_SKIPS/BLOCKED/FAIL/PLANNED，0 executed 不得 PASS；按 target 去重执行，case 只映射结果，冲突风险或关键 requirements 使 validate 返回 64，render-report 返回对应退出码。Acceptance: ATF-201 全 SKIP 非 PASS；ATF-202 混合 skip 退出2且 FAIL 退出1；ATF-203 重复 target 只执行一次且冲突被拒。Out of scope: 改写现有集成测试业务断言。"
```

## Step 4 - requirements 与外部影响门

**Intent**: 把说明性 requirements 变成 fail-closed 的类型化 preflight，并禁止通用 runner 自动执行外部影响动作。
**Tags**: impl, security
**Chain rationale**: TDD 覆盖每个门的正负路径，Flutter reviewer 检查 runner 集成，security reviewer 对外部影响和权限放大做终审。

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:flutter-reviewer,ecc:security-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-4] 串行执行 Step 4；把自由文本 requires/risk 收敛为计划列出的有限枚举和四类风险模式，preflight 在任何 Flutter/ADB/Patrol/网络子进程前完成。local-write 只允许明确本地目标；external-impact 通用 runner 永远 BLOCKED，allow env 不能代替用户本轮确认；迁移现有 specs 时不得扩大权限。Acceptance: ATF-301 requirements 正负测试齐全且未知值 fail closed；ATF-302 远程写不能自动执行；ATF-303 规格迁移无静默放权。Out of scope: 获取账号、使用联系方式或影响第三方。"
```

## Step 5 - catalog、双向发现和 impact

**Intent**: 建立唯一 target catalog，并用双向资产发现阻止页面、测试和映射静默漂移。
**Tags**: impl, test
**Chain rationale**: TDD 固定集合差和稳定生成，`e2e-runner` 检查测试资产语义，Flutter reviewer 审查 catalog 与现有入口兼容性。

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-5] 串行执行 Step 5；建立稳定排序的 test/auto_test/catalog.json，一条唯一 target 含 sources/dependencies/risk/requirements/tags，显式排除必须有 reason。双向扫描所有 integration_test/**/*_test.dart 和 lib/page/**/*_page.dart；catalog/覆盖生成支持只读 --check；impact 仅输出命中 target 加固定 smoke，未映射源码直接失败。Acceptance: ATF-401 当前测试全收录或排除；ATF-402 当前页面双向差集为0；ATF-403 重复生成字节一致且 --check 通过。Out of scope: 批量补 E2E 或改 155 份历史结论。"
```

## Step 6 - 状态、证据和缓存迁移

**Intent**: 在保留旧历史的同时拆出稳定状态、证据和缓存合同，消除对 ignored reports 的恢复依赖。
**Tags**: refactor, migration
**Chain rationale**: Architect 先守住数据边界，refactor cleaner 控制重复，TDD 验证迁移和缓存，Flutter reviewer 做最终实现审查。

```bash
/ecc:orchestrate custom "ecc:architect,ecc:refactor-cleaner,ecc:tdd-guide,ecc:flutter-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-6] 串行执行 Step 6；保留旧 task_state 内容但停止追加，新增最小 state/evidence schema 与本地运行态，fresh clone 从 catalog 生成完整 UNKNOWN 计划。缓存键绑定 App HEAD、Backend HEAD、target/dependency hash、API/WS/profile 指纹、设备和 fixture，任一变化必须 miss；schema 拒绝秘密和无证据 PASS。Acceptance: ATF-501 无旧报告仍可计划；ATF-502 App/Backend/环境缓存失效测试通过；ATF-503 schema、哈希和脱敏负向测试通过。Out of scope: 删除历史证据或继承旧 HEAD PASS。"
```

## Step 7 - CI 和统一自动验收入口

**Intent**: 让本地和 CI 复用一个无设备 gate，并用负向自检证明门禁不会假绿。
**Tags**: impl, test, build
**Chain rationale**: TDD 和 E2E runner 验证 gate；build resolver 处理 CI/脚本错误；Flutter reviewer 确保项目入口一致。

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:build-error-resolver,ecc:flutter-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-7] 串行执行 Step 7；新增 scripts/check_auto_test_framework.sh 作为本地与 CI 唯一无设备 gate，串行运行 Python tooling tests、strict validate、catalog/generated --check、脱敏负向测试、py_compile 和 git diff --check；run_test_suite.sh 复用该入口，不复制逻辑。连续运行两次必须稳定且零 diff，并用临时 fixture 验证缺页、未知 requirement、全 SKIP、target 冲突和凭证字段会失败。Acceptance: ATF-601、ATF-602、ATF-603 全部有退出码和证据。Out of scope: 真机、Patrol、远程后端和发布流程。"
```

## Step 8 - 当前 HEAD 最终验收

**Intent**: 在当前 HEAD 上独立复核全部自动门和证据边界，不执行被人工门保护的外部验收。
**Tags**: test, review
**Chain rationale**: TDD/E2E reviewer 复跑确定性门，Flutter reviewer 检查项目契约，通用 reviewer 最终核对证据和范围。

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:code-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-8] 在全部前置 Step 本地提交后只读收口当前 HEAD：运行统一 gate 两次、P0 plan、diff/status 检查，审计 help/退出码、SKIP 语义、最终目标一致性、catalog 双向覆盖、fresh-clone 计划、证据脱敏和旧入口兼容。只允许修复本计划引入的回归，不放宽 fail-closed。Acceptance: ATF-701 所有 ID 有命令/退出码/证据；ATF-702 仅任务拥有文件且无秘密/产物；ATF-703 结论为 PASS/PARTIAL/BLOCKED，未执行设备/远程/视觉不得称产品 E2E PASS。Out of scope: 真机验收、远程验收、发布和 push。"
```

## Batch execution

下面仅用于顺序粘贴；不得并发执行。任一步非 PASS 时停止，不执行后续命令。

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:code-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-1] 在 /Users/leeyi/project/imboy.pub/imboyapp 执行 Step 1：只读核对 App 与 ../imboy 后端的 AGENTS/CLAUDE、HEAD、dirty state，统计25 specs及 integration/page/ledger 漂移；仅新增五类匿名 flutter machine-event 夹具与基线证据，不启动 Flutter、设备、Erlang 节点或网络。保留并行改动。Acceptance: ATF-001 两仓事实完整；ATF-002 夹具可由 stdlib 解析且无凭证；ATF-003 外部动作未执行。Out of scope: 修框架、改 App/Backend 产品代码、更新台账状态。"
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:security-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-2] 串行执行 Step 2；仅拥有 capture 脚本、auto_test capture/命令构造代码及其 stdlib 测试。先用 mock 复现成功截图后的未定义变量和父子目标漂移，再做最小修复；run/capture 必须共享最终 APP/API/WS 配置，日志不得泄露凭证，远程/缺条件须在启动子进程前 BLOCKED。Acceptance: ATF-101 双 checkpoint 成功；ATF-102 父子目标一致且错配 fail closed；ATF-103 远程/缺设备/缺凭证不启动进程。Out of scope: 真机、视觉基线、Flutter 业务测试。"
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-3] 串行执行 Step 3；用 Step 1 machine-event 夹具先写失败测试，再让 runner 解析 flutter test --machine，输出 PASS/PASS_WITH_SKIPS/BLOCKED/FAIL/PLANNED，0 executed 不得 PASS；按 target 去重执行，case 只映射结果，冲突风险或关键 requirements 使 validate 返回 64，render-report 返回对应退出码。Acceptance: ATF-201 全 SKIP 非 PASS；ATF-202 混合 skip 退出2且 FAIL 退出1；ATF-203 重复 target 只执行一次且冲突被拒。Out of scope: 改写现有集成测试业务断言。"
/ecc:orchestrate custom "ecc:tdd-guide,ecc:flutter-reviewer,ecc:security-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-4] 串行执行 Step 4；把自由文本 requires/risk 收敛为计划列出的有限枚举和四类风险模式，preflight 在任何 Flutter/ADB/Patrol/网络子进程前完成。local-write 只允许明确本地目标；external-impact 通用 runner 永远 BLOCKED，allow env 不能代替用户本轮确认；迁移现有 specs 时不得扩大权限。Acceptance: ATF-301 requirements 正负测试齐全且未知值 fail closed；ATF-302 远程写不能自动执行；ATF-303 规格迁移无静默放权。Out of scope: 获取账号、使用联系方式或影响第三方。"
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-5] 串行执行 Step 5；建立稳定排序的 test/auto_test/catalog.json，一条唯一 target 含 sources/dependencies/risk/requirements/tags，显式排除必须有 reason。双向扫描所有 integration_test/**/*_test.dart 和 lib/page/**/*_page.dart；catalog/覆盖生成支持只读 --check；impact 仅输出命中 target 加固定 smoke，未映射源码直接失败。Acceptance: ATF-401 当前测试全收录或排除；ATF-402 当前页面双向差集为0；ATF-403 重复生成字节一致且 --check 通过。Out of scope: 批量补 E2E 或改 155 份历史结论。"
/ecc:orchestrate custom "ecc:architect,ecc:refactor-cleaner,ecc:tdd-guide,ecc:flutter-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-6] 串行执行 Step 6；保留旧 task_state 内容但停止追加，新增最小 state/evidence schema 与本地运行态，fresh clone 从 catalog 生成完整 UNKNOWN 计划。缓存键绑定 App HEAD、Backend HEAD、target/dependency hash、API/WS/profile 指纹、设备和 fixture，任一变化必须 miss；schema 拒绝秘密和无证据 PASS。Acceptance: ATF-501 无旧报告仍可计划；ATF-502 App/Backend/环境缓存失效测试通过；ATF-503 schema、哈希和脱敏负向测试通过。Out of scope: 删除历史证据或继承旧 HEAD PASS。"
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:build-error-resolver,ecc:flutter-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-7] 串行执行 Step 7；新增 scripts/check_auto_test_framework.sh 作为本地与 CI 唯一无设备 gate，串行运行 Python tooling tests、strict validate、catalog/generated --check、脱敏负向测试、py_compile 和 git diff --check；run_test_suite.sh 复用该入口，不复制逻辑。连续运行两次必须稳定且零 diff，并用临时 fixture 验证缺页、未知 requirement、全 SKIP、target 冲突和凭证字段会失败。Acceptance: ATF-601、ATF-602、ATF-603 全部有退出码和证据。Out of scope: 真机、Patrol、远程后端和发布流程。"
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:code-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-8] 在全部前置 Step 本地提交后只读收口当前 HEAD：运行统一 gate 两次、P0 plan、diff/status 检查，审计 help/退出码、SKIP 语义、最终目标一致性、catalog 双向覆盖、fresh-clone 计划、证据脱敏和旧入口兼容。只允许修复本计划引入的回归，不放宽 fail-closed。Acceptance: ATF-701 所有 ID 有命令/退出码/证据；ATF-702 仅任务拥有文件且无秘密/产物；ATF-703 结论为 PASS/PARTIAL/BLOCKED，未执行设备/远程/视觉不得称产品 E2E PASS。Out of scope: 真机验收、远程验收、发布和 push。"
```
