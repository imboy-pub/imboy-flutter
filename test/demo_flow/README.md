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
| DF-01 | [account_flow.md](./account_flow.md) | 注册、登录、首次进入和账号恢复 | 部分通过：登录契约 9/9 复跑维持（08-18）；注册仍受本地 License 配额 402 阻塞（本地 user 表 1993，profile=enterprise 不覆盖存量）；退出重登维持共享容器 E2EE 秘密清理风险阻塞 |
| DF-02 | [friend_flow.md](./friend_flow.md) | 添加好友并建立关系 | 本地 API 全闭环通过（08-18 复跑 7/7 维持）；生产只读 5/5；双端 UI 通知待执行（真机本轮已恢复在线，留待真机轮次） |
| DF-03 | [conversation_flow.md](./conversation_flow.md) | 会话列表、未读和进入聊天 | API 契约与 macOS 入口通过（08-18 复跑维持）；有效会话写入本轮闭环通过（e2ee 信封→ACK→归档→pin/unpin 幂等）；未读清零待对端回复消息 |
| DF-04 | [single_chat_flow.md](./single_chat_flow.md) | 好友进入单聊并完成消息闭环 | 单账号发送受理链路通过（08-18：e2ee 信封 ACK+归档+会话生成）；明文拒收为 required 策略设计行为；双端闭环维持历史 PASS；端上 E2EE 密码学闭环属 DF-11 |
| DF-05 | [channel_flow.md](./channel_flow.md) | 频道发现到群日程的消费者链路 | API 部分通过（08-18 生产只读复跑维持）；频道→群跨模块结构性不成立维持（alpha.36 后 20 个 channel 模块 grep 零绑定字段）；本地订阅/付费证据见 DF-12/13 |
| DF-06 | [group_flow.md](./group_flow.md) | 群功能总索引和执行入口 | 08-18 索引已同步各专题状态：建群 3/3、管理 4/4（含群主转让历史首次）、消息 2/2、协作 4/4 全部 API 级闭环维持或新增 |
| DF-07 | [group_creation_flow.md](./group_creation_flow.md) | 建群、面对面建群和入群 | 通过（08-18 复跑 3/3；face2face_save 落库修复在 alpha.36 实测生效，断言已按文档加严：save 响应含 group map+member_list、detail 回读、attr=join 列表） |
| DF-08 | [group_chat_flow.md](./group_chat_flow.md) | 群内消息和成员协作 | 密文归档 2/2 复跑维持（08-18）；msg_page 键名 bug 复核未修（to_groupid vs to_id，归档行存在同时 API total=0 实测复现）；@成员定性为本地 strict 环境结构性不可覆盖（密文 binary 与 mentions map 要求互斥） |
| DF-09 | [group_management_flow.md](./group_management_flow.md) | 群信息、成员和权限管理 | 通过（08-18 复跑 4/4：群名/公告、角色提升/恢复、成员移除+邀回维持，新增 DF-09-4 群主转让为历史首次执行，含 per_hour_once 限流负向断言） |
| DF-10 | [group_collaboration_flow.md](./group_collaboration_flow.md) | 群日程、任务和投票 | 通过（08-18 复跑 4/4 维持：创建/确认/提交/投票/回读）；费用与跨频道链路维持不覆盖（日程/任务/投票端点无费用语义） |
| DF-11 | [e2ee_security_flow.md](./e2ee_security_flow.md) | E2EE 建立、消息安全和密钥恢复 | 本地密码学通过（08-18 复跑 64 项 0 失败，room_key_olm_roundtrip 真实执行）；本地 policy=required/secure_e2ee 无变化；生产 disabled 维持；双设备/恢复阻塞维持（设备已在线但密钥类操作需人工授权） |

### P1：重要业务能力

