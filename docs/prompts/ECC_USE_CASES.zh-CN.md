# IMBoy ECC 使用案例 / Flutter

 > 本文是可直接复制到 Codex 会话的 ECC 使用案例库。每个案例均可独立复制，以 `$skill-name` 开头。原 72 个工程案例各提供一个提示词；新增功能场景提供 A 新增功能、B 优化现有功能、C 测试现有功能三个独立提示词。
>
> **使用约定**
> - 在已安装 ECC 的 Codex 会话中，复制单个案例的完整代码块执行。
> - 先确认当前工作目录和目标仓库；跨仓案例需明确各仓库实际 checkout 路径。
> - 仓库内 AGENTS.md、CLAUDE.md、项目架构文档、测试执行合同和安全规则优先于 ECC 通用建议。
> - 提示词中的“只读”案例不得修改文件；实施案例仅允许修改当前任务必需文件。
> - 默认不得 commit、push、合并、部署、执行生产写入或接触真实用户数据；需要时另行授权。
> - 不得通过删除/弱化测试、扩大 skip、关闭门禁或伪造证据制造 PASS。
> - 报告实际执行的命令、退出码、结果、未执行项和证据位置；未执行不得声称通过。
>
> **案例编号全局唯一**：ECC-001 至 ECC-121。四个仓库按职责分配，后端主仓提供统一索引。

## 本仓库范围

本文件包含 Flutter 工程案例 13 个，以及 Flutter 客户场景复刻/功能迭代案例 14 个；合计 27 个（ECC-002、023–034、090–101、117–118）。

> **时间估算说明**：时间为单个案例的一次 A/B/C 模式执行预算，包含仓库阅读、代码分析、必要实施及相关验证；不是保证完成时间。A/B/C 只能选择一种执行。30 分钟及以上建议安排 ZCODE 闲时任务。遇到缺少设备、数据库、凭据、外部服务或需求决策时，应报告 BLOCKED/NOT RUN，不能为了符合预算而跳过验证。复杂度按当前仓库结构与案例提示词范围估算，实际会随工作树状态、测试环境和缺陷数量变化。
## 案例清单

### 项目理解与架构分析

#### ECC-002 · Flutter 多端架构梳理

**预计执行时间：45 分钟**（单次执行；包含代码阅读、定向实施/分析与相关验证）

**Skills：** `codebase-onboarding`

```text
$codebase-onboarding

只读分析 imboy-flutter。梳理 Android、iOS、macOS、Web 架构，重点分析 Riverpod、go_router、MVVM、Repository、SQLite/SQLCipher、WebSocket、WebRTC、E2EE 和平台适配。输出真实入口、模块地图、关键调用链、现有硬约束和技术债，不创建文件。
```

### Flutter 多端客户端

#### ECC-023 · 新增聊天消息功能

**预计执行时间：60 分钟**（单次执行；包含代码阅读、定向实施/分析与相关验证）

**Skills：** `dart-flutter-patterns` · `tdd-workflow`

```text
$dart-flutter-patterns $tdd-workflow

在 imboy-flutter 新增指定聊天消息功能。先检查 messaging 模块、MessagingFacade、MessageRepository、消息模型和 UI 组件。遵循 Riverpod、Repository 和模块公开边界。先写测试再实现，复用已有能力，完成后运行对应测试。
```

#### ECC-024 · Riverpod 状态管理治理

**预计执行时间：45 分钟**（单次执行；包含代码阅读、定向实施/分析与相关验证）

**Skills：** `flutter-dart-code-review` · `change-impact`

```text
$flutter-dart-code-review $change-impact

审计 Riverpod 状态管理。检查 Provider 生命周期、重复请求、无效刷新、异步竞态、状态污染和跨账号状态泄漏。找出可复现问题，提出最小改进方案；未经授权不做全局重构。
```

#### ECC-025 · SQLite 数据库迁移

**预计执行时间：60 分钟**（单次执行；包含代码阅读、定向实施/分析与相关验证）

**Skills：** `change-impact` · `tdd-workflow` · `test-collaboration`

```text
$change-impact $tdd-workflow $test-collaboration

审查或实施 SQLite 数据库迁移。以 lib/service/migrations/manifest_all.dart 为唯一真源，检查版本升级、降级、旧数据保留、账号隔离、事务中断和重放。运行对应 sqlite migration gate，不维护旁路迁移副本。
```

#### ECC-026 · E2EE 密钥备份与恢复

**预计执行时间：90 分钟**（单次执行；包含代码阅读、定向实施/分析与相关验证）

**Skills：** `security-review` · `test-collaboration`

```text
$security-review $test-collaboration

审计 E2EE 密钥备份、恢复、导入、导出和设备切换流程。检查密钥生命周期、加密边界、错误恢复、敏感日志和账号隔离。列出真实代码路径与测试缺口，不读取、打印或修改真实密钥和用户数据。
```

#### ECC-027 · WebSocket 重连和消息 ACK

**预计执行时间：60 分钟**（单次执行；包含代码阅读、定向实施/分析与相关验证）

**Skills：** `change-impact` · `tdd-workflow`

```text
$change-impact $tdd-workflow

分析客户端 WebSocket 断线重连、登录恢复、消息 ACK、重复消息去重和离线同步。覆盖网络切换、应用后台恢复、设备切换和连接连续失败场景。优先复用现有服务和测试框架，先补回归测试。
```

#### ECC-028 · 附件上传断点续传

**预计执行时间：90 分钟**（单次执行；包含代码阅读、定向实施/分析与相关验证）

**Skills：** `tdd-workflow` · `module-regression`

```text
$tdd-workflow $module-regression

审查附件上传任务持久化检查点和恢复逻辑。检查任务重启、重复上传、网络中断、文件变化、账号切换及服务端确认。复用 attachment_upload_task 机制，不重复实现任务队列。
```

#### ECC-029 · 四平台行为差异

**预计执行时间：60 分钟**（单次执行；包含代码阅读、定向实施/分析与相关验证）

**Skills：** `test-collaboration` · `parallel-execution-optimizer`

```text
$test-collaboration $parallel-execution-optimizer

分析 Android、iOS、macOS、Web 测试覆盖。按系统权限、SQLite、WebSocket、WebRTC、文件系统和推送拆分测试义务。使用 test/auto_test/execution_contract.json 生成精确矩阵。缺设备或环境标记 BLOCKED，不得判定 PASS。
```

#### ECC-030 · Widget 无障碍检查

**预计执行时间：20 分钟**（单次执行；包含代码阅读、定向实施/分析与相关验证）

**Skills：** `flutter-dart-code-review` · `test-collaboration`

```text
$flutter-dart-code-review $test-collaboration

检查核心聊天、联系人、群组、登录页面的 Semantics、焦点顺序、键盘操作、屏幕阅读器和触控目标。结合 DESIGN.md 和现有 UI 测试约束，输出真实问题及回归用例。
```

#### ECC-031 · 路由与登录守卫

**预计执行时间：45 分钟**（单次执行；包含代码阅读、定向实施/分析与相关验证）

**Skills：** `dart-flutter-patterns` · `tdd-workflow`

```text
$dart-flutter-patterns $tdd-workflow

审计 go_router 路由、登录状态、权限守卫、深链接和退出登录跳转。验证未登录访问、Token 失效、账号切换、页面恢复和非法路由。优先扩展已有路由体系，不引入第二套路由机制。
```

#### ECC-032 · PR/Full 测试计划

**预计执行时间：60 分钟**（单次执行；包含代码阅读、定向实施/分析与相关验证）

**Skills：** `test-collaboration` · `verification-loop`

```text
$test-collaboration $verification-loop

分析 test/auto_test/execution_contract.json 和 docs/testing/execution.md。为当前变更生成精确 PR 验证计划，列出目标、平台、依赖、命令、预期证据和阻塞条件。不得用 all_tests.dart 或零执行结果冒充全量回归。
```

#### ECC-033 · Flutter 模块边界治理

**预计执行时间：60 分钟**（单次执行；包含代码阅读、定向实施/分析与相关验证）

**Skills：** `module-governance` · `module-regression`

```text
$module-governance $module-regression

审计 lib/modules、lib/page 和 infrastructure 依赖边界。检查 public.dart、Facade、Repository Port 和第三方依赖使用。结合 scripts/check_boundaries.dart 找出实际违规，给出按风险排序的治理计划。
```

#### ECC-034 · Flutter 多端发布验收

**预计执行时间：90 分钟**（单次执行；包含代码阅读、定向实施/分析与相关验证）

**Skills：** `production-audit` · `deployment-patterns`

```text
$production-audit $deployment-patterns

审计 Android、iOS、macOS、Web 发布链路。检查 SDK 锁定、构建配置、签名、依赖、版本号、产物、平台差异和回滚方案。区分 CI 已验证、本地已验证和尚未验证内容。不得执行发布。
```


