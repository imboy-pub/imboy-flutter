# IMBoy 企业客户端 UI/UX：可测试、可落地、可验收任务清单 V1.1

计划ID：`imboy-enterprise-uiux-v1`（沿用V1）｜状态：`READY_FOR_LOCAL_W0`。

**初始全部TODO，不是已运行报告。** 共51张卡：40张必需自动卡、9张原生平台人工卡、1张真实跨会话卡、1张可重复报告卡；5个Batch。JSON是任务结构真源，Markdown由同包工具生成；不得双写漂移。

关联：[PRD](PRD.md) · [测试合同](TEST_CONTRACT.md) · [续跑协议](RESUME_PROTOCOL.md) · [升级迁移](MIGRATION.md) · [验收清单](ACCEPTANCE.md) · [命令索引](COMMANDS.json)。

## 1. 范围与路径

只修改Flutter展示、局部纯展示组件、本地化及对应测试/文档。Backend/Admin仅必要时只读；不修改或运行后端/数据库，不抢占真机。API/DTO/Provider/Service/Domain、权限、feature、掩码、CAS/SSE/分页/SSO不变。既有修复先复验，不为产生代码diff重写。

源码路径从原研究提交定位，T01—T04按本机已提交HEAD复核；研究SHA不是固定执行基线。新增路径不代表当前已存在。`<生效locale>`、`@resolved/`在T04展开为逐文件清单；`@runtime/`和`@package/`分别是公共Git目录运行区与本发行包，不是源码目录通配授权。表中生产文件授权仅限“改哪个区块”列，不是整文件业务修改权。

每卡实施规模≤0.5人日，是任务切分上限，不是模型耗时承诺。达到上限仍未完成则拆子卡并登记范围/依赖/证据，不通过改状态强行收尾。已有完成任务可以test/docs-only；测试、实现与本任务提交一一映射。T29的结果文档提交只能在候选K门结束后产生，不把报告R当新代码已测。

## 2. Batch、并行度与结束标志

| Batch | 目标 | 工作流与资源约束 | 验收节点 |
|---|---|---|---|
| B0 冻结现场 | 无前置循环地完成发现/调查/路径/范围/锁/状态合同 | T00协调；T01/02/03只读并行写inbox；T04及.a/b/c由协调器串行接收；不并写index | M0：所有启动产物和实际正反例有记录；历史基线失败另列，不伪称零问题 |
| B1 建立输入 | 结构harness与本地化稳定；视觉字体独立 | T05/T06使用共享单写者；T07/08/09最多3lane；T05.a缺字体只阻塞视觉 | M1：真实夹具/文案可运行；字体能力单列 |
| B2 页面实施 | 消除当前实际缺口，保持业务行为 | P1/P2/P3最多3写lane；同页同文件串行；T13/T14不因T12的颜色阻塞而等待 | M2：本页定向断言和scope通过；每页可先进入B3 |
| B3 验证与视觉封存 | 结构/图像生成/审查分别记账，保留312配置 | 每页T22/23/24→.a→.b；T25—27调用回归不依赖golden；默认重型Flutter最多1进程 | M3：312配置计数、review、普通比较与回归证据齐全 |
| B4 最终与交接 | 同候选K门、原生平台卡、真实续跑、随时报告 | T28可前移到控制模块形成后；T29汇合；9原生卡受设备锁；T28.m独立；T33每批末/阻塞/暂停均可执行 | M4A自动通过；M4B原生通过；真实跨会话恢复独立状态 |

最多4活跃代理=3页面worker+1协调器。没有子代理能力则串行同一DAG。共享i18n/生成strings/harness/总状态/集成由协调器独写；P2独占cs_workspace_entry.dart入口外观，P3不得修改。Flutter锁按SDK真实路径/设备ID，不用各计划独立锁假装跨计划互斥。

## 3. 依赖图与最短并行落地路径

```text
T00 → (T01 || T02 || T03) → T04
T04 → T04.a(scope)                          ┐
T04 → T04.b(lock) → T04.c(state)             │
T04 → T05(structure)                        ├→ T07 / T08 / T09各页夹具
T04 → T06(i18n)                             ┘
T05 → T05.a(font) ─────────────────────────────→ 各页视觉/真实文字几何门

P1: T07 → T10 → T11 → T12 ┐
          ├→ T13         ├→ T22 → T22.a → T22.b ┐
          └→ T14 → T15   ┴→ T25               │
P2: T08 → T16 → T17 → T18 → T23 → T23.a → T23.b ├→ T29(K最终门)
                         └→ T26               │
P3: T09 → T19 → T20 → T21 → T24 → T24.a → T24.b ┤
                         └→ T27               │
T04.a + T04.c → T28(实际模块故障套件) ───────────┘
T28 + T04.c → T28.m(真实新会话；非自动门前置)
T29 → T30/30.a/30.b、T31/31.a/31.b、T32/32.a/32.b
T00 → T33(任意成功/失败/阻塞都可重复报告)
```

图示用于阅读，完整依赖以各卡与JSON为准；T22/23/24均额外依赖T05.a。主要候选关键链是P1实现→结构→golden→最终门，现场字体/设备会改变实际瓶颈，不能仅用任务编号当排期。

**最先可做：**T00完成后并行三页只读调查；T04后scope、锁/状态、结构、本地化各有明确产物；共同输入与guards稳定后开三页面原lane。视觉环境阻塞不阻塞T25—27；共享文件冲突由mutex调度，不额外伪造业务依赖。

## 4. 执行任务索引

| ID | Batch / lane | 名称 | 上限人日 | 依赖 | 类型 |
|---|---|---|---:|---|---|
| T00 | B0 / COORD | 登记现场与原始工作树 | 0.50 | 无 | bootstrap |
| T01 | B0 / P1 | 核验频道现状与调用入口 | 0.25 | T00 | inventory |
| T02 | B0 / P2 | 核验工作台入口与免登边界 | 0.25 | T00 | inventory |
| T03 | B0 / P3 | 核验坐席字段与隐私口径 | 0.25 | T00 | inventory |
| T04 | B0 / COORD | 冻结路径、命令和能力清单 | 0.50 | T01, T02, T03 | contract |
| T04.a | B0 / COORD | 建立范围与禁止符号门 | 0.50 | T04 | verification |
| T04.b | B0 / COORD | 建立进程身份与短事务锁 | 0.50 | T04 | verification |
| T04.c | B0 / COORD | 建立持久化事务与状态校验 | 0.50 | T04.b | verification |
| T05 | B1 / COORD | 建立不依赖视觉字体的结构夹具框架 | 0.50 | T04 | verification |
| T05.a | B1 / COORD | 冻结视觉字体与栅格环境 | 0.50 | T05 | verification |
| T06 | B1 / COORD | 冻结并生成本地化展示文案 | 0.50 | T04 | verification |
| T07 | B1 / P1 | 建立频道真实路由夹具 | 0.50 | T05, T06, T04.a, T04.c | verification |
| T08 | B1 / P2 | 建立工作台入口夹具 | 0.50 | T05, T06, T04.a, T04.c | verification |
| T09 | B1 / P3 | 建立坐席三态字段夹具 | 0.50 | T05, T06, T04.a, T04.c | verification |
| T10 | B2 / P1 | 收敛频道身份头部 | 0.50 | T07 | implementation |
| T11 | B2 / P1 | 验证统计非加载占位 | 0.25 | T10 | implementation |
| T12 | B2 / P1 | 区分频道动作可用状态 | 0.50 | T11 | implementation |
| T13 | B2 / P1 | 统一讨论横幅方向指示 | 0.25 | T07 | implementation |
| T14 | B2 / P1 | 折叠频道高级筛选 | 0.50 | T07 | implementation |
| T15 | B2 / P1 | 补齐错误空态与日期装饰 | 0.50 | T14 | implementation |
| T16 | B2 / P2 | 统一工作台分组容器 | 0.50 | T08 | implementation |
| T17 | B2 / P2 | 复验办公删除与地址隐藏 | 0.25 | T16 | implementation |
| T18 | B2 / P2 | 对齐资源入口图标与文本 | 0.50 | T17 | implementation |
| T19 | B2 / P3 | 提取会话行共用信息布局 | 0.50 | T09 | implementation |
| T20 | B2 / P3 | 统一安全摘要与缺失回退 | 0.25 | T19 | implementation |
| T21 | B2 / P3 | 转换可读来源并隐藏原枚举 | 0.50 | T20 | implementation |
| T22 | B3 / P1 | 验证P1结构矩阵与无障碍 | 0.50 | T10, T11, T12, T13, T15, T05.a | verification |
| T22.a | B3 / P1 | 生成P1候选golden与差异包 | 0.50 | T22 | verification |
| T22.b | B3 / P1 | 审查并封存P1视觉基线 | 0.50 | T22.a | visual_review |
| T23 | B3 / P2 | 验证P2结构矩阵与无障碍 | 0.50 | T18, T05.a | verification |
| T23.a | B3 / P2 | 生成P2候选golden与差异包 | 0.50 | T23 | verification |
| T23.b | B3 / P2 | 审查并封存P2视觉基线 | 0.50 | T23.a | visual_review |
| T24 | B3 / P3 | 验证P3结构矩阵与无障碍 | 0.50 | T21, T05.a | verification |
| T24.a | B3 / P3 | 生成P3候选golden与差异包 | 0.50 | T24 | verification |
| T24.b | B3 / P3 | 审查并封存P3视觉基线 | 0.50 | T24.a | visual_review |
| T25 | B3 / P1 | 回归频道原业务调用 | 0.50 | T10, T11, T12, T13, T15 | verification |
| T26 | B3 / P2 | 回归工作台权限与免登调用 | 0.50 | T18 | verification |
| T27 | B3 / P3 | 回归坐席接单分页与隔离 | 0.50 | T21 | verification |
| T28 | B4 / COORD | 演练中断恢复与证据失效 | 0.50 | T04.a, T04.c | verification |
| T28.m | B4 / COORD | 验证真实新会话接续原工作树 | 0.25 | T04.c, T28 | manual |
| T29 | B4 / COORD | 验证最终集成候选门禁 | 0.50 | T22.b, T23.b, T24.b, T25, T26, T27, T28 | candidate_gate |
| T30 | B4 / P1 | 验收P1的iOS原生流程 | 0.25 | T29 | manual |
| T30.a | B4 / P1 | 验收P1的Android原生流程 | 0.25 | T29 | manual |
| T30.b | B4 / P1 | 验收P1的macOS原生流程 | 0.25 | T29 | manual |
| T31 | B4 / P2 | 验收P2的iOS原生流程 | 0.25 | T29 | manual |
| T31.a | B4 / P2 | 验收P2的Android原生流程 | 0.25 | T29 | manual |
| T31.b | B4 / P2 | 验收P2的macOS原生流程 | 0.25 | T29 | manual |
| T32 | B4 / P3 | 验收P3的iOS原生流程 | 0.25 | T29 | manual |
| T32.a | B4 / P3 | 验收P3的Android原生流程 | 0.25 | T29 | manual |
| T32.b | B4 / P3 | 验收P3的macOS原生流程 | 0.25 | T29 | manual |
| T33 | B4 / COORD | 汇总验收与交付候选 | 0.25 | T00 | report |

## 5. 文件级执行卡

测试名是必须实现或映射的验收目标，不表示当前已经存在/运行。人工卡的具体单场景≤3步脚本见NATIVE_CASES.json；准备条件单列。非人工卡中的观察步骤供review，不强迫无设备的自动实施停工。

### T00 · 登记现场与原始工作树

