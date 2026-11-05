# 测试执行治理续跑状态

## 工作区、来源和授权

- 继续使用 `/workspace/scratch/c02895233621/imboy-flutter`，分支 `fix/test-execution-governance`；不要再创建任务分支/worktree。
- remote 为 `https://github.com/imboy-pub/imboy-flutter.git`；全部任务代码提交到 [Draft PR #41](https://github.com/imboy-pub/imboy-flutter/pull/41)，用户已明确授权发布，没有授权合并。
- 先查 `git status --short --branch`、`git log -1`、`git worktree list --porcelain`、PR 当前 head 和对应 CI。保留其他 worktree/未提交内容，不用 reset、clean 或强推。
- 原始 main 基点 `9f5d36e5b852f0a3dc20c94a0997fde82d9852d2`；已核验 CI 的 main parent 为 `2e06c75ebf9885920d6809d4f4581be103aec49a`。本轮入口修复前的 task head 是 `87194335cfcd80245e588271ce55e08ef0610d88`；发布后 head 以 Git/PR 为准。
- 已读 AGENTS/CLAUDE 和测试说明；ios/macOS/plugin 保留区未修改。并排 imboy `cb95fa72`、imboyadmin `202de6b` 只供源码合同，不连接服务。
- CLI push 没有凭证；沿用已授权 GitHub Git database 接口。创建的 tree 必须等于本地 index tree；用原 head 的 expected_sha、force=false 更新原分支。同步本地 ref 前核验 parent/tree/无未暂存差异，不寻找额外凭证。

## 当前实现与计数

继续复用 `auto_test.py` / `auto_test_lib`，没有另建测试系统：Git 跟踪发现、唯一主套件、14 profiles、平台/产品/角色/variant 实例、原 machine_events/result、逐实例证据和最终对账。未知目录、多主归属、悬空引用、无真实 runner/controller、空计划、缺结果都不能通过。

- 发现 1,522 个 Dart/Python 源文件；1,420 个独立目标、102 个辅助等、0 未归属。辅助为 helper 92、fixture 3、driver 5、aggregate 1、included-test 1。
- 主套件：unit 580、widget 292、component 117、sqlite-ffi 129、crypto-ffi 21、backend-contract 45、golden 11、route-smoke 1、device-single 158、device-pair 18、native-ui 2、tooling 46。
- PR 为 1,180 目标/2,359 实例（Linux 1,179，macOS 1,180）；full 为 1,420 目标/3,282 实例。full 计划不是 full 通过。
- CI 冻结同一 PR plan，12 个 platform×suite worker，Linux coverage_eligible 1,132；业务与覆盖率选择同源，覆盖率不重纳入专项或再跑一遍业务。
- `web-shell` profile 按合法前缀自动接管，当前 16 目标/31 实例；本机 wrapper 为宿主15+Chrome1。Chrome 专属不发 VM。profile 前缀为空、非法或只指向辅助文件会失败。
- 字体合同保持 component/macOS，五用例完整，Linux PLATFORM_NA 不删除 Mac 义务。
- kill-replay 保持 device-single 主归属，改为实际 Android standard 控制器。原来错误的 iOS/macOS 义务改为 PLATFORM_NA；Android 义务仍在。full 因此从 3,284 更正为 3,282，device-single 从433为431，device从465为463。
- 计数：executed=passed+failed+skipped；actually_run=passed+failed。普通断言不重试洗绿；基础设施重试保留全部尝试。任何未批准 skip、非零进程、零执行、缺事件/收据/文件/hash 均不能通过。

## 本轮入口修复

1. pre-push 默认只执行归属硬门禁，backend 明确 OUT_OF_SCOPE。显式 `--backend` / `IMBOY_PRE_PUSH_BACKEND=1` 才走统一 backend 计划；缺环境、skip、失败均阻断。不再自动加载 test.env、探测后端或输出账号。
2. 两个跨平台 E2EE shell 只转交声明的 device-pair 目标，保留 sender→receiver→final；无默认真实设备 ID、grep PASS 或独立选择器。
3. Web Shell 保留 SDK/资产/analyze/build 用途，测试交统一 profile；dry-run 在前置之前。前置失败留日志并生成全部 UPSTREAM_FAILED，quick 不缩测试范围；人工预览不算自动化通过。
4. SQLite kill-replay 复用原进程与 invocation：prepare→结构化 ready→PID→固定测试包 force-stop→PID 消失→verify。准备仅协调证据，业务计数只来自 verify。五阶段、ready 前缀、观察顺序、命令、收据与 hash 可重放；verify 必须 KILLED_ROLLED_BACK。
5. 独立审查发现的 ready 后 prepare 断言被中断逻辑掩盖已修复：assertion、skip、unknown error 均 BLOCKED 且不调用 verify；只有原基础设施分类明确认可的 transport 异常可保留为受控停止证据。没有新增 skip 豁免。
6. 手动 Golden 先做现有 SDK 的 Dart/源码配置检查，实际 Flutter pin/framework/engine 交统一 Golden preflight；其他 profile 保留普通完整 SDK 检查。避免 PR3.47.5 误挡 Golden 登记3.47.7；工作流仍仅手动、默认只计划。

环境和精确命令见 [execution.md](execution.md)、[specialist-fixtures.md](specialist-fixtures.md)。kill_ready 在现有 Dart 的 db.transaction 之前，证据不能证明精确 SQL 事务内杀点；本任务未改该业务源码。

## 本轮本地验证与证据

仓外报告根：`/workspace/scratch/c02895233621/pr-ci-followup/entrypoint-followup/`；文件内 commit/source_fingerprint 标识实际快照。旧收据不可冒充新 head。

- catalog 56 tests、adapter/runner 127 tests、entrypoint 34 tests 分别 PASS；这些命令含重叠范围，不相加冒充独立用例总数。
- 独立 kill 注入复核四种情形见 `kill-review-recheck.json`。实际 wrapper dry-run 选中1个Android；无设备执行 ENV_MISSING、0 attempts、exit2，无 adb 调用；证据另存 `pr-ci-followup/kill-replay-no-device/`。
- 实际 pre-push 默认静态归属 PASS，backend OUT_OF_SCOPE；backend 显式缺环境45/45 ENV_MISSING、0用例、exit2。
- 实际 Web Shell dry-run 为16目标/16实例；无SDK执行16/16 UPSTREAM_FAILED、依赖web-shell-sdk、0用例、exit2、无缺结果。
- 全仓归属、SDK --config-only、文件行数门、bash -n、Python compileall、git diff --check 通过。最终统一 tooling：46/46结果齐全，44 PASS、2 ENV_MISSING，764 passed/0 failed/0 skipped，exit2；见 `tooling-final/summary.json`。framework --checks-only 七项静态门 PASS，见 `framework/gate_summary.json`。
- 14 profile/PR覆盖率选择/12worker分区检查、pr/full计划、归属与迁移差异见 `candidate-*`；发布后必须重新生成 `published-*`。相对旧主选择器仍为297新增接管、883保留、38移入专项、202专项归属；这是选择迁移，不是执行证明。
- 当前本机无 Flutter/Dart。两个现有工具目标 `tool/uiux/recovery_contract_test.py`、`tool/uiux/test_lock_contract.py` 需要可靠的 ps 进程起始时间，当前环境预检阻塞；已发布候选的 CI 已实际执行通过。

## 已完成的最新 CI 证据（入口修复前）

[run7：42024193817](https://github.com/imboy-pub/imboy-flutter/actions/runs/42024193817)，task head `87194335`，实际 merge `24e8aec4ca9bd11512654f03fe49dea6240137a9`，parents 为 main `2e06c75` + task head。GitHub completed/failure。

- 12 个 worker 和8个静态/契约 job 已核验；所有 artifact ZIP 摘要/长度、安全解压、原始机器事件、进程、LCOV 和最终汇总已独立重放。验证器冻结自87194335，未用未发布代码解释旧收据。
- 2,359/2,359 实例齐全，0 缺失/重复/无效证据；原始状态2,357 PASS、2 FTS BLOCKED。24,985 passed、0 failed、4 skipped，actually_run=24,985、executed=24,989；122进程退出0，没有重试/超时。
- Linux12,490 passed/2skip，macOS12,495/2skip；两平台 tooling 各760用例通过。Mac字体5/5、准备页21/21通过。静态SDK为Flutter3.47.5/Dart3.13.4，formatter2792文件0changed，analyzer0/0/0。
- 覆盖率72,073/120,306=59.9081%，高于原38%阈值；但1,132义务只1,131完整成功，唯一缺口为Linux FTS UNEXPECTED_SKIP。coverage 保持 BLOCKED/INCOMPLETE_COVERAGE_EVIDENCE，LCOV独立重建逐字节一致。
- 最终 IMBoy Test Summary 实际运行，保持 BLOCKED/UPSTREAM_FAILED，具体依赖host-tests、coverage。全局阻塞后的2,359行与原始worker的2,357 PASS是不同层次；不是2,359个断言失败。
- 完整证据在 `pr-ci-followup/run7/`；`final-independent-audit.json`、`coverage-audit.json`、`upstream-audit.json` 的完整结论与CI一致。更早失败/修复证据仍在run3/run5/run6，不能混入本轮results目录。

## 继续顺序与未解除条件

1. 确认入口修复是否已提交PR41；未发布时先完成/读取本地最终门禁，核验精确stage tree再发布。已发布就续查最新head对应CI，不重复创建分支/提交。
2. 发布后重新冻结published清单/计划；新CI的plan、12workers、coverage、summary都绑定同一merge/source fingerprint。核验ZIP与物理收据，不拿run7旧结果替代新提交。不要仅为进度发docs-only提交重复全跑。
3. 更新PR描述及仓外current-state.json；生成报告包时只放生成的清单/日志/收据/报告，不复制Git源代码。已存在验证包应更新同一文件，而不是重复创建。
4. FTS current-schema两用例仍 UNEXPECTED_SKIP：dbVersion/注册inventory37，v38是draft。不要删用例、改draft fixture、加豁免或仅为绿CI注册生产迁移。既定前置见 sibling imboy cb95fa72 的 `docs/design/2026-10-20-channel-group-ux/plan-v2.2.md` 和 app `1ae24621590ae4b285419731c1f871f71034561d`：到期/远端回退语义、实际连接recursive_triggers、Web/SQLCipher隔离验证后再正式注册。
5. 没有真实后端、Golden像素、设备/双端/Patrol或full通过证据。Golden缺基线为ENV_MISSING，禁止自动生成后声称回归通过；j16c/j28b companion、MC owned context、验收冻结输入/租约仍须真实准备。所有数据使用合成fixture/隔离账号，不访问生产。
6. 分支保护选择稳定的 IMBoy Test Summary 需维护者设置；保持Draft，不合并。最终回复分开报告静态、工具、Flutter、后端、设备/双端、完整回归等级及具体阻塞。
