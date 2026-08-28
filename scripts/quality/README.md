# scripts/quality — 双体验功能目录 · 增量静态分析质量门

## 目的

全仓 `flutter analyze` 存在约 165 项历史问题（绝大多数为 info 级，集中于
test/ 与 integration_test/）。既定方针是**不清存量债、只拦新增**：双体验
（dual-exp）功能目录内出现**新增**的分析问题即失败，其余目录维持现状不入门。

问题身份 = (文件路径, 规则代码) + 该组合的条数；**不记行号**（行号随编辑
漂移，无法做稳定基线）。

## 文件

| 文件 | 说明 |
|---|---|
| `check_analyze_increment.sh` | 门脚本（bash） |
| `analyze_baseline.txt` | 基线（脚本生成，勿手改） |

## 用法

```bash
bash scripts/quality/check_analyze_increment.sh                    # 增量检查
bash scripts/quality/check_analyze_increment.sh --update-baseline  # 有意变更后重采基线
```

退出码契约（对齐 `scripts/run_sqlite_migration_gate.sh`）：

| 码 | 含义 |
|---|---|
| 0 | PASS：功能目录无新增分析问题（条数较基线减少不失败，仅提示可收紧） |
| 1 | FAIL：出现基线外 / 超量的 (文件, 规则) 组合，打印超出的条目 |
| 2 | BLOCKED：flutter 不可用 / analyze 未正常完成 / 基线缺失 |
| 64 | 参数错误 |

脚本内部跑 `flutter analyze --no-pub ...`（全仓一次，约 15~60s），再过滤
到功能目录与基线比对。`--no-pub` 是刻意的：门绝不在隐式执行
`flutter pub get`，避免重写 `pubspec.lock`。

## 功能目录清单（16 个前缀）

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

## 何时重采基线

- 有意接受新目录进 `FEATURE_PATHS` 且其存量问题需入基线时；
- 升级 Flutter / analyzer 或调整 `analysis_options.yaml` 导致全量条目漂移时；
- 存量问题被修复、条数下降后想收紧门槛时（脚本会列出可收紧的组合）。

重采结果 `analyze_baseline.txt` 必须与引发变更的代码**同一个提交**review，
防止借基线掩盖新增问题。

## 与既有门的关系（不重复、不替代）

| 既有门 | 粒度 | 关系 |
|---|---|---|
| lefthook pre-commit `dart-analyze` | staged 的 lib/**/*.dart 单文件 | 快速反馈，覆盖不到未 staged / 跨文件影响 |
| lefthook pre-push `dart-analyze-full` | `dart analyze lib` 零容忍 | 仅 lib/ 且当前恰好零增量才可行；本门提供可演进的基线机制 |
| `.github/workflows/quality.yml` flutter-analyze | 全仓 severity 级 ratchet（errors=0 / warnings<=830 / infos<=703） | 只看总数不看位置；本门是 (文件, 规则) 粒度的功能目录增量门 |

本门**不挂 pre-commit**：全量 analyze 单跑 15~60s，挂钩会拖慢所有提交；
pre-commit 已有 staged 文件级快速反馈，增量门放 CI 与按需本地执行即可。

## CI 接入点（未自动接线，接入时照抄）

推荐挂在 `.github/workflows/quality.yml` 的 `flutter-analyze` job 内，
在 `Get dependencies` / `Materialize CI environment` step 之后追加一步：

```yaml
      - name: Dual-exp analyze increment gate
        run: bash scripts/quality/check_analyze_increment.sh
```

（该 job 已有 Flutter 环境与 pub get；门内 analyze 复用同一环境，增量成本
约一次 analyze 时长。）
