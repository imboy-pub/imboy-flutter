# test_automation

本目录采用方案 B（分层 YAML）组织自动化测试，目标是把 10 条功能线做成可追踪、可恢复执行、可持续扩展的执行体系。

更新时间：2026-03-01

## 当前执行入口

- 执行器：`test_automation/scripts/run_yaml_mapped_suite.sh`
- 执行索引：`test_automation/scenarios/executable_cases.yaml`

执行器特性：
- 支持中断恢复：`--resume --run-id <RUN_ID>`
- 支持失败重跑：`--rerun-failed`
- 支持全局重试：`--max-retries <n>`
- 支持单任务超时：`--task-timeout-seconds <sec>`
- 失败不中断：单 case 失败写入 `FAILED_SKIPPED` 后继续下一个

## 目录结构（方案 B）

```text
test_automation/
├── README.md
├── scenarios/
│   ├── domain/                       # 10 个功能域 YAML
│   ├── cases/                        # 36 个场景 case YAML
│   ├── executable_cases.yaml         # 可执行映射索引（runner 读取）
│   ├── 01_simple_tap.yaml            # 历史规格 YAML（保留追溯）
│   └── ...                           # 历史规格 YAML（保留追溯）
├── scripts/
│   └── run_yaml_mapped_suite.sh
├── .state_yaml/                      # 运行状态（可恢复）
├── reports/
│   └── yaml_runs/                    # 运行报告
```

## 10 条功能线覆盖（当前）

- `单聊`：4 case（auto 4）
- `群聊`：4 case（auto 4）
- `会话管理`：3 case（auto 3）
- `会话消息提醒`：3 case（auto 3）
- `WebSocket 重试与确认`：4 case（auto 4）
- `端到端加密`：4 case（auto 4）
- `Tag 系统`：3 case（auto 1，manual-assist 2）
- `收藏系统`：3 case（auto 2，manual-assist 1）
- `频道系统`：4 case（auto 4）
- `朋友圈`：4 case（auto 2，manual-assist 2）

合计：`36 case`，其中 `enabled(auto)=31`，`manual-assist(pending)=5`。

## 运行方式

```bash
# 1) 校验映射与计划（不执行测试）
bash test_automation/scripts/run_yaml_mapped_suite.sh --dry-run

# 2) 执行全量（失败不中断）
bash test_automation/scripts/run_yaml_mapped_suite.sh

# 3) 指定 RUN_ID（建议手工执行时固定）
bash test_automation/scripts/run_yaml_mapped_suite.sh --run-id yaml_manual_20260301

# 4) 中断恢复
bash test_automation/scripts/run_yaml_mapped_suite.sh --resume --run-id yaml_manual_20260301

# 5) 只重跑失败项
bash test_automation/scripts/run_yaml_mapped_suite.sh --resume --run-id yaml_manual_20260301 --rerun-failed
```

## 输出与证据

- 状态目录：`test_automation/.state_yaml/<RUN_ID>/`
- 汇总报告：`test_automation/reports/yaml_runs/<RUN_ID>/summary.tsv`
- 人类可读报告：`test_automation/reports/yaml_runs/<RUN_ID>/summary.md`
- 机器可读报告：
  - `results.json`
  - `results.junit.xml`
- 单 case 日志：`<case_id>.runner.log`

## 环境说明

部分 UI 集成 case 依赖真实账号、设备和联调数据（已在 `precondition` 标注）：
- 常见前置：`TEST_PHONE`、`TEST_PASSWORD`、可用网络、可访问后端
- 默认 `dart-define`：`APP_ENV=local_home`

不满足前置时，执行器会将该 case 标记为 `FAILED_SKIPPED` 并继续后续 case。
另外，部分集成测试已实现“前置缺失主动 skip”策略（测试进程返回 0），以避免环境故障阻断整条回归链路。

## test user
android_test_001@imboy.pub (TSID 90600962240284672)

117@imboy.pub (TSID 88300811150690304) admin888
