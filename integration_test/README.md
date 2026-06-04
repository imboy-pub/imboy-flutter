# ImBoy Flutter 集成测试

## 测试三层架构

```
Tier 1 ── API 契约测试      test/api/              dart test，无设备，可 CI
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
flutter test integration_test/channel/channel_e2e_test.dart ...
flutter test integration_test/channel/channel_publish_test.dart ...
flutter test integration_test/channel/channel_edit_persistence_test.dart ...
flutter test integration_test/channel/channel_subscribed_detail_consistency_test.dart ...
flutter test integration_test/contact/friend_management_test.dart ...
flutter test integration_test/contact/add_friend_request_test.dart --dart-define=TEST_SEARCH_KEYWORD=<uid> ...
flutter test integration_test/auth/register_flow_test.dart ...
flutter test integration_test/auth/password_change_test.dart \
  --dart-define=TEST_NEW_PASSWORD=<new_pwd> \
  --dart-define=TEST_ALLOW_PASSWORD_CHANGE=true ...
```

---

## 跳过策略

| 场景 | 处理方式 | CI 结果 |
|------|---------|---------|
| 后端不可达 | `markTestSkipped` | SKIP（不假绿） |
| 未配置凭证 | `markTestSkipped` | SKIP |
| 登录失败 | `markTestSkipped` | SKIP |
| 数据为空 | `markTestSkipped` | SKIP |
| 断言失败 | `fail` / `expect` | FAIL（真实失败） |

> **禁止**：`if (!ok) { return; }` 裸返回——使测试假绿，CI 无法发现问题。

---

## 共享工具库

`integration_test/flows/test_utils.dart`

| 函数 | 用途 |
|------|------|
| `settle(tester)` | 等待帧稳定 |
| `takeScreenshot(tester, name)` | 截图，不支持时静默跳过 |
| `ensureBackendAvailable()` | 后端探活，进程内缓存 |
| `checkPreconditions(tester)` | 后端 + 入口 + 自动登录组合检查 |
| `safeTap / tapAny` | 安全点击 |
| `drainKnownFrameworkExceptions` | 过滤良性框架异常，未知异常重抛 |
| `FlowConfig.*` | 从 `--dart-define` 读取配置 |

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

---

## test_automation/ 关系

`test_automation/scenarios/executable_cases.yaml` 引用的测试路径在重构后保持不变，YAML 无需修改。

```bash
bash test_automation/scripts/run_yaml_mapped_suite.sh
bash test_automation/scripts/run_yaml_mapped_suite.sh --resume --run-id <RUN_ID>
bash test_automation/scripts/run_yaml_mapped_suite.sh --rerun-failed
```

---

## 废弃文件

- `integration_test/test_helper.dart` → 用 `flows/test_utils.dart`
- `integration_test/test_config.dart` → 用 `FlowConfig`
