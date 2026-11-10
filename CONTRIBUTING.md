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

## 自动安全扫描

[Security Scan](./.github/workflows/security-scan.yml) 在推送到 `main` / `dev`、以这两个分支为目标的 PR，以及手动触发时运行。其他分支仅 push 不触发；开 PR 后会随 PR 更新扫描。扫描当前检出的完整工作区，不是只检查新增问题，也不扫描完整 Git 历史。

- Semgrep CE 使用 `p/security-audit`、`p/secrets`、`p/owasp-top-ten`；所有规则级别进入报告，`HIGH` / `CRITICAL` 及旧格式 `ERROR` 级发现使检查失败。Semgrep 规则级别不等同于 CVSS 高危评分。
- Trivy 显式启用 `vuln,misconfig,secret`，扫描依赖、受支持的配置及密钥；报告并阻断 `HIGH,CRITICAL`，包含开发依赖和暂无修复版本的漏洞。
- 两个扫描 job 独立运行；安装失败、规则/数据库下载错误、扫描器致命错误或报告上传失败都使检查失败。汇总检查名称固定为 `security-scan`。
- Trivy 扫描步骤固定 `exit-code: "0"`，仅分离扫描执行状态；发现不会在该步骤提前终止。`Verify Trivy report` 在非取消情况下检查扫描步骤确已成功，以及固定版本的 SARIF 结构、规则对应关系、严重性和位置。执行失败、报告缺失或未知/损坏格式以退出码 2 失败；独立 `Enforce Trivy findings` 再按 `FINDINGS_EXIT_CODE` 阻断发现。Semgrep 也先检查扫描步骤的真实 outcome，执行错误不能按正常发现处理。
- 两份原始 SARIF 只使用独立 category 上传到 **Security → Code scanning**；PR 分析也显示在对应 PR 检查中。原始 JSON/SARIF 可能包含源码或密钥片段，因此不上传普通 Actions artifact，也不提交进仓库。
- 每个扫描器另外生成一份字段白名单脱敏清单，以独立 Actions artifact 保留 14 天；名称包含 run ID 和 attempt。清单仅保留规则 ID、分类、严重性、文件/行号，依赖项另含包名、已安装版本和修复版本；不含原始 message、源码片段或密钥匹配内容。清单记录扫描器版本、仓库、实际检出的 `GITHUB_SHA`、run ID/attempt，只有本次成功执行并完成报告检查后生成的清单才上传。发现门禁失败仍会上传有效清单，原始报告继续仅在 Code scanning 查看。
- 保留既有 Gitleaks、测试和质量门。使用普通 `pull_request`，不需要业务密钥或 Semgrep 账号，不运行应用安装/构建脚本。

Semgrep 的 `warn` / `warning` 级解析、规则匹配或超时诊断不单独阻断，但摘要会明确显示数量、类型和“部分文件或规则未完成分析”。其他级别（含未知级别）的诊断、报告无效或零文件扫描均失败。绿色只表示配置的门禁通过，不保证所有源码路径都被完整分析；不得把覆盖告警当成零问题。

### 接入与维护

工作流默认 `FINDINGS_EXIT_CODE: "1"`。存量发现也会让检查失败。若维护者明确选择观察期，可在评审后的变更中设为 `"0"`；仅发现问题不再阻断，扫描器执行/报告错误仍失败。这不自动提供“只拦新增”的基线能力，也不改变既有 Gitleaks 门。

首次运行后，在目标分支保护或 ruleset 中把 **`security-scan`** 加入必需检查，才会强制阻止失败 PR 合并；仅合入 YAML 不会修改仓库设置。先确认三项 job 实际执行及 SARIF 可见，再启用必需检查。若 Code scanning 上传被权限或仓库功能设置拒绝，应修正配置，不能以忽略错误代替成功。

Dependabot/fork 的普通 PR 可上传 SARIF。若 Dependabot authored 的 squash merge 使 `push` 运行只有只读 token，上传可能返回 403；由有权限维护者发起新的 `workflow_dispatch` 获取该提交的报告，并评估后续合并方式。不要为解决此问题改用 `pull_request_target` 执行 PR 代码或忽略上传错误。

外部 Actions 固定到完整提交 SHA，注释保留版本；既有 Dependabot 的 `github-actions` 更新继续适用。Semgrep/Trivy 引擎版本固定在 workflow 中，需要随升级验证。Semgrep Registry 规则和 Trivy 漏洞数据库随上游更新，因此即使代码不变，发现也可能变化。误报或例外应逐项记录理由并审阅，不用排除整个业务目录压低数量。

### 本仓覆盖边界