| 字段 | 合同 |
|---|---|
| ID / 名称 | T00 / 登记现场与原始工作树 |
| Batch / Workstream / 规模 | B0 / COORD / ≤0.50人日 |
| 目标 | 建立唯一plan注册表，首次和恢复均能解析同一仓库/工作树。 |
| 参考依据 | R18、RESUME_PROTOCOL §2—4 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/BASELINE.md`<br>`docs/plans/enterprise-uiux-v1/execution/STATUS.md`<br>`@runtime/registry.json`<br>`@runtime/state.json`<br>`@runtime/events.jsonl` |
| 改哪个区块、改成什么 | 先发现同plan旧登记/创建意图，再受锁保护登记；源码仓库只读。T00—T03的并行勘察只把报告写入@runtime/inbox/<task>/，由协调器审核后单任务提交到集成树；此时不创建页面lane。 |
| 依赖 | 无 |
| 关联验收项 | AC-R-01, AC-R-04, AC-Q-08, AC-R-06 |
| 自动/证据验收断言 | 包完整性与静态检查通过；真实repo/common-dir/HEAD/dirty哈希及创建意图已记录；已有登记时原worktree数量不增加；无来源工作区文件被改动。 |
| 命令ID | C-PACKAGE, C-BOOT-GIT, C-BOOT-WORKTREES |
| 定向命令说明 | C-PACKAGE；C-BOOT-GIT；C-BOOT-WORKTREES。本卡只用已提供的包校验器和已安装Git，不调用T04后才产生的工具。 |
| 人工观察（每场景≤3步） | 1. 打开原项目与注册的候选目录。<br>2. 核对两者HEAD、分支和git status记录。<br>3. 确认没有改动原项目或占用设备。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | integration-writer |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | 只revert本卡文档提交；保留注册表/工作树供恢复，不自动删除，不把清理运行态当回滚。 |
| 风险 | 误认目录、将linked .git当目录、把别的计划工作树接管。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T01 · 核验频道现状与调用入口

| 字段 | 合同 |
|---|---|
| ID / 名称 | T01 / 核验频道现状与调用入口 |
| Batch / Workstream / 规模 | B0 / P1 / ≤0.25人日 |
| 目标 | 把每个P1问题关联到实际路由、代码区块、既有测试和待修判定。 |
| 参考依据 | R01—R05、R15/R16、C01—C04 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P1_INVENTORY.md` |
| 改哪个区块、改成什么 | 只读C01—C04及现有路由/测试；记录stats=null、contentToolsAvailable及发布权限，不改代码。 首次执行不依赖尚不存在的PATHS/commands.json/check_state。缺设备只记观察未验，不阻塞源码inventory。报告先写本任务独占inbox，协调器逐卡提交。 |
| 依赖 | T00 |
| 关联验收项 | AC-R-04, AC-Q-08 |
| 自动/证据验收断言 | P1-01—07均有NEEDS_FIX/VERIFY_EXISTING/BLOCKED_EVIDENCE、具体符号和来源SHA；列出embedded、standalone及真正父shell。 |
| 命令ID | C-PACKAGE, C-BOOT-GIT |
| 定向命令说明 | C-PACKAGE；C-BOOT-GIT。逐项核对inventory中的实际文件/符号/只读命令结果；T04以后再运行加固检查，不作为本卡首次完成前置。 |
| 人工观察（每场景≤3步） | 1. 打开企业频道详情。<br>2. 核对头部、统计、筛选与错误入口的记录。<br>3. 对照当前页面确认哪些已修复。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | inbox:T01 |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 拿注释或旧截图代替现状；只看假detailEntry漏掉嵌套头部。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T02 · 核验工作台入口与免登边界

| 字段 | 合同 |
|---|---|
| ID / 名称 | T02 / 核验工作台入口与免登边界 |
| Batch / Workstream / 规模 | B0 / P2 / ≤0.25人日 |
| 目标 | 列明所有实际入口的来源、可见条件、目标和既有测试。 |
| 参考依据 | R06—R09、C05/C06 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P2_INVENTORY.md` |
| 改哪个区块、改成什么 | 只读EnterpriseWorkbenchPage、shell._page/_resourceEntry和CsWorkspaceEntryTile，不修改桥/权限。 首次执行不依赖尚不存在的PATHS/commands.json/check_state。缺设备只记观察未验，不阻塞源码inventory。报告先写本任务独占inbox，协调器逐卡提交。 |
| 依赖 | T00 |
| 关联验收项 | AC-R-04, AC-Q-08 |
| 自动/证据验收断言 | 记录办公是否已删、URL是否仅目的地址、每行icon、Android确认登录、CS gate与空资源实际渲染；无假设路由。 |
| 命令ID | C-PACKAGE, C-BOOT-GIT |
| 定向命令说明 | C-PACKAGE；C-BOOT-GIT。逐项核对inventory中的实际文件/符号/只读命令结果；T04以后再运行加固检查，不作为本卡首次完成前置。 |
| 人工观察（每场景≤3步） | 1. 进入工作台。<br>2. 核对当前显示的每个入口与平台条件。<br>3. 打开应用后核对目的页未被本次勘察改变。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | inbox:T02 |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 误删除OA entries或Android确认入口；用List<Widget>.length当真实可见行数。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T03 · 核验坐席字段与隐私口径

| 字段 | 合同 |
|---|---|
| ID / 名称 | T03 / 核验坐席字段与隐私口径 |
| Batch / Workstream / 规模 | B0 / P3 / ≤0.25人日 |
| 目标 | 建立三态现有可用字段、摘要和掩码的展示合同。 |
| 参考依据 | R10—R14、C07—C09 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P3_INVENTORY.md` |
| 改哪个区块、改成什么 | 只读CsQueueItem解析、csMaskContactName、CsPagedSessionList与三态构建区；保留现有缺摘要隐私裁决。 首次执行不依赖尚不存在的PATHS/commands.json/check_state。缺设备只记观察未验，不阻塞源码inventory。报告先写本任务独占inbox，协调器逐卡提交。 |
| 依赖 | T00 |
| 关联验收项 | AC-R-04, AC-Q-08 |
| 自动/证据验收断言 | 逐字段记录安全摘要/hasLastMessage/source/waitingSince与掩码调用；未读/末条时间标已核验或不在本版；不得推造字段。 |
| 命令ID | C-PACKAGE, C-BOOT-GIT |
| 定向命令说明 | C-PACKAGE；C-BOOT-GIT。逐项核对inventory中的实际文件/符号/只读命令结果；T04以后再运行加固检查，不作为本卡首次完成前置。 |
| 人工观察（每场景≤3步） | 1. 切换待接/处理中/已关闭。<br>2. 对照合成同名会话检查摘要及来源差异。<br>3. 确认记录中无真实姓名、Token或消息原文。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | inbox:T03 |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 将等待时长当末条时间；将既有域函数“顺手修复”。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T04 · 冻结路径、命令和能力清单

