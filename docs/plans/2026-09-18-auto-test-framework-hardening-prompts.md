# Plan-Orchestrate Result

**Plan**: `docs/plans/2026-09-18-auto-test-framework-hardening-plan.md`
**Lang (orchestrate reviewer)**: `flutter`
**System under test**: `Flutter/Dart + Erlang/OTP + Cowboy`
**Harness implementation**: `Python stdlib + shell`
**ECC mode**: `plugin`
**Steps**: 15
**Scope**: `all-pages-all-functions + deep-domain`

> 严格按 Step 依赖 DAG 和 Wave 执行；同一 Wave 中资源与文件租约不冲突的任务必须并行。框架先可信化，再用源码白盒发现和 Android 真机/macOS 黑盒操作模拟人工测试员，把每个可达页面的每个用户可见功能至少执行一次；E2EE 与企业协作领域追加多角色、安全和恢复验收。
> 为节省 Token，确定性脚本负责发现、核销、续跑和汇总；AI 只处理无法静态判定的入口、首个失败根因和语义审查，不重复阅读 PASS 日志。

## 单个 ZCODE 会话（推荐）

将下面整段作为一个全新 ZCODE 会话的首条消息。它会自行按 15 步执行，不需要再逐条粘贴后文命令。

```text
你是本任务的唯一 Coordinator 和执行者。工作目录固定为 /Users/leeyi/project/imboy.pub/imboyapp，计划唯一真源是 docs/plans/2026-09-18-auto-test-framework-hardening-plan.md。被测系统是 Flutter/Dart 客户端 + ../imboy 的 Erlang/OTP/Cowboy 后端；Python stdlib + shell 只是测试调度、结果判定和证据归档控制面。

目标：在一个 ZCODE 会话内按计划的 Step 依赖 DAG/Wave 执行完 Step 1 -> Step 15；ready 且租约不冲突的工作必须并行，不为形式而串行。执行期不向用户提问、不等待确认；基于当前条件做安全范围内的最优覆盖，缺条件或未授权动作只 BLOCKED 相关项并继续。允许按需重构全部 auto-test 资产但不得修改 Flutter/Erlang 产品行为；在 Android 真机/macOS 从真实入口逐页执行可见功能等价类，并深测 E2EE、Enterprise/Organization、Workspace、Group、Channel、Moment、Project。整个会话只交付一个 HTML 报告文档。

会话结束时只回复 `test-report.html` 的绝对路径和 Overall verdict，不另写第二份测试总结；所有细节只在该 HTML 中。

启动时：
1. 完整读取计划及适用的AGENTS.md/CLAUDE.md，确认App与Backend是独立Git根；记录两仓HEAD、branch、dirty/untracked、staged/unstaged binary diff及untracked文件SHA-256和已有协调器。既有改动视为他人所有，不reset/clean/stash/restore，不覆盖或吸收无关diff；后续用基线哈希证明字节不变。
2. 创建或恢复唯一RUN_ROOT=test/auto_test/reports/hardening-<UTC>；有效且原Coordinator不活跃才续跑。不匹配或已有active Coordinator时不得接管/建worker/写仓库；创建独立只读blocked RUN_ROOT，采集HEAD/status与协调器摘要，用renderer或stdlib html.escape固定模板生成唯一最小HTML，Overall=BLOCKED、reason=BLOCKED_ACTIVE_COORDINATOR或BLOCKED_RUN_ROOT_MISMATCH后结束。正常run记录step/head/ID/命令/退出码/证据hash/verdict/commit且不写秘密或真实联系人。
3. 后端默认只读。只有 D2 全部成立时才允许本地隔离 fixture 写入：解析后的 API/WS 地址全部是 127.0.0.0/8、::1 或本机 Unix socket，Backend HEAD/profile 可验证、专用账号归属已确认、数据带本 run marker 且可定向销毁；private/dev 标签不构成本机授权。不得自行启停节点、迁移数据库、改 Erlang/Cowboy 产品代码或访问远程/生产环境。

每个 Step 使用同一闭环：
1. 只读取当前 Step、依赖、拥有文件、Acceptance 和 Out of scope；先由 rg/find/stdlib 生成集合差与摘要，再读取直接相关源码。Step 1 仅可新增匿名夹具和证据；只读 Step 无 diff 时记录 NO_COMMIT_READ_ONLY，不创建空提交。
2. 写步骤先建立最小失败测试，再做根因级最小修改；复用已有 helper、Flutter machine events 和 Python stdlib，不新增第三方依赖，不修改 Flutter/Erlang 产品功能或现有业务断言。
3. 执行当前 Acceptance，记录命令、退出码、摘要、证据路径和 SHA-256。0 executed、skip、TODO、skeleton、截图但无 oracle、历史报告或 exit 0 均不得冒充 PASS。
4. 独立审查fail-closed、脱敏、兼容性和范围。worker不commit；Coordinator持GIT_COMMIT lease后只提交单Step精确路径，再在该commit HEAD重跑Acceptance；不用git add -A，不push。状态分三层：scheduler WAITING/READY/RUNNING/DONE/INTERRUPTED，target PASS/PASS_WITH_SKIPS/FLAKY/BLOCKED/FAIL/PLANNED，scope PASS/PARTIAL/BLOCKED。H依赖要求Acceptance PASS，S依赖只要求终态并精确传播受影响shard；Step15始终执行。

并发调度：任一时刻含Coordinator最多8个active agent，即最多7个worker；累计创建数不限。coordinator.json记录agent_id/step/status/lease，创建前断言ACTIVE worker<7；只有Coordinator创建agent，每个ready Step默认一个primary worker，审查角色复用或随后串行；下方Chain仅供单步调试，禁止并行启动完整Chain。Step2/3/4按精确owned-path并行，不改CLI、公共入口/类型/helper，Step5唯一集成；Step10/12 App并行，Backend持BACKEND_EXEC串行；Step14冻结源码后Android/macOS各一只读worker。lease以RUN_ROOT/leases原子mkdir获取并记录owner/进程/heartbeat；超时不自动抢占，确认owner和设备进程停止、核对fixture写入后才接管。

设备与安全门：D1授权Step11/13/14使用当次可见Android真机和本机macOS；D2仅授权已验证的本地隔离、专用账号、可销毁run-marker数据。H1其他设备、H2远程/后端变更、H3第三方影响、H4截图上传、H5基线替换、H6发布均未授权。命中门时不询问：停止该动作、记录BLOCKED与安全替代，继续独立shard；不得用真实用户/联系人、通知第三方、真实支付、push或部署。

全量核销规则：tracked inventory/domain只保存required/excluded声明，不保存运行PASS；本轮结果写RUN_ROOT。每个function_id含page/entry/control/action/oracle/platform/requirement/fixture/target，Android与macOS每个适用项本轮恰有一次结果。A/local-write缓存仅限当前RUN_ROOT续跑，并绑定HEAD/tree/dependency、环境、设备状态、fixture namespace/marker/generation和账号匿名指纹；任一变化即失效。AI只读计数/hash和异常包，不重读PASS日志。

Step15在最终HEAD双跑gate并执行inventory/domain --check；B/C祖先证据只可经closure compatibility rebind，A/E2EE真客户端/local-write必须最终两仓HEAD。无论上游结果均生成唯一面向用户文档RUN_ROOT/test-report.html，不生成第二份总结。HTML离线自包含，含两仓基线、pilot/耗时、Step/Acceptance证据、精确计数、八域及Overall、FAIL/FLAKY/BLOCKED/NEW_ENTRY和待决策项；只允许PASS/PARTIAL/BLOCKED且不得含秘密/真实联系人/截图二进制。
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
| 8 | 框架当前 HEAD 验收 | test, review | `ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:code-reviewer` |
| 9 | 全页面功能清单、领域矩阵和隔离夹具 | plan, test, review | `ecc:planner,ecc:architect,ecc:e2e-runner,ecc:code-reviewer` |
| 10 | E2EE App/Backend 确定性安全门 | test, security | `ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:security-reviewer` |
| 11 | Android/macOS E2EE 真客户端验收 | test, security, device | `ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:security-reviewer` |
| 12 | Enterprise/Organization 合同与租户边界 | test, security | `ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:security-reviewer` |
| 13 | Workspace/Group 真机多角色验收 | test, security, device | `ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:security-reviewer` |
| 14 | 全页面一次遍历与 Channel/Moment/Project 深测 | test, device | `ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:security-reviewer` |
| 15 | 当前 HEAD 总收口 | test, review | `ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:code-reviewer` |

---

## Step 1 - 当前事实、夹具和边界基线

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:code-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-1] 只读核对两仓HEAD/dirty及资产计数，用git diff --binary、cached diff和untracked逐文件SHA建基线；新增五类匿名machine-event夹具，并冻结config/result/requirements最小接口草图，不建共享实现、不启动Flutter/设备/后端/网络。Acceptance: ATF-001 基线与集合差完整；ATF-002 stdlib可解析且无秘密；ATF-003 进程/套接字探测无外部动作。Out of scope: 修框架、改产品、更新历史结论。"
```

