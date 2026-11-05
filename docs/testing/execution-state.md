# 测试执行治理续跑状态

## 工作区

- 日期：2026-11-05；路径 `/workspace/scratch/c02895233621/imboy-flutter`。
- 分支 `fix/test-execution-governance`，实现与验证的基准 HEAD `9f5d36e5b852f0a3dc20c94a0997fde82d9852d2`；发布后的当前 HEAD 以 `git log -1` 为准。
- remote `https://github.com/imboy-pub/imboy-flutter.git`。用户 Mac 路径在本环境不存在。
- 后端只读 sibling `imboy` cb95fa72；admin `imboyadmin` 202de6b；只校验源码，不连接服务。
- 已读适用 AGENTS/CLAUDE，保留其他工作区修改；没有改保留区 ios/macOS/plugin。
- 下述验证记录来自创建 PR 前的实现快照；当时新文件逐路径 intent-to-add 供 Git 发现，尚未提交或推送。
- 用户随后明确授权“创建PR”，允许提交并推送本任务分支、创建 Draft PR；没有授权合并。发布状态与 PR 链接以 GitHub 和交付回复为准。

## 已完成的实现

统一 Git 跟踪发现、12套件单主归属、13 profiles、产品/平台/角色/variant矩阵；已知目录新增目标自动纳入，未知/冲突/悬空/无 runner 硬失败。所有主入口、coverage、SQLite/E2EE/route共用既有 auto_test 框架的新 execution-* 命令。

机器事件与真实退出码共同判定，零执行/全或部分未批准skip/缺证据不能PASS；前后源指纹、产品真实生成物、可搬迁日志/事件/process receipts/hash、最终全实例对账。稳定 CI summary always，无上游 workflow paths 过滤。

单设备/18配对文件/Patrol独立编排；真实API严格隔离loopback；Golden基线环境合同；验收三目标复用既有冻结输入与lease；MC owned复用现有coordinator并核验独立gate；full不因环境不足缩为局部通过。

## 最终计数与验证

- Git发现1522 Dart/Python源：1420独立目标，102辅助/驱动等，未归属0；不是Flutter用例数量。
- PR 1180目标/2360实例，full 1420目标/3285实例。13 profiles全计划构建通过；PR与coverage selected IDs相同。
- `PYTHONPATH=test/tooling/auto_test python3 -m unittest discover -s test/tooling -p 'test_*.py'`：618 tests PASS，38.632秒。
- `AUTO_TEST_REPORT_ROOT=/workspace/scratch/c02895233621/verification-final/framework bash scripts/check_auto_test_framework.sh`：整体BLOCKED/exit2；静态归属/spec/catalog/报告/编译/自检/产品合同通过。
- 该框架实际执行 `execution-run --profile tooling --platform linux`：46目标收到46结果，44 PASS/2 ENV_MISSING；实际684用例通过，failed=0/skipped=0。
- 工具结果再经 `execution-summary` 实查文件/hash及重解析后同样44 PASS/2 BLOCKED，无缺结果。
- 14项shell语法/Python编译/SDK pin/依赖只读/文件大小/diff静态检查通过；全部workflow YAML解析及无paths合同通过。
- `execution-run --plan verification-final/full-plan.json`：3285实例全部UPSTREAM_FAILED，0用例执行，exit2，complete_regression=false。
- backend/linux45、Golden11、pair30、native2实例执行预检全部ENV_MISSING、0用例，均exit2。
- 缺结果反向汇总发现46个MISSING_RESULT；取消上游反向汇总发现3285个缺结果并报告UPSTREAM_FAILED，均非PASS。
- 实际SDK检查exit1：找不到flutter。当前没有Flutter/Dart、真实后端、设备/双端、Golden像素或完整回归通过证据。

完整原始证据：`/workspace/scratch/c02895233621/verification-final/`。关键文件 ownership.json/md、migration.json、pr/full-plan.json、profile-checks.json、tooling-reconciled.json、full-reconciled.json、各ENV报告和日志。

## PR #41 后续验证（2026-11-05）

- Draft PR：https://github.com/imboy-pub/imboy-flutter/pull/41；首个发布提交 `43dcfb372c29f0e99d7862257fd31182b7184aa7`，仍基于上述 main。
- 首轮 CI：https://github.com/imboy-pub/imboy-flutter/actions/runs/41999512600。归属与计划、框架静态门禁、SQLite 迁移静态门禁、错误码/Protobuf 源码契约、Secrets scan、DCO 已通过。
- CI 成功准备 Flutter 3.47.5 / Dart 3.13.4。首次分析为 0 error / 1 warning / 1 info；格式检查在 2792 个文件中只发现两份本 PR 改动的后端契约文件有差异。
- 后续修复删除 `group_collaboration_flow_test.dart` 中 `fail()` 后的不可达 return，并为 `group_pro_readonly_contract_test.dart` 的隔离 URL 守卫补齐花括号、调整格式。隔离条件和业务断言保持原义。
- 本地定向验证 `PYTHONPATH=test/tooling/auto_test python3 -m unittest test_execution_adapters test_execution_catalog test_execution_entrypoints`：99 tests PASS；归属门禁和 `git diff --check` 通过。
- 当前开发环境仍没有 Dart/Flutter，修复后的格式与分析必须由下一轮固定 SDK 的 CI 复核。记录时首轮 Linux/macOS 业务测试仍在执行，不能据静态门禁通过推断业务或完整回归通过。

## 未解除条件及下一步

1. 安装仓库固定Flutter3.47.5/Dart，按锁定依赖准备包、SQLite和Rust加密库；本环境固定SDK下载/发行索引探测返回404，未替换版本。
2. 两工具目标 tool/uiux/test_lock_contract.py 与 recovery_contract_test.py 需要可稳定查询父/子进程启动时间的ps环境；不削弱原lock断言。
3. 在隔离环境准备API/WS/签名材料/合成账号、Golden固定平台字体及既有基线、真实设备/配对/Patrol及需要的租约/fixture。精确条件见 execution.md 与 specialist-fixtures.md。
4. message_fts_transaction_test.dart中v38触发器尚未注册导致C2C/C2G共2个硬skip；实际执行会UNEXPECTED_SKIP。未擅自注册迁移或添加豁免。
5. j16c/j28b外部companion及旧客户端、MC owned context、验收冻结输入须由真实准备流程提供。Patrol实际版本的依赖冻结行为待验证，未添加猜测flag。
6. 环境齐备后先跑对应专项，再收集原full计划所有实例与公共gates对账；不得以分片/静态/工具通过代替完整回归。
7. CI分支保护改为稳定的IMBoy Test Summary需维护者设置。PR已获创建授权；仅发布本任务分支，合并仍需另行授权。

续跑：先读本状态、运行 git status --short --branch 与 git worktree list，核对diff及证据，从本worktree继续，不重建已完成能力。任何源变更都要重新冻结计划并运行对应验证。