| 字段 | 合同 |
|---|---|
| ID / 名称 | T04 / 冻结路径、命令和能力清单 |
| Batch / Workstream / 规模 | B0 / COORD / ≤0.50人日 |
| 目标 | 将动态路径、测试入口及允许改动符号逐项解析，不能留空命令或隐式前置。 |
| 参考依据 | R17/R18、C10/C11、PRD §1/7 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/PATHS.md`<br>`docs/plans/enterprise-uiux-v1/execution/commands.resolved.json`<br>`docs/plans/enterprise-uiux-v1/execution/ALLOWLIST.json`<br>`docs/plans/enterprise-uiux-v1/execution/CAPABILITIES.json`<br>`docs/plans/enterprise-uiux-v1/execution/TASKS.resolved.json` |
| 改哪个区块、改成什么 | 只冻结合同，不在本卡开发全部恢复工具；结合现有设施选择复用或薄适配。解析flutter/FVM为argv数组，P2旧测试目录、所有生效locale、生成文件与资源锁身份必须有实证。 发行包本体保持不变；路径解析和后续拆卡形成execution/TASKS.resolved.json及追加overlay，由运行检查器验证有效DAG与父卡义务继承，不修改包校验器的固定发行计数。 |
| 依赖 | T01, T02, T03 |
| 关联验收项 | AC-R-04, AC-Q-08, AC-R-08 |
| 自动/证据验收断言 | 运行命令均有argv/cwd/资源/前置产物/成功条件；动态项不得留TODO或空串；源码路径old→new有唯一映射；不可用能力标局部BLOCKED而非伪造可用。 |
| 命令ID | C-PACKAGE |
| 定向命令说明 | C-PACKAGE；核对commands.resolved.json与CAPABILITIES.json的逐项证据；禁止调用尚未创建的运行检查器。 |
| 人工观察（每场景≤3步） | 1. 打开PATHS与当前项目树。<br>2. 核对3页文件及i18n真实命令。<br>3. 查看guard正反例退出码记录。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | integration-writer |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 只靠正则误判token或漏改业务；生成器路径漂移；guard被放宽。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T04.a · 建立范围与禁止符号门

| 字段 | 合同 |
|---|---|
| ID / 名称 | T04.a / 建立范围与禁止符号门 |
| Batch / Workstream / 规模 | B0 / COORD / ≤0.50人日 |
| 目标 | 识别文件白名单内偷改业务，以及未提交、未跟踪和测试绕过变更。 |
| 参考依据 | RESUME_PROTOCOL.md / TEST_CONTRACT.md |
| 改动范围（逐文件/运行产物） | `tool/uiux/check_scope.py`<br>`tool/uiux/test_scope_contract.py` |
| 改哪个区块、改成什么 | 优先复用仓库已有检查器并加薄适配；检查base→HEAD、index、worktree及本任务未跟踪文件。只对白名单展示符号放行；domain/provider/service、scope参数、claim等函数摘要不可变；不依赖扫描器自行猜授权。 |
| 依赖 | T04 |
| 关联验收项 | AC-Q-01, AC-Q-02, AC-R-04 |
| 自动/证据验收断言 | scope_rejects_forbidden_file；scope_rejects_frozen_symbol_change_in_allowed_file；scope_checks_index_worktree_untracked；scope_rejects_skip_tolerance_textscale_bypass；scope_accepts_existing_tokens；反例必须非0。 |
| 命令ID | C-SCOPE-SELF, C-SCOPE |
| 定向命令说明 | python3 tool/uiux/test_scope_contract.py；python3 tool/uiux/check_scope.py --base "$UIUX_BASE_SHA" |
| 人工观察（每场景≤3步） | 1. 查看合法Token正例结果。<br>2. 查看允许文件内改claim参数的拒绝结果。<br>3. 核对检查器没有改动被测仓库。 |
| 证据绑定 | 证据绑定被验证对象、命令退出码、hash与环境；自检报告不等于真实产品运行。 |
| 资源/冲突 | integration-writer |
| 失败处理 | 只阻塞真正依赖此产物或资源的任务；不扩大权限，不清零重试预算。 |
| 回滚方式 | revert本任务提交；有消费该产物的下游时先回滚下游或阻塞；保留运行态证据，不回滚用户基线。 |
| 风险 | 只检查新增行或目录白名单会漏业务；规则不确定必须记录待审，不放宽整文件。 |
| 完成判定 | 自动/人工义务按kind分别记账；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T04.b · 建立进程身份与短事务锁

| 字段 | 合同 |
|---|---|
| ID / 名称 | T04.b / 建立进程身份与短事务锁 |
| Batch / Workstream / 规模 | B0 / COORD / ≤0.50人日 |
| 目标 | 同机协调器和worker具有可验证所有权，旧owner不能恢复后写入新状态。 |
| 参考依据 | RESUME_PROTOCOL.md / TEST_CONTRACT.md |
| 改动范围（逐文件/运行产物） | `tool/uiux/plan_lock.py`<br>`tool/uiux/test_lock_contract.py` |
| 改哪个区块、改成什么 | 复用已有可靠资源协议优先；缺失时仅做本机POSIX短事务锁薄层，不建后台服务/远端调度器。固定锁文件不删除重建，owner=(host,boot/process-start,pid,session,epoch)。短事务OS锁保护校验owner→变更同一临界区；长任务受admission记录约束。 |
| 依赖 | T04 |
| 关联验收项 | AC-R-01, AC-R-04, AC-R-07 |
| 自动/证据验收断言 | lock_live_owner_rejected；lock_pid_reuse_rejected；lock_timeout_is_not_takeover；lock_release_old_epoch_rejected；lock_child_alive_blocks_takeover；lock_owner_unknown_fails_closed；测试临时目录与子进程中执行。 |
| 命令ID | C-LOCK-SELF |
| 定向命令说明 | python3 tool/uiux/test_lock_contract.py |
| 人工观察（每场景≤3步） | 1. 在测试目录启动一个锁owner。<br>2. 用第二个进程尝试写入，确认被拒。<br>3. 结束第一个测试进程后验证按规则接管，原工程不受影响。 |
| 证据绑定 | 证据绑定被验证对象、命令退出码、hash与环境；自检报告不等于真实产品运行。 |
| 资源/冲突 | integration-writer |
| 失败处理 | 只阻塞真正依赖此产物或资源的任务；不扩大权限，不清零重试预算。 |
| 回滚方式 | revert本任务提交；有消费该产物的下游时先回滚下游或阻塞；保留运行态证据，不回滚用户基线。 |
| 风险 | 执行器只提供短命shell PID时不能当会话身份；无法验证根进程时只允许串行且歧义接管阻塞。 |
| 完成判定 | 自动/人工义务按kind分别记账；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T04.c · 建立持久化事务与状态校验

| 字段 | 合同 |
|---|---|
| ID / 名称 | T04.c / 建立持久化事务与状态校验 |
| Batch / Workstream / 规模 | B0 / COORD / ≤0.50人日 |
| 目标 | 状态快照与事件日志有确定恢复顺序，不以时间戳猜最新状态。 |
| 参考依据 | RESUME_PROTOCOL.md / TEST_CONTRACT.md |
| 改动范围（逐文件/运行产物） | `tool/uiux/plan_state.py`<br>`tool/uiux/check_state.py`<br>`tool/uiux/test_state_contract.py` |
| 改哪个区块、改成什么 | 在锁薄层内做PREPARE事件→快照原子替换→COMMIT事件；snapshot记录last_txid/revision/prev_hash，提交事实仍以Git与证据为准。check_state只读验证；不得实现另一个任务调度平台。模块目标限本计划状态/登记/恢复，不运行Git修改命令。 |
| 依赖 | T04.b |
| 关联验收项 | AC-R-01, AC-R-04, AC-R-06, AC-R-07 |
| 自动/证据验收断言 | state_prepare_without_snapshot_not_accepted；state_snapshot_without_commit_reconciled_once；state_torn_last_event_quarantined；state_revision_conflict_rejected；state_example_cannot_replace_live；state_status_enum_complete；state_commit_missing_not_pass。 |
| 命令ID | C-STATE-SELF, C-STATE |
| 定向命令说明 | python3 tool/uiux/test_state_contract.py；python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1 |
| 人工观察（每场景≤3步） | 1. 运行临时状态目录故障用例。<br>2. 检查恢复后的revision和txid一致。<br>3. 确认实际原worktree没有被该测试创建、删除或改写。 |
| 证据绑定 | 证据绑定被验证对象、命令退出码、hash与环境；自检报告不等于真实产品运行。 |
| 资源/冲突 | integration-writer |
| 失败处理 | 只阻塞真正依赖此产物或资源的任务；不扩大权限，不清零重试预算。 |
| 回滚方式 | revert本任务提交；有消费该产物的下游时先回滚下游或阻塞；保留运行态证据，不回滚用户基线。 |
| 风险 | 快照与JSONL两个文件不可能靠一次rename共同原子提交；必须按指定事务恢复，不能仅写“原子更新”。 |
| 完成判定 | 自动/人工义务按kind分别记账；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T05 · 建立不依赖视觉字体的结构夹具框架

| 字段 | 合同 |
|---|---|
| ID / 名称 | T05 / 建立不依赖视觉字体的结构夹具框架 |
| Batch / Workstream / 规模 | B1 / COORD / ≤0.50人日 |
| 目标 | 为三页面提供同一SDK/字体/时钟/平台/尺寸主题的真实Widget挂载能力。 |
| 参考依据 | R17/R18、PRD §7 |
| 改动范围（逐文件/运行产物） | `test/uiux/support/uiux_harness.dart`<br>`test/uiux/contract/harness_test.dart`<br>`docs/plans/enterprise-uiux-v1/execution/STRUCTURE_ENV.md` |
| 改哪个区块、改成什么 | 复用真实Widget harness；结构/交互测试不等待视觉字体资产。缺确定性CJK字体只阻塞T05.a及视觉验证，不阻塞i18n、实现、调用回归。无真实字体的截图标STRUCTURE_ONLY，不冒充中文可读性或精确文本几何验收。 |
| 依赖 | T04 |
| 关联验收项 | AC-R-04, AC-R-08 |
| 自动/证据验收断言 | harness_real_shell_mounts；harness_restores_platform_locale_clock；harness_fails_render_exceptions；harness_font_missing_does_not_disable_nonvisual_tests；结构环境的判定与视觉环境分开。 |
| 命令ID | C-T05-1 |
| 定向命令说明 | flutter test test/uiux/contract/harness_test.dart --reporter expanded |
| 人工观察（每场景≤3步） | 1. 打开合成fixture测试截图。<br>2. 切换360/1280与scale2。<br>3. 确认汉字真实可读、未缩放规避。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | integration-writer, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 金图使用系统不固定字体导致漂移；只挂假页误报通过。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T05.a · 冻结视觉字体与栅格环境

| 字段 | 合同 |
|---|---|
| ID / 名称 | T05.a / 冻结视觉字体与栅格环境 |
| Batch / Workstream / 规模 | B1 / COORD / ≤0.50人日 |
| 目标 | 固定可复现的CJK/图标/emoji fallback与Flutter环境，图像比较有确定输入。 |
| 参考依据 | RESUME_PROTOCOL.md / TEST_CONTRACT.md |
| 改动范围（逐文件/运行产物） | `test/uiux/support/golden_font_loader.dart`<br>`test/uiux/contract/font_contract_test.dart`<br>`docs/plans/enterprise-uiux-v1/execution/GOLDEN_ENV.md` |
| 改哪个区块、改成什么 | 优先读取已有授权字体资产；仅登记资产路径/hash/来源许可，不分发系统字体。固定SDK/engine/OS版本/locale/DPR/时钟/图片/动画；所有选择写环境清单，黄金图只在相同环境比较。 |
| 依赖 | T05 |
| 关联验收项 | AC-R-04 |
| 自动/证据验收断言 | golden_font_has_required_cjk_glyphs；golden_rejects_ahem_or_missing_font；golden_environment_hash_changes_on_font_sdk_change；fixture_emojis_have_explicit_policy；缺字体仅VISUAL_BLOCKED。 |
| 命令ID | C-T05-a-1 |
| 定向命令说明 | flutter test test/uiux/contract/font_contract_test.dart --reporter expanded |
| 人工观察（每场景≤3步） | 1. 查看中文长姓名和标点样张。<br>2. 核对字体来源与hash登记。<br>3. 检查同环境重跑不发生文字方块或栅格漂移。 |
| 证据绑定 | 证据绑定被验证对象、命令退出码、hash与环境；自检报告不等于真实产品运行。 |
| 资源/冲突 | integration-writer, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 只阻塞真正依赖此产物或资源的任务；不扩大权限，不清零重试预算。 |
| 回滚方式 | revert本任务提交；有消费该产物的下游时先回滚下游或阻塞；保留运行态证据，不回滚用户基线。 |
| 风险 | 字体license/emoji fallback/异平台渲染漂移；不能用扩大容差解决。 |
| 完成判定 | 自动/人工义务按kind分别记账；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T06 · 冻结并生成本地化展示文案

| 字段 | 合同 |
|---|---|
| ID / 名称 | T06 / 冻结并生成本地化展示文案 |
| Batch / Workstream / 规模 | B1 / COORD / ≤0.50人日 |
| 目标 | 全部新增标签、来源和错误文案均由既有本地化系统输出。 |
| 参考依据 | R12/R16/R17、PRD §4—6 |
| 改动范围（逐文件/运行产物） | `assets/i18n/<生效locale>/workspace.i18n.yaml`<br>`assets/i18n/<生效locale>/channel.i18n.yaml`<br>`assets/i18n/<生效locale>/enterpriseOa.i18n.yaml`<br>`assets/i18n/<生效locale>/customerService.i18n.yaml`<br>`@resolved/i18n-generated-files`<br>`test/uiux/contract/copy_contract_test.dart` |
| 改哪个区块、改成什么 | 优先复用已有等义键；只新增局部键/改本页键；统一生成一次，其他lane只读；存在同名文件漂移必须先更新PATHS，不猜目录。 本卡只依赖路径/生成器合同，不依赖视觉字体；T05.a缺字体不阻塞本卡。 |
| 依赖 | T04 |
| 关联验收项 | AC-Q-06, AC-R-04 |
| 自动/证据验收断言 | uiux_copy_has_no_debug_url_or_raw_source；uiux_discuss_copy_has_no_arrow；所有当前受支持locale键一致，生成器再次运行无diff；新文案不含真实客户信息。 |
| 命令ID | C-I18N, C-T06-1 |
| 定向命令说明 | <commands.json中冻结的现有i18n命令>；flutter test test/uiux/contract/copy_contract_test.dart |
| 人工观察（每场景≤3步） | 1. 切换中文及英语。<br>2. 查看讨论引导/来源/错误fixture。<br>3. 确认不是键名、原枚举或地址。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | integration-writer, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 多个worker覆盖strings.g.dart；只翻译一种语言；改动全站通用重试语义。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T07 · 建立频道真实路由夹具

| 字段 | 合同 |
|---|---|
| ID / 名称 | T07 / 建立频道真实路由夹具 |
| Batch / Workstream / 规模 | B1 / P1 / ≤0.50人日 |
| 目标 | 覆盖真实频道宿主及内容页，不以测试标记组件替代被测内容。 |
| 参考依据 | R01/R15/R16、C01—C04 |
| 改动范围（逐文件/运行产物） | `test/uiux/p1/p1_fixtures.dart`<br>`test/uiux/p1/p1_fixture_smoke_test.dart` |
| 改哪个区块、改成什么 | 仅注入既有依赖替身，使用合成数据；对不编入当前构建的路由测试原重定向，不修改生产manifest。 |
| 依赖 | T05, T06, T04.a, T04.c |
| 关联验收项 | AC-R-04 |
| 自动/证据验收断言 | p1_fixture_uses_real_embedded_content；p1_fixture_respects_feature_gate；构造有内容/统计未请求/初始错误/分页错误/空/无结果/长名/只读；初始业务调用trace保存。 |
| 命令ID | C-T07-1 |
| 定向命令说明 | flutter test test/uiux/p1/p1_fixture_smoke_test.dart |
| 人工观察（每场景≤3步） | 1. 用测试环境打开对应频道fixture。<br>2. 确认能看见真实内容组件而非“测试页面”标记。<br>3. 查看原返回、发布栏与筛选仍存在。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P1, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 全局provider残留导致跨case污染；fixture绕开真实feature gate。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T08 · 建立工作台入口夹具

| 字段 | 合同 |
|---|---|
| ID / 名称 | T08 / 建立工作台入口夹具 |
| Batch / Workstream / 规模 | B1 / P2 / ≤0.50人日 |
| 目标 | 可确定性验证资源有无、CS gate及Android辅助入口。 |
| 参考依据 | R06—R09、C05/C06 |
| 改动范围（逐文件/运行产物） | `test/uiux/p2/p2_fixtures.dart`<br>`test/uiux/p2/p2_fixture_smoke_test.dart` |
| 改哪个区块、改成什么 | 挂载真实EnterpriseWorkbenchPage与shell资源构建；必要的测试seam只允许透传已有输入，不新增权限逻辑。 |
| 依赖 | T05, T06, T04.a, T04.c |
| 关联验收项 | AC-R-04 |
| 自动/证据验收断言 | p2_fixture_uses_real_shell_entries；记录无工作区/普通成员/有坐席/feature关闭/有OA配置/Android inbound开启输入；应用点击trace为基线值。 |
| 命令ID | C-T08-1 |
| 定向命令说明 | flutter test test/uiux/p2/p2_fixture_smoke_test.dart |
| 人工观察（每场景≤3步） | 1. 进入有资源与无资源测试工作台。<br>2. 核对客服与项目条件显示。<br>3. 查看Android确认登录入口仍可达。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P2, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 只传几个普通ListTile漏测实际CsWorkspaceEntryTile隐藏状态。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T09 · 建立坐席三态字段夹具

| 字段 | 合同 |
|---|---|
| ID / 名称 | T09 / 建立坐席三态字段夹具 |
| Batch / Workstream / 规模 | B1 / P3 / ≤0.50人日 |
| 目标 | 使用相同合成DTO验证三态摘要、来源与业务trace。 |
| 参考依据 | R10—R13、C07—C09 |
| 改动范围（逐文件/运行产物） | `test/uiux/p3/p3_fixtures.dart`<br>`test/uiux/p3/p3_fixture_smoke_test.dart` |
| 改哪个区块、改成什么 | 测试时钟固定；复用现有API模拟层记录参数与调用次数，不改变真实DTO解析。 |
| 依赖 | T05, T06, T04.a, T04.c |
| 关联验收项 | AC-R-04 |
| 自动/证据验收断言 | p3_fixture_covers_preview_missing_and_unknown_source；含同掩码不同摘要、hasLastMessage=true但无摘要、无消息、widget/未知/空、claim中、409、无权限；禁真实数据。 |
| 命令ID | C-T09-1 |
| 定向命令说明 | flutter test test/uiux/p3/p3_fixture_smoke_test.dart |
| 人工观察（每场景≤3步） | 1. 打开三态合成会话。<br>2. 比对同名不同摘要与无摘要场景。<br>3. 查看接入中与冲突场景的原行为记录。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P3, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 测试为展示补数据掩盖真实缺字段；偶发时间导致golden漂移。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T10 · 收敛频道身份头部

| 字段 | 合同 |
|---|---|
| ID / 名称 | T10 / 收敛频道身份头部 |
| Batch / Workstream / 规模 | B2 / P1 / ≤0.50人日 |
| 目标 | 完整详情路由只有一个返回职责和一个频道身份标题。 |
| 参考依据 | P1-01、D01/D03、R01/R02 |
| 改动范围（逐文件/运行产物） | `lib/page/workspace/workspace_channel_detail_page.dart`<br>`lib/page/channel/channel_detail_page.dart`<br>`lib/page/channel/widgets/channel_header_bar.dart`<br>`test/uiux/p1/header_test.dart` |
| 改哪个区块、改成什么 | 宿主继续拥有AppBar；HeaderBar以展示参数隐藏重复身份标题，保留头像/角色/订阅数；仅当前详情调用选择紧凑模式；不改路由栈。 |
| 依赖 | T07 |
| 关联验收项 | AC-P1-01, AC-R-04 |
| 自动/证据验收断言 | p1_embedded_has_one_navigation_back_and_identity_title；p1_standalone_back_pops_once；p1_metadata_keeps_role_count；大字标题无overflow。 |
| 命令ID | C-T10-1 |
| 定向命令说明 | flutter test test/uiux/p1/header_test.dart |
| 人工观察（每场景≤3步） | 1. 从频道列表进入详情。<br>2. 观察顶部与元信息区不重复频道大标题。<br>3. 返回一次回到原列表。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P1, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 删除父shell导航、丢更多/DM、HeaderBar默认参数影响非企业入口。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T11 · 验证统计非加载占位

| 字段 | 合同 |
|---|---|
| ID / 名称 | T11 / 验证统计非加载占位 |
| Batch / Workstream / 规模 | B2 / P1 / ≤0.25人日 |
| 目标 | 统计不请求或已终止时不显示永久骨架。 |
| 参考依据 | P1-02、R15、C03 |
| 改动范围（逐文件/运行产物） | `lib/page/channel/widgets/channel_header_bar.dart`<br>`test/uiux/p1/stats_state_test.dart` |
| 改哪个区块、改成什么 | 源码已正确时只补测试；需要改时仅改HeaderBar显示分支，不动_loadStats/autoLoadStats的加载语义。 |
| 依赖 | T10 |
| 关联验收项 | AC-P1-02, AC-R-04 |
| 自动/证据验收断言 | p1_stats_disabled_has_no_skeleton；p1_stats_null_uses_existing_count_without_request；p1_unknown_count_is_not_fabricated；autoLoadStats=false无新增网络请求。 |
| 命令ID | C-T11-1 |
| 定向命令说明 | flutter test test/uiux/p1/stats_state_test.dart |
| 人工观察（每场景≤3步） | 1. 进入企业频道详情。<br>2. 观察创建者角色旁的统计信息。<br>3. 刷新/重进后确认无一直闪烁的灰条。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P1, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 把未知值显示0；为了消失骨架增加后台请求或计时器。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T12 · 区分频道动作可用状态

| 字段 | 合同 |
|---|---|
| ID / 名称 | T12 / 区分频道动作可用状态 |
| Batch / Workstream / 规模 | B2 / P1 / ≤0.50人日 |
| 目标 | 动作图标可识别，静音/禁用/进行中状态互不混淆。 |
| 参考依据 | P1-04、D02/D08、R05/R17 |
| 改动范围（逐文件/运行产物） | `lib/page/channel/widgets/channel_header_bar.dart`<br>`test/uiux/p1/actions_test.dart` |
| 改哪个区块、改成什么 | 仅调整_buildCircleActionItem及调用的展示参数、null处理和语义；用既有Token实测组合；原静音函数和权限来源不改。 |
| 依赖 | T11 |
| 关联验收项 | AC-P1-04, AC-Q-02, AC-R-04 |
| 自动/证据验收断言 | p1_action_enabled_contrast_at_least_3；p1_action_targets_at_least_48；p1_missing_callback_is_disabled_not_noop；p1_muted_is_toggleable_not_disabled；pending不重复回调。 |
| 命令ID | C-T12-1 |
| 定向命令说明 | flutter test test/uiux/p1/actions_test.dart |
| 人工观察（每场景≤3步） | 1. 以原允许角色进入频道。<br>2. 查看并点击管理/静音/转发/分享中可用动作。<br>3. 对照禁用/执行中fixture确认状态及读屏名称不同。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P1, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 改成新权限判断；用灰色表示“静音已开启”却被误当不可操作。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T13 · 统一讨论横幅方向指示

| 字段 | 合同 |
|---|---|
| ID / 名称 | T13 / 统一讨论横幅方向指示 |
| Batch / Workstream / 规模 | B2 / P1 / ≤0.25人日 |
| 目标 | 横幅只有一个方向指示且保持原讨论目标。 |
| 参考依据 | P1-05、R03、C01 |
| 改动范围（逐文件/运行产物） | `lib/page/workspace/workspace_channel_detail_page.dart`<br>`test/uiux/p1/discuss_banner_test.dart` |
| 改哪个区块、改成什么 | 使用T06已冻结文案并保留一个尾部chevron；已有正确实现则test-only；合并装饰图标语义。 |
| 依赖 | T07 |
| 关联验收项 | AC-P1-05, AC-R-04 |
| 自动/证据验收断言 | p1_discuss_has_exactly_one_direction_indicator；p1_discuss_tap_opens_original_group_target_once；scale2中英文均可读；文案无箭头。 |
| 命令ID | C-T13-1 |
| 定向命令说明 | flutter test test/uiux/p1/discuss_banner_test.dart |
| 人工观察（每场景≤3步） | 1. 打开频道详情。<br>2. 观察横幅只有一处箭头。<br>3. 点击横幅进入原群入口。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P1, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 文案已含箭头再加chevron；更改General群相关业务。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T14 · 折叠频道高级筛选

| 字段 | 合同 |
|---|---|
| ID / 名称 | T14 / 折叠频道高级筛选 |
| Batch / Workstream / 规模 | B2 / P1 / ≤0.50人日 |
| 目标 | 默认只展示搜索和筛选入口，展开不触发额外业务查询。 |
| 参考依据 | P1-06、D09、R01/R11、C04 |
| 改动范围（逐文件/运行产物） | `lib/page/channel/widgets/channel_message_feed.dart`<br>`test/uiux/p1/filter_controls_test.dart` |
| 改哪个区块、改成什么 | 仅_buildPostFilters/展示布局新增本地展开状态；保留_query/_tag/_essenceOnly/_page语义和provider参数；不新增筛选业务。 |
| 依赖 | T07 |
| 关联验收项 | AC-P1-06a, AC-R-04 |
| 自动/证据验收断言 | p1_advanced_filters_collapsed_by_default；p1_toggle_filters_preserves_values_and_request_count；p1_submit_filter_matches_baseline_query；p1_collapse_moves_focus_safely；mc_*现有key保持可访问。 |
| 命令ID | C-T14-1 |
| 定向命令说明 | flutter test test/uiux/p1/filter_controls_test.dart |
| 人工观察（每场景≤3步） | 1. 进入有内容的频道。<br>2. 点筛选，输入标签并使用全部/精华。<br>3. 收起再展开，确认条件保留且结果仍正确。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P1, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 收起销毁输入controller导致条件丢失；改变提交时机/分页；键盘小高度overflow。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T15 · 补齐错误空态与日期装饰

| 字段 | 合同 |
|---|---|
| ID / 名称 | T15 / 补齐错误空态与日期装饰 |
| Batch / Workstream / 规模 | B2 / P1 / ≤0.50人日 |
| 目标 | 失败有说明与真实恢复入口，空内容不渲染孤立日期。 |
| 参考依据 | P1-03/P1-07、D10、R16 |
| 改动范围（逐文件/运行产物） | `lib/page/channel/widgets/channel_message_feed.dart`<br>`lib/page/channel/channel_detail_page.dart`<br>`test/uiux/p1/content_states_test.dart` |
| 改哪个区块、改成什么 | 只调整错误/空态构建及日期装饰条件，复用现有重试；不改变加载状态转换；若现有分页无单独重试回调，保留原恢复入口并记录。 |
| 依赖 | T14 |
| 关联验收项 | AC-P1-03, AC-P1-06b, AC-R-04 |
| 自动/证据验收断言 | p1_initial_error_has_icon_title_hint_retry；p1_retry_calls_existing_action_once；p1_empty_and_no_results_have_zero_date_separators；p1_pagination_error_keeps_loaded_items；p1_readonly_empty_has_no_publish_cta。 |
| 命令ID | C-T15-1 |
| 定向命令说明 | flutter test test/uiux/p1/content_states_test.dart |
| 人工观察（每场景≤3步） | 1. 打开失败/无内容的测试频道。<br>2. 核对错误说明、无孤立日期、只读空态无发布按钮。<br>3. 恢复网络并点原重试，确认内容恢复。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P1, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 原错误被吞成空态；分页失败清空已有列表；日期分组/排序被改变。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T16 · 统一工作台分组容器

| 字段 | 合同 |
|---|---|
| ID / 名称 | T16 / 统一工作台分组容器 |
| Batch / Workstream / 规模 | B2 / P2 / ≤0.50人日 |
| 目标 | 资源、应用、辅助登录入口具有同一背景和分组节奏。 |
| 参考依据 | P2-01/P2-05、D04、R06—R09 |
| 改动范围（逐文件/运行产物） | `lib/modules/enterprise_oa/presentation/enterprise_workbench_page.dart`<br>`test/uiux/p2/containers_test.dart` |
| 改哪个区块、改成什么 | 复用现有insetGrouped，设置局部Token背景/边距，避免重复标题和空壳；隐藏子widget的可见性问题按PRD P2-05处理，不改gate。 |
| 依赖 | T08 |
| 关联验收项 | AC-P2-01, AC-R-04 |
| 自动/证据验收断言 | p2_groups_share_surface_and_insets；p2_empty_resources_leave_no_empty_container；p2_single_apps_has_no_duplicate_section_title；真实隐藏CS行场景无空卡；scale2自然增高。 |
| 命令ID | C-T16-1 |
| 定向命令说明 | flutter test test/uiux/p2/containers_test.dart |
| 人工观察（每场景≤3步） | 1. 进入资源完整工作台。<br>2. 切换无资源/单应用场景。<br>3. 亮暗切换确认无断裂或空白卡片。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P2, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 通过复制CS权限逻辑解决空组；随手改全局Cupertino主题。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T17 · 复验办公删除与地址隐藏

| 字段 | 合同 |
|---|---|
| ID / 名称 | T17 / 复验办公删除与地址隐藏 |
| Batch / Workstream / 规模 | B2 / P2 / ≤0.25人日 |
| 目标 | 办公入口为0，应用入口为1且不展示URL，原免登链不变。 |
| 参考依据 | P2-02/P2-03、C05、R06/R09 |
| 改动范围（逐文件/运行产物） | `lib/modules/enterprise_oa/presentation/enterprise_workbench_page.dart`<br>`test/uiux/p2/apps_entry_test.dart` |
| 改哪个区块、改成什么 | 优先保留当前已删的实现并只补测试；不得修改appsUrl/_openApps/_issueBridgeAuthCode及业务参数。 |
| 依赖 | T16 |
| 关联验收项 | AC-P2-02, AC-P2-03, AC-P2-05, AC-R-04 |
| 自动/证据验收断言 | p2_office_absent_apps_single；p2_apps_url_absent_from_text_semantics_tooltip；p2_app_tap_preserves_destination_and_bridge；p2_android_inbound_entry_remains；配置OA后应用入口仍可用。 |
| 命令ID | C-T17-1 |
| 定向命令说明 | flutter test test/uiux/p2/apps_entry_test.dart |
| 人工观察（每场景≤3步） | 1. 打开已配置OA的工作台。<br>2. 确认无办公列表和URL副标题。<br>3. 点击应用，确认进入原页面且原免登按需调用不变。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P2, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 删掉entries/_issueBridgeAuthCode；把隐藏test_oa地址误写为生产化完成。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T18 · 对齐资源入口图标与文本

| 字段 | 合同 |
|---|---|
| ID / 名称 | T18 / 对齐资源入口图标与文本 |
| Batch / Workstream / 规模 | B2 / P2 / ≤0.50人日 |
| 目标 | 所有实际可见导航行采用统一图标槽和文本起点。 |
| 参考依据 | P2-04、D02/D04、R09、C06 |
| 改动范围（逐文件/运行产物） | `lib/page/workspace_shell/enterprise_shell_page.dart`<br>`lib/modules/enterprise_oa/presentation/enterprise_workbench_page.dart`<br>`lib/modules/customer_service/presentation/cs_workspace_entry.dart`<br>`test/uiux/p2/entry_rows_test.dart` |
| 改哪个区块、改成什么 | 仅shell._page工作台分支及_resourceEntry外观；cs_workspace_entry属于P2独占，不在P3写集合；保留全部可见性表达式和onTap。 |
| 依赖 | T17 |
| 关联验收项 | AC-P2-04, AC-R-04 |
| 自动/证据验收断言 | p2_visible_rows_have_uniform_icon_slot_and_text_start；p2_all_entry_hit_targets_at_least_48；p2_resource_gates_order_and_routes_equal_baseline；P2外其他Tab快照/行为不变。 |
| 命令ID | C-T18-1 |
| 定向命令说明 | flutter test test/uiux/p2/entry_rows_test.dart |
| 人工观察（每场景≤3步） | 1. 进入有权限的资源工作台。<br>2. 查看客服/项目/群组/频道/附件/应用文字对齐。<br>3. 逐个打开可见入口核对原目标。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P2, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 修改shell共享方法影响其他Tab；与P3误抢cs_workspace_entry文件。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T19 · 提取会话行共用信息布局

| 字段 | 合同 |
|---|---|
| ID / 名称 | T19 / 提取会话行共用信息布局 |
| Batch / Workstream / 规模 | B2 / P3 / ≤0.50人日 |
| 目标 | 三态使用同一纯展示信息组件，状态动作仍由原页面持有。 |
| 参考依据 | P3-01/P3-04、D05、R10/R11 |
| 改动范围（逐文件/运行产物） | `lib/modules/customer_service/presentation/cs_queue_view.dart`<br>`lib/modules/customer_service/presentation/cs_session_list_view.dart`<br>`lib/modules/customer_service/presentation/cs_session_row_content.dart`<br>`test/uiux/p3/row_structure_test.dart` |
| 改哪个区块、改成什么 | 新增纯展示CsSessionRowContent，接收已可用的显示输入/内容widget；页面保留_fetchPage/_claim/_open及全部作用域；只抽重复布局。 |
| 依赖 | T09 |
| 关联验收项 | AC-P3-01, AC-P3-02, AC-R-04 |
| 自动/证据验收断言 | p3_all_statuses_share_information_order；p3_name_is_existing_mask_result；p3_queue_keeps_claim_action_other_views_keep_open_action；组件无API/provider/权限依赖；最小88自然增高。 |
| 命令ID | C-T19-1 |
| 定向命令说明 | flutter test test/uiux/p3/row_structure_test.dart |
| 人工观察（每场景≤3步） | 1. 依次进入待接/处理中/已关闭。<br>2. 对照名称、摘要、来源的位置。<br>3. 核对待接接入按钮与其他状态打开动作未混淆。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P3, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 抽组件时迁移claim/分页业务；强制固定三行导致空摘要留空白。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T20 · 统一安全摘要与缺失回退

| 字段 | 合同 |
|---|---|
| ID / 名称 | T20 / 统一安全摘要与缺失回退 |
| Batch / Workstream / 规模 | B2 / P3 / ≤0.25人日 |
| 目标 | 已有摘要三态一致显示，缺失时遵守原隐私回退。 |
| 参考依据 | P3-01/P3-02、R13、C07/C08 |
| 改动范围（逐文件/运行产物） | `lib/modules/customer_service/presentation/cs_queue_view.dart`<br>`lib/modules/customer_service/presentation/cs_session_row_content.dart`<br>`test/uiux/p3/preview_test.dart` |
| 改哪个区块、改成什么 | 复用csQueuePreviewText，不改变数据判断；只能调整显示行数/语义与容器；若当前一致则只补测试。 |
| 依赖 | T19 |
| 关联验收项 | AC-P3-01, AC-R-04 |
| 自动/证据验收断言 | p3_same_safe_preview_in_all_statuses；p3_has_message_without_preview_renders_no_placeholder；p3_no_message_keeps_documented_fallback；p3_preview_never_fetches_message_body；scale2最多2行。 |
| 命令ID | C-T20-1 |
| 定向命令说明 | flutter test test/uiux/p3/preview_test.dart |
| 人工观察（每场景≤3步） | 1. 查看同掩码但不同安全摘要的两条会话。<br>2. 查看有消息无摘要及完全无消息的fixture。<br>3. 切换三态确认显示规则一致。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P3, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 用真实姓名/原消息补足区分度；重新引入“加密消息”或猜测附件。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T21 · 转换可读来源并隐藏原枚举

| 字段 | 合同 |
|---|---|
| ID / 名称 | T21 / 转换可读来源并隐藏原枚举 |
| Batch / Workstream / 规模 | B2 / P3 / ≤0.50人日 |
| 目标 | 来源显示名称在三态一致，未知wire不泄漏。 |
| 参考依据 | P3-03、R12、C07/C08 |
| 改动范围（逐文件/运行产物） | `lib/modules/customer_service/presentation/cs_queue_view.dart`<br>`lib/modules/customer_service/presentation/cs_session_list_view.dart`<br>`lib/modules/customer_service/presentation/cs_session_row_content.dart`<br>`lib/modules/customer_service/presentation/cs_source_label.dart`<br>`test/uiux/p3/source_label_test.dart` |
| 改哪个区块、改成什么 | 新增纯展示来源映射；默认仅widget→网页咨询、未知→其他渠道、空→来源未知；i18n来自T06；不改cs_api解析或数据模型。 |
| 依赖 | T20 |
| 关联验收项 | AC-P3-03, AC-R-04 |
| 自动/证据验收断言 | p3_widget_source_is_localized_web_chat；p3_unknown_source_is_generic_not_raw；p3_empty_source_is_unknown；p3_semantics_and_tooltips_never_expose_wire_or_raw_name；DTO与HTTP请求原值不变。 |
| 命令ID | C-T21-1 |
| 定向命令说明 | flutter test test/uiux/p3/source_label_test.dart |
| 人工观察（每场景≤3步） | 1. 查看网页来源会话。<br>2. 查看未知/空来源合成会话。<br>3. 使用读屏或语义检查确认没有内部枚举和原姓名。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P3, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 全局替换widget破坏协议；给未知值猜具体渠道名。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T22 · 验证P1结构矩阵与无障碍

| 字段 | 合同 |
|---|---|
| ID / 名称 | T22 / 验证P1结构矩阵与无障碍 |
| Batch / Workstream / 规模 | B3 / P1 / ≤0.50人日 |
| 目标 | P1全部平台、宽度、主题及scale1/2结构断言有准确执行计数。 |
| 参考依据 | P1-01—07、D01—D10、R17 |
| 改动范围（逐文件/运行产物） | `test/uiux/p1/accessibility_test.dart`<br>`docs/plans/enterprise-uiux-v1/execution/P1_MATRIX.md` |
| 改哪个区块、改成什么 | 本卡只完成结构/语义/尺寸/对比度与键盘边界断言；golden生成与视觉审查拆至后两张卡。使用真实字体后才签精确文字几何；无取巧clamp/缩小字号。 |
| 依赖 | T10, T11, T12, T13, T15, T05.a |
| 关联验收项 | AC-P1-01, AC-Q-02, AC-Q-03, AC-Q-04, AC-R-04 |
| 自动/证据验收断言 | p1_matrix_all_expected_configs_executed；p1_semantics_labels_and_targets_valid；p1_text_and_enabled_icon_contrast_valid；p1_short_viewport_keyboard_focus_reachable；expected=executed、必需case无skip。 |
| 命令ID | C-T22-1 |
| 定向命令说明 | flutter test test/uiux/p1/accessibility_test.dart --reporter expanded |
| 人工观察（每场景≤3步） | 1. 查看本页结构矩阵计数。<br>2. 打开360宽大字和1280真实shell样张。<br>3. 核对不可达按钮、溢出及隐私语义反例均能失败。 |
| 证据绑定 | 结构矩阵记录配置ID及实际执行计数；golden生成/审查不在本卡冒充完成。 |
| 资源/冲突 | lane:P1, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 盲目更新golden；Ahem掩盖汉字宽度；大字固定头高溢出。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T22.a · 生成P1候选golden与差异包

| 字段 | 合同 |
|---|---|
| ID / 名称 | T22.a / 生成P1候选golden与差异包 |
| Batch / Workstream / 规模 | B3 / P1 / ≤0.50人日 |
| 目标 | 产生120个准确配置及before/after/diff，更新不是自动批准。 |
| 参考依据 | RESUME_PROTOCOL.md / TEST_CONTRACT.md |
| 改动范围（逐文件/运行产物） | `test/uiux/golden/p1_golden_test.dart`<br>`docs/plans/enterprise-uiux-v1/execution/P1_GOLDEN_MANIFEST.json`<br>`@runtime/golden/p1/candidates/` |
| 改哪个区块、改成什么 | 复用已存在golden优先；新测试必需baseline不存在即失败。仅运行本页update命令，候选输出写versioned目录，不覆盖已封存baseline。before取W0原场景截图；新控件无旧图必须标NEW_SCENARIO及设计断言，不用新图伪造before。 |
| 依赖 | T22 |
| 关联验收项 | AC-Q-03, AC-R-04, AC-Q-09 |
| 自动/证据验收断言 | p1_golden_manifest_count_is_120；matrix_config_id唯一；每图sha256/env/input/requirement/task齐全；missing_baseline_fails；image_update_does_not_approve；before只取原SHA。 |
| 命令ID | C-T22-a-1 |
| 定向命令说明 | flutter test test/uiux/golden/p1_golden_test.dart --update-goldens --reporter expanded；核对本页manifest；不得把退出0叫已批准。 |
| 人工观察（每场景≤3步） | 1. 查看本页manifest配置数量。<br>2. 打开本页before/after/diff样张。<br>3. 确认已封存旧图hash未被更新操作覆盖。 |
| 证据绑定 | 证据绑定被验证对象、命令退出码、hash与环境；自检报告不等于真实产品运行。 |
| 资源/冲突 | lane:P1, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 只阻塞真正依赖此产物或资源的任务；不扩大权限，不清零重试预算。 |
| 回滚方式 | revert本任务提交；有消费该产物的下游时先回滚下游或阻塞；保留运行态证据，不回滚用户基线。 |
| 风险 | 整仓update抹掉回归；只比较新图与自身；ignored PNG未保留。 |
| 完成判定 | 自动/人工义务按kind分别记账；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T22.b · 审查并封存P1视觉基线

| 字段 | 合同 |
|---|---|
| ID / 名称 | T22.b / 审查并封存P1视觉基线 |
| Batch / Workstream / 规模 | B3 / P1 / ≤0.50人日 |
| 目标 | 按需求逐图或可证明等价的图组审查，再只读普通比较。 |
| 参考依据 | RESUME_PROTOCOL.md / TEST_CONTRACT.md |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P1_GOLDEN_REVIEW.md`<br>`@runtime/golden/p1/sealed/` |
| 改哪个区块、改成什么 | 每张图必须有review结果与差异理由；完全相同像素且语义断言一致可组审但manifest仍逐配置。记录reviewer身份/SELF_REVIEW_ONLY或INDEPENDENT；没有独立审查工具不伪造。封存工程基线不等于产品UX人工通过。 |
| 依赖 | T22.a |
| 关联验收项 | AC-Q-03, AC-R-04 |
| 自动/证据验收断言 | p1_every_golden_has_review_entry；p1_sealed_baseline_is_immutable；p1_normal_compare_zero_diff；p1_missing_or_changed_sealed_file_fails；恢复后不自动update；review失败回原页修复。 |
| 命令ID | C-T22-b-1 |
| 定向命令说明 | flutter test test/uiux/golden/p1_golden_test.dart --reporter expanded；核对manifest与sealed目录hash一致。 |
| 人工观察（每场景≤3步） | 1. 按需求核对本页全部图或已证明等价组。<br>2. 登记每张图结论、审查身份及hash。<br>3. 不带update参数重跑比较并确认无diff。 |
| 证据绑定 | 证据绑定被验证对象、命令退出码、hash与环境；自检报告不等于真实产品运行。 |
| 资源/冲突 | lane:P1, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 只阻塞真正依赖此产物或资源的任务；不扩大权限，不清零重试预算。 |
| 回滚方式 | revert本任务提交；有消费该产物的下游时先回滚下游或阻塞；保留运行态证据，不回滚用户基线。 |
| 风险 | 自审冒充独立审批；大批review超粒度；达到上限仍未完成时拆本页批次子卡，不草率全PASS。 |
| 完成判定 | 自动/人工义务按kind分别记账；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T23 · 验证P2结构矩阵与无障碍

