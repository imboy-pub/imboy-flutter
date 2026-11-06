> **执行归属与全量范围**：先读 [统一测试执行说明](../docs/testing/execution.md)。
> `all_tests.dart` 仅为部分目标聚合，宿主 API、单设备、双端、Patrol 分别编排。
> `bash scripts/run_test_suite.sh --profile device --dry-run` 查看设备义务；full 缺环境必须阻塞。
> 以下历史单目标示例不代表全量通过；不得使用生产地址或真实用户身份。

# ImBoy Flutter 集成测试

## 统一执行范围

执行合同、结果口径和隔离环境准备见 [统一测试执行说明](../docs/testing/execution.md)。
`all_tests.dart` 是历史小范围聚合入口，明确归为 aggregate，不重复作为独立业务目标执行。
设备文件也不等于设备全量；真实 API 目标、平台专项、双端和 Patrol 各有归属及 runner。

| 范围 | profile | 运行条件 |
|---|---|---|
| 无设备真实 API/WS | backend | 字面 loopback 后端、合成身份、隔离签名材料 |
| 单设备流程 | device-single | 已核对的平台/设备与目标 fixture |
| 双端消息、RTC、跨端加密 | device-pair | 完整配对角色、平台拓扑与编排 |
| Patrol 原生权限/系统 UI | native-ui | Android instrumentation、本次 JUnit |
| 所有适用目标与产品组合 | full | 以上及宿主、FFI、Golden 等全部条件 |

## 命令

```bash
# 无设备、无账号也能查看精确实例；只生成计划不代表执行通过。
bash scripts/run_test_suite.sh --profile device --dry-run
bash scripts/run_test_suite.sh --profile full --dry-run

# 各专项，准备条件见统一说明；报告放在仓外。
bash scripts/run_test_suite.sh --profile backend --platform macos --artifact-dir /tmp/imboy-backend
bash scripts/run_test_suite.sh --profile device-single --platform android --artifact-dir /tmp/imboy-android
bash scripts/run_test_suite.sh --profile device-pair --artifact-dir /tmp/imboy-pairs
bash scripts/run_test_suite.sh --profile native-ui --platform android --artifact-dir /tmp/imboy-native

# 单目标仍消费同一归属/平台/产品合同；结果仅代表这个显式范围。
bash scripts/run_test_suite.sh --profile device-single --platform android \
  --target integration_test/app_test.dart --artifact-dir /tmp/imboy-app-target

# 真正完整回归；缺任一适用平台、fixture 或结果会阻塞。
bash scripts/run_test_suite.sh --profile full --artifact-dir /tmp/imboy-full
```

使用唯一报告目录保存每次尝试。多宿主、多产品和配对控制器的分片方式、最终对账命令
见统一说明；不能把同一设备遍历成功表述为 full 通过。相机等系统权限专项要求明确准备
硬件和授权；目标内部保留的无设备降级断言，只证明该降级路径，不能证明真实拍照通过。

## 未执行与失败

| 场景 | reason_code | 结果 |
|---|---|---|
| 当前平台不适用 | PLATFORM_NA | NOT_APPLICABLE；保留其他适用平台义务 |
| 本次 profile 未选择 | OUT_OF_SCOPE | NOT_SELECTED |
| 后端/账号/密钥/设备/基线缺失 | ENV_MISSING | BLOCKED |
| 前置失败、取消或缺证据 | UPSTREAM_FAILED | BLOCKED，附具体前置 |
| 已选目标运行时出现未批准 skip | UNEXPECTED_SKIP | BLOCKED；即使进程退出 0 |
| 断言失败 | BUSINESS_ASSERTION_FAIL | FAIL，不重试洗绿 |

底层旧测试的 `markTestSkipped` 不再等于专项通过。登录失败、缺 fixture、数据为空和未授权
写入必须被预检或最终 machine 对账发现；缺结果、零执行、运行器崩溃同样不能通过。
测试账号和数据必须在隔离环境合成，禁止通过生产地址或真实客户身份补齐环境。

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

### MC22 owned negative coordinator

`micro_community_owned_android_negative_test.dart` waits for **real OS VIEW**
intents and independent fixture control actions; launching Flutter alone cannot
complete it. After explicit physical-device authorization, start the existing
owned negative fixture in a unique private run directory, then run:

```sh
python3 scripts/mc22_owned_coordinator.py \
  --context /absolute/private/android-negative-live-context-r1.json \
  --device <authorized-device-id> --events /absolute/run/mc22-coordinator-attempt-1.jsonl
```

Run the existing Flutter negative test alongside it with that lease's defines,
`--flavor gzCustomer`, and the same device. Repeat with a **new lease and new log
names** for `reconnect`. The coordinator requires an existing owned API reverse
mapping, preserves the independent phase-control connection, sends the same VIEW
URI before/after revocation, and restores only its API mapping after interruption.
It does not uninstall apps, create databases, or acquire device authorization.

Coordinator success is only transport evidence: require Flutter exit 0, fixture
final DB assertions/exit 0, physical-device/build identity, and all MC22 leaf
oracles together. A timeout/error remains failure. Never overwrite earlier logs.
