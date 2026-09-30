# 命令参考 / Commands Reference

> [docs/README](../README.md) > **命令参考**

<!-- AUTO-GENERATED: 本文件由命令参考表自动维护，请勿手工编辑本标记与各表格内容；
     手工补充请写在「备注」节。真源：
     - pubspec.yaml（依赖 / SDK 约束 / slang / patrol 配置）
     - scripts/*.sh、scripts/*.dart（脚本头注释中的用法）
     - README.md、CLAUDE.md、integration_test/README.md 中已有命令
     Last updated: 2026-09-30 -->

## 日常开发

| 命令 | 用途 | 真源 |
|------|------|------|
| `flutter pub get` | 安装依赖 | README |
| `flutter doctor` / `flutter devices` | 检查环境 / 列出设备（功能调试用真机，禁模拟器） | README |
| `flutter run -d <设备ID> --dart-define=APP_ENV=local_home --dart-define=API_BASE_URL_OVERRIDE=http://<局域网IP>:9800` | 真机运行（手机上 127.0.0.1 指向手机自身，不能连电脑） | README |
| `flutter analyze` | 静态检查（基线：`dart analyze lib` 零 issues） | README、CLAUDE.md |
| `dart scripts/check_boundaries.dart` | 模块边界检查 | README |

环境配置：`APP_ENV` 取 `pro` / `dev` / `local` / `local_home` / `local_office`，分别对应 `lib/config/env_pro.dart` / `env_dev.dart` / `env_local.dart` / `env_local_home.dart` / `env_local_office.dart`。

## 代码生成

| 命令 | 用途 | 真源 |
|------|------|------|
| `dart run slang` | 重新生成多语言代码（源 `assets/i18n/<locale>/*.i18n.yaml` → 生成物 `lib/i18n/*.g.dart`，勿手改） | README、slang.yaml |
| `flutter pub run build_runner build` | Riverpod / envied 等代码生成 | CLAUDE.md |
| `./scripts/regen_protobuf.sh` | 从 `../imboy/src/imboy.proto` 重新生成 Dart protobuf 到 `lib/service/protocol/`；前置 `dart pub global activate protoc_plugin` | scripts/regen_protobuf.sh |
| `dart scripts/generate_error_code.dart` | 从后端 `../imboy/include/error_code.hrl` 生成 `lib/config/error_code.dart` | scripts/generate_error_code.dart |
| `dart scripts/generate_error_code.dart --check` | 只校验错误码生成物是否最新（CI / lefthook 用） | scripts/generate_error_code.dart |
| `dart scripts/generate_error_code.dart --source=<error_code.hrl 路径>` | 独立 clone（无并排 imboy 仓）时显式指定源；也可用环境变量 `IMBOY_ERROR_CODE_HRL` | scripts/generate_error_code.dart |
| `dart run tool/generate_sqlite_migrations.dart --check` | SQLite 迁移生成物校验（迁移唯一真源是 `lib/service/migrations/manifest_all.dart`） | CLAUDE.md |

## 测试

### 三层测试架构

| 层 | 命令 | 设备要求 |
|----|------|---------|
| Tier 1 · API/WS 契约测试 | `API_BASE_URL=http://127.0.0.1:9800 TEST_PHONE=<账号> TEST_PASSWORD=<密码> IMBOY_SOLIDIFIED_KEY=<目标环境签名密钥> flutter test test/unit_test/api/ --concurrency=1 --timeout=60s`（`scripts/pre_push_gate.sh` 门禁口径） | 无设备。✅ 运行器两难已修复（2026-09-30，方案 A）：`test/unit_test/api/flutter_test_config.dart` 就近 `HttpOverrides.global = null` 关掉 smoke 拦截，`flutter test` 走真实网络（无后端时真实变红 SocketException，门禁复活）；`dart test` 仍不可用（被 patrol 等 Flutter-only 依赖阻断），文档一律写 `flutter test`。skip 判据为运行时探测 `ApiTestConfig.isNetworkMocked`（查 `HttpOverrides.current`），不再猜运行器 |
| Tier 2 · 冒烟门控 | `flutter test integration_test/smoke/smoke_test.dart --dart-define=APP_ENV=pro --dart-define=TEST_PHONE=<手机号> --dart-define=TEST_PASSWORD=<密码> -d <真机设备ID>` | 真机，合并前必须绿 |
| Tier 3 · UI 流程测试 | `flutter test integration_test/all_tests.dart --dart-define=APP_ENV=local_office --dart-define=TEST_PHONE=<手机号> --dart-define=TEST_PASSWORD=<密码> -d <真机设备ID>` | 真机 |

macOS 桌面（无需真机）：同一套 integration_test 用 `-d macos`，并显式传 `--dart-define=API_BASE_URL=https://pro.imboy.pub`。

业务写入类集成测试还需显式授权：`--dart-define=TEST_ALLOW_BUSINESS_WRITES=true`、`--dart-define=TEST_ALLOW_CHANNEL_WRITES=true` 等，且目标环境不能是生产。详见 [integration_test/README.md](../../integration_test/README.md)。

### 单元 / Widget 测试

| 命令 | 用途 | 真源 |
|------|------|------|
| `flutter test` | 单元和 Widget 测试（不带路径递归扫 `test/`；`integration_test/` 刻意留在仓库根，勿并入） | README、CLAUDE.md |

### 测试编排与门禁脚本

| 命令 | 用途 | 真源 |
|------|------|------|
| `bash scripts/run_sqlite_migration_gate.sh --local` | SQLite 迁移治理统一 Gate（本地全量）；CI 用 `--ci`（evidence 到 `build/`）。退出码：0=PASS / 1=FAIL / 2=BLOCKED / 64=参数错误 | scripts/run_sqlite_migration_gate.sh |
| `bash scripts/run_test_suite.sh` | 确定性测试编排器（设备自动发现仅限 Android 真机；环境变量 `IMBOY_TEST_DEVICE`/`TEST_DEVICE`、`IMBOY_TEST_ARTIFACT_DIR`、`IMBOY_RUN_INTEGRATION`、`IMBOY_RUN_PATROL`、`IMBOY_ALLOW_REMOTE_TEST`） | scripts/run_test_suite.sh |
| `bash scripts/check_auto_test_framework.sh` | auto-test 框架统一验收 gate（本地与 CI 同一入口） | scripts/check_auto_test_framework.sh |
| `bash scripts/pre_push_gate.sh` | pre-push 门控：只跑无设备的 Tier 1 API 契约测试；后端不可达时优雅跳过 | scripts/pre_push_gate.sh |
| `source scripts/test.env && bash scripts/setup_test_data.sh` | 幂等准备集成测试基础数据（测试账号 Alice/Bob + 双向好友关系）；库重置后重跑即可 | scripts/setup_test_data.sh |
| `bash scripts/run_e2ee_suite.sh` | E2EE 客户端安全验证套件 | scripts/run_e2ee_suite.sh |
| `bash scripts/run_kill_replay.sh [device_serial] [attempt]` | kill_replay 两阶段编排（强杀进程后验证数据不回滚） | scripts/run_kill_replay.sh |
| `bash scripts/run_cross_platform_e2ee_interop.sh` | Android ↔ macOS C2C E2EE 互操作验收（不连后端、不写业务数据） | scripts/run_cross_platform_e2ee_interop.sh |
| `bash scripts/oneclick_login_e2e.sh` | 一键登录全链路自动化验证（Android 真机） | scripts/oneclick_login_e2e.sh |
| `DEMO_FLOW_SCOPE=p1 DEMO_FLOW_MODEL=<model> bash scripts/run_demo_flows.sh` | 串行执行 test/demo_flow 流程计划（默认只跑 P0） | scripts/run_demo_flows.sh |
| `./scripts/verify_web_shell.sh`（`--quick` 跳过 build web） | Web Shell 模块健康度一键验证 | scripts/verify_web_shell.sh |

## 构建

> 脚本行为细节（full-selected 门禁、flavor、签名、产物路径）见 [构建与发布](../build-and-release.md)，此处只留命令索引。
> 构建脚本前置：并排存在 `../imboy/` 仓，且其 `scripts/generate_product_features.py --check --require-profile full-selected` 通过。

| 命令 | 用途 | 真源 |
|------|------|------|
| `flutter build apk --debug --flavor standard` | 本地 Android 构建（白标 flavor 引入后必须显式指定） | README |
| `./scripts/build_android_apk.sh <version>`（例 `1.0.0-alpha.18`） | 发布用 APK 构建（校验版本号格式与 `docs/changelog.md` 条目） | scripts/build_android_apk.sh |
| `./scripts/build_play_aab.sh <build_number> [build_name]` | Google Play AAB（`--flavor standard`，注入 `ALIPAY_APP_ID`；build_name 缺省取 pubspec.yaml `version`） | scripts/build_play_aab.sh |
| `./scripts/build_ios.sh <build_number> [build_name]` | iOS 构建（同 full-selected 前置检查） | scripts/build_ios.sh |
| `./scripts/check_play_release.sh` | Play 发布产物校验（可配 `PLAY_BASE_URL`、`SKIP_URL_CHECK=1`） | scripts/check_play_release.sh |

## 备注（手工区）

<!-- 手工补充的长期备注写在这里，不进上方生成表。 -->

- 翻译新增后在 `assets/i18n/zh-CN/<namespace>.i18n.yaml` 添加键 → `dart run slang` → 同步其他语言；YAML 新值一律加引号。
- `example.env` 与 `scripts/test.env` 是 git 跟踪的模板；本地 `.env.*` 被 `.gitignore` 的 `.env*` 忽略，不入库。变量清单见 [environment-variables.md](./environment-variables.md)。