## IMBoy 客户端业务场景复刻（Flutter）

> 本组面向客户业务场景复刻。每个场景提供三条独立提示词：A 新增功能；B 优化现有功能（重点适用于新模型复审旧 AI 代码）；C 测试现有功能。将提示词中的“客户”替换为具体客户、行业、角色和目标流程。



#### ECC-090 · 客户聊天 App 复刻方案

**预计执行时间（单选一种模式）：A 新增功能 90 分钟 · B 优化现有功能 60 分钟 · C 测试现有功能 45 分钟**

**场景：** 个人即时通讯客户端体验

**A · 新增功能 · `product-capability` + `orch-add-feature` + `dart-flutter-patterns` + `tdd-workflow`**

```text
$product-capability $orch-add-feature $dart-flutter-patterns $tdd-workflow

业务场景：客户聊天 App 复刻方案（个人即时通讯客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：为该场景新增功能。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

读取该场景对应的领域概念、路由/接口、数据模型、Flutter/Admin 消费入口和现有测试，先做能力盘点：哪些可直接复用、哪些可通过配置组合、哪些确实缺失。不得重复造轮子或把未开放能力当作已交付。

为真正缺失的能力形成 capability contract：角色与权限、用户旅程、状态机、输入输出、数据归属、API/WS、迁移兼容、失败恢复、观测和验收标准。客户输入不完整时列出阻塞问题并停在方案阶段；需求明确时按 orch-add-feature 的计划门禁执行，先写失败测试再实现最小差异。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

运行相关定向测试和契约/架构门禁。只修改批准范围，不 commit、不 push、不合并、不部署。
```

**B · 优化现有功能 / 新模型复审旧 AI 代码 · `brownfield-retrospective` + `flutter-dart-code-review` + `tdd-workflow` + `verification-loop`**

```text
$brownfield-retrospective $flutter-dart-code-review $tdd-workflow $verification-loop

业务场景：客户聊天 App 复刻方案（个人即时通讯客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：优化现有功能，重点用于新一代 AI 模型复审和改进旧 AI 模型生成的代码。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

按 brownfield-retrospective 的 slice-first 方法，把范围限制在约 15 个文件或 2000 行以内。不要信任旧模型自评、注释或现有测试完整性；独立重建真实行为、调用链、数据流、权限边界、失败路径、并发/竞态、资源生命周期和跨端契约，建立改动前测试/性能/错误行为基线。

重点检查：逻辑正确性、边界条件、异常处理、幂等与重试、安全、性能热点、重复/过度抽象、可维护性和跨端一致性；特别排查只改响应未改查询/持久化、只修主路径漏掉其他分支、字段/可空性漂移、异常吞掉、UI-only 权限、mock 通过但真实路径失败、测试与实现共享错误假设等 AI 常见盲点。

每项发现提供文件/行号、证据、影响、风险和最小修复方案。优先行为保持型优化；先新增/修正测试证明问题，再做最小改动。涉及公共 API/WS、数据库结构、E2EE、权限语义或用户可见行为变化时先请求确认。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

先在会话中输出基线和差距清单；不要自动创建 docs/retro 或重复报告。对范围内明确且行为保持的改进可以实施；完成后运行相关测试、静态检查和 diff review，报告改动前后证据与未验证项。不 commit、不 push、不合并、不部署。
```

**C · 测试现有功能 · `test-collaboration` + `ai-regression-testing` + `verification-loop`**

```text
$test-collaboration $ai-regression-testing $verification-loop

业务场景：客户聊天 App 复刻方案（个人即时通讯客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：测试现有功能，独立验证旧 AI 模型生成的实现。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

先不要修改业务实现。盘点该场景已有单元、集成、契约、E2E、平台/设备测试和 CI 门禁，建立“需求/不变量 → 测试资产或 TEST-ID → 命令 → 证据”矩阵。覆盖正常路径、权限拒绝、非法输入、边界值、重复请求、并发、超时、故障恢复、旧数据兼容和跨端行为。

针对 AI 生成代码特别检查 mock/sandbox 与真实路径不一致、数据库查询/写入字段遗漏、序列化遗漏、仅测 happy path、异常吞掉、重试重复副作用和测试 fixture 迎合实现。只新增有区分力的测试，不复制重复用例、不降低阈值、不扩大 skip。docs/testing/execution.md、test/auto_test/execution_contract.json 和现有单元/Widget/集成测试；缺少真机标 BLOCKED。

逐项报告 PASS/FAIL/BLOCKED/NOT RUN、真实命令、退出码、测试数量和证据位置。发现缺陷先提供复现和最小修复建议；未经授权不修改业务代码。不得把未执行或环境缺失标记为 PASS。
```

#### ECC-091 · 客户社群 App 复刻方案

**预计执行时间（单选一种模式）：A 新增功能 90 分钟 · B 优化现有功能 60 分钟 · C 测试现有功能 45 分钟**

**场景：** 群组协作客户端体验

**A · 新增功能 · `product-capability` + `orch-add-feature` + `dart-flutter-patterns` + `tdd-workflow`**

```text
$product-capability $orch-add-feature $dart-flutter-patterns $tdd-workflow

业务场景：客户社群 App 复刻方案（群组协作客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：为该场景新增功能。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

读取该场景对应的领域概念、路由/接口、数据模型、Flutter/Admin 消费入口和现有测试，先做能力盘点：哪些可直接复用、哪些可通过配置组合、哪些确实缺失。不得重复造轮子或把未开放能力当作已交付。

为真正缺失的能力形成 capability contract：角色与权限、用户旅程、状态机、输入输出、数据归属、API/WS、迁移兼容、失败恢复、观测和验收标准。客户输入不完整时列出阻塞问题并停在方案阶段；需求明确时按 orch-add-feature 的计划门禁执行，先写失败测试再实现最小差异。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

运行相关定向测试和契约/架构门禁。只修改批准范围，不 commit、不 push、不合并、不部署。
```

**B · 优化现有功能 / 新模型复审旧 AI 代码 · `brownfield-retrospective` + `flutter-dart-code-review` + `tdd-workflow` + `verification-loop`**

```text
$brownfield-retrospective $flutter-dart-code-review $tdd-workflow $verification-loop

业务场景：客户社群 App 复刻方案（群组协作客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：优化现有功能，重点用于新一代 AI 模型复审和改进旧 AI 模型生成的代码。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

按 brownfield-retrospective 的 slice-first 方法，把范围限制在约 15 个文件或 2000 行以内。不要信任旧模型自评、注释或现有测试完整性；独立重建真实行为、调用链、数据流、权限边界、失败路径、并发/竞态、资源生命周期和跨端契约，建立改动前测试/性能/错误行为基线。

重点检查：逻辑正确性、边界条件、异常处理、幂等与重试、安全、性能热点、重复/过度抽象、可维护性和跨端一致性；特别排查只改响应未改查询/持久化、只修主路径漏掉其他分支、字段/可空性漂移、异常吞掉、UI-only 权限、mock 通过但真实路径失败、测试与实现共享错误假设等 AI 常见盲点。

每项发现提供文件/行号、证据、影响、风险和最小修复方案。优先行为保持型优化；先新增/修正测试证明问题，再做最小改动。涉及公共 API/WS、数据库结构、E2EE、权限语义或用户可见行为变化时先请求确认。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

先在会话中输出基线和差距清单；不要自动创建 docs/retro 或重复报告。对范围内明确且行为保持的改进可以实施；完成后运行相关测试、静态检查和 diff review，报告改动前后证据与未验证项。不 commit、不 push、不合并、不部署。
```

**C · 测试现有功能 · `test-collaboration` + `ai-regression-testing` + `verification-loop`**

```text
$test-collaboration $ai-regression-testing $verification-loop

业务场景：客户社群 App 复刻方案（群组协作客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：测试现有功能，独立验证旧 AI 模型生成的实现。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

先不要修改业务实现。盘点该场景已有单元、集成、契约、E2E、平台/设备测试和 CI 门禁，建立“需求/不变量 → 测试资产或 TEST-ID → 命令 → 证据”矩阵。覆盖正常路径、权限拒绝、非法输入、边界值、重复请求、并发、超时、故障恢复、旧数据兼容和跨端行为。

针对 AI 生成代码特别检查 mock/sandbox 与真实路径不一致、数据库查询/写入字段遗漏、序列化遗漏、仅测 happy path、异常吞掉、重试重复副作用和测试 fixture 迎合实现。只新增有区分力的测试，不复制重复用例、不降低阈值、不扩大 skip。docs/testing/execution.md、test/auto_test/execution_contract.json 和现有单元/Widget/集成测试；缺少真机标 BLOCKED。

逐项报告 PASS/FAIL/BLOCKED/NOT RUN、真实命令、退出码、测试数量和证据位置。发现缺陷先提供复现和最小修复建议；未经授权不修改业务代码。不得把未执行或环境缺失标记为 PASS。
```

