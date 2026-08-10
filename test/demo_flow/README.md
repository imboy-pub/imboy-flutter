# imboyapp Demo Flow TODO 计划

> 本目录记录跨页面、跨模块的业务演示流程。
> 当前内容是 Claude Code 可执行的 TODO 计划，不代表流程已经通过验收。
> 建立日期：2026-08-09

## 1. 目录职责

`test/auto_test/` 是页面级功能点台账：回答“每个页面上的单项功能是否测过”。

`test/demo_flow/` 是跨页面业务链路：回答“用户能否从入口走到结果”。

`integration_test/` 是未来的可执行端到端测试代码。当前先把业务流程、数据前置、验收标准和阻塞条件写清楚，再决定哪些流程值得自动化。

本目录不参与 `test/auto_test/regen_readme.py` 的页面统计，也不放 `*_test.dart` 文件。

P0 的现有测试复用、缺口和执行门槛见 [P0_EXECUTION_PLAN.md](./P0_EXECUTION_PLAN.md)。

## 2. Demo Flow 清单

### P0：核心产品闭环

| 编号 | 文档 | 业务目标 | 当前状态 |
|---|---|---|---|
| DF-01 | [account_flow.md](./account_flow.md) | 注册、登录、首次进入和账号恢复 | 部分通过，注册/恢复待补齐 |
| DF-02 | [friend_flow.md](./friend_flow.md) | 添加好友并建立关系 | API 部分通过，双账号 UI 阻塞 |
| DF-03 | [conversation_flow.md](./conversation_flow.md) | 会话列表、未读和进入聊天 | API/Android 真机入口通过，macOS 本机环境仍有阻塞 |
| DF-04 | [single_chat_flow.md](./single_chat_flow.md) | 好友进入单聊并完成消息闭环 | 双端明文消息闭环通过；服务端历史归档为空；E2EE 未覆盖 |
| DF-05 | [channel_flow.md](./channel_flow.md) | 频道发现到群日程的消费者链路 | API 部分通过，跨模块链路未闭环 |
| DF-06 | [group_flow.md](./group_flow.md) | 群功能总索引和执行入口 | API 部分通过，专题链路未闭环 |
| DF-07 | [group_creation_flow.md](./group_creation_flow.md) | 建群、面对面建群和入群 | 普通建群/邀请与双端回读通过；面对面入群仍未验收 |
| DF-08 | [group_chat_flow.md](./group_chat_flow.md) | 群内消息和成员协作 | 双账号文本消息闭环通过；@成员与失败分支未覆盖 |
| DF-09 | [group_management_flow.md](./group_management_flow.md) | 群信息、成员和权限管理 | 群名/公告与成员角色可逆写入、双端回读通过；成员增删未覆盖 |
| DF-10 | [group_collaboration_flow.md](./group_collaboration_flow.md) | 群日程、任务和投票 | 双账号写入、确认/提交/投票及详情回读通过；费用与跨频道链路未覆盖 |
| DF-11 | [e2ee_security_flow.md](./e2ee_security_flow.md) | E2EE 建立、消息安全和密钥恢复 | 本地密码学通过，双设备 UI 阻塞 |

### P1：重要业务能力

| 编号 | 文档 | 业务目标 | 当前状态 |
|---|---|---|---|
| DF-12 | [channel_creator_flow.md](./channel_creator_flow.md) | 频道创建、发布、评论和管理 | 只读/API/本地页面部分通过，写入阻塞 |
| DF-13 | [paid_channel_flow.md](./paid_channel_flow.md) | 付费频道、订单和购买后解锁 | 订单只读部分通过，购买阻塞 |
| DF-14 | [group_content_flow.md](./group_content_flow.md) | 群相册、群文件和媒体内容 | API只读通过，受影响本地测试已修复，媒体闭环阻塞 |
| DF-15 | [group_organization_flow.md](./group_organization_flow.md) | 群分类、标签、二维码和邀请 | 分类/标签只读/API通过，扫码和写入阻塞 |
| DF-16 | [moments_flow.md](./moments_flow.md) | 发布朋友圈并完成查看、互动 | feed只读/API和本地UI部分通过，写入阻塞 |
| DF-17 | [wallet_flow.md](./wallet_flow.md) | 钱包余额、转账和结果回传 | 余额/流水只读通过，转账阻塞 |
| DF-18 | [red_packet_flow.md](./red_packet_flow.md) | 红包发送、领取和结果查看 | 无安全生产证据，资金流程阻塞 |
| DF-19 | [contact_management_flow.md](./contact_management_flow.md) | 联系人备注、标签和分组管理 | 联系人只读/API和本地标签UI部分通过，写入阻塞 |
| DF-20 | [qrcode_invite_flow.md](./qrcode_invite_flow.md) | 用户、群、频道二维码和扫码邀请 | 本地二维码渲染通过，双端扫码阻塞 |
| DF-21 | [call_flow.md](./call_flow.md) | 单聊音视频和 RTC 房间 | 本地状态/UI协议通过，双端媒体阻塞 |
| DF-22 | [live_room_flow.md](./live_room_flow.md) | 直播间创建、开播和观看 | 本地状态通过，媒体服务/开播阻塞 |