| 字段 | 合同 |
|---|---|
| ID / 名称 | T23 / 验证P2结构矩阵与无障碍 |
| Batch / Workstream / 规模 | B3 / P2 / ≤0.50人日 |
| 目标 | P2全部平台、宽度、主题及scale1/2结构断言有准确执行计数。 |
| 参考依据 | P2-01—05、D02/D04/D07/D08 |
| 改动范围（逐文件/运行产物） | `test/uiux/p2/accessibility_test.dart`<br>`docs/plans/enterprise-uiux-v1/execution/P2_MATRIX.md` |
| 改哪个区块、改成什么 | 本卡只完成结构/语义/尺寸/对比度与键盘边界断言；golden生成与视觉审查拆至后两张卡。使用真实字体后才签精确文字几何；无取巧clamp/缩小字号。 |
| 依赖 | T18, T05.a |
| 关联验收项 | AC-P2-01, AC-Q-02, AC-Q-03, AC-Q-04, AC-R-04 |
| 自动/证据验收断言 | p2_matrix_all_expected_configs_executed；p2_semantics_labels_and_targets_valid；p2_text_and_enabled_icon_contrast_valid；p2_short_viewport_keyboard_focus_reachable；expected=executed、必需case无skip。 |
| 命令ID | C-T23-1 |
| 定向命令说明 | flutter test test/uiux/p2/accessibility_test.dart --reporter expanded |
| 人工观察（每场景≤3步） | 1. 查看本页结构矩阵计数。<br>2. 打开360宽大字和1280真实shell样张。<br>3. 核对不可达按钮、溢出及隐私语义反例均能失败。 |
| 证据绑定 | 结构矩阵记录配置ID及实际执行计数；golden生成/审查不在本卡冒充完成。 |
| 资源/冲突 | lane:P2, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 只测理想有资源忽略CS全部隐藏；只测裸工作台漏shell错误条。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T23.a · 生成P2候选golden与差异包

