# imboyapp 文档入口

> 本目录只放 Flutter 客户端的稳定知识、代码地图、测试、合规和架构决策。临时会话记录、已完成计划和一次性 QA 材料分别放在 `archive/`；完整项目说明见 [根 README](../README.md) 和 [CLAUDE.md](../CLAUDE.md)。

## 按目标开始

| 目标 | 入口 |
|---|---|
| 第一次运行项目 | [根 README](../README.md) |
| 了解架构和边界 | [CLAUDE.md](../CLAUDE.md) · [模块地图](./module-map.md) |
| 找代码入口 | [代码地图](./codemaps/index.md) |
| 写 UI | 先读 [DESIGN.md](../DESIGN.md) |
| 做单元 / Widget / 真机测试 | [测试宪章](./qa/testing-charter.md) · [全量清单](./qa/full-app-test-checklist.md) |
| 查功能状态 | [功能状态](./reference/feature-status.md) |
| 查用户可见帮助 | [FAQ](./FAQ.md) |
| 查隐私与商店申报 | [隐私政策](./privacy-policy.md) · [Data Safety](./data-safety-declaration.md) |

## 项目事实

| 项目 | 当前约定 |
|---|---|
| 客户端 | Flutter / Dart 3.8+，支持 iOS、Android 和桌面端 |
| 状态与路由 | Riverpod · go_router |
| 数据与实时通信 | SQLite（schema v30）· Dio · WebSocket · WebRTC |
| 架构 | MVVM + Repository；业务模块按 DDD 组织 |
| 国际化 | slang；源文件在 `assets/i18n/`，`lib/i18n/` 是生成物 |
| 后端 | 相邻仓库 `../imboy/`（Erlang/OTP 28+） |

以代码为准的事实：SQLite 版本看 `lib/service/sqlite.dart`；依赖版本看 `pubspec.yaml`；路由和模块边界看代码与 `CLAUDE.md`。本页不重复维护文件数量、完成率和易过期的里程碑数字。

## 目录分工

| 目录 | 内容 | 是否进入日常入口 |
|---|---|---|
| `codemaps/` | 架构、依赖、数据流和代码地图 | 是 |
| `qa/` | 测试策略与验收清单 | 是 |
| `reference/` | 功能状态和稳定参考 | 是 |
| `adr/` | 架构决策记录 | 按需 |
| `plans/` | 进行中的方案 | 否，完成后归档 |
| `archive/` | 已完成计划、审计和一次性报告 | 仅历史查询 |

根目录的 `FAQ.md`、`privacy-policy.md`、`data-safety-declaration.md` 会随 App 打包，文件名和路径不可改。

## 开发硬约束

- 写 UI 前先读 `DESIGN.md`；颜色、间距、字号使用 `AppColors`、`AppSpacing`、`FontSizeType`。
- 附件 URL 必须经过 `AssetsService.viewUrl` 授权，禁止直接使用裸网络图片 URL。
- 翻译只改 `assets/i18n/`，再运行 `dart run slang`；不要手改 `lib/i18n/*.g.dart`。
- 外部调用优先使用 `lib/modules/<domain>/public.dart`，领域层不要泄漏基础设施依赖。
- 功能验证使用真机；不要用模拟器代替媒体、推送和真实网络链路验证。
- 禁止修改 `ios/*`、`macos/*` 和 `plugin/r_upgrade`。

## 文档维护

1. 代码边界、设计约束和长期决策写入 `CLAUDE.md`、`DESIGN.md` 或 `adr/`，不要塞进本页。
2. 计划完成后移入 `archive/`；只有仍可执行、仍会被查阅的内容留在稳定目录。
3. 修改协议、数据库、构建流程或用户隐私行为时，同步更新受影响文档和根 README。
4. 不提交生产数据、真实密钥、设备标识或其他个人信息。

## 其他

```agsl
flutter build apk --release \
        --obfuscate \
        --split-debug-info=debugInfo \
        --target-platform=android-arm,android-arm64 \
        --split-per-abi \
        -t lib/main.dart \
        --dart-define=APP_ENV=pro --dart-define=ALIPAY_APP_ID=2021004142626807

```