#### ECC-092 · 客户内容频道 App 复刻方案

**预计执行时间（单选一种模式）：A 新增功能 90 分钟 · B 优化现有功能 60 分钟 · C 测试现有功能 45 分钟**

**场景：** 频道订阅客户端体验

**A · 新增功能 · `product-capability` + `orch-add-feature` + `dart-flutter-patterns` + `tdd-workflow`**

```text
$product-capability $orch-add-feature $dart-flutter-patterns $tdd-workflow

业务场景：客户内容频道 App 复刻方案（频道订阅客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：为该场景新增功能。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

读取该场景对应的领域概念、路由/接口、数据模型、Flutter/Admin 消费入口和现有测试，先做能力盘点：哪些可直接复用、哪些可通过配置组合、哪些确实缺失。不得重复造轮子或把未开放能力当作已交付。

为真正缺失的能力形成 capability contract：角色与权限、用户旅程、状态机、输入输出、数据归属、API/WS、迁移兼容、失败恢复、观测和验收标准。客户输入不完整时列出阻塞问题并停在方案阶段；需求明确时按 orch-add-feature 的计划门禁执行，先写失败测试再实现最小差异。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

运行相关定向测试和契约/架构门禁。只修改批准范围，不 commit、不 push、不合并、不部署。
```

**B · 优化现有功能 / 新模型复审旧 AI 代码 · `brownfield-retrospective` + `flutter-dart-code-review` + `tdd-workflow` + `verification-loop`**

```text
$brownfield-retrospective $flutter-dart-code-review $tdd-workflow $verification-loop

业务场景：客户内容频道 App 复刻方案（频道订阅客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：优化现有功能，重点用于新一代 AI 模型复审和改进旧 AI 模型生成的代码。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

按 brownfield-retrospective 的 slice-first 方法，把范围限制在约 15 个文件或 2000 行以内。不要信任旧模型自评、注释或现有测试完整性；独立重建真实行为、调用链、数据流、权限边界、失败路径、并发/竞态、资源生命周期和跨端契约，建立改动前测试/性能/错误行为基线。

重点检查：逻辑正确性、边界条件、异常处理、幂等与重试、安全、性能热点、重复/过度抽象、可维护性和跨端一致性；特别排查只改响应未改查询/持久化、只修主路径漏掉其他分支、字段/可空性漂移、异常吞掉、UI-only 权限、mock 通过但真实路径失败、测试与实现共享错误假设等 AI 常见盲点。

每项发现提供文件/行号、证据、影响、风险和最小修复方案。优先行为保持型优化；先新增/修正测试证明问题，再做最小改动。涉及公共 API/WS、数据库结构、E2EE、权限语义或用户可见行为变化时先请求确认。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

先在会话中输出基线和差距清单；不要自动创建 docs/retro 或重复报告。对范围内明确且行为保持的改进可以实施；完成后运行相关测试、静态检查和 diff review，报告改动前后证据与未验证项。不 commit、不 push、不合并、不部署。
```

**C · 测试现有功能 · `test-collaboration` + `ai-regression-testing` + `verification-loop`**

```text
$test-collaboration $ai-regression-testing $verification-loop

业务场景：客户内容频道 App 复刻方案（频道订阅客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：测试现有功能，独立验证旧 AI 模型生成的实现。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

先不要修改业务实现。盘点该场景已有单元、集成、契约、E2E、平台/设备测试和 CI 门禁，建立“需求/不变量 → 测试资产或 TEST-ID → 命令 → 证据”矩阵。覆盖正常路径、权限拒绝、非法输入、边界值、重复请求、并发、超时、故障恢复、旧数据兼容和跨端行为。

针对 AI 生成代码特别检查 mock/sandbox 与真实路径不一致、数据库查询/写入字段遗漏、序列化遗漏、仅测 happy path、异常吞掉、重试重复副作用和测试 fixture 迎合实现。只新增有区分力的测试，不复制重复用例、不降低阈值、不扩大 skip。docs/testing/execution.md、test/auto_test/execution_contract.json 和现有单元/Widget/集成测试；缺少真机标 BLOCKED。

逐项报告 PASS/FAIL/BLOCKED/NOT RUN、真实命令、退出码、测试数量和证据位置。发现缺陷先提供复现和最小修复建议；未经授权不修改业务代码。不得把未执行或环境缺失标记为 PASS。
```

#### ECC-093 · 客户动态社区 App 复刻方案

**预计执行时间（单选一种模式）：A 新增功能 90 分钟 · B 优化现有功能 60 分钟 · C 测试现有功能 45 分钟**

**场景：** 朋友圈客户端体验

**A · 新增功能 · `product-capability` + `orch-add-feature` + `dart-flutter-patterns` + `tdd-workflow`**

```text
$product-capability $orch-add-feature $dart-flutter-patterns $tdd-workflow

业务场景：客户动态社区 App 复刻方案（朋友圈客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：为该场景新增功能。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

读取该场景对应的领域概念、路由/接口、数据模型、Flutter/Admin 消费入口和现有测试，先做能力盘点：哪些可直接复用、哪些可通过配置组合、哪些确实缺失。不得重复造轮子或把未开放能力当作已交付。

为真正缺失的能力形成 capability contract：角色与权限、用户旅程、状态机、输入输出、数据归属、API/WS、迁移兼容、失败恢复、观测和验收标准。客户输入不完整时列出阻塞问题并停在方案阶段；需求明确时按 orch-add-feature 的计划门禁执行，先写失败测试再实现最小差异。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

运行相关定向测试和契约/架构门禁。只修改批准范围，不 commit、不 push、不合并、不部署。
```

**B · 优化现有功能 / 新模型复审旧 AI 代码 · `brownfield-retrospective` + `flutter-dart-code-review` + `tdd-workflow` + `verification-loop`**

```text
$brownfield-retrospective $flutter-dart-code-review $tdd-workflow $verification-loop

业务场景：客户动态社区 App 复刻方案（朋友圈客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：优化现有功能，重点用于新一代 AI 模型复审和改进旧 AI 模型生成的代码。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

按 brownfield-retrospective 的 slice-first 方法，把范围限制在约 15 个文件或 2000 行以内。不要信任旧模型自评、注释或现有测试完整性；独立重建真实行为、调用链、数据流、权限边界、失败路径、并发/竞态、资源生命周期和跨端契约，建立改动前测试/性能/错误行为基线。

重点检查：逻辑正确性、边界条件、异常处理、幂等与重试、安全、性能热点、重复/过度抽象、可维护性和跨端一致性；特别排查只改响应未改查询/持久化、只修主路径漏掉其他分支、字段/可空性漂移、异常吞掉、UI-only 权限、mock 通过但真实路径失败、测试与实现共享错误假设等 AI 常见盲点。

每项发现提供文件/行号、证据、影响、风险和最小修复方案。优先行为保持型优化；先新增/修正测试证明问题，再做最小改动。涉及公共 API/WS、数据库结构、E2EE、权限语义或用户可见行为变化时先请求确认。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

先在会话中输出基线和差距清单；不要自动创建 docs/retro 或重复报告。对范围内明确且行为保持的改进可以实施；完成后运行相关测试、静态检查和 diff review，报告改动前后证据与未验证项。不 commit、不 push、不合并、不部署。
```

**C · 测试现有功能 · `test-collaboration` + `ai-regression-testing` + `verification-loop`**

```text
$test-collaboration $ai-regression-testing $verification-loop

业务场景：客户动态社区 App 复刻方案（朋友圈客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：测试现有功能，独立验证旧 AI 模型生成的实现。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

先不要修改业务实现。盘点该场景已有单元、集成、契约、E2E、平台/设备测试和 CI 门禁，建立“需求/不变量 → 测试资产或 TEST-ID → 命令 → 证据”矩阵。覆盖正常路径、权限拒绝、非法输入、边界值、重复请求、并发、超时、故障恢复、旧数据兼容和跨端行为。

针对 AI 生成代码特别检查 mock/sandbox 与真实路径不一致、数据库查询/写入字段遗漏、序列化遗漏、仅测 happy path、异常吞掉、重试重复副作用和测试 fixture 迎合实现。只新增有区分力的测试，不复制重复用例、不降低阈值、不扩大 skip。docs/testing/execution.md、test/auto_test/execution_contract.json 和现有单元/Widget/集成测试；缺少真机标 BLOCKED。

逐项报告 PASS/FAIL/BLOCKED/NOT RUN、真实命令、退出码、测试数量和证据位置。发现缺陷先提供复现和最小修复建议；未经授权不修改业务代码。不得把未执行或环境缺失标记为 PASS。
```

#### ECC-094 · 客户登录/扫码登录/多账号体验

**预计执行时间（单选一种模式）：A 新增功能 90 分钟 · B 优化现有功能 60 分钟 · C 测试现有功能 45 分钟**