## Step 2 - 截图采集和目标配置修复

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:security-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-2] Wave1并行分支，只写capture/target-config新模块、截图脚本及其stdlib测试，不改scripts/auto_test.py。先复现成功截图未定义变量与父子目标漂移，再统一最终APP/API/WS配置；preflight验证实际子进程目标，日志脱敏，远程或缺条件启动前BLOCKED。Acceptance: ATF-101 双checkpoint；ATF-102 配置一致且错配关闭；ATF-103 远程/缺设备/凭证不启动。Out of scope: 真机截图、视觉基线、业务断言。"
```

## Step 3 - 结构化结果和唯一 target

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-3] Wave1只写runner/result/report与stdlib测试。解析真实脱敏+合成events；0 executed/oracle_count<1非PASS，result JSON含status/reason/counts，target去重。验证INFRA_FAIL->PASS为FLAKY、三次infra为BLOCKED、业务FAIL零重试、指纹变化新序列；实现唯一HTML renderer。Acceptance: ATF-201 全SKIP关闭；ATF-202 重试/退出码正确；ATF-203 target一次且冲突拒绝；ATF-204 HTML转义脱敏、稳定且无第二报告。Out of scope: 设备、业务断言。"
```

## Step 4 - requirements 与外部影响门

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:flutter-reviewer,ecc:security-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-4] Wave1并行分支，只写schema/policy/迁移新模块、fixtures与stdlib测试，不改CLI/公共helper或批量spec。requires/risk用有限枚举且preflight先于子进程；local-write只准解析后全为127/8、::1或本机Unix socket，private/dev标签不授权，external-impact永远BLOCKED。Acceptance: ATF-301 未知值关闭；ATF-302 非loopback/远程写不自动执行；ATF-303 迁移无放权。Out of scope: 账号、联系方式、第三方影响。"
```

## Step 5 - catalog、双向发现和 impact

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-5] H:2/3/4 Acceptance全PASS后由唯一CONTROL_ENTRY writer接入CLI并迁移spec；catalog双向扫描integration_test、lib/page、modules presentation与路由。排除码只准PLATFORM_NA/FEATURE_DISABLED/UNREACHABLE_DEAD_CODE/DUPLICATE_EQUIVALENCE，环境/TODO/skip不得排除；生成支持--check。Acceptance: ATF-401 测试全收录；ATF-402 页面/路由差集0；ATF-403 重复生成字节一致。Out of scope: 补页面E2E、改产品。"
```