| 字段 | 合同 |
|---|---|
| ID / 名称 | T23.a / 生成P2候选golden与差异包 |
| Batch / Workstream / 规模 | B3 / P2 / ≤0.50人日 |
| 目标 | 产生72个准确配置及before/after/diff，更新不是自动批准。 |
| 参考依据 | RESUME_PROTOCOL.md / TEST_CONTRACT.md |
| 改动范围（逐文件/运行产物） | `test/uiux/golden/p2_golden_test.dart`<br>`docs/plans/enterprise-uiux-v1/execution/P2_GOLDEN_MANIFEST.json`<br>`@runtime/golden/p2/candidates/` |
| 改哪个区块、改成什么 | 复用已存在golden优先；新测试必需baseline不存在即失败。仅运行本页update命令，候选输出写versioned目录，不覆盖已封存baseline。before取W0原场景截图；新控件无旧图必须标NEW_SCENARIO及设计断言，不用新图伪造before。 |
| 依赖 | T23 |
| 关联验收项 | AC-Q-03, AC-R-04, AC-Q-09 |
| 自动/证据验收断言 | p2_golden_manifest_count_is_72；matrix_config_id唯一；每图sha256/env/input/requirement/task齐全；missing_baseline_fails；image_update_does_not_approve；before只取原SHA。 |
| 命令ID | C-T23-a-1 |
| 定向命令说明 | flutter test test/uiux/golden/p2_golden_test.dart --update-goldens --reporter expanded；核对本页manifest；不得把退出0叫已批准。 |
| 人工观察（每场景≤3步） | 1. 查看本页manifest配置数量。<br>2. 打开本页before/after/diff样张。<br>3. 确认已封存旧图hash未被更新操作覆盖。 |
| 证据绑定 | 证据绑定被验证对象、命令退出码、hash与环境；自检报告不等于真实产品运行。 |
| 资源/冲突 | lane:P2, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 只阻塞真正依赖此产物或资源的任务；不扩大权限，不清零重试预算。 |
| 回滚方式 | revert本任务提交；有消费该产物的下游时先回滚下游或阻塞；保留运行态证据，不回滚用户基线。 |
| 风险 | 整仓update抹掉回归；只比较新图与自身；ignored PNG未保留。 |
| 完成判定 | 自动/人工义务按kind分别记账；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T23.b · 审查并封存P2视觉基线

