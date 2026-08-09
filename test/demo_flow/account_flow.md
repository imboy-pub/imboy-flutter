# DF-01 注册 → 登录 → 首次进入 → 账号恢复

> 优先级：P0
> 状态：`登录与账号子页通过 / 注册、恢复受控跳过`

## 1. 目标

验证新用户可以注册账号、完成首次进入，老用户可以登录并在忘记密码时走账号恢复入口。

## 2. 前置条件

- [ ] 使用明确的非生产环境和专用测试账号/手机号。
- [ ] 注册验证码、密码和账号数据由人工确认，不把凭证写入仓库或日志。
- [ ] 注册和改密会写入账号数据；默认不使用真实第三方手机号。

## 3. TODO 步骤

- [ ] 打开注册页，填写测试账号和密码。
  - 预期：必填校验、密码规则和下一步按钮状态正确。
  - 页面计划：[signup_page.md](../auto_test/passport/signup_page.md)
- [ ] 完成注册继续流程并进入主界面。
  - 预期：注册成功、会话建立、首次进入不白屏。
  - 页面计划：[signup_continue_page.md](../auto_test/passport/signup_continue_page.md)、[welcome/](../auto_test/welcome/)
- [x] 使用已注册账号登录并进入主界面。
  - 预期：登录成功后恢复用户资料和会话。
  - 页面计划：[login_page.md](../auto_test/passport/login_page.md)
- [x] 进入账号管理，确认当前账号和设备信息。
  - 预期：账号身份、登录状态和设备列表正确。
  - 页面计划：[manage_account_page.md](../auto_test/passport/manage_account_page.md)
- [ ] 在专用测试账号上验证忘记密码入口和验证码失败提示。
  - 预期：失败不改变原密码，恢复成功后新密码可登录。
  - 页面计划：[forgot_password_page.md](../auto_test/passport/forgot_password_page.md)、[forgot_password_pin_code_page.md](../auto_test/passport/forgot_password_pin_code_page.md)

## 4. 验收标准

- [ ] 注册、登录、退出后重新登录和账号恢复均有服务端结果。
- [ ] 错误验证码、错误密码和重复注册不会误报成功。
- [ ] 账号恢复不会影响其他测试账号。

## 5. 当前覆盖与阻塞

- 已有局部测试：`integration_test/auth/register_flow_test.dart`。
- 2026-08-09：生产认证接口包含在蓝绿发布后的定向 P0 API 合约回归中，认证用例 `9/9` 通过；整体定向套件 `58` 项通过、`1` 项受控跳过。Android 与 macOS 生产登录冒烟通过，macOS `app_test.dart` 基础入口 `2/2` 通过，证明已注册账号登录 API 和 App 基础启动可用。
- 同一账号以 `account`、`email` 两种 API 登录类型各运行一次，均 9/9 通过；Android 真机已在账号子页复核中完成 UI 登录，macOS 仍受本机数据环境限制。
- 2026-08-09：Android 华为真机 `mine_subpages_smoke_test.dart` 生产登录后进入 9 个「我的」子页并通过 `1/1`；注销页只验证渲染，不点击执行按钮。首次运行因测试未自动登录而跳过，补齐统一 `checkPreconditions` 后复跑通过。
- 注册、退出后重登、忘记密码和恢复 UI 尚未形成完整证据；客户端自动登录仍受桌面/真机运行器交互能力限制。
- 验证码、真实手机号和改密属于外部条件；缺条件时标记 `阻塞`。
- 2026-08-09：注册、退出后重登和忘记密码/恢复均按生产写入与验证码前置条件受控跳过；本轮不把登录和账号子页通过扩展为完整账号闭环。

## 6. 未来自动化目标

现有 `integration_test/app_test.dart` 与 `integration_test/mine/mine_subpages_smoke_test.dart` 已覆盖登录、主 Shell 和账号/设备入口；暂不新增包装测试。注册、退出后重登及恢复仅在隔离环境和专用账号可用时执行。