**场景：** 登录、账号和设备

**A · 新增功能 · `product-capability` + `orch-add-feature` + `dart-flutter-patterns` + `tdd-workflow`**

```text
$product-capability $orch-add-feature $dart-flutter-patterns $tdd-workflow

业务场景：客户登录/扫码登录/多账号体验（登录、账号和设备）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：为该场景新增功能。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

读取该场景对应的领域概念、路由/接口、数据模型、Flutter/Admin 消费入口和现有测试，先做能力盘点：哪些可直接复用、哪些可通过配置组合、哪些确实缺失。不得重复造轮子或把未开放能力当作已交付。

为真正缺失的能力形成 capability contract：角色与权限、用户旅程、状态机、输入输出、数据归属、API/WS、迁移兼容、失败恢复、观测和验收标准。客户输入不完整时列出阻塞问题并停在方案阶段；需求明确时按 orch-add-feature 的计划门禁执行，先写失败测试再实现最小差异。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

运行相关定向测试和契约/架构门禁。只修改批准范围，不 commit、不 push、不合并、不部署。
```

**B · 优化现有功能 / 新模型复审旧 AI 代码 · `brownfield-retrospective` + `flutter-dart-code-review` + `tdd-workflow` + `verification-loop`**

```text
$brownfield-retrospective $flutter-dart-code-review $tdd-workflow $verification-loop

业务场景：客户登录/扫码登录/多账号体验（登录、账号和设备）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：优化现有功能，重点用于新一代 AI 模型复审和改进旧 AI 模型生成的代码。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

按 brownfield-retrospective 的 slice-first 方法，把范围限制在约 15 个文件或 2000 行以内。不要信任旧模型自评、注释或现有测试完整性；独立重建真实行为、调用链、数据流、权限边界、失败路径、并发/竞态、资源生命周期和跨端契约，建立改动前测试/性能/错误行为基线。

重点检查：逻辑正确性、边界条件、异常处理、幂等与重试、安全、性能热点、重复/过度抽象、可维护性和跨端一致性；特别排查只改响应未改查询/持久化、只修主路径漏掉其他分支、字段/可空性漂移、异常吞掉、UI-only 权限、mock 通过但真实路径失败、测试与实现共享错误假设等 AI 常见盲点。

每项发现提供文件/行号、证据、影响、风险和最小修复方案。优先行为保持型优化；先新增/修正测试证明问题，再做最小改动。涉及公共 API/WS、数据库结构、E2EE、权限语义或用户可见行为变化时先请求确认。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

先在会话中输出基线和差距清单；不要自动创建 docs/retro 或重复报告。对范围内明确且行为保持的改进可以实施；完成后运行相关测试、静态检查和 diff review，报告改动前后证据与未验证项。不 commit、不 push、不合并、不部署。
```

**C · 测试现有功能 · `test-collaboration` + `ai-regression-testing` + `verification-loop`**

```text
$test-collaboration $ai-regression-testing $verification-loop

业务场景：客户登录/扫码登录/多账号体验（登录、账号和设备）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：测试现有功能，独立验证旧 AI 模型生成的实现。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

先不要修改业务实现。盘点该场景已有单元、集成、契约、E2E、平台/设备测试和 CI 门禁，建立“需求/不变量 → 测试资产或 TEST-ID → 命令 → 证据”矩阵。覆盖正常路径、权限拒绝、非法输入、边界值、重复请求、并发、超时、故障恢复、旧数据兼容和跨端行为。

针对 AI 生成代码特别检查 mock/sandbox 与真实路径不一致、数据库查询/写入字段遗漏、序列化遗漏、仅测 happy path、异常吞掉、重试重复副作用和测试 fixture 迎合实现。只新增有区分力的测试，不复制重复用例、不降低阈值、不扩大 skip。docs/testing/execution.md、test/auto_test/execution_contract.json 和现有单元/Widget/集成测试；缺少真机标 BLOCKED。

逐项报告 PASS/FAIL/BLOCKED/NOT RUN、真实命令、退出码、测试数量和证据位置。发现缺陷先提供复现和最小修复建议；未经授权不修改业务代码。不得把未执行或环境缺失标记为 PASS。
```

#### ECC-095 · 客户消息互动与效率工具

**预计执行时间（单选一种模式）：A 新增功能 90 分钟 · B 优化现有功能 60 分钟 · C 测试现有功能 45 分钟**

**场景：** 聊天消息丰富交互

**A · 新增功能 · `product-capability` + `orch-add-feature` + `dart-flutter-patterns` + `tdd-workflow`**

```text
$product-capability $orch-add-feature $dart-flutter-patterns $tdd-workflow

业务场景：客户消息互动与效率工具（聊天消息丰富交互）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：为该场景新增功能。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

读取该场景对应的领域概念、路由/接口、数据模型、Flutter/Admin 消费入口和现有测试，先做能力盘点：哪些可直接复用、哪些可通过配置组合、哪些确实缺失。不得重复造轮子或把未开放能力当作已交付。

为真正缺失的能力形成 capability contract：角色与权限、用户旅程、状态机、输入输出、数据归属、API/WS、迁移兼容、失败恢复、观测和验收标准。客户输入不完整时列出阻塞问题并停在方案阶段；需求明确时按 orch-add-feature 的计划门禁执行，先写失败测试再实现最小差异。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

运行相关定向测试和契约/架构门禁。只修改批准范围，不 commit、不 push、不合并、不部署。
```

**B · 优化现有功能 / 新模型复审旧 AI 代码 · `brownfield-retrospective` + `flutter-dart-code-review` + `tdd-workflow` + `verification-loop`**

```text
$brownfield-retrospective $flutter-dart-code-review $tdd-workflow $verification-loop

业务场景：客户消息互动与效率工具（聊天消息丰富交互）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：优化现有功能，重点用于新一代 AI 模型复审和改进旧 AI 模型生成的代码。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

按 brownfield-retrospective 的 slice-first 方法，把范围限制在约 15 个文件或 2000 行以内。不要信任旧模型自评、注释或现有测试完整性；独立重建真实行为、调用链、数据流、权限边界、失败路径、并发/竞态、资源生命周期和跨端契约，建立改动前测试/性能/错误行为基线。

重点检查：逻辑正确性、边界条件、异常处理、幂等与重试、安全、性能热点、重复/过度抽象、可维护性和跨端一致性；特别排查只改响应未改查询/持久化、只修主路径漏掉其他分支、字段/可空性漂移、异常吞掉、UI-only 权限、mock 通过但真实路径失败、测试与实现共享错误假设等 AI 常见盲点。

每项发现提供文件/行号、证据、影响、风险和最小修复方案。优先行为保持型优化；先新增/修正测试证明问题，再做最小改动。涉及公共 API/WS、数据库结构、E2EE、权限语义或用户可见行为变化时先请求确认。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

先在会话中输出基线和差距清单；不要自动创建 docs/retro 或重复报告。对范围内明确且行为保持的改进可以实施；完成后运行相关测试、静态检查和 diff review，报告改动前后证据与未验证项。不 commit、不 push、不合并、不部署。
```

**C · 测试现有功能 · `test-collaboration` + `ai-regression-testing` + `verification-loop`**

```text
$test-collaboration $ai-regression-testing $verification-loop

业务场景：客户消息互动与效率工具（聊天消息丰富交互）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：测试现有功能，独立验证旧 AI 模型生成的实现。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

先不要修改业务实现。盘点该场景已有单元、集成、契约、E2E、平台/设备测试和 CI 门禁，建立“需求/不变量 → 测试资产或 TEST-ID → 命令 → 证据”矩阵。覆盖正常路径、权限拒绝、非法输入、边界值、重复请求、并发、超时、故障恢复、旧数据兼容和跨端行为。

针对 AI 生成代码特别检查 mock/sandbox 与真实路径不一致、数据库查询/写入字段遗漏、序列化遗漏、仅测 happy path、异常吞掉、重试重复副作用和测试 fixture 迎合实现。只新增有区分力的测试，不复制重复用例、不降低阈值、不扩大 skip。docs/testing/execution.md、test/auto_test/execution_contract.json 和现有单元/Widget/集成测试；缺少真机标 BLOCKED。

逐项报告 PASS/FAIL/BLOCKED/NOT RUN、真实命令、退出码、测试数量和证据位置。发现缺陷先提供复现和最小修复建议；未经授权不修改业务代码。不得把未执行或环境缺失标记为 PASS。
```

#### ECC-096 · 客户媒体/位置消息场景

**预计执行时间（单选一种模式）：A 新增功能 90 分钟 · B 优化现有功能 60 分钟 · C 测试现有功能 45 分钟**

**场景：** 多媒体与位置共享

**A · 新增功能 · `product-capability` + `orch-add-feature` + `dart-flutter-patterns` + `tdd-workflow`**

