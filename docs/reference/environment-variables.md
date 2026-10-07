# 环境变量参考 / Environment Variables Reference

> [docs/README](../README.md) > **环境变量**

<!-- AUTO-GENERATED: 本文件由环境变量文档自动维护，真源：
     - example.env（git 跟踪的 .env 模板；本地 .env.* 被 .gitignore 的 `.env*` 忽略，不入库）
     - lib/config/env_*.dart（@Envied 注解读取的 .env.<APP_ENV> 键名）
     - lib/ 与 integration_test/ 中的 String.fromEnvironment（dart-define 编译期变量）
     - scripts/test.env（git 跟踪的集成测试 shell 配置）
     Last updated: 2026-09-30 -->

变量按注入时机分三层：

| 层 | 注入方式 | 配置文件 | 是否入库 |
|----|---------|---------|---------|
| A. 构建期（envied） | `build_runner` 从 `.env.<APP_ENV>` 读取，编译进 `lib/config/env_<env>.g.dart` | `.env.local` / `.env.pro` 等 | 模板入库（`example.env`），真实文件被 `.gitignore` 的 `.env*` 忽略 |
| B. 编译期（dart-define） | `flutter run/test/build --dart-define=KEY=VALUE` | 命令行 | 否 |
| C. Shell 环境 | `source scripts/test.env` 或进程环境变量 | `scripts/test.env`（git 跟踪） | 模板入库 |

---

## A. 构建期：`.env.<APP_ENV>`（envied）

模板 [example.env](../../example.env)。本地复制为 `.env.<APP_ENV>`（如 `.env.local`、`.env.pro`）后跑 `flutter pub run build_runner build` 重新生成。

| 变量 | 必填 | 说明 |
|------|------|------|
| `API_BASE_URL` | 必填 | 后端 API 基址 |
| `SOLIDIFIED_KEY` | 必填 | 服务端↔App 数据对称加密密钥（32 位字符串，须与服务端一致；避免特殊字符） |
| `SOLIDIFIED_KEY_IV` | 必填 | 对应 IV（128 比特 = 16 字节，须与服务端一致） |
| `IOS_APP_ID` | 可选 | Apple App Store 数字 ID（iOS 升级页 `RUpgrade.upgradeFromAppStore` 跳转用，非微信 AppId） |
| `JPUSH_APPKEY` | 可选 | 极光推送 AppKey；需与 `android/local.properties` 的 `jpush.appKey` 一致（真实值严禁入库） |
| `A_MAP_WEBS_KEY` / `A_MAP_IOS_KEY` / `A_MAP_ANDROID_KEY` | 可选 | 高德地图 Web 服务 / iOS / Android Key |
| `ALIPAY_APP_ID` | 可选 | 支付宝 App 支付 appId（公开值非密钥；未配置时充值降级为「即将开通」） |
| `ALIPAY_UNIVERSAL_LINK` | 可选 | 支付宝 UL 统一用 pro 域名（AASA 仅部署在 pro.imboy.pub） |

> ⚠️ 键名注意：高德三个键名必须带下划线写作 `A_MAP_*`（与 `lib/config/env_*.dart` 的 `@EnviedField(varName:)` 一致，`example.env` 模板已对齐）。旧本地 `.env.*` 若仍是 `AMAP_*`（无下划线）须改名，否则 envied 静默读不到值、高德 Key 失效。

> 另：`env_local.dart` 还声明了 `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` 字段，`example.env` 模板未提供；如需 AI 测试字段自行加入本地 `.env.local`。

---

## B. 编译期：dart-define

### 环境与连接（核心）

| 变量 | 必填 | 默认 | 说明 |
|------|------|------|------|
| `APP_ENV` | 否 | `pro` | 环境：`pro` / `dev` / `local` / `local_home` / `local_office`，对应 `lib/config/env_*.dart` |
| `API_BASE_URL_OVERRIDE` | 否 | 空 | 覆盖 `.env` 中的 API 基址（`local`/`local_home`/`local_office` 环境生效） |
| `WS_URL_OVERRIDE` | 否 | 空 | 覆盖 WebSocket 地址（集成测试注入，避免首次安装真机依赖历史缓存） |
| `SOLIDIFIED_KEY_OVERRIDE` / `SOLIDIFIED_KEY_IV_OVERRIDE` | 否 | 空 | 覆盖签名密钥 / IV（测试用） |
| `API_BASE_URL` | Tier 2/3 必填 | — | 集成测试与 macOS 桌面运行的后端地址（如 `http://127.0.0.1:9800`、`https://pro.imboy.pub`） |
| `TEST_PHONE` / `TEST_PASSWORD` | 必填 | 由自有隔离环境提供 | 测试账号与凭证；运行前核对账号归属和登录能力。不得使用生产账号或把凭证写入仓库、报告。 |

### 支付（payment_config.dart）

| 变量 | 必填 | 说明 |
|------|------|------|
| `ALIPAY_APP_ID` | 否 | 覆盖构建期注入值；未配置则充值降级「即将开通」 |
| `ALIPAY_UNIVERSAL_LINK` | 否 | 支付宝 Universal Link |
| `WECHAT_APP_ID` | 否 | 微信支付 appId |
| `WECHAT_UNIVERSAL_LINK` | 否 | 微信 Universal Link |

