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

### 已取得的 CI 结果与运行器修复

- 格式修复已发布为 `bdbe06bd2d37c227ae1602c86c4ebbf65c406f1f`。[第二轮 CI](https://github.com/imboy-pub/imboy-flutter/actions/runs/42001967982) 在固定 Flutter 3.47.5 / Dart 3.13.4 下验证 2792 个 Dart 文件格式通过、0 changed；Analyzer 为 0 error / 0 warning / 0 info，全部静态和源码契约门禁通过。两平台业务任务及最终汇总仍失败，没有完整 PR 通过证据。
- 已下载并核验首轮 CI 的真实执行证据。Linux：1180/1180 目标有结果，198 PASS / 982 BLOCKED，4221 passed / 0 failed / 2 skipped。macOS：1180/1180 有结果，195 PASS / 983 BLOCKED / 2 FAIL，4054 passed / 3 failed / 2 skipped。两平台证据哈希均与原始收据一致。
- 首轮主要阻塞是一个包含约 980 个目标的 Flutter 串行进程达到既有 900 秒限时，缺失 machine `done`；最后一个已开始测试不能据此被认定为挂起。修复为对既有 host 分组按最多 128 个目标分批，并恢复纯 unit/widget/component 分组的 Flutter 默认并发；SQLite、crypto、后端、Golden、路由等专项继续串行或隔离执行。原限时、目标矩阵、覆盖率范围和逐实例对账保持不变。
- 首轮两平台各 21 个 crypto-ffi 目标 / 185 用例通过；SQLite 各 126 个目标通过、1 个因 2 个 FTS skip 被阻断，合计 1292 passed / 2 skipped。Linux 全部 46 个 tooling 目标 / 716 用例通过，说明本地的两个 `ps` 阻塞可在正常 Linux CI 解除。以上是实际通过的子集，不代表整个 Flutter 或完整回归通过。
- 修复 macOS 首轮发现的 3 个工具断言失败：Bash 3.2 在 `set -u` 下展开空参数数组、临时目录 `/var` 与 `/private/var` 的规范路径差异，以及测试 fixture 硬编码 Linux。没有改动业务断言。
- 补齐超时清理：每次调用拥有独立 POSIX 进程组，只清理该组并回收主进程，冻结日志/事件快照后再记录哈希。合成测试验证忽略 TERM 的后代不会继续写日志、无关进程保留、部分执行不能 PASS；这项生命周期缺陷由定向测试复现，不能表述为已发现 CI 原始收据哈希错误。非 POSIX 主机明确阻断，不声称已支持 Windows 进程树监督。
- 当前修复的本地验证：`PYTHONPATH=test/tooling/auto_test python3 -m unittest discover -s test/tooling -p 'test_*.py'` 为 **625 tests PASS**；统一 tooling 执行与独立证据再对账均为 46/46 有结果、44 PASS / 2 ENV_MISSING、691 passed / 0 failed / 0 skipped。另有 8 项路由包装器测试通过，路由 dry-run 计划含 176 实例、业务执行 0。归属、Python 编译、shell 语法和 diff 检查通过。
- CI 原始证据在 `/workspace/scratch/c02895233621/pr-ci-followup/original-hosts/`；修复验证在 `pr-ci-followup/runtime-fix-validation/`。运行器修复已发布为 `a045b78bc0a7e5596cdf45e7e36d0ff3d4d722dd`，全部本任务修改集中在 Draft PR #41；工作分支不更换。保留此前失败结果，不用重试洗掉断言失败。

### 第三轮 CI 的源码绑定与既有业务阻塞

- [第三轮 CI](https://github.com/imboy-pub/imboy-flutter/actions/runs/42007621614) 对应 task head `a045b78`，实际 checkout 是 `de2f298e2bb58376895fc5292d05bbc862697993`。其第一 parent 为任务进行中前进后的 main `2e06c75ebf9885920d6809d4f4581be103aec49a`，第二 parent 为 task head。PR 元数据一度仍返回旧 `base_sha=9f5d36e`；来源以实际 checkout 日志和 Git parent 为准，不能把旧 base 快照当成本轮测试源码。
- 本轮冻结计划 ZIP 的 SHA-256 已核验：1180 个目标 / 2360 个实例，commit 为上述 merge checkout，源指纹 `3ec04fd9ae47f25179cda369ba363cc564fa6b705ac033289db4599a3bf7baba`。任务分支独立计划仍为原始 main 基准上的源指纹 `5339c90f3c7a3d3d2bdaa27507d69a6b8f0bbf4355d87210d99f403d982456fb`；两者不得混用于证据对账。
- 本轮格式仍为 2792 文件 / 0 changed，Analyzer 0 error / 0 warning / 0 info；归属、源码契约、框架与 SQLite 静态门通过。文件行数门失败：main 新改动使 `test/talk_record/talk_record_prepare_page_test.dart` 从基线 886 增至 905 行。任务分支该文件仍是 886 行、与原基准 blob 完全一致；合并候选与新 main 的 905 行 blob 完全一致。保留他人变更，不提高基线；该合并候选的质量门失败有效，最终汇总须体现上游失败。
- 找到了 FTS skip 注释引用的既定设计：后端 sibling 仓库 `cb95fa72f9bc617d0f30ddd6b98da51f39cfd2af` 的 `docs/design/2026-10-20-channel-group-ux/plan-v2.2.md`，以及 App 原提交 `1ae24621590ae4b285419731c1f871f71034561d`。两项 current-version 用例有意等待 v38 正式注册；它们不是缺少一段可任意替换的 draft fixture。
- 现有 `migration_v38_fts_draft_test.dart` 已在首轮两平台各 12/12 PASS，但它手动升级临时 v37 库，不能替代当前已注册 schema 的验收。保留原两项 `UNEXPECTED_SKIP`，不删除、不豁免，也不将其重新归类为第二份 draft 验证。解除前需要处理本地时效、远端回退和展示期间到期语义，证明应用实际连接的 `recursive_triggers` 条件，完成相应 Web/SQLCipher 二进制隔离验证，再按既有迁移流程正式注册；这些工作使用合成环境，不要求生产数据或服务。
- 记录时第三轮 Linux/macOS host 任务尚在运行。运行器分批耗时、macOS 修复、完整覆盖率和最终汇总必须以本轮完成后的收据判断；不能根据静态或旧轮子集通过提前记为全量 PASS。

### 继续处理合并候选的测试行数门

- 用户要求所有本任务修改继续提交 PR #41。当前复用既有 `pumpPrepare` helper：三个导航测试共用原有容器/router 准备，全部 20 次紧随准备的 `pumpAndSettle` 收入 helper；后续交互、pending 权限竞态中的单次 `pump` 和所有断言保持原位。
- 该目标没有外部 helper 调用者。任务分支文件从 886 降到 851 行；与 main `2e06c75` 的真实三方合成无冲突，合成后 870 行，低于原 886 行基线。main 的 19 处 `ensureVisible` 全保留，20 个 `testWidgets` 声明及 73 个断言位点未减少。没有调整基线、删测试或改变业务代码。
- 本地文件大小门、全仓归属门和 diff 检查通过；独立只读复核确认异步准备顺序。发现/归属计数仍为 1522/1420/102/0，无新增文件或 runner。静态证据在 `/workspace/scratch/c02895233621/pr-ci-followup/prepare-harness-fix/`，不作为 Flutter 执行通过证据。
- 新提交必须重新生成计划，使用其实际 CI merge checkout 收据确认两平台的导航、权限和账号切换行为。此前 run 42007621614/42009273371 的 host 任务记录时仍在执行，不能将旧候选收据当作此测试源码的验证。

## 未解除条件及下一步

1. 安装仓库固定Flutter3.47.5/Dart，按锁定依赖准备包、SQLite和Rust加密库；本环境固定SDK下载/发行索引探测返回404，未替换版本。
2. 两工具目标 tool/uiux/test_lock_contract.py 与 recovery_contract_test.py 需要可稳定查询父/子进程启动时间的ps环境；不削弱原lock断言。
3. 在隔离环境准备API/WS/签名材料/合成账号、Golden固定平台字体及既有基线、真实设备/配对/Patrol及需要的租约/fixture。精确条件见 execution.md 与 specialist-fixtures.md。
4. message_fts_transaction_test.dart中v38触发器尚未注册导致C2C/C2G共2个硬skip；实际执行会UNEXPECTED_SKIP。未擅自注册迁移或添加豁免。
5. j16c/j28b外部companion及旧客户端、MC owned context、验收冻结输入须由真实准备流程提供。Patrol实际版本的依赖冻结行为待验证，未添加猜测flag。
6. 环境齐备后先跑对应专项，再收集原full计划所有实例与公共gates对账；不得以分片/静态/工具通过代替完整回归。
7. CI分支保护改为稳定的IMBoy Test Summary需维护者设置。PR已获创建授权；仅发布本任务分支，合并仍需另行授权。

续跑：先读本状态、运行 git status --short --branch 与 git worktree list，核对diff及证据，从本worktree继续，不重建已完成能力。任何源变更都要重新冻结计划并运行对应验证。
