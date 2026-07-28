# ImBoy 自动化测试总览

本项目支持三种自动化测试路径，按当前可用性排列：

---

## 方案 A — mobile-mcp（Claude Code 直接控制，推荐）

**无需 Maestro driver 签名，Claude Code 通过 MCP 工具直接操作模拟器。**

### 前提

1. Xcode 安装好，模拟器已有 iOS ≤18.x runtime（iOS 26+ 有 amap 限制，见下文）
2. Claude Code 配置了 `mobile-mcp` MCP server（检查 `~/.claude.json`）

### 目标设备：iPhone 16 模拟器（iOS 18.5）

```bash
# 启动模拟器
xcrun simctl boot E2DB52F3-D627-401A-9DF7-D9433EE9C039

# 构建并安装 app
cd imboyapp
flutter build ios --simulator --dart-define=APP_ENV=pro -d E2DB52F3-D627-401A-9DF7-D9433EE9C039
xcrun simctl install E2DB52F3-D627-401A-9DF7-D9433EE9C039 build/ios/iphonesimulator/Runner.app

# 启动 Simulator.app 显示界面
open -a Simulator
```

### 运行测试（Claude Code 执行）

Claude Code 通过 `mcp__mobile__*` 工具操作：

| 工具 | 作用 |
|------|------|
| `mcp__mobile__set_device` | 选择目标模拟器 |
| `mcp__mobile__launch_app` | 启动 app（bundle ID: `pub.imboy.2`） |
| `mcp__mobile__screenshot` | 截图验证 |
| `mcp__mobile__tap` | 点击坐标 |
| `mcp__mobile__input_text` | 输入文字 |
| `mcp__mobile__swipe` | 滑动手势 |
| `mcp__mobile__get_ui` | 获取 UI 树（辅助定位） |
| `mcp__mobile__stop_app` | 关闭 app |

### iOS 版本限制

| iOS 版本 | amap 构建 | 可用性 |
|---------|----------|--------|
| iOS 17.5 / 18.x | ✅ 正常 | **推荐** |
| iOS 26.x | ❌ amap 无 arm64 模拟器 slice | 不可用 |

---

## 方案 B — Maestro YAML flows

**声明式 YAML 脚本，51 个 Flow 覆盖启动、登录方式切换、认证表单、账号绑定校验、消息、联系人、附近的人、二维码、频道、我的页、设置、隐私、E2EE 备份与钱包。**

### 安装

```bash
brew install mobile-dev-inc/tap/maestro
```

### macOS Desktop（当前可用）

```bash
# 后台启动 macOS app
cd imboyapp
flutter run -d macos --dart-define=APP_ENV=pro &

# 等待启动后运行 flow
maestro test maestro/01_login.yaml \
  -e APP_ID=pub.imboy.macos \
  -e PHONE=+8613800138000 \
  -e PASSWORD=yourpwd
```

### iOS 模拟器（iOS 18.x，需先安装 app）

```bash
maestro test --config maestro/config.yaml maestro/ \
  -e APP_ID=pub.imboy.2 \
  -e PHONE=+8613800138000 \
  -e PASSWORD=yourpwd \
  -e FRIEND_ACCOUNT=friend_account
```

### iOS 真机（当前受阻）

