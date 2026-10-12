# 贡献指南 / Contributing

> imboyapp（Flutter 移动端）开发环境、命令、测试与提交规范。
> 架构与模块索引见 [CLAUDE.md](./CLAUDE.md)；完整命令参考见 [docs/reference/commands.md](./docs/reference/commands.md)；环境变量见 [docs/reference/environment-variables.md](./docs/reference/environment-variables.md)。

## 开发环境

- Flutter 3.41.x（Dart SDK 约束 `^3.13.3`，见 [pubspec.yaml](./pubspec.yaml)）
- 一台已连接的真机：**功能调试必须用真机，禁止用模拟器做功能验证**
- 可访问的 IMBoy 后端：相邻仓库 `../imboy/`（Erlang/OTP 28+），部分脚本与代码生成依赖并排 clone

```bash
flutter doctor && flutter devices   # 环境与设备自检
flutter pub get                     # 安装依赖
```

首次运行见 [README.md](./README.md)「本地启动」。

## 常用命令

```bash
flutter analyze                         # 静态检查（基线：dart analyze lib 零 issues）
flutter test                            # 单元和 Widget 测试
dart scripts/check_boundaries.dart      # 模块边界检查
dart run slang                          # 重新生成多语言代码
dart scripts/generate_error_code.dart --check   # 错误码生成物校验
```

构建、代码生成、集成测试等完整命令表见 [docs/reference/commands.md](./docs/reference/commands.md)（自动生成，真源为 pubspec.yaml 与 scripts/）。

## 测试流程

三层测试架构（详见 [integration_test/README.md](./integration_test/README.md)）：

| 层 | 内容 | 要求 |
|----|------|------|
| Tier 1 | `test/unit_test/api/` API/WS 契约测试 | 无设备，可 CI。用 `flutter test`（`dart test` 被 patrol 依赖阻断）；真实网络由 `api/flutter_test_config.dart` 就近恢复，详见 `docs/reference/commands.md` Tier 1 注 |
| Tier 2 | `integration_test/smoke/` 冒烟门控 | 真机；合并前必须绿 |
| Tier 3 | `integration_test/` UI 流程测试 | 真机；回归可选 |

### Widget / 单元测试注意事项

- Widget 测试用 `ProviderScope` 包裹组件；覆盖 Notifier 时 `overrideWith` 与 `loadData` 须一起覆盖。
- 单元测试直接测业务逻辑，不依赖 UI 层；纯函数契约测试与 SQLite ffi in-memory 测试优先。
- `test/unit_test/` 无需设备；`integration_test/` 刻意留在仓库根，`flutter test` 不带路径只扫 `test/`，勿把端到端测试挪进 `test/`。
- 测试细节与坑位清单见 [test/CLAUDE.md](./test/CLAUDE.md)。

### 集成测试前置

```bash
source scripts/test.env && bash scripts/setup_test_data.sh   # 幂等准备测试账号与好友关系
```

写入类用例必须显式设置 `TEST_ALLOW_BUSINESS_WRITES=true` 等写闸（见 [环境变量参考](./docs/reference/environment-variables.md)），且目标环境不能是生产。

## 代码风格

- **Design Token**：颜色 / 间距 / 字号必须通过 `AppColors` / `AppSpacing` / `FontSizeType`，禁止硬编码 `Color(0x…)`、`fontSize:` 数字字面量、`Colors.*`（`lib/theme/` 与生成物除外）。lefthook `design-tokens` 钩子在 pre-commit 强制检查，扫描的是新增行（`///` 注释除外）。
- **格式化**：`dart format`（pre-commit 对 staged 文件强制 `--set-exit-if-changed`）。
- **静态检查**：`dart analyze`（pre-commit 对 `lib/**` staged 文件运行）。
- **附件 URL**：必须经 `AssetsService.viewUrl` 授权，禁止直接 `Image.network(url)` 等裸 URL 用法。
- **i18n**：只改 `assets/i18n/<locale>/<namespace>.i18n.yaml`，跑 `dart run slang` 生成；禁止手改 `lib/i18n/*.g.dart`。YAML 新值一律加引号（slang 对裸 bool/数字类型有解析陷阱）。
- **错误码**：`lib/config/error_code.dart` 是生成物，改后端 `error_code.hrl` 后运行 `dart scripts/generate_error_code.dart` 重新生成，禁止手补常量（pre-commit / pre-push 有同步校验）。
- **保留区禁改**：`ios/*`、`macos/*`、`plugin/r_upgrade`。

## 提交规范

- 提交信息遵循 **Conventional Commits**：`<type>(<scope>)!?: <subject>`，type 取 `feat|fix|refactor|docs|test|chore|perf|ci|style|build|revert`，subject ≤ 90 字符（lefthook commit-msg 强制校验）。
- pre-commit 钩子（[lefthook.yml](./lefthook.yml)）并行运行：`dart format`、`dart analyze`、`gitleaks`（防密钥入库）、`error-code-sync`、`design-tokens`。
- pre-push 钩子串行运行：`scripts/quality/check_analyzer_ratchet.sh`（analyze 基线棘轮）、`error-code-sync`（`IMBOY_SKIP_PRE_PUSH=1` 可跳过；独立 clone 无并排 imboy 仓时自动跳过）、`scripts/pre_push_gate.sh`（Tier 1 API 契约测试，后端不可达时优雅跳过）。
- **不要提交**：`.env*` 真实配置（已 gitignore）、构建产物、含生产数据（PII）的任何文件。

## PR 清单

提交 PR 前自查：

- [ ] `flutter analyze` 零新增 issues（基线零 warning/info）
- [ ] `flutter test` 全绿（单元 + Widget）
- [ ] UI 改动已读 [DESIGN.md](./DESIGN.md)，未硬编码颜色/间距/字号
- [ ] 翻译改动已跑 `dart run slang` 并同步 10 个语言文件，YAML 新值带引号
- [ ] 触碰 `lib/config/error_code.dart` 的改动来自生成器而非手改
- [ ] 新增 API/字段与三端术语对齐后端仓 `docs/glossary.md`
- [ ] 提交信息符合 Conventional Commits，未包含密钥或 PII
- [ ] 涉及 SQLite 迁移：改 `lib/service/migrations/manifest_all.dart` 后通过 `bash scripts/run_sqlite_migration_gate.sh --local`