## 3. 统一执行约束

### 环境

- 默认使用本地或明确标记的非生产环境，以及真机端到端测试。
- 运行前确认 `API_BASE_URL` / `APP_ENV` 指向目标环境；禁止凭默认值向生产写入。
- 端到端测试放在仓库根目录 `integration_test/`，不能放入 `test/`，避免被无头 `flutter test` 扫描。

### 账号与数据

- 至少准备测试账号 A、测试账号 B；账号归属和环境必须由负责人确认。
- 群、频道、朋友圈素材、钱包余额均使用可回收的测试数据。
- 需要第二账号、真实媒体、支付余额或写操作授权时，标记为 `阻塞`，不以 UI 显示代替服务端成功证据。

### 证据

每条流程至少记录：

1. 起始数据和环境；
2. 实际操作路径；
3. 页面结果；
4. 服务端成功日志或 API 响应；
5. 失败、跳过或阻塞原因；
6. 后续是否值得编写 `integration_test`。

### 状态定义

| 状态 | 含义 |
|---|---|
| `TODO` | 计划已写入，尚未完成本流程验收 |
| `进行中` | 已开始执行，但尚未形成完整证据链 |
| `通过` | 所有关键步骤均有证据，且无未解释失败 |
| `阻塞` | 缺环境、账号、授权、数据或新 APK，暂不能安全执行 |
| `不实施` | 评估后确认当前不值得做或不属于现有产品能力 |

## 4. 推荐执行顺序

1. DF-01 账号登录；
2. DF-02 添加好友；
3. DF-03 会话列表；
4. DF-04 单聊消息；
5. DF-07～DF-10 群核心流程；
6. DF-05 频道消费者链路；
7. DF-11 E2EE 安全链路；
8. DF-12～DF-15 频道/群扩展能力；
9. DF-16～DF-22 朋友圈、钱包、多媒体和邀请能力。

先完成 P0，才能判断 IMBoy 当前已有能力是否形成可展示的核心产品闭环。P1 中朋友圈、钱包、红包、音视频和直播分别受数据写入、资金、双端设备和媒体环境约束，不应为了“流程完整”而强行执行。

## 4.1 2026-08-09 P1 本轮证据汇总

### 生产只读 API

负责人已独立完成以下 9 个 API 契约文件的生产只读验证：

`channel_order/contact/group_album/group_category/group_file/group_member/group_tag/moment/wallet`

结果：`39 passed, 3 skipped, 0 failed`。运行方式为 `dart test`，API_BASE_URL 和测试账号来自 `.env.pro`；这 9 个选定套件没有执行业务 POST 写入、付费、转账、红包或删除。该结果只证明对应 API 只读/错误边界，不证明完整业务闭环。

审计注意：本轮批量命令曾误包含 `wallet_api_fail_contract_test.dart`，向生产转账端点发送过一次无效参数校验请求，服务端返回 `400`，未观察到成功响应。该请求不计入上述证据；是否完全无副作用仍需服务端审计确认，后续禁止重新运行该测试。

### 本地页面与状态测试

首轮一批 P1 相关 Flutter 页面、状态机、协议和本地集成测试为 `464` 项，其中 `458 passed, 6 failed`；失败集中在群相册照片导航 3 项、群文件上传入口 3 项。复核确认这 6 项是页面 Cupertino 图标/稳定 key 已变更而测试仍查找旧 Material 图标，未发现业务逻辑失败；修正测试定位器后，受影响的两个文件共 `29 passed, 0 failed`。本轮未修改 `lib/`、`test/auto_test/`。

### 本轮未完成

- Android 生产只读页面复跑在 Gradle 构建阶段主动停止，未产生新的 Android PASS 证据；已有历史只读证据仍按各 flow 文档引用。
- 频道创建/发布/评论/邀请、付费购买、朋友圈发布/互动、联系人备注/标签写入、群分类写入、二维码扫码入群、钱包转账、红包、双端通话和直播开播均保持 `BLOCKED`。
- `.env.pro` 不得直接 `source`；后续只提取需要的变量，禁止输出凭证。

## 5. Claude Code 执行协议

执行某个流程时，Claude Code 必须：

1. 先读取本文件和目标流程文档；
2. 再读取文档列出的 `test/auto_test/` 页面计划，确认已有证据和未闭环事项；
3. 只执行目标流程，不顺手扩展产品功能；
4. 每完成一个阶段就回写目标流程的 TODO、证据和阻塞原因；
5. 只有在人工确认测试环境、账号和写操作授权后，才执行真实写入；
6. 需要自动化时，先新增失败测试或明确的跳过条件，再实现最小测试代码；
7. 最后运行目标测试并报告通过、失败、跳过、阻塞四类结果。

## 6. 当前不在本目录实施的内容

- 不新增频道预约功能；现有频道、群聊、付费频道、群日程和钱包只用于验证现有能力组合。
- 不新增活动平台、AA 账本、托管、退款或自动分摊能力。
- 不把 `test/auto_test/` 的页面级状态复制一份到本目录；这里只保留流程引用和跨模块验收结果。
- P0/P1 表示业务验证优先级，不表示可以绕过账号、资金、密钥或第三方影响的人工确认。
