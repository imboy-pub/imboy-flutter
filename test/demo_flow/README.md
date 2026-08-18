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
| DF-01 | [account_flow.md](./account_flow.md) | 注册、登录、首次进入和账号恢复 | 部分通过：登录契约 9/9 与 macOS 入口通过（08-17）；注册受本地 License 配额 402 阻塞；退出重登受共享容器 E2EE 秘密清理风险阻塞 |
| DF-02 | [friend_flow.md](./friend_flow.md) | 添加好友并建立关系 | 本地 API 全闭环通过（08-17：搜索→删除→申请→确认→双端回读 7/7）；生产只读 5/5；双端 UI 通知阻塞 |
| DF-03 | [conversation_flow.md](./conversation_flow.md) | 会话列表、未读和进入聊天 | API 契约与 macOS 入口通过（08-17：1/1+2/2，构建签名修复后历史 OOM 未复现）；有效会话写入待隔离数据 |
| DF-04 | [single_chat_flow.md](./single_chat_flow.md) | 好友进入单聊并完成消息闭环 | 双端明文消息闭环历史 PASS 维持（08-17 无第二设备未新增）；macOS 入口 1/1；本地明文发送被 required 策略正确拒收；E2EE 未覆盖 |
| DF-05 | [channel_flow.md](./channel_flow.md) | 频道发现到群日程的消费者链路 | API 部分通过；频道→群跨模块结构性不成立（无群绑定字段，08-17 复核维持）；本地订阅/付费证据见 DF-12/13 |
| DF-06 | [group_flow.md](./group_flow.md) | 群功能总索引和执行入口 | 08-17 本地建群/面对面/管理/消息/协作 API 级全部闭环；索引已同步各专题状态 |
| DF-07 | [group_creation_flow.md](./group_creation_flow.md) | 建群、面对面建群和入群 | 通过（08-17 本地 API 级：普通建群+邀请回读、面对面暗号入群双方落库 3/3）；本地 face2face_save 静默不落库 bug 上游已修复待部署 |
| DF-08 | [group_chat_flow.md](./group_chat_flow.md) | 群内消息和成员协作 | 双账号文本消息闭环历史 PASS 维持；08-17 本地密文消息服务端归档验证 2/2；发现 msg_page 键名与列不匹配致历史恒空（疑似历史"归档为空"根因）；@成员与失败分支未覆盖 |
| DF-09 | [group_management_flow.md](./group_management_flow.md) | 群信息、成员和权限管理 | 通过（08-17 本地 API 级全闭环 3/3：群名/公告、角色提升/恢复、成员移除+邀回——移除为历史首次执行）；群主转让/危险操作未覆盖 |
| DF-10 | [group_collaboration_flow.md](./group_collaboration_flow.md) | 群日程、任务和投票 | 双账号写入历史 PASS 维持；08-17 本地单账号 API 闭环 4/4（创建/确认/提交/投票/回读）；费用与跨频道链路未覆盖 |
| DF-11 | [e2ee_security_flow.md](./e2ee_security_flow.md) | E2EE 建立、消息安全和密钥恢复 | 本地密码学通过（08-17 复跑 64 项），生产策略已变 disabled，双设备/恢复阻塞 |

### P1：重要业务能力

| 编号 | 文档 | 业务目标 | 当前状态 |
|---|---|---|---|
| DF-12 | [channel_creator_flow.md](./channel_creator_flow.md) | 频道创建、发布、评论和管理 | 本地 API 写入闭环通过（08-17：创建/编辑/发布/评论/管理 7/7，三重门禁默认 SKIP）；UI 链路与订阅者视角阻塞 |
| DF-13 | [paid_channel_flow.md](./paid_channel_flow.md) | 付费频道、订单和购买后解锁 | 本地 mock 全链闭环通过（08-17：充值→订单→解锁→退款回收 6/6）；生产购买阻塞（无付费频道样本+禁写） |
| DF-14 | [group_content_flow.md](./group_content_flow.md) | 群相册、群文件和媒体内容 | 相册创建+回读通过（08-17）；文件/照片上传阻塞于本地 Garage 对象存储不在线（endpoint IP 过期 192.168.1.150→本机 192.168.0.98） |
| DF-15 | [group_organization_flow.md](./group_organization_flow.md) | 群分类、标签、二维码和邀请 | 本地写入回读通过（08-17：分类/标签 4/4 + 群二维码 API 生成回读 + 渲染 9/9）；双端扫码阻塞 |
| DF-16 | [moments_flow.md](./moments_flow.md) | 发布朋友圈并完成查看、互动 | 本地API闭环通过（发布/好友可见/点赞/评论/回读），UI链路未复验 |
| DF-17 | [wallet_flow.md](./wallet_flow.md) | 钱包余额、转账和结果回传 | 本地API部分通过：充值/发送/扣款/流水/错误分支通过；accept被后端BUG-A阻塞 |
| DF-18 | [red_packet_flow.md](./red_packet_flow.md) | 红包发送、领取和结果查看 | 本地API闭环通过（发送/领取/重复拒绝/详情一致/双方余额流水），UI链路未复验 |
| DF-19 | [contact_management_flow.md](./contact_management_flow.md) | 联系人备注、标签和分组管理 | 本地写入闭环通过（08-17：备注/标签/打标/筛选/分组/移动 8/8）；发现分组 API 客户端未接入与 id 契约形状问题；UI 展示阻塞 |
| DF-20 | [qrcode_invite_flow.md](./qrcode_invite_flow.md) | 用户、群、频道二维码和扫码邀请 | 本地渲染与用户/群码 API 生成回读通过，频道码服务端路由缺失，双端扫码阻塞 |
| DF-21 | [call_flow.md](./call_flow.md) | 单聊音视频和 RTC 房间 | 本地状态机/信令 51 项通过，生产入口可达（902），本地 join 缺 LiveKit 配置，双端媒体阻塞 |
| DF-22 | [live_room_flow.md](./live_room_flow.md) | 直播间创建、开播和观看 | 本地列表状态与 API 只读回读通过，开播/观看阻塞（媒体服务缺失） |

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

