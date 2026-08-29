# scripts/quality — 静态分析 / 文件行数质量门

## 门总览（三个门，互补不替代）

| 门 | 范围 | 基线 | 状态 |
|---|---|---|---|
| `check_analyzer_ratchet.sh` | **全仓** analyzer | `analyzer_ratchet_baseline.txt`（**零基线**） | APP-02（2026-08-29）新增 |
| `check_file_size_ratchet.sh` | **全仓** Dart 文件行数 | `file_size_baseline.txt`（47 个存量超限） | APP-02（2026-08-29）新增 |
| `check_analyze_increment.sh` | 双体验功能目录（16 前缀） | `analyze_baseline.txt` | 历史门，零基线后自动恒 PASS |

## 1. 全仓 analyzer ratchet 门（check_analyzer_ratchet.sh）

### 背景

APP-02（2026-08-29）把全仓 `flutter analyze` 从 159 条（1 error / 63
warning / 95 info，几乎全在 test/ 与 integration_test/）清零。本门锁定
零基线：基线外**新增 1 条即 FAIL**；基线内条数减少不报错（打印可收紧
提示）。问题指纹 = (severity, 规则代码, 文件) + 条数，**不记行号**。

数据源：`dart analyze --format=machine`（`flutter analyze` 无 `--format`
参数；两者共用同一 `analysis_options.yaml` 与 analyzer 语义）。

### 用法

```bash
bash scripts/quality/check_analyzer_ratchet.sh                     # 检查（CI/pre-push 用）
bash scripts/quality/check_analyzer_ratchet.sh --update-baseline   # 有意变更后重采基线
```

退出码：0 PASS / 1 FAIL（基线外新增或超量）/ 2 BLOCKED（dart 不可用、
依赖未装、analyze 异常、基线缺失）/ 64 参数错误。

### 接线

- CI：`.github/workflows/quality.yml` flutter-analyze job 的
  `Analyzer ratchet gate (whole-repo, zero baseline)` step；
- lefthook pre-push `dart-analyze-full`（原 `dart analyze lib`，零基线后
  升级为全仓指纹级）。

### 何时重采基线

- 升级 Flutter / analyzer 或调整 `analysis_options.yaml` 导致条目漂移；
- 有意接受新问题（必须与引发变更的代码**同一提交** review，防借基线
  掩盖新增债务）。

## 2. 文件行数 ratchet 门（check_file_size_ratchet.sh）

### 规则

编码规范：Dart 源文件 **< 800 行**。存量 47 个文件超限（最大 2726 行，
`lib/page/chat/chat/chat_page.dart`）已入基线，只防新增债务：

1. 新文件超 800 行（不在基线）→ FAIL；
2. 基线内文件行数**增长** → FAIL（只许减不许增）；
3. 行数下降 / 跌破 800 → 不失败，打印可收紧提示。

范围：git 跟踪 + 未跟踪未忽略的 `*.dart`（新文件 commit 前也能被本地
拦住）；排除 codegen（`.g/.freezed/.gr/.pb*`）、`plugin/**`（保留区）、
`build/`、`.dart_tool/`。

### 用法

```bash
bash scripts/quality/check_file_size_ratchet.sh                     # 检查
bash scripts/quality/check_file_size_ratchet.sh --update-baseline   # 有意变更后重采基线
```

退出码同上（0/1/2/64）。CI 接线：quality.yml `File size ratchet gate
(800-line)` step。

## 3. 双体验功能目录增量门（check_analyze_increment.sh，历史门）

### 目的（历史背景）

建立时全仓存在约 165 项历史问题（绝大多数 info 级，集中于 test/ 与
integration_test/）。方针是**不清存量债、只拦新增**：双体验（dual-exp）
功能目录内出现**新增**的分析问题即失败。问题身份 = (文件路径, 规则代码)
+ 该组合的条数；不记行号。

APP-02 清零后，功能目录内已无存量条目，本门自动恒 PASS，保留作为双体验
目录的**专项声明式防线**（基线独立于全仓门，若未来有人借全仓门重采基线
放水，本门仍按自己的基线拦双体验目录）。

### 用法

```bash
bash scripts/quality/check_analyze_increment.sh                    # 增量检查
bash scripts/quality/check_analyze_increment.sh --update-baseline  # 有意变更后重采基线
```

退出码契约（对齐 `scripts/run_sqlite_migration_gate.sh`）：0 PASS（条数
较基线减少不失败，仅提示收紧）/ 1 FAIL（基线外 / 超量组合）/ 2 BLOCKED
（flutter 不可用 / analyze 未正常完成 / 基线缺失）/ 64 参数错误。

脚本内部跑 `flutter analyze --no-pub ...`（全仓一次，约 15~60s），再过滤
到功能目录与基线比对。`--no-pub` 是刻意的：门绝不在隐式执行
`flutter pub get`，避免重写 `pubspec.lock`。

### 功能目录清单（16 个前缀）

由双体验合并范围 `git diff --name-only f60a9338..c72ab6b5` 的 lib/ 路径
归纳，固化在脚本的 `FEATURE_PATHS` 数组中。采用**目录级前缀**：目录下新增
文件自动纳入门内。`lib/i18n/`（slang 生成物）不入门。

- `lib/config/`（路由 / 常量 / 初始化）
- `lib/page/channel/`、`lib/page/chat/`、`lib/page/chat_shell/`（双体验 · 移动壳）
- `lib/page/group/`、`lib/page/passport/`、`lib/page/personal_info/`
- `lib/page/scanner/`、`lib/page/search/`、`lib/page/settings/`、`lib/page/wallet/`
- `lib/page/workspace/`（工作台 + 项目，双体验核心）、`lib/page/workspace_shell/`
- `lib/service/`（SQLite 迁移 / 快照 / 契约等）
- `lib/store/api/`、`lib/store/model/`（workspace / project 的 model 与 api）

## 与其它门的关系

| 门 | 粒度 | 关系 |
|---|---|---|
| lefthook pre-commit `dart-analyze` | staged 的 lib/**/*.dart 单文件 | 快速反馈，覆盖不到未 staged / 跨文件影响 |
| lefthook pre-push `dart-analyze-full` | 全仓指纹级 ratchet（= 门 1） | 零基线后由 `dart analyze lib` 升级而来 |
| `.github/workflows/quality.yml` flutter-analyze | 全仓 severity 级 ratchet（errors=0 / warnings<=830 / infos<=703） | 只看总数不看位置的粗粒度兜底；指纹级零基线由门 1 把关 |

全仓门**不挂 pre-commit**：全量 analyze 单跑 10~60s，挂钩会拖慢所有提交；
pre-commit 已有 staged 文件级快速反馈，全仓门放 pre-push 与 CI。

## 基线文件清单（均脚本生成，勿手改）

| 基线 | 生成命令 |
|---|---|
| `analyzer_ratchet_baseline.txt` | `bash scripts/quality/check_analyzer_ratchet.sh --update-baseline` |
| `file_size_baseline.txt` | `bash scripts/quality/check_file_size_ratchet.sh --update-baseline` |
| `analyze_baseline.txt` | `bash scripts/quality/check_analyze_increment.sh --update-baseline` |

重采基线必须与引发变更的代码**同一个提交** review，防止借基线掩盖新增问题。
