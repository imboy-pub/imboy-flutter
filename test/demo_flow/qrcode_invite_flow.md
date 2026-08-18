# DF-20 生成二维码 → 扫码识别 → 进入目标业务

> 优先级：P1
> 状态：`本地渲染与用户/群二维码 API 生成回读通过，频道码服务端路由缺失，双端扫码阻塞`
> 最近验证：2026-08-17

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

## 6. 未来自动化目标

建议新增 `integration_test/demo_flow/qrcode_invite_flow_test.dart`，第一版可使用预置二维码图像，双端扫码保留为真机测试。
