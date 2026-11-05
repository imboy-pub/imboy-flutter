> [imboyapp 根目录](../CLAUDE.md) > **test（测试根目录）**

# 测试目录说明 / Test Directory Guide

执行方式和环境合同以 [统一测试执行说明](../docs/testing/execution.md) 为准。
机器合同是 `test/auto_test/execution_contract.json`；入口为
`python3 scripts/auto_test.py execution-*` / `bash scripts/run_test_suite.sh`。

- `test/unit_test/` 和 `test/` 下其他业务目录都有宿主测试，不得只扫描前者。
- `integration_test/` 保留在根；真实后端、设备、配对、Patrol 按依赖分开编排。
- `test/tooling/` 和现有 Python 自检受同一归属门禁管理。
- `test/auto_test/` 页面需求/规格/catalog 负责业务映射，声明不代表执行通过。
- 驱动/聚合/fixture/辅助显式分类；`all_tests.dart` 不能代表完整设备回归。

```bash
bash .github/scripts/validate_ci_test_paths.sh
python3 scripts/auto_test.py execution-plan --profile pr --output /tmp/imboy-pr-plan.json
# 本机 PR 分片；Linux 改为 --platform linux
bash scripts/run_test_suite.sh --profile pr --platform macos
# 全量缺平台/设备/基线/后端必须阻塞
bash scripts/run_test_suite.sh --profile full
bash scripts/check_auto_test_framework.sh
bash scripts/run_sqlite_migration_gate.sh --local
```

新增测试先进入 Git 跟踪范围，合法规则会自动接管；新家族/特殊依赖补合同并校验。
不得用裸 flutter test 默认扫描代替计划，也不得用 disabled 掩盖未执行。
最近的 flutter_test_config.dart 生效；宿主使用 loopback 合成环境、临时数据库、模拟服务。
真实后端专项使用显式隔离合同；禁止生产账号与生产回退。FFI 按锁定依赖构建，不手填旧版本。
结果必须结合机器事件和退出码；零执行/全跳过/未批准部分skip/缺结果/上游失败不得 PASS。
修改后执行相应验证，在回复中报告命令、结果、未执行原因和证据等级。
