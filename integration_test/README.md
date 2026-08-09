# ImBoy Flutter 集成测试

## 测试三层架构

```
Tier 1 ── API/WS 契约测试   test/api/              dart test，无设备，可 CI，环境变量配置
Tier 2 ── 冒烟门控          integration_test/smoke/ flutter test，需真机，合并必须绿
Tier 3 ── UI 流程测试       integration_test/       flutter test，需真机，回归可选
```

---

## Tier 1：API 契约测试（无设备）

```bash
API_BASE_URL=http://127.0.0.1:9800 \
TEST_PHONE=+8613800138000 \
TEST_PASSWORD=<pwd> \
  dart test test/api/ --concurrency=1
```

覆盖：`auth_api_test.dart`（认证/版本/用户）、`conversation_api_test.dart`（会话/消息/好友/群组）、`ws_api_test.dart`（WebSocket 连接/心跳/格式）

---

## Tier 2：冒烟门控（合并前必须绿）

```bash
flutter test integration_test/smoke/smoke_test.dart \
  --dart-define=API_BASE_URL=http://127.0.0.1:9800 \
  --dart-define=TEST_PHONE=+8613800138000 \
  --dart-define=TEST_PASSWORD=<pwd> \
  -d <real_device_id>
```

前置失败一律 `fail()`，禁止跳过。

---

## Tier 3：UI 流程测试

### 全量

```bash
flutter test integration_test/all_tests.dart \
  --dart-define=APP_ENV=local_office \
  --dart-define=TEST_PHONE=+8613800138000 \
  --dart-define=TEST_PASSWORD=<pwd> \
  -d <real_device_id>
```

### 单模块

```bash
flutter test integration_test/app_test.dart -d <device> --dart-define=APP_ENV=local_office
flutter test integration_test/chat/conversation_test.dart ...
flutter test integration_test/chat/group_chat_test.dart ...
flutter test integration_test/e2e_chat_test.dart ...
flutter test integration_test/channel/channel_e2e_test.dart ... \
  --dart-define=TEST_ALLOW_CHANNEL_WRITES=true
flutter test integration_test/channel/channel_publish_test.dart ... \
  --dart-define=TEST_ALLOW_CHANNEL_WRITES=true
flutter test integration_test/channel/channel_edit_persistence_test.dart ... \
  --dart-define=TEST_ALLOW_CHANNEL_WRITES=true
flutter test integration_test/channel/channel_subscribed_detail_consistency_test.dart ...
flutter test integration_test/contact/friend_management_test.dart ...
flutter test integration_test/contact/add_friend_request_test.dart --dart-define=TEST_SEARCH_KEYWORD=<uid> ...
flutter test integration_test/auth/register_flow_test.dart ...
flutter test integration_test/auth/password_change_test.dart \
  --dart-define=TEST_NEW_PASSWORD=<new_pwd> \
  --dart-define=TEST_ALLOW_PASSWORD_CHANGE=true ...
# 关系/消息/群/密码等业务写入还必须显式设置
# --dart-define=TEST_ALLOW_BUSINESS_WRITES=true，且目标环境不能是生产
```

---

## 跳过策略

| 场景 | 处理方式 | CI 结果 |
|------|---------|---------|
| 后端不可达 | `markTestSkipped` | SKIP（不假绿） |
| 未配置凭证 | `markTestSkipped` | SKIP |
| 登录失败 | `markTestSkipped` | SKIP |
| 数据为空 | `markTestSkipped` | SKIP |
| 频道或业务写入未显式授权/指向生产 | `markTestSkipped` + 立即 `return` | SKIP |
| 断言失败 | `fail` / `expect` | FAIL（真实失败） |

> 门禁必须先调用 `markTestSkipped`，再由调用方立即 `return`；禁止在没有跳过标记的情况下裸返回。

---

## 共享工具库

`integration_test/flows/test_utils.dart`

频道创建、发布和编辑测试还要求 `TEST_ALLOW_CHANNEL_WRITES=true`，并且必须显式
设置 `API_BASE_URL` 或非生产 `APP_ENV`。这些条件独立于账号凭证，是避免 E2E
命令误写目标环境的安全闸门；只读的频道详情一致性测试不需要此开关。

关系、消息、群、日程、密码和其它业务写入测试还要求
`TEST_ALLOW_BUSINESS_WRITES=true`；共享门禁同时拒绝生产 `APP_ENV` 和生产地址，
调用方必须在门禁返回 `false` 后立即 `return`。

| 函数 | 用途 |
|------|------|
| `settle(tester)` | 等待帧稳定 |
| `takeScreenshot(tester, name)` | 截图，不支持时静默跳过 |
| `ensureBackendAvailable()` | 后端探活，进程内缓存 |
| `checkPreconditions(tester)` | 后端 + 入口 + 自动登录组合检查 |
| `safeTap / tapAny` | 安全点击 |
| `drainKnownFrameworkExceptions` | 过滤良性框架异常，未知异常重抛 |
| `FlowConfig.*` | 从 `--dart-define` 读取配置 |
| `requireChannelWriteAuthorization()` | 频道写入授权与生产环境门禁，返回 `false` 时立即退出 |
| `requireBusinessWriteAuthorization()` | 通用业务写入授权与生产环境门禁，返回 `false` 时立即退出 |

---

## Widget Key 索引

优先用 `find.byKey(const Key('...'))` 定位，图标/文本作降级回退。

### 登录页

| Key | Widget |
|-----|--------|
| `login_phone_input` | 手机号输入框 |
| `login_password_input` | 密码输入框 |
| `login_submit_button` | 登录按钮 |

### 底部导航栏

| Key | Tab | 备注 |
|-----|-----|------|
| `tab_conversations` | 消息 | 索引 0 |
| `tab_contacts` | 联系人 | 索引 1 |
| `tab_channel` | 频道 | 索引 2，功能开关控制 |
| `tab_mine` | 我 | 最后索引 |