```text
$product-capability $orch-add-feature $dart-flutter-patterns $tdd-workflow

业务场景：客户媒体/位置消息场景（多媒体与位置共享）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：为该场景新增功能。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

读取该场景对应的领域概念、路由/接口、数据模型、Flutter/Admin 消费入口和现有测试，先做能力盘点：哪些可直接复用、哪些可通过配置组合、哪些确实缺失。不得重复造轮子或把未开放能力当作已交付。

为真正缺失的能力形成 capability contract：角色与权限、用户旅程、状态机、输入输出、数据归属、API/WS、迁移兼容、失败恢复、观测和验收标准。客户输入不完整时列出阻塞问题并停在方案阶段；需求明确时按 orch-add-feature 的计划门禁执行，先写失败测试再实现最小差异。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

运行相关定向测试和契约/架构门禁。只修改批准范围，不 commit、不 push、不合并、不部署。
```

**B · 优化现有功能 / 新模型复审旧 AI 代码 · `brownfield-retrospective` + `flutter-dart-code-review` + `tdd-workflow` + `verification-loop`**

```text
$brownfield-retrospective $flutter-dart-code-review $tdd-workflow $verification-loop

业务场景：客户媒体/位置消息场景（多媒体与位置共享）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：优化现有功能，重点用于新一代 AI 模型复审和改进旧 AI 模型生成的代码。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

按 brownfield-retrospective 的 slice-first 方法，把范围限制在约 15 个文件或 2000 行以内。不要信任旧模型自评、注释或现有测试完整性；独立重建真实行为、调用链、数据流、权限边界、失败路径、并发/竞态、资源生命周期和跨端契约，建立改动前测试/性能/错误行为基线。

重点检查：逻辑正确性、边界条件、异常处理、幂等与重试、安全、性能热点、重复/过度抽象、可维护性和跨端一致性；特别排查只改响应未改查询/持久化、只修主路径漏掉其他分支、字段/可空性漂移、异常吞掉、UI-only 权限、mock 通过但真实路径失败、测试与实现共享错误假设等 AI 常见盲点。

每项发现提供文件/行号、证据、影响、风险和最小修复方案。优先行为保持型优化；先新增/修正测试证明问题，再做最小改动。涉及公共 API/WS、数据库结构、E2EE、权限语义或用户可见行为变化时先请求确认。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

先在会话中输出基线和差距清单；不要自动创建 docs/retro 或重复报告。对范围内明确且行为保持的改进可以实施；完成后运行相关测试、静态检查和 diff review，报告改动前后证据与未验证项。不 commit、不 push、不合并、不部署。
```

**C · 测试现有功能 · `test-collaboration` + `ai-regression-testing` + `verification-loop`**

```text
$test-collaboration $ai-regression-testing $verification-loop

业务场景：客户媒体/位置消息场景（多媒体与位置共享）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：测试现有功能，独立验证旧 AI 模型生成的实现。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

先不要修改业务实现。盘点该场景已有单元、集成、契约、E2E、平台/设备测试和 CI 门禁，建立“需求/不变量 → 测试资产或 TEST-ID → 命令 → 证据”矩阵。覆盖正常路径、权限拒绝、非法输入、边界值、重复请求、并发、超时、故障恢复、旧数据兼容和跨端行为。

针对 AI 生成代码特别检查 mock/sandbox 与真实路径不一致、数据库查询/写入字段遗漏、序列化遗漏、仅测 happy path、异常吞掉、重试重复副作用和测试 fixture 迎合实现。只新增有区分力的测试，不复制重复用例、不降低阈值、不扩大 skip。docs/testing/execution.md、test/auto_test/execution_contract.json 和现有单元/Widget/集成测试；缺少真机标 BLOCKED。

逐项报告 PASS/FAIL/BLOCKED/NOT RUN、真实命令、退出码、测试数量和证据位置。发现缺陷先提供复现和最小修复建议；未经授权不修改业务代码。不得把未执行或环境缺失标记为 PASS。
```

#### ECC-097 · 客户 VoIP/视频会议客户端

**预计执行时间（单选一种模式）：A 新增功能 150 分钟 · B 优化现有功能 105 分钟 · C 测试现有功能 75 分钟**

**场景：** 音视频客户端

**A · 新增功能 · `product-capability` + `orch-add-feature` + `dart-flutter-patterns` + `tdd-workflow`**

```text
$product-capability $orch-add-feature $dart-flutter-patterns $tdd-workflow

业务场景：客户 VoIP/视频会议客户端（音视频客户端）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：为该场景新增功能。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

读取该场景对应的领域概念、路由/接口、数据模型、Flutter/Admin 消费入口和现有测试，先做能力盘点：哪些可直接复用、哪些可通过配置组合、哪些确实缺失。不得重复造轮子或把未开放能力当作已交付。

为真正缺失的能力形成 capability contract：角色与权限、用户旅程、状态机、输入输出、数据归属、API/WS、迁移兼容、失败恢复、观测和验收标准。客户输入不完整时列出阻塞问题并停在方案阶段；需求明确时按 orch-add-feature 的计划门禁执行，先写失败测试再实现最小差异。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

运行相关定向测试和契约/架构门禁。只修改批准范围，不 commit、不 push、不合并、不部署。
```

**B · 优化现有功能 / 新模型复审旧 AI 代码 · `brownfield-retrospective` + `flutter-dart-code-review` + `tdd-workflow` + `verification-loop`**

```text
$brownfield-retrospective $flutter-dart-code-review $tdd-workflow $verification-loop

业务场景：客户 VoIP/视频会议客户端（音视频客户端）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：优化现有功能，重点用于新一代 AI 模型复审和改进旧 AI 模型生成的代码。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

按 brownfield-retrospective 的 slice-first 方法，把范围限制在约 15 个文件或 2000 行以内。不要信任旧模型自评、注释或现有测试完整性；独立重建真实行为、调用链、数据流、权限边界、失败路径、并发/竞态、资源生命周期和跨端契约，建立改动前测试/性能/错误行为基线。

重点检查：逻辑正确性、边界条件、异常处理、幂等与重试、安全、性能热点、重复/过度抽象、可维护性和跨端一致性；特别排查只改响应未改查询/持久化、只修主路径漏掉其他分支、字段/可空性漂移、异常吞掉、UI-only 权限、mock 通过但真实路径失败、测试与实现共享错误假设等 AI 常见盲点。

每项发现提供文件/行号、证据、影响、风险和最小修复方案。优先行为保持型优化；先新增/修正测试证明问题，再做最小改动。涉及公共 API/WS、数据库结构、E2EE、权限语义或用户可见行为变化时先请求确认。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

先在会话中输出基线和差距清单；不要自动创建 docs/retro 或重复报告。对范围内明确且行为保持的改进可以实施；完成后运行相关测试、静态检查和 diff review，报告改动前后证据与未验证项。不 commit、不 push、不合并、不部署。
```

**C · 测试现有功能 · `test-collaboration` + `ai-regression-testing` + `verification-loop`**

```text
$test-collaboration $ai-regression-testing $verification-loop

业务场景：客户 VoIP/视频会议客户端（音视频客户端）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：测试现有功能，独立验证旧 AI 模型生成的实现。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

先不要修改业务实现。盘点该场景已有单元、集成、契约、E2E、平台/设备测试和 CI 门禁，建立“需求/不变量 → 测试资产或 TEST-ID → 命令 → 证据”矩阵。覆盖正常路径、权限拒绝、非法输入、边界值、重复请求、并发、超时、故障恢复、旧数据兼容和跨端行为。

针对 AI 生成代码特别检查 mock/sandbox 与真实路径不一致、数据库查询/写入字段遗漏、序列化遗漏、仅测 happy path、异常吞掉、重试重复副作用和测试 fixture 迎合实现。只新增有区分力的测试，不复制重复用例、不降低阈值、不扩大 skip。docs/testing/execution.md、test/auto_test/execution_contract.json 和现有单元/Widget/集成测试；缺少真机标 BLOCKED。

逐项报告 PASS/FAIL/BLOCKED/NOT RUN、真实命令、退出码、测试数量和证据位置。发现缺陷先提供复现和最小修复建议；未经授权不修改业务代码。不得把未执行或环境缺失标记为 PASS。
```

#### ECC-098 · 客户安全聊天和密钥管理 UI

**预计执行时间（单选一种模式）：A 新增功能 150 分钟 · B 优化现有功能 105 分钟 · C 测试现有功能 75 分钟**

**场景：** 端到端加密客户端体验

**A · 新增功能 · `product-capability` + `orch-add-feature` + `dart-flutter-patterns` + `tdd-workflow`**

