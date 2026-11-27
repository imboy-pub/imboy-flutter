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


## IMBoy 客户端业务场景复刻（Flutter）

> 本组面向客户业务场景复刻。每个场景提供两条独立提示词：A 用于需求/能力映射；B 用于在批准后实施客户差异。将提示词中的“客户”替换为具体客户、行业、角色和目标流程。

### ECC-090 · 客户聊天 App 复刻方案

**场景：** 个人即时通讯客户端体验

**A · `product-lens` + `product-capability` · 客户场景映射**

```text
$product-lens $product-capability

为客户设计 IMBoy Flutter 个人聊天 App 复刻方案。映射登录、好友、会话列表、消息气泡、消息状态、历史同步、输入状态、撤回编辑、转发引用、多设备和离线恢复。检查现有页面与 messaging/social_graph/identity 模块，输出页面地图、交互差异、端能力限制和验收用例。
```

**B · `dart-flutter-patterns` + `contract-first` + `orch-change-feature` · 客户差异实施**

```text
$dart-flutter-patterns $contract-first $orch-change-feature

实施已批准的聊天客户端差异。复用 messaging Facade/Repository、现有消息模型、SQLite 表和 WS 服务。遵守 conv_seq 排序、ACK/重试、未知消息类型降级渲染、生成代码不可手改和 DESIGN 规范。补充 Widget/单元测试；真机媒体/网络验证按测试合同执行。
```

### ECC-091 · 客户社群 App 复刻方案

**场景：** 群组协作客户端体验

**A · `product-lens` + `product-capability` · 客户场景映射**

```text
$product-lens $product-capability

为客户复刻群聊/社群 App。映射群创建、邀请、成员角色、群公告、@、群文件/相册、日程/任务/投票、群资料和群治理。检查 group_collab 与现有 group 页面/服务，区分已接线功能、后台 API 已有但 App 未消费的功能及 phase lock。
```

**B · `dart-flutter-patterns` + `contract-first` + `orch-add-feature` · 客户差异实施**

```text
$dart-flutter-patterns $contract-first $orch-add-feature

实施已批准的群组客户端增量。优先使用 lib/modules/group_collab/public.dart、现有 Service 和 Repository。按角色与 scope 控制操作，补充单元/Widget/设备测试计划；不复制后端规则到客户端作为唯一授权依据。
```

### ECC-092 · 客户内容频道 App 复刻方案

**场景：** 频道订阅客户端体验

**A · `product-lens` + `product-capability` · 客户场景映射**

```text
$product-lens $product-capability

为客户复刻频道/内容订阅 App。映射频道发现、详情、订阅/购买、帖子列表、评论、精华/置顶、讨论群、通知和付费内容访问。核对 channel_content 模块与后端 channel-api-contract-v1，标注一期/二期和支付通道的真实开放状态。
```

**B · `dart-flutter-patterns` + `contract-first` + `orch-change-feature` · 客户差异实施**

```text
$dart-flutter-patterns $contract-first $orch-change-feature

实施已批准的频道客户端差异。复用 channel_content 模块和 API 契约，正确处理 visibility/access_type/join_policy、订阅/购买状态、分页、TSID 和错误信封。补充未订阅/已购买/私有频道等正反例测试，不在客户端绕过后端授权。
```

### ECC-093 · 客户动态社区 App 复刻方案

**场景：** 朋友圈客户端体验

**A · `product-lens` + `product-capability` · 客户场景映射**

```text
$product-lens $product-capability

为客户复刻动态/朋友圈客户端。映射发布图文/视频、可见性设置、好友互动、评论、收藏、举报和内容详情。检查 moment_social 与现有 moment 页面，依据 moment-api-contract-v1 建立隐私与关系矩阵，指出尚未消费的 API。
```

**B · `dart-flutter-patterns` + `contract-first` + `orch-add-feature` · 客户差异实施**

```text
$dart-flutter-patterns $contract-first $orch-add-feature

实施已批准的动态客户端差异。复用 moment_social 模块、附件授权服务和现有 UI 规范。验证不同可见性、黑名单优先、删除内容、分页和媒体授权。补充 Widget 与 API contract tests，不在本地缓存泄露受限动态。
```