| 编号 | 文档 | 业务目标 | 当前状态 |
|---|---|---|---|
| DF-12 | [channel_creator_flow.md](./channel_creator_flow.md) | 频道创建、发布、评论和管理 | 本地 API 写入闭环通过（08-18 复跑 7/7 维持：创建/编辑/发布/评论/管理）；三重门禁默认 SKIP 属设计；UI 链路与订阅者视角阻塞（本地无第二可登录账号+无设备轮次） |
| DF-13 | [paid_channel_flow.md](./paid_channel_flow.md) | 付费频道、订单和购买后解锁 | 本地 mock 全链闭环通过（08-18 复跑 6/6：充值→订单→解锁→退款回收，fixture 无残留）；生产购买维持阻塞（无付费频道样本+资金红线禁写） |
| DF-14 | [group_content_flow.md](./group_content_flow.md) | 群相册、群文件和媒体内容 | 相册创建+回读通过维持（08-18）；文件/照片上传阻塞根因更新：upload_url 域名仅为展示字段，上传核心路径仍读 garage.endpoint 过期 IP 192.168.1.150:3900，解锁需改配置并重启后端 |
| DF-15 | [group_organization_flow.md](./group_organization_flow.md) | 群分类、标签、二维码和邀请 | 分类/标签 4/4 复跑维持（08-18）；群二维码读码出现环境级回归：后端重启后 IMBOY_SOLIDIFIED_KEY 未注入致 tk 校验 302（非代码缺陷，需人工重启注入）；双端扫码待真机 |
| DF-16 | [moments_flow.md](./moments_flow.md) | 发布朋友圈并完成查看、互动 | 本地 API 闭环通过（08-18 复跑 5/5）；UI 链路本轮以 flutter test 补验 109 项 0 失败（feed/发布/详情/并发状态）；真实 HTTP 渲染与手势待真机 |
| DF-17 | [wallet_flow.md](./wallet_flow.md) | 钱包余额、转账和结果回传 | 通过（08-18：上轮 P0 BUG-A 转账收款修复复验——accept code=0 闭环、双方余额/流水核对、重复 accept 拒绝；上轮卡死 pending 全部回收现 0 悬挂；BUG-B 超余额泄露 db_exception 亦修复） |
| DF-18 | [red_packet_flow.md](./red_packet_flow.md) | 红包发送、领取和结果查看 | 本地 API 闭环通过（08-18 复跑 4/4：发送/领取/重复拒绝/详情一致/双方流水）；最低金额前后端不一致维持（后端≥100 分 vs 前端拦<1 分，P2）；UI 链路待真机 |
| DF-19 | [contact_management_flow.md](./contact_management_flow.md) | 联系人备注、标签和分组管理 | 本地写入闭环通过（08-18 复跑 8/8 维持）；payload.id 嵌套 map 缺陷与分组 API 客户端未接入均维持未修；UI 展示待真机 |
| DF-20 | [qrcode_invite_flow.md](./qrcode_invite_flow.md) | 用户、群、频道二维码和扫码邀请 | 渲染 20/20 与用户/群码 API 生成回读 5/5 通过（08-18）；频道码路由缺失且错误语义退化为被通配路由捕获返回 200/code=1（误导性业务错误，后端补路由后需反向加严断言）；双端扫码待真机 |
| DF-21 | [call_flow.md](./call_flow.md) | 单聊音视频和 RTC 房间 | 本地状态机/信令 51 项复跑通过维持（08-18）；本地 join 仍缺 livekit 配置 500（build_grant/4 崩溃）；双端媒体待真机 |
| DF-22 | [live_room_flow.md](./live_room_flow.md) | 直播间创建、开播和观看 | 本地列表状态 12 项与 API 只读回读通过维持（08-18）；开播/观看阻塞维持（与 DF-21 同根因缺媒体服务） |

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

## 4.3 2026-08-18 全量 Flow 复核证据汇总

本轮以 7 个并行会话覆盖全部 DF-01～DF-22，环境为本地后端（127.0.0.1:9800，已升级 **1.0.0-alpha.36**，main@e6d785d0，beam 08:44 编译/08:46 启动）+ 生产只读 + macOS 入口。上轮多项后端修复已随 alpha.36 部署到本地，本轮完成修复复验。

### 本轮通过（含修复复验与历史首次执行）