### 测试写闸（防误写生产）

写入类集成测试必须显式开启对应开关，且目标环境不能是生产；未设置时测试自动 SKIP：

| 变量 | 授权范围 |
|------|---------|
| `TEST_ALLOW_BUSINESS_WRITES` | 关系/消息/群/密码等业务写入总闸 |
| `TEST_ALLOW_CHANNEL_WRITES` | 频道创建/发布/编辑写入 |
| `TEST_ALLOW_PAID_CHANNEL_WRITES` | 付费频道写入 |
| `TEST_ALLOW_GROUP_WRITES` | 群组写入 |
| `TEST_ALLOW_FRIEND_APPLY` | 好友申请写入 |
| `TEST_ALLOW_REGISTER` | 注册流程写入 |
| `TEST_ALLOW_PASSWORD_CHANGE` | 改密写入（配 `TEST_NEW_PASSWORD`） |
| `TEST_ALLOW_SEARCH_ACCEPTANCE` / `TEST_ALLOW_WORKSPACE_ACCEPTANCE` 等 | 搜索/工作台验收写入 |

### 其他常用

| 变量 | 说明 |
|------|------|
| `TEST_SEARCH_KEYWORD` | 好友搜索测试目标（通常填 uid） |
| `TEST_NEW_PASSWORD` | 改密测试的新密码 |
| `WEB_E2E_TOKEN` / `WEB_E2E_UID` | Web 登录 E2E 注入登录态（生产构建默认空自动走正常流程） |
| `IMBOY_WL_*`（`IMBOY_WL_APPLICATION_ID`、`IMBOY_WL_DISPLAY_NAME`、`IMBOY_WL_PRIMARY_COLOR`、`IMBOY_WL_ACCENT_COLOR`、`IMBOY_WL_FLAVOR` 等） | 白标（white-label）构建参数 |

> TEST_* 长尾变量（双账号、E2EE fixture、群协作造数等）全集以各 `integration_test/` 文件头部注释为准，此处不逐一罗列。

---

## C. Shell 环境（scripts/test.env 及脚本级变量）

[scripts/test.env](../../scripts/test.env)（git 跟踪）供 `source` 后给集成测试与后端联调脚本使用：

| 变量 | 必填 | 默认（test.env 现值） | 说明 |
|------|------|------|------|
| `TEST_PHONE` / `TEST_PASSWORD` | 必填 | 由自有隔离环境提供 | 测试账号与凭证；运行前核对账号归属和登录能力。不得使用生产账号或把凭证写入仓库、报告。 |
| `PGHOST` / `PGPORT` / `PGUSER` / `PGDATABASE` / `PGPASSWORD` | 必填 | `127.0.0.1` / `4323` / `imboy_user` / `imboy_v1` / `abc54321` | 测试 PostgreSQL 连接（`setup_test_data.sh` 使用） |
| `IMBOYENV` | 必填 | `local` | 后端环境标识 |
| `HTTP_PORT` | 必填 | `9800` | 后端 HTTP 端口 |
| `BACKEND_STARTUP_TIMEOUT` | 否 | `60` | 后端启动等待秒数 |
| `API_BASE_URL` | 必填 | `http://127.0.0.1:9800` | Tier 1 API 契约测试（`test/unit_test/api/`）使用 |
| `TEST_DEVICE` | 否 | `macos` | 目标设备（`macos` 或 Android 设备 ID） |
| `APP_ENV` | 否 | `local_office` | Flutter 运行环境 |
| `SMOKE_FROM` / `SMOKE_TO` | 否 | `1000000051` / `1000000056` | smoke test 收发双方 UID（Alice/Bob） |

### 脚本级环境变量

| 变量 | 使用脚本 | 必填 | 说明 |
|------|---------|------|------|
| `IMBOY_SOLIDIFIED_KEY` | `integration_test/demo_flow/*`（群码 tk 计算、WS 签名） | 相关用例必填 | 本地签名密钥（与 `.env` 的 `SOLIDIFIED_KEY` 同值）；缺失时用例跳过 |
| `IMBOY_ERROR_CODE_HRL` | `scripts/generate_error_code.dart` | 否 | 后端 `error_code.hrl` 路径（独立 clone 无并排 imboy 仓时必填） |
| `IMBOY_TEST_DEVICE` / `TEST_DEVICE` | `scripts/run_test_suite.sh` | 否 | 测试设备 |
| `IMBOY_TEST_ARTIFACT_DIR` | `scripts/run_test_suite.sh` | 否 | 产物目录（默认 imboy-test-report 下按时间戳） |
| `IMBOY_RUN_INTEGRATION` / `IMBOY_RUN_PATROL` | `scripts/run_test_suite.sh` | 否 | 是否跑集成 / Patrol 阶段 |
| `IMBOY_ALLOW_REMOTE_TEST` | `scripts/run_test_suite.sh` | 否 | 允许远程测试（默认关闭） |
| `IMBOY_CTL_NODE` | `scripts/setup_test_data.sh` | 否 | 后端节点名（默认 `imboy@127.0.0.1`，用于冲洗好友关系缓存） |

---

## 相关文档

- [命令参考](./commands.md)
- [集成测试说明](../../integration_test/README.md)（三层测试与写闸语义）
- [第三方配置指南](../third-party-config-guide.md)
