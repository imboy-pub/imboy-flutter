# IMBoy ECC 使用案例 / Flutter

> 本文是可直接复制到 Codex 会话的 ECC 使用案例库。每个案例均为独立提示词，以 `$skill-name` 开头。
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
> **案例编号全局唯一**：ECC-001 至 ECC-072。四个仓库按职责分配，后端主仓提供统一索引。

## 本仓库范围

本文件包含 Flutter 架构理解和多端客户端案例，共 13 个（ECC-002、023–034）。

## 案例清单

### 项目理解与架构分析

#### ECC-002 · Flutter 多端架构梳理

**Skills：** `codebase-onboarding`

```text
$codebase-onboarding

只读分析 imboy-flutter。梳理 Android、iOS、macOS、Web 架构，重点分析 Riverpod、go_router、MVVM、Repository、SQLite/SQLCipher、WebSocket、WebRTC、E2EE 和平台适配。输出真实入口、模块地图、关键调用链、现有硬约束和技术债，不创建文件。
```

### Flutter 多端客户端

#### ECC-023 · 新增聊天消息功能

**Skills：** `dart-flutter-patterns` · `tdd-workflow`

```text
$dart-flutter-patterns $tdd-workflow

在 imboy-flutter 新增指定聊天消息功能。先检查 messaging 模块、MessagingFacade、MessageRepository、消息模型和 UI 组件。遵循 Riverpod、Repository 和模块公开边界。先写测试再实现，复用已有能力，完成后运行对应测试。
```

#### ECC-024 · Riverpod 状态管理治理

**Skills：** `flutter-dart-code-review` · `change-impact`

```text
$flutter-dart-code-review $change-impact

审计 Riverpod 状态管理。检查 Provider 生命周期、重复请求、无效刷新、异步竞态、状态污染和跨账号状态泄漏。找出可复现问题，提出最小改进方案；未经授权不做全局重构。
```

#### ECC-025 · SQLite 数据库迁移

**Skills：** `change-impact` · `tdd-workflow` · `test-collaboration`

```text
$change-impact $tdd-workflow $test-collaboration

审查或实施 SQLite 数据库迁移。以 lib/service/migrations/manifest_all.dart 为唯一真源，检查版本升级、降级、旧数据保留、账号隔离、事务中断和重放。运行对应 sqlite migration gate，不维护旁路迁移副本。
```

#### ECC-026 · E2EE 密钥备份与恢复

**Skills：** `security-review` · `test-collaboration`

```text
$security-review $test-collaboration

审计 E2EE 密钥备份、恢复、导入、导出和设备切换流程。检查密钥生命周期、加密边界、错误恢复、敏感日志和账号隔离。列出真实代码路径与测试缺口，不读取、打印或修改真实密钥和用户数据。
```

#### ECC-027 · WebSocket 重连和消息 ACK

**Skills：** `change-impact` · `tdd-workflow`

```text
$change-impact $tdd-workflow

分析客户端 WebSocket 断线重连、登录恢复、消息 ACK、重复消息去重和离线同步。覆盖网络切换、应用后台恢复、设备切换和连接连续失败场景。优先复用现有服务和测试框架，先补回归测试。
```

#### ECC-028 · 附件上传断点续传

**Skills：** `tdd-workflow` · `module-regression`

```text
$tdd-workflow $module-regression

审查附件上传任务持久化检查点和恢复逻辑。检查任务重启、重复上传、网络中断、文件变化、账号切换及服务端确认。复用 attachment_upload_task 机制，不重复实现任务队列。
```

#### ECC-029 · 四平台行为差异

**Skills：** `test-collaboration` · `parallel-execution-optimizer`

```text
$test-collaboration $parallel-execution-optimizer

分析 Android、iOS、macOS、Web 测试覆盖。按系统权限、SQLite、WebSocket、WebRTC、文件系统和推送拆分测试义务。使用 test/auto_test/execution_contract.json 生成精确矩阵。缺设备或环境标记 BLOCKED，不得判定 PASS。
```

#### ECC-030 · Widget 无障碍检查

**Skills：** `flutter-dart-code-review` · `test-collaboration`

```text
$flutter-dart-code-review $test-collaboration

检查核心聊天、联系人、群组、登录页面的 Semantics、焦点顺序、键盘操作、屏幕阅读器和触控目标。结合 DESIGN.md 和现有 UI 测试约束，输出真实问题及回归用例。
```

#### ECC-031 · 路由与登录守卫

**Skills：** `dart-flutter-patterns` · `tdd-workflow`

```text
$dart-flutter-patterns $tdd-workflow

审计 go_router 路由、登录状态、权限守卫、深链接和退出登录跳转。验证未登录访问、Token 失效、账号切换、页面恢复和非法路由。优先扩展已有路由体系，不引入第二套路由机制。
```

#### ECC-032 · PR/Full 测试计划

**Skills：** `test-collaboration` · `verification-loop`

```text
$test-collaboration $verification-loop

分析 test/auto_test/execution_contract.json 和 docs/testing/execution.md。为当前变更生成精确 PR 验证计划，列出目标、平台、依赖、命令、预期证据和阻塞条件。不得用 all_tests.dart 或零执行结果冒充全量回归。
```

#### ECC-033 · Flutter 模块边界治理

**Skills：** `module-governance` · `module-regression`

```text
$module-governance $module-regression

审计 lib/modules、lib/page 和 infrastructure 依赖边界。检查 public.dart、Facade、Repository Port 和第三方依赖使用。结合 scripts/check_boundaries.dart 找出实际违规，给出按风险排序的治理计划。
```

#### ECC-034 · Flutter 多端发布验收

**Skills：** `production-audit` · `deployment-patterns`

```text
$production-audit $deployment-patterns

审计 Android、iOS、macOS、Web 发布链路。检查 SDK 锁定、构建配置、签名、依赖、版本号、产物、平台差异和回滚方案。区分 CI 已验证、本地已验证和尚未验证内容。不得执行发布。
```

## 维护说明

- 本文只维护本仓库职责范围内的提示词；跨仓案例的统一索引位于 [imboy 后端主仓 docs/prompts/README.md](https://github.com/imboy-pub/imboy/blob/main/docs/prompts/README.md)。
- 修改案例时保持 ECC 编号不变；新增案例先在后端主仓索引登记编号和归属，避免重复。
- Skill 名称必须与 ECC `skills/<name>/SKILL.md` 中的目录名一致；ECC 升级后应重新核对可用性。
- 提示词是任务入口，不是执行结果或质量证明；验收以真实代码、测试和 CI 证据为准。