Maestro driver bundle ID（`dev.mobile.maestro-driver-ios`）被 mobile.dev 公司注册，
无法绑定到其他 Apple Developer Team。解决方式：
- 升级为 [Maestro Cloud](https://maestro.mobile.dev/cloud) 账号
- 或改用方案 A（mobile-mcp）/ 方案 C（flutter test）

### Flow 说明

| 文件 | 测试内容 |
|------|---------|
| `00_startup.yaml` | App 启动冒烟 |
| `01_login.yaml` | 登录（phone + password） |
| `02_tab_navigation.yaml` | 4 个 Tab 切换 |
| `03_conversation.yaml` | 会话列表 + 搜索 |
| `04_send_message.yaml` | 打开会话 + 发送消息 |
| `05_contacts.yaml` | 联系人 + 新好友入口 |
| `06_channel.yaml` | 频道（feature flag 按需跳过） |
| `07_profile.yaml` | 我的页面 + 设置 |
| `08_logout.yaml` | 退出登录 |
| `10_e2ee_c2c.yaml` | 单聊 E2EE + 发送消息 |
| `11_e2ee_group.yaml` | 群聊 E2EE + 发送消息 |
| `12_moments_post.yaml` | 发布朋友圈 |
| `13_channel_post.yaml` | 发布频道内容 |
| `14_face_to_face.yaml` | 面对面建群 + 扫码入口 |
| `15_mine_navigation.yaml` | 个人资料、收藏、存储、登录设备、反馈入口 |
| `16_settings_navigation.yaml` | 账号、外观、E2EE、帮助与关于入口 |
| `17_contact_discovery.yaml` | 朋友圈、AI 助手、新好友、群聊、标签入口 |
| `18_profile_privacy_qrcode.yaml` | 个人资料、隐私设置、个人二维码 |
| `19_message_search.yaml` | 全局消息搜索与筛选器 |
| `20_e2ee_local_backup.yaml` | E2EE 本地备份导入/导出表单 |
| `21_channel_discovery.yaml` | 频道订阅/管理列表与发现搜索 |
| `22_chat_settings.yaml` | 单聊设置、会话内搜索、聊天背景 |
| `23_conversation_quick_actions.yaml` | 会话页快捷菜单、最近注册、二维码、添加好友入口 |
| `24_wallet_overview.yaml` | 钱包余额、功能区与流水概览 |
| `25_account_security_forms.yaml` | 邮箱、手机号绑定表单只读预览 |
| `26_storage_device_details.yaml` | 存储占用、登录设备与当前设备详情 |
| `27_favorites_search_filter.yaml` | 收藏搜索与类型筛选 |
| `28_group_list_search.yaml` | 群聊列表搜索与角色筛选入口 |
| `29_moment_notifications.yaml` | 朋友圈消息通知空态/列表态 |
| `30_contact_tag_search.yaml` | 联系人标签搜索 |
| `31_logout_account_preview.yaml` | 注销账号页与禁用态安全预览 |
| `32_personal_info_forms.yaml` | 昵称、性别、地区、签名编辑页只读预览 |
| `33_appearance_options.yaml` | 语言、深色模式与字体大小选项 |
| `34_friend_search_forms.yaml` | 新好友与添加好友搜索表单 |
| `35_feedback_history.yaml` | 反馈入口及历史列表/空态/错误态 |
| `36_assistant_plaza_search.yaml` | AI 助手透明声明与目录搜索 |
| `37_group_launch_preview.yaml` | 发起群聊、联系人选择与群选择入口 |
| `38_channel_auxiliary_lists.yaml` | 频道订单及邀请列表（功能开关） |
| `39_recently_registered_users.yaml` | 最近注册用户目录只读状态 |
| `40_device_rename_form.yaml` | 当前设备名称编辑表单预览 |
| `41_feedback_editor_preview.yaml` | 反馈编辑器输入区预览 |
| `42_channel_create_form.yaml` | 频道创建字段与类型预览（功能开关） |
| `43_message_search_filter_states.yaml` | 消息搜索类型与时间筛选交互 |
| `44_group_role_filter_states.yaml` | 群聊角色筛选交互 |
| `45_favorites_type_filter_states.yaml` | 收藏类型筛选交互 |
| `46_new_friend_request_states.yaml` | 新好友申请空态与处理状态 |
| `47_people_nearby_read_only.yaml` | 附近的人页面与定位授权后只读状态 |
| `48_scanner_entry_read_only.yaml` | 扫描二维码页面与相机授权后只读状态 |
| `49_auth_entry_forms.yaml` | 未登录登录、找回密码、注册表单预览（清理本机登录态） |
| `50_login_method_validation.yaml` | 账号、手机、邮箱登录方式切换与空表单校验（清理本机登录态） |
| `51_account_binding_validation.yaml` | 绑定邮箱与手机号非法输入的本地校验（不请求验证码） |

截图产物自动保存在 `.maestro/tests/<timestamp>/`。

> `04`、`10`～`14` 会发送消息、发布内容或进入社交操作，请仅对已确认的测试账号和测试环境执行。`15`～`46` 不提交业务数据；其中 `19`、`43` 会写入本机搜索历史，`22` 需要 `FRIEND_ACCOUNT` 测试夹具，`24` 和 `38` 只查看钱包/订单，严禁在生产环境继续点击充值、提现、转账、退款或邀请处理。`25`、`26`、`31`～`34`、`37`、`40`～`42` 只检查敏感页面或表单，不请求验证码、不修改资料、不选择联系人、不创建频道、不提交反馈、不清理或删除设备，也不勾选/确认注销；`39`、`44`～`46` 只读取目录或切换筛选，不进入资料、群聊或处理好友申请。

只跑低副作用的只读流程：

```bash
maestro test --config maestro/config.yaml --include-tags=read-only maestro/ \
  -e APP_ID=your.app.id \
  -e PHONE=test_account \
  -e PASSWORD=test_password \
  -e FRIEND_ACCOUNT=test_friend_account
```

`49_auth_entry_forms.yaml` 和 `50_login_method_validation.yaml` 带有 `local-state-reset` 标签，会清理本机登录态，未包含在 `read-only` 流程中；如需单独验证认证入口，请在测试账号环境执行：

```bash
maestro test --config maestro/config.yaml maestro/49_auth_entry_forms.yaml \
  maestro/50_login_method_validation.yaml \
  -e APP_ID=your.app.id
```

---

## 方案 C — flutter test integration_test（真机，最可靠）

**Flutter 原生测试框架，用 app 自身签名证书，无额外 driver 签名问题。**

见 [integration_test/README.md](../integration_test/README.md)。

### 快速命令（真机 iPhone 16e）

```bash
cd imboyapp

# 冒烟门控
flutter test integration_test/smoke/smoke_test.dart \
  -d 00008140-000E30561E32801C \
  --dart-define=APP_ENV=pro \
  --dart-define=TEST_PHONE=+8613800138000 \
  --dart-define=TEST_PASSWORD=yourpwd

# 全量 UI 流程
flutter test integration_test/all_tests.dart \
  -d 00008140-000E30561E32801C \
  --dart-define=APP_ENV=pro \
  --dart-define=TEST_PHONE=+8613800138000 \
  --dart-define=TEST_PASSWORD=yourpwd
```

---

## 环境配置

```bash
cp maestro/.env.example maestro/.env
# 填写 PHONE / PASSWORD / DEVICE_ID / APP_ID
```

## Widget Key 速查

| Key | 说明 |
|-----|------|
| `login_phone_input` | 手机号输入框 |
| `login_password_input` | 密码输入框 |
| `login_submit_button` | 登录按钮 |
| `tab_conversations` | 消息 Tab |
| `tab_contacts` | 联系人 Tab |
| `tab_channel` | 频道 Tab |
| `tab_mine` | 我的 Tab |
| `chat_message_input` | 消息输入框 |
| `send_button` | 发送按钮 |
| `conversation_search_input` | 会话搜索框 |
| `add_friend_button` | 添加好友按钮 |
