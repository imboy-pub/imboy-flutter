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

## 维护约定

- 新增长期保留的集成测试文件时，同步更新本 README。
- 如果测试已被 `test_automation/` 接管，优先在那里维护执行编排，不在这里重复写一套流程文档。
- 本文档只记录当前存在的测试文件和直接运行入口，不再保留通用 Flutter 教程模板。