```text
$product-capability $orch-add-feature $dart-flutter-patterns $tdd-workflow

业务场景：客户安全聊天和密钥管理 UI（端到端加密客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：为该场景新增功能。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

读取该场景对应的领域概念、路由/接口、数据模型、Flutter/Admin 消费入口和现有测试，先做能力盘点：哪些可直接复用、哪些可通过配置组合、哪些确实缺失。不得重复造轮子或把未开放能力当作已交付。

为真正缺失的能力形成 capability contract：角色与权限、用户旅程、状态机、输入输出、数据归属、API/WS、迁移兼容、失败恢复、观测和验收标准。客户输入不完整时列出阻塞问题并停在方案阶段；需求明确时按 orch-add-feature 的计划门禁执行，先写失败测试再实现最小差异。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

运行相关定向测试和契约/架构门禁。只修改批准范围，不 commit、不 push、不合并、不部署。
```

**B · 优化现有功能 / 新模型复审旧 AI 代码 · `brownfield-retrospective` + `flutter-dart-code-review` + `tdd-workflow` + `verification-loop`**

```text
$brownfield-retrospective $flutter-dart-code-review $tdd-workflow $verification-loop

业务场景：客户安全聊天和密钥管理 UI（端到端加密客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：优化现有功能，重点用于新一代 AI 模型复审和改进旧 AI 模型生成的代码。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

按 brownfield-retrospective 的 slice-first 方法，把范围限制在约 15 个文件或 2000 行以内。不要信任旧模型自评、注释或现有测试完整性；独立重建真实行为、调用链、数据流、权限边界、失败路径、并发/竞态、资源生命周期和跨端契约，建立改动前测试/性能/错误行为基线。

重点检查：逻辑正确性、边界条件、异常处理、幂等与重试、安全、性能热点、重复/过度抽象、可维护性和跨端一致性；特别排查只改响应未改查询/持久化、只修主路径漏掉其他分支、字段/可空性漂移、异常吞掉、UI-only 权限、mock 通过但真实路径失败、测试与实现共享错误假设等 AI 常见盲点。

每项发现提供文件/行号、证据、影响、风险和最小修复方案。优先行为保持型优化；先新增/修正测试证明问题，再做最小改动。涉及公共 API/WS、数据库结构、E2EE、权限语义或用户可见行为变化时先请求确认。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

先在会话中输出基线和差距清单；不要自动创建 docs/retro 或重复报告。对范围内明确且行为保持的改进可以实施；完成后运行相关测试、静态检查和 diff review，报告改动前后证据与未验证项。不 commit、不 push、不合并、不部署。
```

**C · 测试现有功能 · `test-collaboration` + `ai-regression-testing` + `verification-loop`**

```text
$test-collaboration $ai-regression-testing $verification-loop

业务场景：客户安全聊天和密钥管理 UI（端到端加密客户端体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：测试现有功能，独立验证旧 AI 模型生成的实现。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

先不要修改业务实现。盘点该场景已有单元、集成、契约、E2E、平台/设备测试和 CI 门禁，建立“需求/不变量 → 测试资产或 TEST-ID → 命令 → 证据”矩阵。覆盖正常路径、权限拒绝、非法输入、边界值、重复请求、并发、超时、故障恢复、旧数据兼容和跨端行为。

针对 AI 生成代码特别检查 mock/sandbox 与真实路径不一致、数据库查询/写入字段遗漏、序列化遗漏、仅测 happy path、异常吞掉、重试重复副作用和测试 fixture 迎合实现。只新增有区分力的测试，不复制重复用例、不降低阈值、不扩大 skip。docs/testing/execution.md、test/auto_test/execution_contract.json 和现有单元/Widget/集成测试；缺少真机标 BLOCKED。

逐项报告 PASS/FAIL/BLOCKED/NOT RUN、真实命令、退出码、测试数量和证据位置。发现缺陷先提供复现和最小修复建议；未经授权不修改业务代码。不得把未执行或环境缺失标记为 PASS。
```

#### ECC-099 · 客户企业通讯录和协作工作台

**预计执行时间（单选一种模式）：A 新增功能 90 分钟 · B 优化现有功能 60 分钟 · C 测试现有功能 45 分钟**

**场景：** 组织与工作台体验

**A · 新增功能 · `product-capability` + `orch-add-feature` + `dart-flutter-patterns` + `tdd-workflow`**

```text
$product-capability $orch-add-feature $dart-flutter-patterns $tdd-workflow

业务场景：客户企业通讯录和协作工作台（组织与工作台体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：为该场景新增功能。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

读取该场景对应的领域概念、路由/接口、数据模型、Flutter/Admin 消费入口和现有测试，先做能力盘点：哪些可直接复用、哪些可通过配置组合、哪些确实缺失。不得重复造轮子或把未开放能力当作已交付。

为真正缺失的能力形成 capability contract：角色与权限、用户旅程、状态机、输入输出、数据归属、API/WS、迁移兼容、失败恢复、观测和验收标准。客户输入不完整时列出阻塞问题并停在方案阶段；需求明确时按 orch-add-feature 的计划门禁执行，先写失败测试再实现最小差异。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

运行相关定向测试和契约/架构门禁。只修改批准范围，不 commit、不 push、不合并、不部署。
```

**B · 优化现有功能 / 新模型复审旧 AI 代码 · `brownfield-retrospective` + `flutter-dart-code-review` + `tdd-workflow` + `verification-loop`**

```text
$brownfield-retrospective $flutter-dart-code-review $tdd-workflow $verification-loop

业务场景：客户企业通讯录和协作工作台（组织与工作台体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：优化现有功能，重点用于新一代 AI 模型复审和改进旧 AI 模型生成的代码。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

按 brownfield-retrospective 的 slice-first 方法，把范围限制在约 15 个文件或 2000 行以内。不要信任旧模型自评、注释或现有测试完整性；独立重建真实行为、调用链、数据流、权限边界、失败路径、并发/竞态、资源生命周期和跨端契约，建立改动前测试/性能/错误行为基线。

重点检查：逻辑正确性、边界条件、异常处理、幂等与重试、安全、性能热点、重复/过度抽象、可维护性和跨端一致性；特别排查只改响应未改查询/持久化、只修主路径漏掉其他分支、字段/可空性漂移、异常吞掉、UI-only 权限、mock 通过但真实路径失败、测试与实现共享错误假设等 AI 常见盲点。

每项发现提供文件/行号、证据、影响、风险和最小修复方案。优先行为保持型优化；先新增/修正测试证明问题，再做最小改动。涉及公共 API/WS、数据库结构、E2EE、权限语义或用户可见行为变化时先请求确认。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

先在会话中输出基线和差距清单；不要自动创建 docs/retro 或重复报告。对范围内明确且行为保持的改进可以实施；完成后运行相关测试、静态检查和 diff review，报告改动前后证据与未验证项。不 commit、不 push、不合并、不部署。
```

**C · 测试现有功能 · `test-collaboration` + `ai-regression-testing` + `verification-loop`**

```text
$test-collaboration $ai-regression-testing $verification-loop

业务场景：客户企业通讯录和协作工作台（组织与工作台体验）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：测试现有功能，独立验证旧 AI 模型生成的实现。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

先不要修改业务实现。盘点该场景已有单元、集成、契约、E2E、平台/设备测试和 CI 门禁，建立“需求/不变量 → 测试资产或 TEST-ID → 命令 → 证据”矩阵。覆盖正常路径、权限拒绝、非法输入、边界值、重复请求、并发、超时、故障恢复、旧数据兼容和跨端行为。

针对 AI 生成代码特别检查 mock/sandbox 与真实路径不一致、数据库查询/写入字段遗漏、序列化遗漏、仅测 happy path、异常吞掉、重试重复副作用和测试 fixture 迎合实现。只新增有区分力的测试，不复制重复用例、不降低阈值、不扩大 skip。docs/testing/execution.md、test/auto_test/execution_contract.json 和现有单元/Widget/集成测试；缺少真机标 BLOCKED。

逐项报告 PASS/FAIL/BLOCKED/NOT RUN、真实命令、退出码、测试数量和证据位置。发现缺陷先提供复现和最小修复建议；未经授权不修改业务代码。不得把未执行或环境缺失标记为 PASS。
```

#### ECC-100 · 客户客服 App/坐席端复刻方案

**预计执行时间（单选一种模式）：A 新增功能 150 分钟 · B 优化现有功能 105 分钟 · C 测试现有功能 75 分钟**

**场景：** 客服坐席工作台

**A · 新增功能 · `product-capability` + `orch-add-feature` + `dart-flutter-patterns` + `tdd-workflow`**

```text
$product-capability $orch-add-feature $dart-flutter-patterns $tdd-workflow

业务场景：客户客服 App/坐席端复刻方案（客服坐席工作台）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：为该场景新增功能。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

读取该场景对应的领域概念、路由/接口、数据模型、Flutter/Admin 消费入口和现有测试，先做能力盘点：哪些可直接复用、哪些可通过配置组合、哪些确实缺失。不得重复造轮子或把未开放能力当作已交付。

为真正缺失的能力形成 capability contract：角色与权限、用户旅程、状态机、输入输出、数据归属、API/WS、迁移兼容、失败恢复、观测和验收标准。客户输入不完整时列出阻塞问题并停在方案阶段；需求明确时按 orch-add-feature 的计划门禁执行，先写失败测试再实现最小差异。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

运行相关定向测试和契约/架构门禁。只修改批准范围，不 commit、不 push、不合并、不部署。
```

