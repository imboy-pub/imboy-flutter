# DF-20 生成二维码 → 扫码识别 → 进入目标业务

> 优先级：P1
> 状态：`本地渲染 20/20 与 API 生成回读 5/5 复跑通过（2026-08-19；群码 2 用例当日曾因注入带引号 SOLIDIFIED_KEY 误判环境阻塞，主会话裁决后全量复跑 5/5）；频道码专属路由仍缺失且被 :channel_id 通配吞掉（2026-08-19 实测 code=1 频道不存在）；双端扫码待真机`
> 最近验证：2026-08-19

## 1. 目标

验证用户、群和频道二维码可以生成、保存/展示，并由授权测试账号扫码后进入正确的资料、群或频道入口。

## 2. 前置条件

- [ ] 准备第二设备或第二个授权测试账号。
- [ ] 使用测试用户、测试群和测试频道二维码。
- [ ] 不保存或分享真实用户二维码，不触发对外邀请。

## 3. TODO 步骤

- [ ] 打开用户二维码并扫码。
  - 预期：识别用户资料，后续可进入加好友流程。
  - 页面计划：[user_qrcode_page.md](../auto_test/qrcode/user_qrcode_page.md)、[scanner_page.md](../auto_test/scanner/scanner_page.md)
- [ ] 打开群二维码并扫码。
  - 预期：识别目标群，按权限进入群详情或入群确认。
  - 页面计划：[group_qrcode_page.md](../auto_test/qrcode/group_qrcode_page.md)、[scanner_result_page.md](../auto_test/scanner/scanner_result_page.md)
- [ ] 打开频道二维码并扫码。
  - 预期：进入频道详情或订阅入口。
  - 页面计划：[channel_qrcode_page.md](../auto_test/qrcode/channel_qrcode_page.md)
- [ ] 验证过期码、无效码和取消扫码。
  - 预期：有明确错误，不误跳转或加入。

## 4. 验收标准

- [ ] 三类二维码分别进入正确业务入口。
- [ ] 二维码内容、有效期和权限判断正确。
- [ ] 扫码过程不产生未经授权的好友、群或频道写入。

## 5. 当前覆盖与阻塞

- 需要相机权限、第二设备或第二账号。
- 扫码后涉及好友申请/入群/订阅时，沿用对应流程的授权和证据要求。
- 2026-08-09：用户、群/频道二维码的本地渲染检查通过；没有第二授权账号/设备，扫码识别、好友申请、入群和订阅写入保持 `BLOCKED`。
- 2026-08-17（DEMO-FLOW-20260817）：本地二维码渲染无头复跑 `flutter test test/unit_test/page/qrcode/ test/unit_test/page/scanner/scanner_qrcode_states_test.dart --concurrency=1` → `20` 项全部通过，覆盖用户/群二维码 URL 构造、渲染与扫码结果模型。
- 2026-08-17（DEMO-FLOW-20260817）：新增 `integration_test/demo_flow/qrcode_invite_flow_test.dart`（纯 dart test，本地后端），首次形成二维码**服务端生成回读**证据，`5/5 All tests passed`：
  - 用户码 `GET /api/v1/user/qrcode?id=<uid>` 回读 `type=user`、`id` 一致、含 `isfriend` 关系标记；
  - 无效用户码边界：不存在用户 → `payload.result=user_not_exist`（不误跳转）；
  - 有效群码 `GET /api/v1/group/qrcode?id=&exp=&tk=`（exp 为**毫秒**时间戳、`tk=md5(exp_solidifiedKey)`，与客户端 `qrcode_url.dart` 契约一致）回读 `type=group` + 扫码者 `group_member`；有效群码请求会触发服务端 `join_group(scan_qr_code)`——测试只对 A（13900001002 / uid 104250986822109184）已加入的群发起，join 幂等无成员数变化；测试群 `DEMO-FLOW-20260817-QR-GROUP` 由本轮建群产生（本地写入，仅测试账号，保留可回收）；
  - 过期群码（exp 过去 1 小时 + 正确 tk）→ 业务错误「验证码已过期」，不误入群；
  - **契约缺口（新发现）**：客户端 `buildChannelQrcodeUrl` 构造 `/api/v1/channel/qrcode?id=&exp=&tk=`，但后端 `imboy_router.erl` 未注册该路由——频道二维码扫码在服务端侧无法解析，需后端补路由或客户端调整。测试已将该缺口固化为断言。
