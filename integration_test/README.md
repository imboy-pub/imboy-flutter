# IMBoy Flutter 集成测试

本目录存放 Flutter `integration_test` 测试文件，覆盖应用启动、登录、单聊、群聊、会话、联系人和频道等场景。

如果要按 10 条功能线做可恢复执行，优先使用：

```bash
bash test_automation/scripts/run_yaml_mapped_suite.sh
```

本 README 只说明 `integration_test/` 目录本身的直接运行方式。

## 当前目录

```text
integration_test/
├── all_tests.dart
├── app_simple_test.dart
├── app_test.dart
├── chat_test.dart
├── e2e_chat_test.dart
├── enhanced_chat_test.dart
├── group_manage_test.dart
├── login_test.dart
├── simple_demo_test.dart
├── simple_tap_test.dart
├── test_config.dart
├── test_helper.dart
├── chat/
│   ├── c2c_chat_test.dart
│   ├── c2c_dual_role_test.dart
│   ├── conversation_test.dart
│   └── group_chat_test.dart
├── channel/
│   ├── channel_e2e_test.dart
│   ├── channel_edit_persistence_test.dart
│   ├── channel_publish_test.dart
│   └── channel_subscribed_detail_consistency_test.dart
├── contact/
│   ├── add_friend_request_test.dart
│   └── friend_management_test.dart
├── e2e/                                   # 前后端 API 联调测试
│   ├── api_test_client.dart               # HTTP 测试客户端 & 断言工具
│   ├── api_e2e_test.dart                  # 核心 API 端到端测试
│   ├── ws_e2e_test.dart                   # WebSocket 联调测试
│   └── all_e2e_test.dart                  # 全套件入口
└── helper/
    ├── test_enhanced_helper.dart
    └── test_html_reporter.dart
```

## 推荐入口

### 1. 运行全部集成测试

```bash
flutter test integration_test --dart-define=APP_ENV=local_office -d macos
```

### 2. 运行单个基础测试

```bash
flutter test integration_test/app_simple_test.dart --dart-define=APP_ENV=local_office -d macos
flutter test integration_test/login_test.dart --dart-define=APP_ENV=local_office -d macos
flutter test integration_test/chat_test.dart --dart-define=APP_ENV=local_office -d macos
flutter test integration_test/e2e_chat_test.dart --dart-define=APP_ENV=local_office -d macos
```

### 3. 运行按能力拆分的测试

```bash
flutter test integration_test/chat/c2c_chat_test.dart --dart-define=APP_ENV=local_office -d macos
flutter test integration_test/chat/group_chat_test.dart --dart-define=APP_ENV=local_office -d macos
flutter test integration_test/chat/conversation_test.dart --dart-define=APP_ENV=local_office -d macos
flutter test integration_test/contact/friend_management_test.dart --dart-define=APP_ENV=local_office -d macos
```

### 4. 运行频道相关测试

```bash
flutter test integration_test/channel/channel_e2e_test.dart --dart-define=APP_ENV=local_office -d macos
flutter test integration_test/channel/channel_publish_test.dart --dart-define=APP_ENV=local_home -d macos
flutter test integration_test/channel/channel_edit_persistence_test.dart --dart-define=APP_ENV=local_home -d macos
flutter test integration_test/channel/channel_subscribed_detail_consistency_test.dart --dart-define=APP_ENV=local_home -d macos
```

## 运行说明

- `channel/channel_e2e_test.dart` 含创建频道后发布消息场景，要求后端和登录态可用。
- `channel/channel_publish_test.dart` 优先从已有可发布频道执行，不依赖现场创建频道。
- `channel/channel_edit_persistence_test.dart` 会修改频道描述并在结束后尝试恢复原值。
- `chat/c2c_dual_role_test.dart`、联系人相关测试通常更依赖双端账号、联调数据或设备前置。

### 5. 运行 E2E 前后端联调测试

E2E 联调测试直接通过 HTTP/WebSocket 与后端通信，验证前后端数据链路完整性。

```bash
# 方式 1: 使用运行脚本（推荐）
cp .env.e2e.example .env.e2e   # 首次使用，填入实际配置
./scripts/run_e2e_tests.sh

# 方式 2: 直接运行
flutter test integration_test/e2e/api_e2e_test.dart \
  --dart-define=APP_ENV=local_office \
  --dart-define=API_BASE_URL=http://192.168.2.19:9800 \
  --dart-define=TEST_PHONE=13800138000 \
  --dart-define=TEST_PASSWORD=test123456 \
  -d macos

# 仅 API 测试
./scripts/run_e2e_tests.sh --api-only

# 仅 WebSocket 测试
./scripts/run_e2e_tests.sh --ws-only

# Android 真机联调
./scripts/run_e2e_tests.sh -d R5CR20XXXXX --api-url http://192.168.1.100:9800
```

**E2E 测试覆盖范围：**

| 模块 | 测试点 |
|------|--------|
| 认证 | 登录成功/失败、Token 刷新 |
| 版本检查 | 有更新/无更新、字段完整性 |
| 用户信息 | 获取用户、用户设置 |
| 好友 | 好友列表 |
| 会话 | 会话列表、置顶会话 |
| 离线消息 | 拉取离线消息 |
| 初始化 | 初始化配置、ws_url |
| 群组 | 群组列表 |
| 搜索 | 最近联系人 |
| 错误处理 | 未认证访问、无效路径 |
| WebSocket | 连接建立、心跳、S2C 消息、稳定性 |

## 维护约定

- 新增长期保留的集成测试文件时，同步更新本 README。
- 如果测试已被 `test_automation/` 接管，优先在那里维护执行编排，不在这里重复写一套流程文档。
- 本文档只记录当前存在的测试文件和直接运行入口，不再保留通用 Flutter 教程模板。