**B · 优化现有功能 / 新模型复审旧 AI 代码 · `brownfield-retrospective` + `flutter-dart-code-review` + `tdd-workflow` + `verification-loop`**

```text
$brownfield-retrospective $flutter-dart-code-review $tdd-workflow $verification-loop

业务场景：客户客服 App/坐席端复刻方案（客服坐席工作台）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：优化现有功能，重点用于新一代 AI 模型复审和改进旧 AI 模型生成的代码。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

按 brownfield-retrospective 的 slice-first 方法，把范围限制在约 15 个文件或 2000 行以内。不要信任旧模型自评、注释或现有测试完整性；独立重建真实行为、调用链、数据流、权限边界、失败路径、并发/竞态、资源生命周期和跨端契约，建立改动前测试/性能/错误行为基线。

重点检查：逻辑正确性、边界条件、异常处理、幂等与重试、安全、性能热点、重复/过度抽象、可维护性和跨端一致性；特别排查只改响应未改查询/持久化、只修主路径漏掉其他分支、字段/可空性漂移、异常吞掉、UI-only 权限、mock 通过但真实路径失败、测试与实现共享错误假设等 AI 常见盲点。

每项发现提供文件/行号、证据、影响、风险和最小修复方案。优先行为保持型优化；先新增/修正测试证明问题，再做最小改动。涉及公共 API/WS、数据库结构、E2EE、权限语义或用户可见行为变化时先请求确认。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

先在会话中输出基线和差距清单；不要自动创建 docs/retro 或重复报告。对范围内明确且行为保持的改进可以实施；完成后运行相关测试、静态检查和 diff review，报告改动前后证据与未验证项。不 commit、不 push、不合并、不部署。
```

**C · 测试现有功能 · `test-collaboration` + `ai-regression-testing` + `verification-loop`**

```text
$test-collaboration $ai-regression-testing $verification-loop

业务场景：客户客服 App/坐席端复刻方案（客服坐席工作台）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：测试现有功能，独立验证旧 AI 模型生成的实现。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

先不要修改业务实现。盘点该场景已有单元、集成、契约、E2E、平台/设备测试和 CI 门禁，建立“需求/不变量 → 测试资产或 TEST-ID → 命令 → 证据”矩阵。覆盖正常路径、权限拒绝、非法输入、边界值、重复请求、并发、超时、故障恢复、旧数据兼容和跨端行为。

针对 AI 生成代码特别检查 mock/sandbox 与真实路径不一致、数据库查询/写入字段遗漏、序列化遗漏、仅测 happy path、异常吞掉、重试重复副作用和测试 fixture 迎合实现。只新增有区分力的测试，不复制重复用例、不降低阈值、不扩大 skip。docs/testing/execution.md、test/auto_test/execution_contract.json 和现有单元/Widget/集成测试；缺少真机标 BLOCKED。

逐项报告 PASS/FAIL/BLOCKED/NOT RUN、真实命令、退出码、测试数量和证据位置。发现缺陷先提供复现和最小修复建议；未经授权不修改业务代码。不得把未执行或环境缺失标记为 PASS。
```

#### ECC-101 · 客户充值/账单/订阅中心复刻

**预计执行时间（单选一种模式）：A 新增功能 150 分钟 · B 优化现有功能 105 分钟 · C 测试现有功能 75 分钟**

**场景：** 钱包与支付客户端

**A · 新增功能 · `product-capability` + `orch-add-feature` + `dart-flutter-patterns` + `tdd-workflow`**

```text
$product-capability $orch-add-feature $dart-flutter-patterns $tdd-workflow

业务场景：客户充值/账单/订阅中心复刻（钱包与支付客户端）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：为该场景新增功能。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

读取该场景对应的领域概念、路由/接口、数据模型、Flutter/Admin 消费入口和现有测试，先做能力盘点：哪些可直接复用、哪些可通过配置组合、哪些确实缺失。不得重复造轮子或把未开放能力当作已交付。

为真正缺失的能力形成 capability contract：角色与权限、用户旅程、状态机、输入输出、数据归属、API/WS、迁移兼容、失败恢复、观测和验收标准。客户输入不完整时列出阻塞问题并停在方案阶段；需求明确时按 orch-add-feature 的计划门禁执行，先写失败测试再实现最小差异。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

运行相关定向测试和契约/架构门禁。只修改批准范围，不 commit、不 push、不合并、不部署。
```

**B · 优化现有功能 / 新模型复审旧 AI 代码 · `brownfield-retrospective` + `flutter-dart-code-review` + `tdd-workflow` + `verification-loop`**

```text
$brownfield-retrospective $flutter-dart-code-review $tdd-workflow $verification-loop

业务场景：客户充值/账单/订阅中心复刻（钱包与支付客户端）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：优化现有功能，重点用于新一代 AI 模型复审和改进旧 AI 模型生成的代码。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

按 brownfield-retrospective 的 slice-first 方法，把范围限制在约 15 个文件或 2000 行以内。不要信任旧模型自评、注释或现有测试完整性；独立重建真实行为、调用链、数据流、权限边界、失败路径、并发/竞态、资源生命周期和跨端契约，建立改动前测试/性能/错误行为基线。

重点检查：逻辑正确性、边界条件、异常处理、幂等与重试、安全、性能热点、重复/过度抽象、可维护性和跨端一致性；特别排查只改响应未改查询/持久化、只修主路径漏掉其他分支、字段/可空性漂移、异常吞掉、UI-only 权限、mock 通过但真实路径失败、测试与实现共享错误假设等 AI 常见盲点。

每项发现提供文件/行号、证据、影响、风险和最小修复方案。优先行为保持型优化；先新增/修正测试证明问题，再做最小改动。涉及公共 API/WS、数据库结构、E2EE、权限语义或用户可见行为变化时先请求确认。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

先在会话中输出基线和差距清单；不要自动创建 docs/retro 或重复报告。对范围内明确且行为保持的改进可以实施；完成后运行相关测试、静态检查和 diff review，报告改动前后证据与未验证项。不 commit、不 push、不合并、不部署。
```

**C · 测试现有功能 · `test-collaboration` + `ai-regression-testing` + `verification-loop`**

```text
$test-collaboration $ai-regression-testing $verification-loop

业务场景：客户充值/账单/订阅中心复刻（钱包与支付客户端）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：测试现有功能，独立验证旧 AI 模型生成的实现。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

先不要修改业务实现。盘点该场景已有单元、集成、契约、E2E、平台/设备测试和 CI 门禁，建立“需求/不变量 → 测试资产或 TEST-ID → 命令 → 证据”矩阵。覆盖正常路径、权限拒绝、非法输入、边界值、重复请求、并发、超时、故障恢复、旧数据兼容和跨端行为。

针对 AI 生成代码特别检查 mock/sandbox 与真实路径不一致、数据库查询/写入字段遗漏、序列化遗漏、仅测 happy path、异常吞掉、重试重复副作用和测试 fixture 迎合实现。只新增有区分力的测试，不复制重复用例、不降低阈值、不扩大 skip。docs/testing/execution.md、test/auto_test/execution_contract.json 和现有单元/Widget/集成测试；缺少真机标 BLOCKED。

逐项报告 PASS/FAIL/BLOCKED/NOT RUN、真实命令、退出码、测试数量和证据位置。发现缺陷先提供复现和最小修复建议；未经授权不修改业务代码。不得把未执行或环境缺失标记为 PASS。
```

#### ECC-117 · 设备管理与推送体验

**预计执行时间（单选一种模式）：A 新增功能 90 分钟 · B 优化现有功能 60 分钟 · C 测试现有功能 45 分钟**

**场景：** 多设备登录、通知设置和推送排障

**A · 新增功能 · `product-capability` + `orch-add-feature` + `dart-flutter-patterns` + `tdd-workflow`**

```text
$product-capability $orch-add-feature $dart-flutter-patterns $tdd-workflow

业务场景：设备管理与推送体验（多设备登录、通知设置和推送排障）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：为该场景新增功能。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

读取该场景对应的领域概念、路由/接口、数据模型、Flutter/Admin 消费入口和现有测试，先做能力盘点：哪些可直接复用、哪些可通过配置组合、哪些确实缺失。不得重复造轮子或把未开放能力当作已交付。

为真正缺失的能力形成 capability contract：角色与权限、用户旅程、状态机、输入输出、数据归属、API/WS、迁移兼容、失败恢复、观测和验收标准。客户输入不完整时列出阻塞问题并停在方案阶段；需求明确时按 orch-add-feature 的计划门禁执行，先写失败测试再实现最小差异。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

运行相关定向测试和契约/架构门禁。只修改批准范围，不 commit、不 push、不合并、不部署。
```