## Step 6 - 状态、证据和缓存迁移

```bash
/ecc:orchestrate custom "ecc:architect,ecc:refactor-cleaner,ecc:tdd-guide,ecc:flutter-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-6] 运行态只写ignored RUN_ROOT。精确cache绑定两仓HEAD及target/runner/config/closure/环境；HEAD变即miss。仅B/C证据允许完整hash相同时compatibility rebind；A/E2EE/local-write必须最终HEAD且绑定RUN_ID、fixture、账号、设备状态。Acceptance: ATF-501 fresh clone可计划；ATF-502 cache/rebind正负闭环；ATF-503 拒绝秘密、非法NA/降级等级、缺hash及空/损坏lease。Out of scope: 删除旧证据或沿用过期PASS。"
```

## Step 7 - CI 和统一自动验收入口

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:build-error-resolver,ecc:flutter-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-7] 建立本地/CI唯一无设备gate，运行tooling tests、strict validate、catalog/generated --check、脱敏、py_compile与diff check；run_test_suite复用它，旧run_all_integration_tests改兼容壳或退役，删除固定设备/生产URL/账号与关键词判PASS。Acceptance: ATF-601 双跑零diff；ATF-602 缺页/未知requirement/全SKIP/冲突/秘密注入均失败；ATF-603 CI与本地同入口。Out of scope: 真机、远程、发布。"
```

## Step 8 - 框架当前 HEAD 验收

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:code-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-8] 只读收口当前HEAD：统一gate双跑、P0 plan、diff/status，审计SKIP、目标、catalog、fresh-clone、脱敏与旧入口；只可修本计划回归。Acceptance: ATF-701 所有旧ID有命令/证据；ATF-702 本任务diff/commit仅含owned files，启动前无关dirty字节不变且无秘密产物；ATF-703 只报PASS/PARTIAL/BLOCKED，框架PASS不冒充产品PASS。Out of scope: 真机、远程、发布；无diff记NO_COMMIT_READ_ONLY。"
```

## Step 9 - 全页面功能清单、领域矩阵和隔离夹具