| 字段 | 合同 |
|---|---|
| ID / 名称 | T23.b / 审查并封存P2视觉基线 |
| Batch / Workstream / 规模 | B3 / P2 / ≤0.50人日 |
| 目标 | 按需求逐图或可证明等价的图组审查，再只读普通比较。 |
| 参考依据 | RESUME_PROTOCOL.md / TEST_CONTRACT.md |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P2_GOLDEN_REVIEW.md`<br>`@runtime/golden/p2/sealed/` |
| 改哪个区块、改成什么 | 每张图必须有review结果与差异理由；完全相同像素且语义断言一致可组审但manifest仍逐配置。记录reviewer身份/SELF_REVIEW_ONLY或INDEPENDENT；没有独立审查工具不伪造。封存工程基线不等于产品UX人工通过。 |
| 依赖 | T23.a |
| 关联验收项 | AC-Q-03, AC-R-04 |
| 自动/证据验收断言 | p2_every_golden_has_review_entry；p2_sealed_baseline_is_immutable；p2_normal_compare_zero_diff；p2_missing_or_changed_sealed_file_fails；恢复后不自动update；review失败回原页修复。 |
| 命令ID | C-T23-b-1 |
| 定向命令说明 | flutter test test/uiux/golden/p2_golden_test.dart --reporter expanded；核对manifest与sealed目录hash一致。 |
| 人工观察（每场景≤3步） | 1. 按需求核对本页全部图或已证明等价组。<br>2. 登记每张图结论、审查身份及hash。<br>3. 不带update参数重跑比较并确认无diff。 |
| 证据绑定 | 证据绑定被验证对象、命令退出码、hash与环境；自检报告不等于真实产品运行。 |
| 资源/冲突 | lane:P2, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 只阻塞真正依赖此产物或资源的任务；不扩大权限，不清零重试预算。 |
| 回滚方式 | revert本任务提交；有消费该产物的下游时先回滚下游或阻塞；保留运行态证据，不回滚用户基线。 |
| 风险 | 自审冒充独立审批；大批review超粒度；达到上限仍未完成时拆本页批次子卡，不草率全PASS。 |
| 完成判定 | 自动/人工义务按kind分别记账；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T24 · 验证P3结构矩阵与无障碍

| 字段 | 合同 |
|---|---|
| ID / 名称 | T24 / 验证P3结构矩阵与无障碍 |
| Batch / Workstream / 规模 | B3 / P3 / ≤0.50人日 |
| 目标 | P3全部平台、宽度、主题及scale1/2结构断言有准确执行计数。 |
| 参考依据 | P3-01—05、D05/D06、R17 |
| 改动范围（逐文件/运行产物） | `test/uiux/p3/accessibility_test.dart`<br>`docs/plans/enterprise-uiux-v1/execution/P3_MATRIX.md` |
| 改哪个区块、改成什么 | 本卡只完成结构/语义/尺寸/对比度与键盘边界断言；golden生成与视觉审查拆至后两张卡。使用真实字体后才签精确文字几何；无取巧clamp/缩小字号。 |
| 依赖 | T21, T05.a |
| 关联验收项 | AC-P3-02, AC-Q-02, AC-Q-03, AC-Q-04, AC-R-04 |
| 自动/证据验收断言 | p3_matrix_all_expected_configs_executed；p3_semantics_labels_and_targets_valid；p3_text_and_enabled_icon_contrast_valid；p3_short_viewport_keyboard_focus_reachable；expected=executed、必需case无skip。 |
| 命令ID | C-T24-1 |
| 定向命令说明 | flutter test test/uiux/p3/accessibility_test.dart --reporter expanded |
| 人工观察（每场景≤3步） | 1. 查看本页结构矩阵计数。<br>2. 打开360宽大字和1280真实shell样张。<br>3. 核对不可达按钮、溢出及隐私语义反例均能失败。 |
| 证据绑定 | 结构矩阵记录配置ID及实际执行计数；golden生成/审查不在本卡冒充完成。 |
| 资源/冲突 | lane:P3, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 按钮挤出屏幕；Semantics恢复原始姓名；静态时间与真实格式不一致。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T24.a · 生成P3候选golden与差异包

| 字段 | 合同 |
|---|---|
| ID / 名称 | T24.a / 生成P3候选golden与差异包 |
| Batch / Workstream / 规模 | B3 / P3 / ≤0.50人日 |
| 目标 | 产生120个准确配置及before/after/diff，更新不是自动批准。 |
| 参考依据 | RESUME_PROTOCOL.md / TEST_CONTRACT.md |
| 改动范围（逐文件/运行产物） | `test/uiux/golden/p3_golden_test.dart`<br>`docs/plans/enterprise-uiux-v1/execution/P3_GOLDEN_MANIFEST.json`<br>`@runtime/golden/p3/candidates/` |
| 改哪个区块、改成什么 | 复用已存在golden优先；新测试必需baseline不存在即失败。仅运行本页update命令，候选输出写versioned目录，不覆盖已封存baseline。before取W0原场景截图；新控件无旧图必须标NEW_SCENARIO及设计断言，不用新图伪造before。 |
| 依赖 | T24 |
| 关联验收项 | AC-Q-03, AC-R-04, AC-Q-09 |
| 自动/证据验收断言 | p3_golden_manifest_count_is_120；matrix_config_id唯一；每图sha256/env/input/requirement/task齐全；missing_baseline_fails；image_update_does_not_approve；before只取原SHA。 |
| 命令ID | C-T24-a-1 |
| 定向命令说明 | flutter test test/uiux/golden/p3_golden_test.dart --update-goldens --reporter expanded；核对本页manifest；不得把退出0叫已批准。 |
| 人工观察（每场景≤3步） | 1. 查看本页manifest配置数量。<br>2. 打开本页before/after/diff样张。<br>3. 确认已封存旧图hash未被更新操作覆盖。 |
| 证据绑定 | 证据绑定被验证对象、命令退出码、hash与环境；自检报告不等于真实产品运行。 |
| 资源/冲突 | lane:P3, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 只阻塞真正依赖此产物或资源的任务；不扩大权限，不清零重试预算。 |
| 回滚方式 | revert本任务提交；有消费该产物的下游时先回滚下游或阻塞；保留运行态证据，不回滚用户基线。 |
| 风险 | 整仓update抹掉回归；只比较新图与自身；ignored PNG未保留。 |
| 完成判定 | 自动/人工义务按kind分别记账；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T24.b · 审查并封存P3视觉基线

| 字段 | 合同 |
|---|---|
| ID / 名称 | T24.b / 审查并封存P3视觉基线 |
| Batch / Workstream / 规模 | B3 / P3 / ≤0.50人日 |
| 目标 | 按需求逐图或可证明等价的图组审查，再只读普通比较。 |
| 参考依据 | RESUME_PROTOCOL.md / TEST_CONTRACT.md |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P3_GOLDEN_REVIEW.md`<br>`@runtime/golden/p3/sealed/` |
| 改哪个区块、改成什么 | 每张图必须有review结果与差异理由；完全相同像素且语义断言一致可组审但manifest仍逐配置。记录reviewer身份/SELF_REVIEW_ONLY或INDEPENDENT；没有独立审查工具不伪造。封存工程基线不等于产品UX人工通过。 |
| 依赖 | T24.a |
| 关联验收项 | AC-Q-03, AC-R-04 |
| 自动/证据验收断言 | p3_every_golden_has_review_entry；p3_sealed_baseline_is_immutable；p3_normal_compare_zero_diff；p3_missing_or_changed_sealed_file_fails；恢复后不自动update；review失败回原页修复。 |
| 命令ID | C-T24-b-1 |
| 定向命令说明 | flutter test test/uiux/golden/p3_golden_test.dart --reporter expanded；核对manifest与sealed目录hash一致。 |
| 人工观察（每场景≤3步） | 1. 按需求核对本页全部图或已证明等价组。<br>2. 登记每张图结论、审查身份及hash。<br>3. 不带update参数重跑比较并确认无diff。 |
| 证据绑定 | 证据绑定被验证对象、命令退出码、hash与环境；自检报告不等于真实产品运行。 |
| 资源/冲突 | lane:P3, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 只阻塞真正依赖此产物或资源的任务；不扩大权限，不清零重试预算。 |
| 回滚方式 | revert本任务提交；有消费该产物的下游时先回滚下游或阻塞；保留运行态证据，不回滚用户基线。 |
| 风险 | 自审冒充独立审批；大批review超粒度；达到上限仍未完成时拆本页批次子卡，不草率全PASS。 |
| 完成判定 | 自动/人工义务按kind分别记账；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T25 · 回归频道原业务调用

| 字段 | 合同 |
|---|---|
| ID / 名称 | T25 / 回归频道原业务调用 |
| Batch / Workstream / 规模 | B3 / P1 / ≤0.50人日 |
| 目标 | P1展示重排前后的关键请求和导航trace一致。 |
| 参考依据 | PRD §1、P1全部、C02/C04 |
| 改动范围（逐文件/运行产物） | `test/uiux/p1/behavior_regression_test.dart`<br>`docs/plans/enterprise-uiux-v1/execution/P1_REGRESSION.md` |
| 改哪个区块、改成什么 | 不新增业务实现；若发现业务缺陷记录OUT_OF_SCOPE，不能以本卡修后端/分页规则。 |
| 依赖 | T10, T11, T12, T13, T15 |
| 关联验收项 | AC-P1-01, AC-Q-05, AC-R-04 |
| 自动/证据验收断言 | p1_search_submit_trace_equals_baseline；p1_filter_toggle_has_zero_network_delta；p1_publish_visibility_and_callback_unchanged；p1_stats_disabled_request_count_unchanged；既有channel定向测试全通过。 |
| 命令ID | C-T25-1, C-LEGACY-P1 |
| 定向命令说明 | flutter test test/uiux/p1/behavior_regression_test.dart；flutter test test/unit_test/page/channel |
| 人工观察（每场景≤3步） | 1. 进入可发布与只读频道。<br>2. 分别搜索、筛选、滚动加载。<br>3. 核对发布入口和返回行为仍按原权限工作。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P1, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 基线trace本身有bug被固化；把预期展示变化当业务变化。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T26 · 回归工作台权限与免登调用

| 字段 | 合同 |
|---|---|
| ID / 名称 | T26 / 回归工作台权限与免登调用 |
| Batch / Workstream / 规模 | B3 / P2 / ≤0.50人日 |
| 目标 | 入口外观变化不改变原可见性、目的地和免登时机。 |
| 参考依据 | PRD §1、P2全部、C05/C06 |
| 改动范围（逐文件/运行产物） | `test/uiux/p2/behavior_regression_test.dart`<br>`docs/plans/enterprise-uiux-v1/execution/P2_REGRESSION.md` |
| 改哪个区块、改成什么 | 采用W0冻结的既有OA/enterprise测试入口；网络/外部OA缺失单独BLOCKED_ENV，不改客户端鉴权解决。 |
| 依赖 | T18 |
| 关联验收项 | AC-P2-03, AC-P2-05, AC-Q-05, AC-R-04 |
| 自动/证据验收断言 | p2_gate_truth_table_unchanged；p2_app_open_does_not_prefetch_auth_code；p2_bridge_callback_preserved；p2_inbound_login_route_preserved；URL隐藏断言和点击目标断言同时通过。 |
| 命令ID | C-T26-1, C-LEGACY-P2 |
| 定向命令说明 | flutter test test/uiux/p2/behavior_regression_test.dart；运行commands.json中已核实的P2既有定向测试 |
| 人工观察（每场景≤3步） | 1. 普通成员和合格坐席分别进入工作台。<br>2. 点击应用及Android确认登录入口。<br>3. 核对权限、目的页及现有免登成功/失败表现未变化。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P2, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 误把本地模拟免登PASS说成真实OA联调PASS。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T27 · 回归坐席接单分页与隔离

