# DF-01 注册 → 登录 → 首次进入 → 账号恢复

> 优先级：P0
> 状态：`登录与账号子页通过（2026-08-19 复跑维持 9/9）/ 注册本地被 License 配额阻塞（2026-08-19 复核仍 402）/ 找回密码失败分支通过（2026-08-19 复核维持）/ 退出重登阻塞（2026-08-19 复核维持）`

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
- 2026-08-17（Demo Flow 复验轮）：
  - 生产只读登录契约复跑：`API_BASE_URL/TEST_PHONE/TEST_PASSWORD` 从 `.env.pro` 注入执行 `dart test test/unit_test/api/auth_api_test.dart --concurrency=1`，`9/9 All tests passed`（登录 uid=4、错误凭证、token 刷新、init、版本检查、用户信息、无效路径边界）。未执行任何生产写入。
  - 注册机制侦察（imboy 后端仓只读）：`/api/v1/passport/signup` 与 `/api/v1/passport/findpassword` 均先经 `verification_code_ds:consume/2` 校验验证码；本地 `config/sys.local.config` 配置了仅 local/dev/test 生效的 `verification_master_code` 万能码（生产 `sys.config` 留空禁用），且本地 `api_auth_switch=off` 免签名。
  - 本地注册（DEMO-FLOW-20260817 前缀测试账号，POST 本地 signup）：万能码校验已通过（请求到达配额检查），但被 License 配额守卫结构化拒绝 `402 用户数已达授权上限`（社区版默认 `community_max_users=100` 已满）。**注册在本地环境阻塞于容量，非验证码问题**；本轮不清理本地用户数据（禁止删除）。
  - 错误验证码注册分支（本地）：`code=000000` → `code=1 验证码无效`，验证码门禁正确拒绝、无误报成功。
  - 找回密码失败分支（本地，复用 `.env.pro` 测试账号 uid=4）：`POST /api/v1/passport/findpassword` 错误验证码 → `code=1 验证码无效`；随后原密码重新登录 `code=0` 成功（uid=4）。**错误验证码不改变原密码已验证**；"恢复成功后新密码可登录"的正向分支未执行（不修改真实测试账号密码）。
  - 本地登录可用性：`.env.pro` 测试账号在本地后端可登录（uid=4，token 正常），本地 `conversation/mine` 为空（无会话数据）。
  - 退出重登（macOS App 自身会话）：**阻塞**。共享 macOS 容器仍持有 117（uid=50）生产会话与 r14 双端闭环的本地消息库；`quitLogin` 的 `E2eeSecretInventory.purgeAll` 按前缀**全局**清理 `e2ee_/olm_/db_cipher_key_` 等秘密（跨账号），登出会毁掉该本地证据库的解密密钥；且以本地环境启动会对生产 token 触发 401 自动登出（同样触发 purge）。无隔离容器或第二设备可用，本轮不执行。
  - 证据文件（本机临时目录，不入仓）：`/tmp/demo_flow_20260817/`（signup_a/b.json、signup_wrongcode.json、findpwd_wrongcode.json、local_login_pro_acct.json、relogin_original_pwd.txt）。
- 2026-08-18（后端升级后复核轮，本地后端 main@e6d785d0 已加载 08:44 编译代码、policy 返回 `profile=enterprise / e2ee_mode=required / storage_mode=secure_e2ee`）：
  - 生产只读登录契约复跑：`.env.pro` 变量逐项提取注入（未 source、未回显凭证）执行 `dart test test/unit_test/api/auth_api_test.dart --concurrency=1` → `9/9 All tests passed`（登录 uid=4、错误凭证、token 刷新、未认证 401、init、版本检查、极高版本不更新、用户信息、无效路径）。未执行任何生产写入。
  - 注册 402 复核（后端已升级，探测一次）：万能码 `verification_master_code` 校验仍通过；首轮缺 `nickname` 参数返回 `code=1 昵称不能为空`，补全后请求到达配额守卫仍被结构化拒绝 `402 用户数已达授权上限`；本地库 `user` 表 count=1993（只读 SQL 核实）。**注册维持阻塞于 License 配额**——尽管 policy profile 已是 enterprise，当前 license 的 max_users 仍不覆盖 1993 存量用户；本轮不清理本地用户数据（禁止删除）。
  - 退出重登阻塞复核：`user_repo_local.dart` `quitLogin` 仍调用 `E2eeSecretInventory.production().purgeAll()` 按 `secretKeyPrefixes` 前缀**全局**清理（跨账号，E2EE-015 设计行为，代码未变）；共享 macOS 容器（`pub.imboy.macos`）仍持有 `pro_1.db / pro_4.db / pro_50.db` 等多账号证据库（含 r14 双端闭环消息）。无隔离容器或第二设备，**维持阻塞不执行**。
  - 证据文件（本机临时目录，不入仓）：`/tmp/demo_flow_20260818/`（signup_probe.json、signup_probe2.json、local_login_pro4.json）。
- 2026-08-19（复核轮，本地后端维持 main@e6d785d0 / 1.0.0-alpha.36，`/healthz` ok）：
  - 生产只读登录契约复跑：`.env.pro` 变量逐项提取注入（未 source、未回显凭证）执行 `dart test test/unit_test/api/auth_api_test.dart --concurrency=1` → `9/9 All tests passed`（登录 uid=4、错误凭证、token 刷新、未认证 401、init、版本检查、极高版本不更新、用户信息、无效路径）。未执行任何生产写入。
  - 注册 402 复核（单次探测）：万能码 + `nickname` 齐备的 signup 请求（`DEMO-FLOW-20260819` 前缀测试账号）到达配额守卫，仍被结构化拒绝 `402 用户数已达授权上限`——**License 配额阻塞维持**（本轮未重复只读 SQL 计数，user 存量以 08-18 记录 count=1993 为准）；错误验证码 `code=000000` 分支 → `code=1 验证码无效`，验证码门禁仍正确拒绝、无误报成功。
  - 找回密码失败分支复跑：本地 `POST /api/v1/passport/findpassword` 错误验证码 → `code=1 验证码无效`；随后原密码重新登录 `code=0`（uid=4）。**错误验证码不改变原密码，维持 08-17 结论**；正向改密分支继续不执行。
  - 退出重登阻塞复核（代码 + 容器证据）：`lib/store/repository/user_repo_local.dart` `quitLogin`（233 行起）第 268 行仍调用 `E2eeSecretInventory.production().purgeAll()` 按前缀**全局**清理（跨账号，代码未变）；共享 macOS 容器 `pub.imboy.macos` 仍持有 `pro_1.db / pro_4.db / pro_50.db`（含 -shm/-wal）多账号证据库。无隔离容器或第二设备，**维持阻塞不执行**。
  - 证据文件（本机临时目录，不入仓）：`/tmp/demo_flow_20260819/`（df01_probe_result.json、token_uid4.txt；探针脚本 df01_probe.py 复用后即弃，不含凭证回显）。

## 6. 未来自动化目标

现有 `integration_test/app_test.dart` 与 `integration_test/mine/mine_subpages_smoke_test.dart` 已覆盖登录、主 Shell 和账号/设备入口；暂不新增包装测试。注册、退出后重登及恢复仅在隔离环境和专用账号可用时执行。