```bash
/ecc:orchestrate custom "ecc:planner,ecc:architect,ecc:e2e-runner,ecc:code-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-9] 从路由、页面、台账、manifest和测试生成静态inventory/domain；固定排除码和最低证据等级，运行时未知入口记NEW_ENTRY。定义至少6个匿名账号别名及独立shard fixture；生成零交互preflight，把route drift、Backend、D2缺口映射为局部BLOCKED后继续。Acceptance: DOM-001 静态差集0且有NEW_ENTRY回填；DOM-002 启用能力完整、TODO/skip仅进RUN_ROOT；DOM-003 多角色fixture无秘密。Out of scope: 真实数据、产品代码、等待用户输入。"
```

## Step 10 - E2EE App/Backend 确定性安全门

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:security-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-10] App侧可与Step12并行；Backend命令统一持BACKEND_EXEC后才跑run_e2ee_suite、make e2ee-verify及PG模块。验证明文降级、错身份/设备/签名、replay/tamper、C2C/C2G边界、room-key、附件/恢复、群历史、日志均关闭。Acceptance: E2EE-001 当前两仓实跑0skip；E2EE-002 安全负向通过；E2EE-003 未执行/TODO/D级逐capability BLOCKED且不阻断无关shard。Out of scope: 产品逻辑、启停迁移、真实数据。"
```

## Step 11 - Android/macOS E2EE 真客户端验收

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:security-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-11] 用flutter devices当次Android ID和macOS先跑两条跨端E2EE互操作；勿用默认ID。仅在D2全部满足时执行双向C2C/C2G真聊天、重启重进及UI/WS/ACK/本地持久化/后端密文交叉取证，否则精确BLOCKED。Acceptance: E2EE-101 离线Olm/Megolm互操作0skip；E2EE-102 隔离真聊天通过或前置阻断；E2EE-103 设备证据脱敏且不外传。Out of scope: iOS、远程后端、未确认账号、修缺陷。"
```

## Step 12 - Enterprise/Organization 合同与租户边界

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:security-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-12] App侧organization/enterprise/customer_service及workspace/group合同可与Step10并行；Backend scoped EUnit及../imboy/scripts/enterprise_business_feature_matrix.sh、customer_service_feature_matrix.sh统一持BACKEND_EXEC串行。Acceptance: ENT-001 两仓B/C与租户负向实跑；ENT-002 owner/default workspace/成员生命周期/消息资产CS/停用保留有断言或逐项BLOCKED；ENT-003 跨租户、非成员、降权token、归档暂停关闭，skip不假绿。Out of scope: 产品代码、迁移。"
```

## Step 13 - Workspace/Group 真机多角色验收

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:security-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-13] 仅在D2满足时，用Android真机/macOS模拟owner/admin/member/nonmember：登录、Personal/Workspace切换、org/workspace选择、跨A/B租户边界及Group创建/加入/移除/转让/禁言/E2EE/notice/task/vote/schedule/file/album/tag/category；只清理run marker数据。Acceptance: WG-001 两端导航与重启无skip；WG-002 角色/IDOR有UI+API证据；WG-003 Group能力执行或具体BLOCKED。Out of scope: 远程租户、真实联系人、不可逆清理、修缺陷。"
```

## Step 14 - 全页面一次遍历与 Channel/Moment/Project 深测

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:security-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-14] PhaseA冻结后双平台跑20页pilot，独立fixture且同正式oracle；每平台至少30个duration样本，结果计入覆盖并从PhaseB排除。PhaseB平台fixture隔离，跨端单worker持双设备。首次NEW_ENTRY暂停全部worker，集中修复提交后清空并重跑全部A/local-write；freeze-v2后新缺口只BLOCKED不提交。infra重试≤2且通过仍FLAKY。Acceptance: FULL-001、FULL-002、FULL-003守恒可续跑；CPM-001、CPM-002、CPM-003逐项裁决。Out of scope: 远程、真实支付/通知、产品修复。"
```

## Step 15 - 当前 HEAD 总收口

```bash
/ecc:orchestrate custom "ecc:tdd-guide,ecc:e2e-runner,ecc:flutter-reviewer,ecc:code-reviewer" "[Plan: docs/plans/2026-09-18-auto-test-framework-hardening-plan.md#step-15] 无论上游结果始终执行：最终HEAD gate双跑、inventory/domain --check；B/C仅经closure rebind，A/E2EE/local-write必须最终HEAD。只生成RUN_ROOT/test-report.html，不生成第二份总结；离线单文件含两仓基线、pilot/耗时、15步/Acceptance、精确计数、八域/Overall、FAIL/FLAKY/BLOCKED/NEW_ENTRY及待决策项。Acceptance: FINAL-001 current-HEAD证据；FINAL-002 无假绿；FINAL-003 diff/秘密/push检查；FINAL-004 HTML转义脱敏、证据一致、重复字节相同。Out of scope: 修产品、远程/发布。"
```