**B · 优化现有功能 / 新模型复审旧 AI 代码 · `brownfield-retrospective` + `flutter-dart-code-review` + `tdd-workflow` + `verification-loop`**

```text
$brownfield-retrospective $flutter-dart-code-review $tdd-workflow $verification-loop

业务场景：设备管理与推送体验（多设备登录、通知设置和推送排障）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：优化现有功能，重点用于新一代 AI 模型复审和改进旧 AI 模型生成的代码。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

按 brownfield-retrospective 的 slice-first 方法，把范围限制在约 15 个文件或 2000 行以内。不要信任旧模型自评、注释或现有测试完整性；独立重建真实行为、调用链、数据流、权限边界、失败路径、并发/竞态、资源生命周期和跨端契约，建立改动前测试/性能/错误行为基线。

重点检查：逻辑正确性、边界条件、异常处理、幂等与重试、安全、性能热点、重复/过度抽象、可维护性和跨端一致性；特别排查只改响应未改查询/持久化、只修主路径漏掉其他分支、字段/可空性漂移、异常吞掉、UI-only 权限、mock 通过但真实路径失败、测试与实现共享错误假设等 AI 常见盲点。

每项发现提供文件/行号、证据、影响、风险和最小修复方案。优先行为保持型优化；先新增/修正测试证明问题，再做最小改动。涉及公共 API/WS、数据库结构、E2EE、权限语义或用户可见行为变化时先请求确认。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

先在会话中输出基线和差距清单；不要自动创建 docs/retro 或重复报告。对范围内明确且行为保持的改进可以实施；完成后运行相关测试、静态检查和 diff review，报告改动前后证据与未验证项。不 commit、不 push、不合并、不部署。
```

**C · 测试现有功能 · `test-collaboration` + `ai-regression-testing` + `verification-loop`**

```text
$test-collaboration $ai-regression-testing $verification-loop

业务场景：设备管理与推送体验（多设备登录、通知设置和推送排障）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：测试现有功能，独立验证旧 AI 模型生成的实现。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

先不要修改业务实现。盘点该场景已有单元、集成、契约、E2E、平台/设备测试和 CI 门禁，建立“需求/不变量 → 测试资产或 TEST-ID → 命令 → 证据”矩阵。覆盖正常路径、权限拒绝、非法输入、边界值、重复请求、并发、超时、故障恢复、旧数据兼容和跨端行为。

针对 AI 生成代码特别检查 mock/sandbox 与真实路径不一致、数据库查询/写入字段遗漏、序列化遗漏、仅测 happy path、异常吞掉、重试重复副作用和测试 fixture 迎合实现。只新增有区分力的测试，不复制重复用例、不降低阈值、不扩大 skip。docs/testing/execution.md、test/auto_test/execution_contract.json 和现有单元/Widget/集成测试；缺少真机标 BLOCKED。

逐项报告 PASS/FAIL/BLOCKED/NOT RUN、真实命令、退出码、测试数量和证据位置。发现缺陷先提供复现和最小修复建议；未经授权不修改业务代码。不得把未执行或环境缺失标记为 PASS。
```

#### ECC-118 · 举报、位置与个人数据控制

**预计执行时间（单选一种模式）：A 新增功能 90 分钟 · B 优化现有功能 60 分钟 · C 测试现有功能 45 分钟**

**场景：** 客户隐私设置、位置授权和举报入口

**A · 新增功能 · `product-capability` + `orch-add-feature` + `dart-flutter-patterns` + `tdd-workflow`**

```text
$product-capability $orch-add-feature $dart-flutter-patterns $tdd-workflow

业务场景：举报、位置与个人数据控制（客户隐私设置、位置授权和举报入口）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：为该场景新增功能。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

读取该场景对应的领域概念、路由/接口、数据模型、Flutter/Admin 消费入口和现有测试，先做能力盘点：哪些可直接复用、哪些可通过配置组合、哪些确实缺失。不得重复造轮子或把未开放能力当作已交付。

为真正缺失的能力形成 capability contract：角色与权限、用户旅程、状态机、输入输出、数据归属、API/WS、迁移兼容、失败恢复、观测和验收标准。客户输入不完整时列出阻塞问题并停在方案阶段；需求明确时按 orch-add-feature 的计划门禁执行，先写失败测试再实现最小差异。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

运行相关定向测试和契约/架构门禁。只修改批准范围，不 commit、不 push、不合并、不部署。
```

**B · 优化现有功能 / 新模型复审旧 AI 代码 · `brownfield-retrospective` + `flutter-dart-code-review` + `tdd-workflow` + `verification-loop`**

```text
$brownfield-retrospective $flutter-dart-code-review $tdd-workflow $verification-loop

业务场景：举报、位置与个人数据控制（客户隐私设置、位置授权和举报入口）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：优化现有功能，重点用于新一代 AI 模型复审和改进旧 AI 模型生成的代码。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

按 brownfield-retrospective 的 slice-first 方法，把范围限制在约 15 个文件或 2000 行以内。不要信任旧模型自评、注释或现有测试完整性；独立重建真实行为、调用链、数据流、权限边界、失败路径、并发/竞态、资源生命周期和跨端契约，建立改动前测试/性能/错误行为基线。

重点检查：逻辑正确性、边界条件、异常处理、幂等与重试、安全、性能热点、重复/过度抽象、可维护性和跨端一致性；特别排查只改响应未改查询/持久化、只修主路径漏掉其他分支、字段/可空性漂移、异常吞掉、UI-only 权限、mock 通过但真实路径失败、测试与实现共享错误假设等 AI 常见盲点。

每项发现提供文件/行号、证据、影响、风险和最小修复方案。优先行为保持型优化；先新增/修正测试证明问题，再做最小改动。涉及公共 API/WS、数据库结构、E2EE、权限语义或用户可见行为变化时先请求确认。Riverpod、MVVM/Repository、public.dart、SQLite migration manifest、WebSocket/WebRTC、DESIGN.md 和平台差异。

先在会话中输出基线和差距清单；不要自动创建 docs/retro 或重复报告。对范围内明确且行为保持的改进可以实施；完成后运行相关测试、静态检查和 diff review，报告改动前后证据与未验证项。不 commit、不 push、不合并、不部署。
```

**C · 测试现有功能 · `test-collaboration` + `ai-regression-testing` + `verification-loop`**

```text
$test-collaboration $ai-regression-testing $verification-loop

业务场景：举报、位置与个人数据控制（客户隐私设置、位置授权和举报入口）。客户信息：[填写客户行业、用户角色、业务目标、关键流程、特殊业务规则、数据规模和验收指标]。本次范围：[填写具体端、模块、功能切片]。

任务：测试现有功能，独立验证旧 AI 模型生成的实现。

先核对当前仓库 HEAD、工作区状态、AGENTS.md/CLAUDE.md、架构/产品文档、API/WS/数据契约、真实代码和测试。以代码与可执行证据为准，标记 CURRENT、TARGET、LOCKED、UNKNOWN、NOT_VERIFIED；不能把文档/API 存在等同于功能已经端到端交付。

先不要修改业务实现。盘点该场景已有单元、集成、契约、E2E、平台/设备测试和 CI 门禁，建立“需求/不变量 → 测试资产或 TEST-ID → 命令 → 证据”矩阵。覆盖正常路径、权限拒绝、非法输入、边界值、重复请求、并发、超时、故障恢复、旧数据兼容和跨端行为。

针对 AI 生成代码特别检查 mock/sandbox 与真实路径不一致、数据库查询/写入字段遗漏、序列化遗漏、仅测 happy path、异常吞掉、重试重复副作用和测试 fixture 迎合实现。只新增有区分力的测试，不复制重复用例、不降低阈值、不扩大 skip。docs/testing/execution.md、test/auto_test/execution_contract.json 和现有单元/Widget/集成测试；缺少真机标 BLOCKED。

逐项报告 PASS/FAIL/BLOCKED/NOT RUN、真实命令、退出码、测试数量和证据位置。发现缺陷先提供复现和最小修复建议；未经授权不修改业务代码。不得把未执行或环境缺失标记为 PASS。
```

## 维护说明

- 本文只维护本仓库职责范围内的提示词；跨仓案例的统一索引位于 [imboy 后端主仓 docs/prompts/README.md](https://github.com/imboy-pub/imboy/blob/main/docs/prompts/README.md)。
- 修改案例时保持 ECC 编号不变；新增案例先在后端主仓索引登记编号和归属，避免重复。
- Skill 名称必须与 ECC `skills/<name>/SKILL.md` 中的目录名一致；ECC 升级后应重新核对可用性。
- 提示词是任务入口，不是执行结果或质量证明；验收以真实代码、测试和 CI 证据为准。