| 字段 | 合同 |
|---|---|
| ID / 名称 | T27 / 回归坐席接单分页与隔离 |
| Batch / Workstream / 规模 | B3 / P3 / ≤0.50人日 |
| 目标 | 三态展示修改不改变作用域/CAS/分页/SSE/打开会话行为。 |
| 参考依据 | PRD §1、P3-05、C07—C09 |
| 改动范围（逐文件/运行产物） | `test/uiux/p3/behavior_regression_test.dart`<br>`docs/plans/enterprise-uiux-v1/execution/P3_REGRESSION.md` |
| 改哪个区块、改成什么 | 仅测试/证据；CAS/权限缺陷必须登记越界，不能更改_csApi/_claim相关逻辑。 |
| 依赖 | T21 |
| 关联验收项 | AC-P3-04, AC-Q-05, AC-R-04 |
| 自动/证据验收断言 | p3_claim_sends_original_expected_version_and_scope；p3_double_tap_claim_once；p3_409_capacity_forbidden_branches_unchanged；p3_tab_counts_server_only；p3_cursor_and_sse_refresh_unchanged；原customer_service目录通过。 |
| 命令ID | C-T27-1, C-LEGACY-P3 |
| 定向命令说明 | flutter test test/uiux/p3/behavior_regression_test.dart；flutter test test/customer_service |
| 人工观察（每场景≤3步） | 1. 在测试环境接入一条待接会话。<br>2. 切换处理中并打开该会话。<br>3. 观察已有冲突/无权限fixture不显示伪成功。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | lane:P3, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | UI测试改变原API调用顺序；刷新计数被客户端重新推算。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T28 · 演练中断恢复与证据失效

| 字段 | 合同 |
|---|---|
| ID / 名称 | T28 / 演练中断恢复与证据失效 |
| Batch / Workstream / 规模 | B4 / COORD / ≤0.50人日 |
| 目标 | 协议模拟通过，真实跨会话恢复是否完成有独立证据。 |
| 参考依据 | R18、RESUME_PROTOCOL §6/8 |
| 改动范围（逐文件/运行产物） | `tool/uiux/recovery_contract_test.py`<br>`docs/plans/enterprise-uiux-v1/execution/RECOVERY_DRILL.md` |
| 改哪个区块、改成什么 | 导入并调用T04.a/b/c实际实现的范围、锁与状态模块，在临时Git仓库/子进程执行故障注入；禁止复制第二套“预期行为”模拟器来证明自己正确。真实跨会话证据独立在T28.m，不是本卡自动PASS前置。 |
| 依赖 | T04.a, T04.c |
| 关联验收项 | AC-R-02, AC-R-04, AC-R-07 |
| 自动/证据验收断言 | recovery_reuses_registered_worktree；recovery_adopts_committed_unrecorded_task；recovery_rejects_live_lock；recovery_marks_changed_tree_stale；recovery_preserves_foreign_dirty；原工程演练无破坏；跨会话未实做则MANUAL_PENDING。；至少覆盖RECOVERY_CASES.json的全部案例；每个用例记录实际repo/worktree列表、HEAD、state txid与exitcode；失败返回非0。 |
| 命令ID | C-RECOVERY, C-STATE |
| 定向命令说明 | python3 tool/uiux/recovery_contract_test.py；python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1 |
| 人工观察（每场景≤3步） | 1. 运行临时Git故障注入套件。<br>2. 核对各预期拒绝/恢复结果及退出码。<br>3. 确认真实仓库worktree和dirty哈希未变化。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | integration-writer |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 为了模拟崩溃破坏真实dirty文件；锁超时即抢占；把模拟演练当真实恢复。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T28.m · 验证真实新会话接续原工作树

| 字段 | 合同 |
|---|---|
| ID / 名称 | T28.m / 验证真实新会话接续原工作树 |
| Batch / Workstream / 规模 | B4 / COORD / ≤0.25人日 |
| 目标 | 在真实执行器新会话中确认原路径、分支、基线及下一任务全部正确。 |
| 参考依据 | RESUME_PROTOCOL.md / TEST_CONTRACT.md |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/CROSS_SESSION_RESUME.md` |
| 改哪个区块、改成什么 | 原会话先checkpoint并释放已确认无活worker的admission；用户或执行器实际发起新会话并粘贴同一提示词。此卡可在任一安全checkpoint触发，不要求等所有页面完成；未发生重启时MANUAL_PENDING。 |
| 依赖 | T04.c, T28 |
| 关联验收项 | AC-R-03 |
| 自动/证据验收断言 | before/after session_id不同；repo/common-dir/integration与lane路径/base_sha相同；未额外新建工作树；未重复提交；next_task根据持久状态正确。 |
| 命令ID | C-STATE |
| 定向命令说明 | python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1；记录真实两次会话checkpoint的证据。 |
| 人工观察（每场景≤3步） | 1. 保存checkpoint并结束当前执行会话。<br>2. 在新会话粘贴同一EXECUTION_PROMPT全文。<br>3. 核对原worktree与下一卡，保存两次会话证据。 |
| 证据绑定 | 证据绑定被验证对象、命令退出码、hash与环境；自检报告不等于真实产品运行。 |
| 资源/冲突 | integration-writer |
| 失败处理 | 只阻塞真正依赖此产物或资源的任务；不扩大权限，不清零重试预算。 |
| 回滚方式 | revert本任务提交；有消费该产物的下游时先回滚下游或阻塞；保留运行态证据，不回滚用户基线。 |
| 风险 | 同进程调用两次函数不是跨会话；缺原工作树不能保证找回未提交内容。 |
| 完成判定 | 自动/人工义务按kind分别记账；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T29 · 验证最终集成候选门禁

| 字段 | 合同 |
|---|---|
| ID / 名称 | T29 / 验证最终集成候选门禁 |
| Batch / Workstream / 规模 | B4 / COORD / ≤0.50人日 |
| 目标 | 对同一冻结候选树完成所有自动门，无旧证据冒用。 |
| 参考依据 | PRD §2/7、TASKS §6 |
| 改动范围（逐文件/运行产物） | `@runtime/evidence/final/`<br>`@runtime/candidate_seal.json`<br>`docs/plans/enterprise-uiux-v1/execution/FINAL_GATES.md` |
| 改哪个区块、改成什么 | 冻结干净集成候选K与tree，所有门只对K运行；日志/结果写外置runtime，不改K。报告提交R只能在门结束后由T33生成；K与R明确区分。历史失败可保留范围完成事实，但自动等级必须PARTIAL_BLOCKED。 所有门结束后可为T29单独提交report-only FINAL_GATES记录（R_gate），候选证书仍指K；不得在门执行中写此记录。 |
| 依赖 | T22.b, T23.b, T24.b, T25, T26, T27, T28 |
| 关联验收项 | AC-Q-01, AC-Q-05, AC-Q-07, AC-R-04, AC-Q-09, AC-Q-10 |
| 自动/证据验收断言 | candidate_K_clean；all_required_gates_same_K_and_environment；target_suite_expected_tests_executed_no_skip；full_flutter_exit_0_no_unexplained_new_skips；golden_baselines_present_and_hashed；scope/frozen-symbol/check_state通过；任何测试中源输入变化=STALE；candidate_seal在所有门通过后写入。 |
| 命令ID | C-RECOVERY, C-STATE, C-SCOPE, C-ANALYZE, C-TARGET-ALL, C-FULL, C-DIFF-CHECK |
| 定向命令说明 | 按TEST_CONTRACT §5执行最终门；所有命令在K上，报告不在测试中写入Git树。 |
| 人工观察（每场景≤3步） | 1. 打开最终候选测试记录。<br>2. 核对所有记录对应相同候选树和SDK。<br>3. 核对原仓库/后端/Admin未被修改。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | integration-writer, flutter-sdk:${SDK_REALPATH_HASH} |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 修改golden后未普通比对；全量失败被记为历史忽略；多个worktree日志混用。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T30 · 验收P1的iOS原生流程

| 字段 | 合同 |
|---|---|
| ID / 名称 | T30 / 验收P1的iOS原生流程 |
| Batch / Workstream / 规模 | B4 / P1 / ≤0.25人日 |
| 目标 | 只验证P1在iOS上的原生UI；不把其他平台混入同卡。 |
| 参考依据 | P1-01—07、PRD §7 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P1_MANUAL_ios.md` |
| 改哪个区块、改成什么 | 采用NATIVE_CASES.json预置单场景脚本，每个场景观察动作≤3步；数据/账号/设备准备单列前置，不藏在步骤内。测试只在已授权环境；缺条件MANUAL_PENDING。 |
| 依赖 | T29 |
| 关联验收项 | AC-M-P1 |
| 自动/证据验收断言 | P1/iOS所有必需case有case_id、build_sha、OS、device、theme、system-font、观察及证据路径；只验证此平台；其他平台不计入本卡；失败不可改成缺环境。 |
| 命令ID | C-STATE |
| 定向命令说明 | 记录NATIVE_CASES.json中本页本平台case结果；python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1仅校验记录，不能代替真实观察。 |
| 人工观察（每场景≤3步） | 1. 按本平台case表进入指定页面或状态。<br>2. 只执行该case指定的一项交互。<br>3. 核对断言并保存截图/录屏或读屏记录。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | device:iOS |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 抢占其他任务真机；系统最大字体不等于精确TextScaler2，混淆两类证据。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T30.a · 验收P1的Android原生流程

| 字段 | 合同 |
|---|---|
| ID / 名称 | T30.a / 验收P1的Android原生流程 |
| Batch / Workstream / 规模 | B4 / P1 / ≤0.25人日 |
| 目标 | 只验证P1在Android上的原生UI；不把其他平台混入同卡。 |
| 参考依据 | P1-01—07、PRD §7 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P1_MANUAL_android.md` |
| 改哪个区块、改成什么 | 采用NATIVE_CASES.json预置单场景脚本，每个场景观察动作≤3步；数据/账号/设备准备单列前置，不藏在步骤内。测试只在已授权环境；缺条件MANUAL_PENDING。 |
| 依赖 | T29 |
| 关联验收项 | AC-M-P1 |
| 自动/证据验收断言 | P1/Android所有必需case有case_id、build_sha、OS、device、theme、system-font、观察及证据路径；只验证此平台；其他平台不计入本卡；失败不可改成缺环境。 |
| 命令ID | C-STATE |
| 定向命令说明 | 记录NATIVE_CASES.json中本页本平台case结果；python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1仅校验记录，不能代替真实观察。 |
| 人工观察（每场景≤3步） | 1. 按本平台case表进入指定页面或状态。<br>2. 只执行该case指定的一项交互。<br>3. 核对断言并保存截图/录屏或读屏记录。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | device:Android |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 抢占其他任务真机；系统最大字体不等于精确TextScaler2，混淆两类证据。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T30.b · 验收P1的macOS原生流程

| 字段 | 合同 |
|---|---|
| ID / 名称 | T30.b / 验收P1的macOS原生流程 |
| Batch / Workstream / 规模 | B4 / P1 / ≤0.25人日 |
| 目标 | 只验证P1在macOS上的原生UI；不把其他平台混入同卡。 |
| 参考依据 | P1-01—07、PRD §7 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P1_MANUAL_macos.md` |
| 改哪个区块、改成什么 | 采用NATIVE_CASES.json预置单场景脚本，每个场景观察动作≤3步；数据/账号/设备准备单列前置，不藏在步骤内。测试只在已授权环境；缺条件MANUAL_PENDING。 |
| 依赖 | T29 |
| 关联验收项 | AC-M-P1 |
| 自动/证据验收断言 | P1/macOS所有必需case有case_id、build_sha、OS、device、theme、system-font、观察及证据路径；只验证此平台；其他平台不计入本卡；失败不可改成缺环境。 |
| 命令ID | C-STATE |
| 定向命令说明 | 记录NATIVE_CASES.json中本页本平台case结果；python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1仅校验记录，不能代替真实观察。 |
| 人工观察（每场景≤3步） | 1. 按本平台case表进入指定页面或状态。<br>2. 只执行该case指定的一项交互。<br>3. 核对断言并保存截图/录屏或读屏记录。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | device:macOS |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 抢占其他任务真机；系统最大字体不等于精确TextScaler2，混淆两类证据。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T31 · 验收P2的iOS原生流程