### ECC-094 · 客户登录/扫码登录/多账号体验

**场景：** 登录、账号和设备

**A · `product-lens` + `product-capability` · 客户场景映射**

```text
$product-lens $product-capability

为客户复刻身份入口。映射手机号/邮箱/账号登录、注册、验证码、找回密码、二维码登录、OIDC/企业 SSO、设备管理、账号切换和退出清理。检查 identity、passport、QR login、enterprise_oa 模块及各平台限制，输出旅程和安全验收矩阵。
```

**B · `dart-flutter-patterns` + `contract-first` + `tdd-workflow` · 客户差异实施**

```text
$dart-flutter-patterns $contract-first $tdd-workflow

实施已批准的身份客户端差异。复用 Passport/QR/OIDC 服务和 auth session scope。验证 QR token 一次性领取、confirmed uid_str 精度、Token 清理、账号本地数据隔离、Web 与原生平台差异。不得把凭据写入 URL、日志或普通偏好存储。
```

### ECC-095 · 客户消息互动与效率工具

**场景：** 聊天消息丰富交互

**A · `product-lens` + `product-capability` · 客户场景映射**

```text
$product-lens $product-capability

为客户复刻增强聊天体验。映射图片/语音/视频/文件/位置/引用/转发/表情回应/置顶/主题/@提及/已读/阅后即焚/历史归档。检查现有消息类型、操作菜单、SQLite 和 API/WS 支持，输出能力矩阵及平台适配缺口。
```

**B · `dart-flutter-patterns` + `tdd-workflow` + `module-regression` · 客户差异实施**

```text
$dart-flutter-patterns $tdd-workflow $module-regression

实施已批准的消息交互差异。遵守消息类型归一化、未知类型 unsupported、消息 ID 不透明字符串、conv_seq 排序、附件授权、E2EE 密文规则和离线任务持久化。补充消息解析、操作状态、Widget 和迁移回归。
```

### ECC-096 · 客户媒体/位置消息场景

**场景：** 多媒体与位置共享

**A · `product-lens` + `product-capability` · 客户场景映射**

```text
$product-lens $product-capability

为客户复刻媒体与位置分享。映射相机/相册、图片视频预览、语音录制播放、文件选择、位置权限、地图展示、缩略图和断点续传。检查 attachments、camera、location 页面和服务，列出 Android/iOS/macOS/Web 的能力差异与权限提示。
```

**B · `dart-flutter-patterns` + `contract-first` + `tdd-workflow` · 客户差异实施**

```text
$dart-flutter-patterns $contract-first $tdd-workflow

实施已批准的媒体/位置客户端差异。复用 AssetsService.viewUrl、附件上传、权限服务和现有缓存策略。验证授权 URL、文件大小/MIME、取消/重试、账号切换、Web 持久化和权限拒绝；按执行合同安排真机验收。
```

### ECC-097 · 客户 VoIP/视频会议客户端

**场景：** 音视频客户端

**A · `product-lens` + `product-capability` · 客户场景映射**

```text
$product-lens $product-capability

为客户复刻一对一通话/视频沟通客户端。映射呼叫邀请、振铃、接听、拒绝、挂断、超时、摄像头/麦克风权限、设备切换、网络恢复和 LiveKit 房间。检查 p2p_call_screen、rtc_room、flutter_webrtc 与 LiveKit SDK，标注群通话/录制等锁定或未验收能力。
```

**B · `dart-flutter-patterns` + `contract-first` + `tdd-workflow` · 客户差异实施**

```text
$dart-flutter-patterns $contract-first $tdd-workflow

实施已批准的 RTC 客户端差异。保持 IM 信令状态机与媒体传输职责分离，正确清理 track/room/peer connection，处理权限拒绝、后台恢复和异常断线。不得把模拟器结果当真实媒体验收；列出并执行可用的真机双端测试义务。
```

### ECC-098 · 客户安全聊天和密钥管理 UI

**场景：** 端到端加密客户端体验

**A · `product-lens` + `product-capability` · 客户场景映射**