## 4.2 2026-08-17 全量 Flow 复核证据汇总

本轮以 7 个并行 Claude Code 会话覆盖全部 DF-01～DF-22，环境为本地后端（127.0.0.1:9800，alpha.27）+ 生产只读（pro.imboy.pub，alpha.36）+ macOS 桌面入口。Android 真机未连接、iPhone 16e 离线，所有双端实时闭环维持历史证据、本轮未新增。

### 本轮通过（本地 API 级闭环，全部带服务端证据）

- DF-07 建群（普通+面对面 3/3）、DF-09 群管理（含历史首次成员移除+邀回 3/3）、DF-10 协作（4/4）、DF-16 朋友圈（5/5）、DF-18 红包（5/5）、DF-02 好友关系（7/7）、DF-19 联系人管理（8/8）、DF-12 频道创作（7/7）、DF-13 付费频道 mock 全链含退款回收（6/6）。
- 生产只读契约复跑全部通过：auth 9/9、contact 5/5、conversation 8 过 2 门禁拦、group 6/6+5/5、schedule/task/vote 12 过 4 门禁拦、album/file/category/tag 全过、channel 12 过 3 门禁拦、moment 4/4、wallet 4/4、e2ee 9 过 1 跳。写端点被 `TEST_ALLOW_API_WRITES` 门禁在发请求前拦截属设计行为。
- 本地 E2EE 协议回归 64 项 0 失败（room_key_olm_roundtrip 本轮真实执行，不再是受控跳过）。

### 本轮发现的后端缺陷（imboy 仓只读定位，未修改）

1. **[P0] 转账收款恒失败**：`transfer_repo.erl` accept/refund 事务内 SELECT 走 `elib_pg:execute`，返回二元组永不匹配 `{ok,1,[...]}` 模式 → 合法 pending 转账恒报「转账订单不存在」（`red_packet_repo.erl:108-112` 注释为同类已修问题的铁证）。
2. **[P1] 群历史消息恒空**：`group/msg_page` 查询键 `to_groupid` 与 `msg_c2g` 实际列 `to_id` 不匹配，SQL 失败被吞后恒返回 `total=0`——疑似历史 flow「服务端历史归档为空」之谜的根因。
3. **[P1] 频道二维码路由缺失**：客户端构造 `/api/v1/channel/qrcode`，后端 `imboy_router.erl` 无此路由。
4. **[P2] 红包最低金额前后端不一致**：后端 ≥100 分，前端仅拦 <1 分。
5. **[P2] `friend/category/add` 响应 `payload.id` 为嵌套 map 而非 TSID 整数**（handler 把整行 map 当 LastInsertId）。
6. **[环境] 本地 alpha.27 `face2face_save` 静默不落库**（上游提交已修复，待部署后加严断言）；本地 Garage endpoint IP 过期（192.168.1.150，本机现为 192.168.0.98）致上传阻塞；本地无 `livekit` 配置段致 RTC join 500（`rtc_room_logic.erl` `build_grant/4` 崩溃）。

### 本轮维持阻塞（缺条件，未强行执行）

- 双端实时闭环类（DF-02 UI 通知、DF-04/DF-08 新增证据、DF-15/DF-20 扫码、DF-21 双端媒体、DF-22 开播）：无第二设备。
- DF-01 注册：本地 License 用户数上限 402；退出重登：共享 macOS 容器上 `quitLogin` 会全局清理 E2EE 秘密（含 r14 证据库），无隔离容器不敢执行。
- 生产付费/资金/密钥/删除类：安全协议一律禁止，维持阻塞。
- 生产 E2EE 策略已演进为 `e2ee_mode=disabled/storage_mode=compliance_e2ee`（历史为 optional），文档已更新。

### 新增可复用测试资产

`integration_test/demo_flow/` 新增 14 个纯 Dart 测试文件（均带非生产 URL + `TEST_ALLOW_API_WRITES` 等三重门禁，默认 SKIP，无凭证环境不假绿）。所有改动未 commit，`git diff --check` 通过。

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
