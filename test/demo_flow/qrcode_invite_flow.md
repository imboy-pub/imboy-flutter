# DF-20 生成二维码 → 扫码识别 → 进入目标业务

> 优先级：P1
> 状态：`本地二维码渲染通过，双端扫码阻塞`

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

## 6. 未来自动化目标

建议新增 `integration_test/demo_flow/qrcode_invite_flow_test.dart`，第一版可使用预置二维码图像，双端扫码保留为真机测试。