Dart 在 Semgrep CE 中属于社区支持，实际覆盖取决于所选规则，不能把成功运行等同于完整 Dart 安全审计。Trivy 可读取 `pubspec.lock`、`ios/Podfile.lock`、`macos/Podfile.lock`；读取保留区不会修改这些文件。当前 Android 没有 `*gradle.lockfile`，不能宣称扫描了全部原生 Android 依赖。SDK 的 `0.0.0`、Git/path 依赖及本地 fork 的包名版本匹配，不能证明真实 SDK 或 fork 源码安全。本 workflow 不初始化子模块，未检出的子模块源码不在覆盖内。

参考：[Semgrep CE 语言](https://semgrep.dev/docs/semgrep-ce-languages)、[Trivy Dart](https://trivy.dev/docs/latest/coverage/language/dart/)、[Trivy 原生依赖覆盖](https://trivy.dev/docs/latest/coverage/language/)。

## Automated security scanning

[Security Scan](./.github/workflows/security-scan.yml) runs on pushes to `main` / `dev`, pull requests targeting either branch, and manual dispatch. A push to another branch alone does not trigger it; subsequent PR updates do. It scans the checked-out workspace, not only newly introduced findings or the entire Git history.

- Semgrep CE uses `p/security-audit`, `p/secrets`, and `p/owasp-top-ten`. All rule severities are reported; `HIGH` / `CRITICAL` and legacy `ERROR` findings fail the check. Semgrep rule severity is not a CVSS rating.
- Trivy explicitly enables `vuln,misconfig,secret` for dependencies, supported configurations, and secrets. It reports and blocks `HIGH,CRITICAL`, including development dependencies and vulnerabilities with no available fix.
- The scanners run independently. Installation, rule/database download, fatal scanner, and report-upload errors fail the workflow. The aggregate check has the stable name `security-scan`.
- The Trivy scan step uses `exit-code: "0"` solely to separate execution status from findings. Unless cancelled, `Verify Trivy report` checks that the scan actually succeeded and validates the pinned version, SARIF structure, rule mappings, severities, and locations. Execution failures and missing, malformed, or unknown reports fail with exit code 2; a separate `Enforce Trivy findings` step applies `FINDINGS_EXIT_CODE` to validated findings. Semgrep also checks the scan step's actual outcome before evaluating findings.
- Original SARIF reports are uploaded only to **Security → Code scanning** under separate categories, with PR analyses also appearing in PR checks. Raw JSON/SARIF may contain source or secret snippets and is never uploaded as an ordinary Actions artifact or committed.
- Each scanner also produces a field-allowlisted inventory retained as a separate Actions artifact for 14 days, named with the run ID and attempt. It contains only rule IDs, categories, severities, file/line locations, and, for dependencies, package names and installed/fixed versions; raw messages, source snippets, and secret matches are omitted. Provenance records the scanner version, repository, checked-out `GITHUB_SHA`, run ID, and attempt. Only an inventory generated after this run's successful execution and report checks is uploaded. Valid inventories remain available when the findings gate fails; raw reports remain in Code scanning.
- Existing Gitleaks, tests, and quality gates remain in place. Ordinary `pull_request` events require no application secrets or Semgrep account, and no application install/build scripts are executed.

Semgrep `warn` / `warning` diagnostics for parsing, rule matching, or timeouts do not independently block, but the summary shows their counts/types and explicitly states that some files or rules were not fully analyzed. Other or unknown diagnostic levels, invalid reports, and zero scanned files fail. A green check means the configured gate passed, not that every source path was fully analyzed; coverage warnings are not zero findings.

### Rollout and maintenance

The default is `FINDINGS_EXIT_CODE: "1"`, so existing findings also fail the check. If maintainers explicitly choose an observation period, change it to `"0"` through a reviewed change. Findings then become report-only, but scanner/report errors still fail. This does not implement a new-findings-only baseline or relax existing Gitleaks gates.

After the first run, require **`security-scan`** in the target branch protection or ruleset to enforce merge blocking. Merging the YAML does not change repository settings. Verify that all three jobs run and SARIF reports are visible before requiring the check. Resolve permission or Code scanning availability errors instead of ignoring upload failures.

Ordinary Dependabot/fork PR runs can upload SARIF. A Dependabot-authored squash merge may leave a push run with a read-only token and produce an upload 403. A maintainer can start a new `workflow_dispatch` to report that commit and review the merge strategy for future updates. Do not switch to `pull_request_target` to execute PR code or ignore upload errors.

External Actions are pinned to full commit SHAs with version comments; existing Dependabot `github-actions` updates still apply. Engine versions are pinned in the workflow and need validation when upgraded. Semgrep Registry rules and the Trivy vulnerability database update independently, so findings may change without source changes. Review and document individual exceptions instead of excluding entire application directories.

### Repository coverage limits

Dart has community support in Semgrep CE; actual coverage depends on the selected rules. A successful run is not a complete Dart security audit. Trivy can read `pubspec.lock`, `ios/Podfile.lock`, and `macos/Podfile.lock` without modifying reserved paths. There is no Android `*gradle.lockfile`, so this workflow cannot claim complete native Android dependency coverage. SDK `0.0.0` entries and package name/version matches for Git/path dependencies or local forks do not establish the safety of the actual SDK or fork source. Submodules are not initialized, so their unpopulated source is outside this scan.

References: [Semgrep CE languages](https://semgrep.dev/docs/semgrep-ce-languages), [Trivy Dart](https://trivy.dev/docs/latest/coverage/language/dart/), [Trivy native dependency coverage](https://trivy.dev/docs/latest/coverage/language/).

### 逐项扫描例外与解析边界 / Reviewed findings and parser boundaries

Semgrep 的 `nosemgrep` 只放在已复核的调用点，并列出完整规则 ID：JDK/Gradle fixture 编译、操作者明确选择并授权上传的私有视觉适配器、固定 ADB 操作，以及测试执行器的独立 argv 参数。这些例外依赖当前输入来源和调用权限，不能用于来自服务请求的命令。旧 `auto_test.run()` 也在设备发现前拒绝 `flutter` / `patrol` 之外的执行器。

Patrol JUnit 只读取当前运行新产生的本地报告；解析器显式拒绝所有 DOCTYPE 声明，拒绝结果仍使证据校验失败。正常 UTF-8/UTF-16、退出码、计数、跳过和 freshness 检查继续保留。此策略不是通用不可信 XML 服务，也不承诺任意大小输入的资源隔离。Semgrep JSON 门禁不计入已标注结果，SARIF 仍保留 `inSource` suppression 记录。

[`.trivyignore.yaml`](./.trivyignore.yaml) 将例外限定到具体 finding ID 和以下两个文件，复核期限为 **2027-02-10**；不排除整个 `macos/`、vendor 或 Ruby 生态：

- `macos/Shims/vendor/Sentry/Gemfile.lock`：仅列出的 9 个漏洞 ID。对应 Gemfile 和上游 Makefile 的 `init-local` 用于 Sentry 自己的 Fastlane/Slather 维护流程；IMBoy CI 使用 Flutter/CocoaPods，没有安装该 Ruby bundle。
- `macos/Shims/vendor/Sentry/test-server/Dockerfile`：仅 `DS-0017`。这是由上游 `run-test-server` 单独启动的 Vapor 测试服务，不在 IMBoy 的构建/部署入口或 Sentry runtime podspec/SwiftPM targets 中。

正向构建依据是 `macos/Podfile` 只把 `flutter_sound` 指向局部 shim，该 podspec 的源码范围为 `Classes/**/*`；应用 Xcode framework phase 链接 Pods，CI 执行 Flutter 构建。历史 SwiftPM 文件仍有 Sentry pin，部分 CI 仍传递 SENTRY_DSN，因此不能把这些例外写成“已验证最终二进制没有 Sentry”。例外只说明上述维护工具未被当前构建执行。若引入对应 bundle 或 test-server，必须先移除例外并重新验收。其他路径上的同一 ID、未列出的 ID，以及过期例外都继续阻断。

Semgrep annotations name exact rule IDs at reviewed call sites: operator-selected toolchains/private adapters, fixed ADB operations, and separate argv values. The legacy runner rejects unsupported executables before device discovery. Reassess these annotations if inputs or execution authority change; they do not authorize request-controlled commands. The local Patrol JUnit parser rejects every DOCTYPE while preserving result validation, without claiming general untrusted-XML resource isolation. Annotated findings remain visible as in-source suppressions in SARIF.

Trivy exceptions cover only the listed IDs in the two exact upstream-maintainer files, expiring **2027-02-10**. The vendored Ruby bundle belongs to Sentry's own maintenance workflow; the Vapor test server is a separate upstream target. Neither is installed or executed by the current IMBoy Flutter/CocoaPods build. Runtime podspec/SwiftPM source targets do not consume those tools. Residual Sentry pins/defines are not final-binary evidence. Remove the exceptions before enabling those upstream tasks. Findings at other paths, other IDs and expired exceptions remain blocking; HIGH/CRITICAL, secret scanning and scanner-failure gates stay enabled.