- **DF-17 钱包 BUG-A 修复复验通过（本轮最高价值）**：transfer accept 闭环 code=0、双方余额与流水核对一致、重复 accept 拒绝；上轮两笔卡死 pending（107540522685696000、107541287196166144）及未记录的第三笔全部成功回收，transfer_order 现 0 笔悬挂；BUG-B（超余额泄露 db_exception）同步修复确认。wallet_flow 状态升级为通过。
- **DF-07 face2face_save 落库修复实测生效**：alpha.36 含修复提交 21af8e78/41034a52，断言按文档加严（save 响应 group map+member_list 双方、detail 回读、非群主侧 attr=join）。
- **DF-09-4 群主转让历史首次执行**：专用面对面群上 A→B 单向转让（owner_uid 回读、role=4/1、group_log type=9 落库、per_hour_once 限流负向断言通过）。
- **DF-03 有效会话写入闭环通过**（上轮遗留项）：符合 v2.0 加密契约的 e2ee 信封消息经真实服务端路径（C2C_SERVER_ACK→归档→conversation/mine）产生会话，pin/unpin 幂等验证通过，数据已还原。
- **DF-16 朋友圈 UI 链路补验**（上轮"未复验"项）：flutter test 109 项 0 失败（feed/发布/详情渲染契约/并发状态）。
- 其余复跑全绿维持：DF-01 登录 9/9、DF-02 好友 7/7、DF-04 单账号受理链路、DF-05 生产只读（channel 6+1 门禁拦/order 3 过 2 跳/wallet 4/has_more 6）、DF-08 密文归档 2/2、DF-10 协作 4/4、DF-11 E2EE 64 项（room_key_olm_roundtrip 真实执行）、DF-12 频道创作 7/7、DF-13 付费频道 mock 6/6（fixture 无残留）、DF-14 相册、DF-15 分类/标签 4/4、DF-18 红包 4/4、DF-19 联系人 8/8、DF-20 渲染 20/20+API 5/5、DF-21 状态机 51 项、DF-22 列表 12 项+只读回读。

### 上轮缺陷复核结果（imboy 仓只读定位，未修改）

1. **已修复并实测确认**：BUG-A 转账收款（transfer_repo accept 事务 query/3）、BUG-B 超余额泄露、face2face_save 静默不落库。
2. **未修复维持**：msg_page 键名 bug（group_handler 仍构造 `to_groupid`，msg_c2g 实际列 `to_id`；归档行存在同时 API total=0 实测复现）；频道二维码路由缺失；friend/category/add payload.id 嵌套 map；红包最低金额前后端不一致（P2）。
3. **新发现**：a) 频道码 `/api/v1/channel/qrcode` 被 `/api/v1/channel/:channel_id` 通配捕获，错误语义从 404 退化为 200+code=1 误导性业务错误；b) @成员在本地 strict 环境结构性不可覆盖（encrypted_message_body 要求密文 binary 与 mentions_from_payload 要求 map 互斥，服务端 mentions 恒空）；c) `scripts/test.env` 的 API_BASE_URL 行内注释会污染 URL 提取导致 non_json_response（须显式传干净环境变量）；d) `channel_api_has_more_test.dart` 等含 flutter_test 的文件必须 `flutter test` 运行。

### 环境级问题（需人工决策，本轮未处置）

1. **DF-14 上传阻塞根因更正**：`upload_url => https://s3.imboy.pub` 仅为 index_handler 暴露的展示字段，上传核心路径读 `garage.endpoint` 仍为过期 IP 192.168.1.150:3900；s3.imboy.pub 域名在线但本机 DNS 被 fake-ip 劫持无法确认归属——解锁需人工确认归属后改 endpoint 并重启后端。
2. **DF-15 群二维码读码回归（环境级）**：后端重启后运行环境无 IMBOY_SOLIDIFIED_KEY 注入，走节点名哈希派生 dev key 分支致 tk 校验 302——需人工注入环境变量重启恢复。
3. **Flutter 3.47.0 SDK artifact 损坏**：挂载框架的无头 widget 测试加载失败（text_painter.dart 编译错误），08-17 相关 9/9 证据维持历史引用。

### 数据与账号披露

- 群流程 B 账号由 test_886209702@example.com（凭证仅存占位符不可考据）切换为 smoke_bob（uid 1000000056，moments/wallet/red_packet 文档已记载账号），三个测试文件登录方式同步调整。
- 本轮真机条件变化：Android 真机 MRD AL00 与 iPhone 16e 已恢复在线（上轮离线），但双端 UI 验收需两设备各自登录授权账号，属真机轮次，本轮未执行，各 flow 维持"待执行（设备已恢复在线）"。
- 钱包余额：期初与上轮期末差（A +990/B +100）为 08-17 后其他流程所致，本轮 A 净 0、B +100（DF-18 红包），上轮悬挂 pending 已全部回收。
- 新增本地可回收数据均已标记 DEMO-FLOW-20260818 并在各 flow 文档记录；含凭证的临时探针脚本已清理；`.env.pro` 未 source、凭证未输出、生产零写入。所有改动未 commit。

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