```text
$product-lens $product-capability

为客户复刻安全聊天体验。映射设备身份核验、安全码/二维码、加密状态、密钥备份恢复、社交恢复、群成员世代变化和加密附件。检查 security_privacy 模块和 E2EE 设置页，按交付 profile 区分可用/锁定能力。
```

**B · `security-review` + `dart-flutter-patterns` + `tdd-workflow` · 客户差异实施**

```text
$security-review $dart-flutter-patterns $tdd-workflow

实施已批准的 E2EE 客户端差异。复用 vodozemac、现有 Olm/Megolm、backup 和 trust service；遵守密钥不进入日志/明文持久层、设备 capability 协商和群密钥世代隔离。补充安全负例、迁移和真机恢复测试，不改变密码学协议而不更新契约。
```

### ECC-099 · 客户企业通讯录和协作工作台

**场景：** 组织与工作台体验

**A · `product-lens` + `product-capability` · 客户场景映射**

```text
$product-lens $product-capability

为客户复刻企业工作台。映射组织创建/切换、部门、成员邀请、工作区、项目、任务/里程碑、企业通讯录、OA 工作台和免登。检查 organization、enterprise、enterprise_app、enterprise_oa、workspace 页面与模块，输出角色矩阵、页面入口和后端能力缺口。
```

**B · `dart-flutter-patterns` + `contract-first` + `orch-change-feature` · 客户差异实施**

```text
$dart-flutter-patterns $contract-first $orch-change-feature

实施已批准的企业工作台差异。复用 organization/enterprise/enterprise_oa 模块和 public.dart；遵守组织/工作区/项目各自角色边界、active owner 不变量、OA code/state/exchange 安全和 TSID 精度。补充路由、权限、状态恢复与跨仓契约测试。
```

### ECC-100 · 客户客服 App/坐席端复刻方案

**场景：** 客服坐席工作台

**A · `product-lens` + `product-capability` · 客户场景映射**

```text
$product-lens $product-capability

为客户复刻客服坐席工作台。映射坐席启停、队列、会话认领/转接/关闭、客户上下文、快捷回复、附件发送、评分、在线状态和并发限制。检查 customer_service 模块及 seat 工作台代码，确认哪些能力在 App 消费、哪些仅后台或挂件可用。
```

**B · `dart-flutter-patterns` + `contract-first` + `tdd-workflow` · 客户差异实施**

```text
$dart-flutter-patterns $contract-first $tdd-workflow

实施已批准的坐席客户端差异。遵守 seat identity 绑定 business_identity、会话 CAS 版本、队列 claim、消息复用 enterprise_message、撤销权限和 scope 校验。补充发送/撤销/并发/附件恢复测试；不得在客户端复制客服消息存储。
```

### ECC-101 · 客户充值/账单/订阅中心复刻

**场景：** 钱包与支付客户端

**A · `product-lens` + `product-capability` · 客户场景映射**

```text
$product-lens $product-capability

为客户复刻钱包和付费权益客户端。映射余额、充值、支付渠道、交易记录、订阅/购买、账单、支付失败恢复和权益状态。检查 billing、wallet 页面及 API，标注支付渠道配置、商店支付限制和后端真实回调状态。
```

**B · `contract-first` + `orch-change-feature` + `tdd-workflow` · 客户差异实施**

```text
$contract-first $orch-change-feature $tdd-workflow

实施已批准的支付客户端差异。复用钱包/账单 API，按后端订单状态为准，处理重复回调、支付中断、恢复购买和金额精度。不得在客户端自行认定支付成功，不在真实账户进行测试支付。
```

## 维护说明

- 本文只维护本仓库职责范围内的提示词；跨仓案例的统一索引位于 [imboy 后端主仓 docs/prompts/README.md](https://github.com/imboy-pub/imboy/blob/main/docs/prompts/README.md)。
- 修改案例时保持 ECC 编号不变；新增案例先在后端主仓索引登记编号和归属，避免重复。
- Skill 名称必须与 ECC `skills/<name>/SKILL.md` 中的目录名一致；ECC 升级后应重新核对可用性。
- 提示词是任务入口，不是执行结果或质量证明；验收以真实代码、测试和 CI 证据为准。