- 双端扫码识别（相机权限、第二设备扫码 → 进入资料/入群/频道）仍保持 `BLOCKED`；本轮证据不替代扫码 UI 闭环。
- 2026-08-18：**复跑维持通过**。本地渲染 `flutter test test/unit_test/page/qrcode/ test/unit_test/page/scanner/scanner_qrcode_states_test.dart --concurrency=1` → `20` 项全部通过；API 生成回读 `dart test integration_test/demo_flow/qrcode_invite_flow_test.dart --concurrency=1` → `5/5 All tests passed`（用户码 type=user、无效码 user_not_exist、群码幂等回读、过期群码拒绝、频道码缺口断言）。运行注意：该测试头部注释示例从 `scripts/test.env` 读 API_BASE_URL，但该行带行内注释（`http://127.0.0.1:9800   # dart test ... 使用`），`read_env` awk 提取会把注释拼进 URL 导致登录报「code=200 non_json_response」——必须显式传 `API_BASE_URL=http://127.0.0.1:9800`（本轮实测确认）。
- 2026-08-18 频道码路由复核（**行为变化，新证据**）：`/api/v1/channel/qrcode` 专属路由在 `imboy_router.erl` 仍无注册（缺陷维持），但后端 alpha.36 下该 URL 不再表现为 404——被 `imboy_router.erl:326` 的 `/api/v1/channel/:channel_id` 通配捕获，"qrcode" 字符串被当作 channel_id 进入 `channel_handler:show` → `channel_logic:get_channel(<<"qrcode">>, Uid)` 查无此频道 → 带 token 实测返回 `HTTP 200 + code=1 msg=频道不存在`。即使 query 携带真实频道 id（本地库 DEMO-FLOW 频道 107539669547485184）与正确 tk，同样报「频道不存在」（show 只读路径参数不读 query 的 id/exp/tk）。结论：频道码扫码在服务端侧依旧不可用，且错误语义从「404 路由缺失」退化为「频道不存在」业务错误，对客户端更具误导性；`DF-20-5` 测试断言（code!=0）当前仍通过，但其「无此路由（404 或路由级错误）」的注释描述已过时，后端补路由后该用例需反向加严为成功回读。
- 2026-08-18 设备复核：Android 真机 MRD AL00 与 iPhone 16e 已在线（同 DF-02 记录），双端扫码 UI 闭环（相机权限、真机扫真实码 → 进入资料/入群/频道）的设备条件恢复，属真机验收轮次，本轮未执行。
- 2026-08-19：**部分复跑通过（3/5）+ 群码 2 用例环境阻塞（非回归）**。
  - 渲染复跑维持：`flutter test test/unit_test/page/qrcode/ test/unit_test/page/scanner/scanner_qrcode_states_test.dart --concurrency=1` → `20/20 All tests passed`（用户/群二维码 URL 构造、渲染与扫码结果模型），本轮未触发 Flutter SDK artifact 编译问题。
  - API 复跑 `dart test integration_test/demo_flow/qrcode_invite_flow_test.dart --concurrency=1`：DF-20-1 用户码 type=user/id 一致/isfriend 通过；DF-20-2 无效码 `user_not_exist` 通过；DF-20-5 频道码缺口断言通过，证据打印实测 `code=1 msg=频道不存在`——`/api/v1/channel/qrcode` 被 `:channel_id` 通配捕获的行为与 08-18 记载一致（缺陷+误导性错误语义维持，后端补路由后需反向加严断言）。
  - **DF-20-3 有效群码 / DF-20-4 过期群码：环境级阻塞**。实测均返回 `code=200 non_json_response`，取证链：今早 10:25 启动的运行节点（`_rel/imboy` 发布包 console 模式）未注入 `IMBOY_SOLIDIFIED_KEY` → `imboy_app:ensure_solidified_keys/0` 走节点名哈希派生 dev key 分支 → `group_handler:qrcode` 的 `md5(exp_Key)==Tk` 校验 `Verified=false` → handler 回 `302` 重定向 `www.imboy.pub` → dio 跟随重定向取回 HTML 200 → `non_json_response`。经只读 RPC 布尔比对确认运行节点 `application:get_env(imboy, solidified_key)` 与 `.env.local` 值 **mismatch**（探针不输出密钥值，已清理）。该问题与 DF-15 在 08-18 记载的群二维码读码回归同根因；**解锁条件：人工以 IMBOY_SOLIDIFIED_KEY 注入重启本地后端**（本会话按规则禁止重启后端）。两用例维持 08-18 的通过证据，不计为本轮回归。
  - 测试文件小改：建群 fallback 标题更新为 `DEMO-FLOW-20260819-QR-GROUP`（本轮未触发，A 已有加入群，零新增群数据）；DF-20-5 新增实际 code/msg 证据打印。运行注意维持：`API_BASE_URL` 必须显式传干净值（`scripts/test.env` 行内注释陷阱）。
  - **主会话裁决（同日）**：上述「运行节点 key mismatch」结论系**带引号比对**误判——`.env.local` 的 `SOLIDIFIED_KEY` 值带双引号，用 `read_env`/awk 提取后未去引号直接注入 `IMBOY_SOLIDIFIED_KEY` 时，tk 计算用的是带引号字符串，服务端校验必 302；该 agent 的 RPC 布尔比对探针同样以带引号串比对，故双重误判。与 DF-15 并行轮（正确去引号，4/4 含群码 code=0 通过）结论冲突后，主会话重放裁决：干净 44 字符 key → 群码 `code=0 msg=success`（role=4）+ 无效 tk 正确 302；故意带引号 key → `code=200 non_json_response`（与 DF-20-3/4 失败签名逐字一致）。**结论：运行节点 key 与 `.env.local` 去引号值一致，无需后端重启或任何变更**；随后以干净 key 全量复跑 `qrcode_invite_flow_test.dart` → `5/5 All tests passed`（DF-20-3 有效群码回读 type=group 幂等、DF-20-4 过期群码业务拒绝均当面通过），DF-20 本轮状态升级为通过。防御性加固：测试文件对 env 注入的 key 增加与文件读取同款的去引号处理，杜绝复发；运行注入仍须保证值本身无引号。

## 6. 未来自动化目标

建议新增 `integration_test/demo_flow/qrcode_invite_flow_test.dart`，第一版可使用预置二维码图像，双端扫码保留为真机测试。