| 字段 | 合同 |
|---|---|
| ID / 名称 | T31 / 验收P2的iOS原生流程 |
| Batch / Workstream / 规模 | B4 / P2 / ≤0.25人日 |
| 目标 | 只验证P2在iOS上的原生UI；不把其他平台混入同卡。 |
| 参考依据 | P2-01—05、PRD §7 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P2_MANUAL_ios.md` |
| 改哪个区块、改成什么 | 采用NATIVE_CASES.json预置单场景脚本，每个场景观察动作≤3步；数据/账号/设备准备单列前置，不藏在步骤内。测试只在已授权环境；缺条件MANUAL_PENDING。 |
| 依赖 | T29 |
| 关联验收项 | AC-M-P2 |
| 自动/证据验收断言 | P2/iOS所有必需case有case_id、build_sha、OS、device、theme、system-font、观察及证据路径；只验证此平台；其他平台不计入本卡；失败不可改成缺环境。 |
| 命令ID | C-STATE |
| 定向命令说明 | 记录NATIVE_CASES.json中本页本平台case结果；python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1仅校验记录，不能代替真实观察。 |
| 人工观察（每场景≤3步） | 1. 按本平台case表进入指定页面或状态。<br>2. 只执行该case指定的一项交互。<br>3. 核对断言并保存截图/录屏或读屏记录。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | device:iOS |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 把隐藏地址理解为生产OA验收；权限角色只有一种就宣称全通过。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T31.a · 验收P2的Android原生流程

| 字段 | 合同 |
|---|---|
| ID / 名称 | T31.a / 验收P2的Android原生流程 |
| Batch / Workstream / 规模 | B4 / P2 / ≤0.25人日 |
| 目标 | 只验证P2在Android上的原生UI；不把其他平台混入同卡。 |
| 参考依据 | P2-01—05、PRD §7 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P2_MANUAL_android.md` |
| 改哪个区块、改成什么 | 采用NATIVE_CASES.json预置单场景脚本，每个场景观察动作≤3步；数据/账号/设备准备单列前置，不藏在步骤内。测试只在已授权环境；缺条件MANUAL_PENDING。 |
| 依赖 | T29 |
| 关联验收项 | AC-M-P2 |
| 自动/证据验收断言 | P2/Android所有必需case有case_id、build_sha、OS、device、theme、system-font、观察及证据路径；只验证此平台；其他平台不计入本卡；失败不可改成缺环境。 |
| 命令ID | C-STATE |
| 定向命令说明 | 记录NATIVE_CASES.json中本页本平台case结果；python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1仅校验记录，不能代替真实观察。 |
| 人工观察（每场景≤3步） | 1. 按本平台case表进入指定页面或状态。<br>2. 只执行该case指定的一项交互。<br>3. 核对断言并保存截图/录屏或读屏记录。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | device:Android |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 把隐藏地址理解为生产OA验收；权限角色只有一种就宣称全通过。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T31.b · 验收P2的macOS原生流程

| 字段 | 合同 |
|---|---|
| ID / 名称 | T31.b / 验收P2的macOS原生流程 |
| Batch / Workstream / 规模 | B4 / P2 / ≤0.25人日 |
| 目标 | 只验证P2在macOS上的原生UI；不把其他平台混入同卡。 |
| 参考依据 | P2-01—05、PRD §7 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P2_MANUAL_macos.md` |
| 改哪个区块、改成什么 | 采用NATIVE_CASES.json预置单场景脚本，每个场景观察动作≤3步；数据/账号/设备准备单列前置，不藏在步骤内。测试只在已授权环境；缺条件MANUAL_PENDING。 |
| 依赖 | T29 |
| 关联验收项 | AC-M-P2 |
| 自动/证据验收断言 | P2/macOS所有必需case有case_id、build_sha、OS、device、theme、system-font、观察及证据路径；只验证此平台；其他平台不计入本卡；失败不可改成缺环境。 |
| 命令ID | C-STATE |
| 定向命令说明 | 记录NATIVE_CASES.json中本页本平台case结果；python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1仅校验记录，不能代替真实观察。 |
| 人工观察（每场景≤3步） | 1. 按本平台case表进入指定页面或状态。<br>2. 只执行该case指定的一项交互。<br>3. 核对断言并保存截图/录屏或读屏记录。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | device:macOS |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 把隐藏地址理解为生产OA验收；权限角色只有一种就宣称全通过。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T32 · 验收P3的iOS原生流程

| 字段 | 合同 |
|---|---|
| ID / 名称 | T32 / 验收P3的iOS原生流程 |
| Batch / Workstream / 规模 | B4 / P3 / ≤0.25人日 |
| 目标 | 只验证P3在iOS上的原生UI；不把其他平台混入同卡。 |
| 参考依据 | P3-01—05、PRD §7 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P3_MANUAL_ios.md` |
| 改哪个区块、改成什么 | 采用NATIVE_CASES.json预置单场景脚本，每个场景观察动作≤3步；数据/账号/设备准备单列前置，不藏在步骤内。测试只在已授权环境；缺条件MANUAL_PENDING。 |
| 依赖 | T29 |
| 关联验收项 | AC-M-P3 |
| 自动/证据验收断言 | P3/iOS所有必需case有case_id、build_sha、OS、device、theme、system-font、观察及证据路径；只验证此平台；其他平台不计入本卡；失败不可改成缺环境。 |
| 命令ID | C-STATE |
| 定向命令说明 | 记录NATIVE_CASES.json中本页本平台case结果；python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1仅校验记录，不能代替真实观察。 |
| 人工观察（每场景≤3步） | 1. 按本平台case表进入指定页面或状态。<br>2. 只执行该case指定的一项交互。<br>3. 核对断言并保存截图/录屏或读屏记录。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | device:iOS |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 测试证据包含原始客户数据；后台无数据而伪造运行通过。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T32.a · 验收P3的Android原生流程

| 字段 | 合同 |
|---|---|
| ID / 名称 | T32.a / 验收P3的Android原生流程 |
| Batch / Workstream / 规模 | B4 / P3 / ≤0.25人日 |
| 目标 | 只验证P3在Android上的原生UI；不把其他平台混入同卡。 |
| 参考依据 | P3-01—05、PRD §7 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P3_MANUAL_android.md` |
| 改哪个区块、改成什么 | 采用NATIVE_CASES.json预置单场景脚本，每个场景观察动作≤3步；数据/账号/设备准备单列前置，不藏在步骤内。测试只在已授权环境；缺条件MANUAL_PENDING。 |
| 依赖 | T29 |
| 关联验收项 | AC-M-P3 |
| 自动/证据验收断言 | P3/Android所有必需case有case_id、build_sha、OS、device、theme、system-font、观察及证据路径；只验证此平台；其他平台不计入本卡；失败不可改成缺环境。 |
| 命令ID | C-STATE |
| 定向命令说明 | 记录NATIVE_CASES.json中本页本平台case结果；python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1仅校验记录，不能代替真实观察。 |
| 人工观察（每场景≤3步） | 1. 按本平台case表进入指定页面或状态。<br>2. 只执行该case指定的一项交互。<br>3. 核对断言并保存截图/录屏或读屏记录。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | device:Android |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 测试证据包含原始客户数据；后台无数据而伪造运行通过。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T32.b · 验收P3的macOS原生流程

| 字段 | 合同 |
|---|---|
| ID / 名称 | T32.b / 验收P3的macOS原生流程 |
| Batch / Workstream / 规模 | B4 / P3 / ≤0.25人日 |
| 目标 | 只验证P3在macOS上的原生UI；不把其他平台混入同卡。 |
| 参考依据 | P3-01—05、PRD §7 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/P3_MANUAL_macos.md` |
| 改哪个区块、改成什么 | 采用NATIVE_CASES.json预置单场景脚本，每个场景观察动作≤3步；数据/账号/设备准备单列前置，不藏在步骤内。测试只在已授权环境；缺条件MANUAL_PENDING。 |
| 依赖 | T29 |
| 关联验收项 | AC-M-P3 |
| 自动/证据验收断言 | P3/macOS所有必需case有case_id、build_sha、OS、device、theme、system-font、观察及证据路径；只验证此平台；其他平台不计入本卡；失败不可改成缺环境。 |
| 命令ID | C-STATE |
| 定向命令说明 | 记录NATIVE_CASES.json中本页本平台case结果；python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1仅校验记录，不能代替真实观察。 |
| 人工观察（每场景≤3步） | 1. 按本平台case表进入指定页面或状态。<br>2. 只执行该case指定的一项交互。<br>3. 核对断言并保存截图/录屏或读屏记录。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | device:macOS |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 测试证据包含原始客户数据；后台无数据而伪造运行通过。 |
| 完成判定 | 全部自动断言有当前输入的成功证据；缺证据不通过。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

### T33 · 汇总验收与交付候选

| 字段 | 合同 |
|---|---|
| ID / 名称 | T33 / 汇总验收与交付候选 |
| Batch / Workstream / 规模 | B4 / COORD / ≤0.25人日 |
| 目标 | 无论成功、失败或阻塞，都输出带证据的当前报告；报告成功不代表产品成功。 |
| 参考依据 | PRD §2/8/9、全部验收项 |
| 改动范围（逐文件/运行产物） | `docs/plans/enterprise-uiux-v1/execution/FINAL_REPORT.md`<br>`docs/plans/enterprise-uiux-v1/execution/STATUS.md`<br>`docs/plans/enterprise-uiux-v1/execution/ACCEPTANCE_RESULTS.json`<br>`docs/plans/enterprise-uiux-v1/execution/ACCEPTANCE_RESULTS.md` |
| 改哪个区块、改成什么 | 调度器每批末、暂停前、无READY任务时均可触发；只依赖已登记现场。先写外置报告；需要提交时单独report-only提交R，指向已验证候选K。初始报告无K时明确NOT_VERIFIED；保留每次report revision。 报告只由明确事件触发，非报告输入hash未变时不重复写/提交；自身report_revision、heartbeat、R提交不触发下一轮报告，避免无READY时无限汇报。 |
| 依赖 | T00 |
| 关联验收项 | AC-R-04, AC-R-05, AC-Q-10, AC-R-08 |
| 自动/证据验收断言 | report_runs_when_T29_failed_or_blocked；每项AC有auto/manual/recovery状态；LOCAL等级由gate结果计算，不能由报告exitcode决定；R只改REPORT_ONLY_ALLOWLIST；记录K与R不同，不宣称R全量已测。；report_same_input_is_idempotent；report_written_event_does_not_requeue_itself。 |
| 命令ID | C-PACKAGE |
| 定向命令说明 | C-PACKAGE；工具可用后运行check_state；报告提交执行git diff --name-status "$UIUX_CANDIDATE_SHA" HEAD与报告白名单校验。 |
| 人工观察（每场景≤3步） | 1. 打开FINAL_REPORT和验收清单。<br>2. 抽取P1/P2/P3各一项核对commit、日志、截图。<br>3. 确认交接写明原worktree和所有待验/阻塞项。 |
| 证据绑定 | 精确记录candidate/lane SHA、待提交tree、输入清单hash、环境hash、argv/cwd/退出码与日志hash；无退出码=INCOMPLETE。 |
| 资源/冲突 | integration-writer |
| 失败处理 | 范围内缺陷→同页修复卡并回归；范围外缺陷→关联受影响AC且局部阻塞；继续其他READY卡。 |
| 回滚方式 | revert本卡单个功能提交（含测试）；已有下游依赖先回滚下游或将其BLOCKED。禁止回滚用户基线提交。 |
| 风险 | 把未验勾成完成；将外部计划问题吞入本任务；交付只留聊天历史。 |
| 完成判定 | REPORT_WRITTEN表示已汇报；当前report snapshot不是任务永久完结或LOCAL_CANDIDATE_PASS。 |
| 提交要求 | Conventional Commit；UIUX-Plan与UIUX-Task trailer；精确暂存；不回滚原基线/不push。报告型提交只证明报告记录，不冒充新HEAD产品已测。 |

## 6. 门禁命令与收口

每卡“命令ID”可在COMMANDS.json找到argv/cwd/producer/成功条件；本机动态项在T04生成commands.resolved.json。详见[TEST_CONTRACT](TEST_CONTRACT.md)第5节各Batch命令。首次T00—T03不得调用未创建的检查器；自卡创建的测试只能在该卡实现后验证，不能在READY前要求自己已通过。

B0记录旧测试基线；B1运行结构/本地化/fixture及analyze；B2按页跑定向测试/scope/analyze；B3运行结构、单页golden普通比较、旧回归与scope/analyze；B4只在干净K运行最终全量。任何空目录、缺图、必需case skip、无exitcode、错tree/环境都不是PASS。

T33只输出报告快照；K通过才LOCAL_CANDIDATE_PASS，九张平台卡通过才UX_ACCEPTED；T28.m真实会话恢复单列。失败或缺设备可以报告PARTIAL_BLOCKED/MANUAL_PENDING，不能删除需求、改后台或新建工作树规避。

完整逐项勾选义务见ACCEPTANCE.md。运行时将实际勾选结果写execution/ACCEPTANCE_RESULTS.json/md，不修改静态验收合同以制造通过。
