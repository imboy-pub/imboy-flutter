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

**声明式 YAML 脚本，9 个 flow 覆盖主要用户路径。**

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
maestro test maestro/config.yaml \
  -e APP_ID=pub.imboy.2 \
  -e PHONE=+8613800138000 \
  -e PASSWORD=yourpwd
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

截图产物自动保存在 `.maestro/tests/<timestamp>/`。

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
