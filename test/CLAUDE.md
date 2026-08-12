> [imboyapp 根目录](../CLAUDE.md) > **test（测试根目录）**

# 测试目录说明 / Test Directory Guide

> 最后更新：2026-08-06

---

## 目录结构

```
imboyapp/
├── test/
│   ├── unit_test/      单元 / widget 测试（551 个 .dart），无头 VM 运行
│   ├── auto_test/      自动化测试计划表（文档，非可执行代码）
│   ├── test_driver/    flutter drive 驱动入口
│   └── CLAUDE.md       本文件
└── integration_test/   端到端测试（26 个 .dart）—— 刻意留在仓库根目录
```

### ⚠️ 为什么 `integration_test/` 不在 `test/` 里面

`flutter test` 不带路径参数时，会**递归扫描 `test/` 下所有 `*_test.dart`**。

`integration_test/` 里的 18 个文件都调用 `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`
并 `app.main()` 启动整个 App，**必须有真机或桌面窗口**才能跑。一旦放进 `test/`，
下面这些裸调用会把它们当单元测试执行，在无设备环境（如 CI 的 ubuntu runner）必然失败：

| 位置 | 命令 |
|---|---|
| `.github/workflows/ci.yml:316` | `flutter test --coverage` |
| `.github/workflows/integration_test.yml:92` | `flutter test --coverage` |
| `.github/workflows/sonar.yml:43` | `flutter test --coverage` |

**同理**：`test_driver/` 下的驱动文件已从 `integration_test.dart` **改名为 `driver.dart`**
——原名匹配 `*_test.dart`，挪进 `test/` 后会被裸 `flutter test` 扫到，
而 `integrationDriver()` 是等待设备连接的，会挂住。

> **约束**：`test/` 下**不得**出现任何需要设备才能运行的 `*_test.dart`。
> 新增端到端测试一律放 `integration_test/`。

---

## 各目录用途

### `unit_test/` —— 单元与 widget 测试

无需设备，跑在无头 VM。按被测代码结构组织：`page/` `service/` `store/` `component/`
`modules/` `api/` `integration/`（进程内集成，非设备）`smoke/` 等。

```bash
flutter test test/unit_test                      # 全量
flutter test test/unit_test/service/e2ee/        # 按模块
flutter test test/unit_test/api/                 # Tier 1 API 契约（pre-push 门禁跑这个）
```

`flutter_test_config.dart` 在 `test/unit_test/` 根，作用域覆盖其下全部子目录。

#### e2ee 测试的 vodozemac 动态库依赖（macOS 本机）

`service/e2ee/` 与 `group_session_service_test.dart` 的 `setUpAll` 会
`dlopen('vodozemac_bindings_dart')`。`flutter test` 的 darwin 目标不走 pod
构建，cargokit 不会自动产出 macOS 动态库 → 缺失时这些文件全部挂在
setUpAll（不是代码回归）。本机一次性补齐（需 Rust 工具链）：

```bash
cd ~/.pub-cache/hosted/pub.dev/flutter_vodozemac-0.7.1/rust
cargo build --release --target aarch64-apple-darwin
mkdir -p /usr/local/lib/vodozemac_bindings_dart.framework
cp target/aarch64-apple-darwin/release/libvodozemac_bindings_dart.dylib \
   /usr/local/lib/vodozemac_bindings_dart.framework/vodozemac_bindings_dart
```

该动态库必须与当前 `pubspec.lock` 中的 `flutter_vodozemac` 同版本构建；
升级 `vodozemac` 后不能继续复用旧版 spike 库，否则会出现 `The message didn't contain a version`
一类的 FFI ABI 错误。当前锁定版本为 `flutter_vodozemac 0.7.1` / `vodozemac 0.7.0`。

真机/真机构建不受影响（iOS/Android 由 pod/gradle 正常链接）。


### `auto_test/` —— 测试计划表（文档）

**不是可执行代码**，是 imboyapp 全部功能点的测试计划，共 **137 个页面 / 1538 个功能点**。

目录结构**镜像 `lib/page/`**：

| 改了这个 | 就更新这个 |
|---|---|
| `lib/page/channel/channel_list_page.dart` | `test/auto_test/channel/channel_list_page.md` |
| `lib/page/wallet/wallet_page.dart` | `test/auto_test/wallet/wallet_page.md` |

入口：[`auto_test/README.md`](./auto_test/README.md)（全局汇总 + 模块索引 + 页面清单）

**维护铁律 —— 保证文档有限膨胀**：

| 规则 | 说明 |
|---|---|
| 一行 = 一个功能点 | 行数只随功能增加，**不随测试轮次增加** |
| 按功能介绍**覆盖写** | 同一功能点永远只有一行；新一轮改状态和计数，不加行 |
| bug 用**计数**不用叙述 | `待处理 = 发现 − 解决`，恒等式可自动校验 |
| 备注只写**当前未闭环**的事 | 闭环即清空；修复细节去 git log 查 |

新增页面时：在对应模块目录建 `<page_name>.md`，抽 8～12 个功能点，
并更新 `auto_test/README.md` 的汇总与索引。

### `demo_flow/` —— 跨模块业务流程计划

`test/demo_flow/` 记录跨页面、跨模块的演示链路，例如频道到群日程、添加好友到单聊、
群管理和朋友圈。它不镜像 `lib/page/`，不参与 `auto_test/README.md` 的页面/功能点统计，
也不放可执行的 `*_test.dart` 文件。

每个流程文档必须写清楚：前置账号与环境、操作步骤、对应的 `auto_test` 页面计划、
服务端证据、验收标准、阻塞条件，以及未来对应的 `integration_test/` 文件。
入口见 [`demo_flow/README.md`](./demo_flow/README.md)。

### `test_driver/` —— flutter drive 驱动

只有 `driver.dart` 一个文件。当前 CI 未使用（走 `flutter test integration_test/xxx -d <device>`），
保留供需要 `flutter drive` 的场景：

```bash
flutter drive --driver=test/test_driver/driver.dart \
              --target=integration_test/app_test.dart -d <device>
```

---

## 常用命令

```bash
# 单元 / widget（无需设备）
flutter test test/unit_test
flutter test test/unit_test --coverage

# 端到端（必须指定设备）
flutter test integration_test/all_tests.dart -d macos \
  --dart-define=APP_ENV=pro --dart-define=API_BASE_URL=https://pro.imboy.pub

flutter test integration_test/smoke/smoke_test.dart -d <真机ID> --dart-define=APP_ENV=pro
```

> 裸 `flutter test`（不带路径）会扫 `test/` 全量，等价于 `flutter test test/unit_test`。
> 保持这个等价关系成立，是本目录约束存在的意义。

---

## 相关文档

- [`auto_test/README.md`](./auto_test/README.md) —— 测试计划总索引
- [`../integration_test/README.md`](../integration_test/README.md) —— 端到端测试方案与设备要求
- [`../CLAUDE.md`](../CLAUDE.md) —— imboyapp 架构文档
