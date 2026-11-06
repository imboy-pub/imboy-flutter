# 测试执行治理续跑状态

## 后续 FTS 任务（2026-11-06）

PR #41 已由用户合并；下方旧分支、授权和 CI 数据仅保留为历史记录。本次用户另行授权
“继续开新 PR 做 FTS”，从 main `8e4c93ebf1e1a59a6091390bec35d503d66b50a0` 开始，
使用 `/workspace/scratch/c02895233621/imboy-flutter-fts`、分支 `fix/message-fts-consistency`。
续跑先核对该工作区、远端分支与 [Draft PR #42](https://github.com/imboy-pub/imboy-flutter/pull/42)，
不重用已关闭的 #41，不覆盖其他 WIP，不合并。远端 `139266bca51a2d65985dea7814a3077dc9004937`
已包含同任务的文件长度门禁拆分；后续保留该提交并整合本地新增边界修复，不强推覆盖。

本轮实现生产连接递归触发器确认、v38 草稿结构合同、聊天/搜索共用期限、查询及展示期
失效过滤，以及 Web WASM/离线 SQLCipher 的可执行合同。迁移仍未注册；两个直写 SQL
skip 保留并继续阻塞完整通过。实际原生驱动/真机二进制、远端历史绝对期限的后端合同
仍需证据，详见 [SQLite 矩阵](../sqlite-migration-test-matrix.md)。

验证命令、日志和可续跑 SDK 保存在仓外 `../fts-evidence/`；以 `current-state.json`、
当前新 PR 的 head 和该 head 的机器事件为准，旧 #41 结果不得重标为新代码结果。
新 PR 的验证状态以其描述和当前提交 CI 为准；没有原生/后端证据时保持 Draft。

English: PR #41 is merged. Continue the separate FTS branch above, preserve WIP and
verify the new PR's exact head. v38 activation and the original direct-SQL skips remain
blocked pending real native/binary evidence and the remote expiry contract. Historical
results below are not validation of this FTS change.

---

## PR #41 历史记录

## 工作区、来源和授权

- 续用 `/workspace/scratch/c02895233621/imboy-flutter`，分支 `fix/test-execution-governance`，remote 为 `https://github.com/imboy-pub/imboy-flutter.git`。
- 用户授权所有任务代码提交至 [Draft PR #41](https://github.com/imboy-pub/imboy-flutter/pull/41)，没有授权合并；不要创建第二个任务分支或 PR。
- 开始先查 status、HEAD、worktree、PR head 和对应 CI，保留其他修改，不用 reset、clean 或强推。
- 原 main 基点 `9f5d36e5b852f0a3dc20c94a0997fde82d9852d2`；本轮重新 fetch 的 main 仍为 `2e06c75ebf9885920d6809d4f4581be103aec49a`。
- 本轮事务检查点修复前的已发布 head 是 `2ced4361c5bc3ab79974936679e5b13ab9e97306`；当前 head 以 Git/PR 为准，不把旧 CI 当成新代码证据。
- 已读根/测试/数据/服务 CLAUDE；ios/macOS/plugin 保留区未修改。并排后端和管理端仅供只读源码合同，不连接服务。
- CLI 无 push 凭证时沿用已授权 GitHub Git database 接口；创建的 tree 必须等于精确暂存的本地 index tree，expected_sha 检查旧 head、force=false。同步本地 ref 前核验 parent/tree/无未暂存差异，不寻找额外凭证，不绕过现有门禁。

## 当前执行合同

复用 `auto_test.py` / `auto_test_lib`：Git 跟踪发现、唯一主套件、14 profiles、平台/产品/角色/variant 实例、原 machine_events/result、逐实例证据和最终对账。未知目录、多主归属、悬空引用、无真实 runner/controller、空计划、缺结果均失败。

- 发现 1,523 个源文件；1,420 个独立目标、103 个辅助等、0 未归属。辅助为 helper 92、fixture 4、driver 5、aggregate 1、included-test 1。
- 主套件：unit 580、widget 292、component 117、sqlite-ffi 129、crypto-ffi 21、backend-contract 45、golden 11、route-smoke 1、device-single 158、device-pair 18、native-ui 2、tooling 46。
- PR 为 1,180 目标/2,359 实例（Linux 1,179、macOS 1,180）；full 为 1,420 目标/3,282 实例。full 计划不是 full 通过。
- CI 冻结同一 PR plan，12 个平台×套件 worker；Linux coverage_eligible 1,132。业务和覆盖率同次执行、同源选择，不重纳入专项。
- 字体合同保持 component/macOS，Linux PLATFORM_NA 不删除 Mac 义务；Web Shell 本机选择宿主15+Chrome1，完整专项16目标/31实例。
- kill-replay 只支持实际 Android standard 控制器；单设备、双端、Patrol、路由、后端和 Golden 保留独立执行约束。
- executed=passed+failed+skipped；actually_run=passed+failed。断言不重试洗绿，基础设施重试保留全部尝试；未批准 skip、非零退出、零执行、缺证据或哈希不符均阻断。

## 本轮继续：真实事务中断检查点（2026-11-06）

上一轮设备目标在 db.transaction 之前发送 kill_ready，无法证明已发生未提交的迁移写入。本轮修复这一真实执行缺口，不改生产 schema 或 MigrationService API：

1. 设备目标和现有 migration_atomic_failure_test 共用 `test/fixtures/sqlite_migration/kill_replay_transaction.dart`，由合法 fixture 目录规则归属，不成为独立业务目标。
2. helper 只接受调用方的 Transaction；在同一事务内执行真实16→17迁移，读回版本17并核验新增 conversation.mention_unread，才回调 ready。
3. ready 使用 `protocol=2 transaction=active from=16 reached=17 to=31`，设备在事务内最多等待30秒，再继续17→31；未中断完成仍为 WINDOW_MISSED。
4. Python 运行时及工件重放均拒绝旧协议、事务未开始/已提交、没有迁移写入或版本不符；即使文件哈希自洽也不能通过。协调收据明确记录 protocol=2。
5. 宿主 FFI 负例检查 ready 后中断的版本/schema/数据回滚，另验证未中断完成31、检查点前真实SQL失败不发ready。它们不证明真实 Android force-stop 或 SQLCipher 二进制行为。
6. Python 负例先红：旧代码会误接受无效 ready，70 tests 报10 failures/1 error；修复后70 tests通过。完整候选验证见仓外 `pr-ci-followup/kill-transaction-followup/` 及当前 PR CI。

该协议证明事务内、迁移边之间的中断，不声称杀在某条 SQLite 指令执行中的精确位置。精确环境与命令见 [execution.md](execution.md)、[specialist-fixtures.md](specialist-fixtures.md)。

## 已完成的上一提交 CI（仅作历史证据）

[42031785586](https://github.com/imboy-pub/imboy-flutter/actions/runs/42031785586)，head `2ced4361`，实际 merge `91e406b531280ee17d34e2889428662f38bb78da`（parents main `2e06c75` + task head）。

- 12 workers、8个静态/契约 jobs；2,359/2,359实例齐全，0缺失/重复/无效证据。原始2,357 PASS、2 FTS BLOCKED。
- 25,057 passed、0 failed、4 skipped；actually_run=25,057、executed=25,061。两平台tooling各796通过；122进程退出0。
- 覆盖率72,073/120,306=59.9081%达到38%，但1,132义务仅1,131完整成功，Linux FTS UNEXPECTED_SKIP使coverage仍BLOCKED。
- 最终稳定检查 BLOCKED/UPSTREAM_FAILED，具体host-tests与coverage；独立重放全部实例、事件/收据/哈希及LCOV与CI一致。
- 原始证据在 `pr-ci-followup/run8/`；最新来源、验证包及当前CI状态见仓外current-state.json和PR描述。新提交必须取得自己的证据。

## 明确保留的阻塞与继续顺序

1. FTS当前schema仍37，v38草稿没有注册；两个直写同步用例保持UNEXPECTED_SKIP。本轮只读复核确认生产SqliteService._onConfigure没有recursive_triggers；现有Web/SQLCipher草稿测试各自打开PRAGMA，不能替代生产接线证据。
2. v38前置仍包括本地到期、远端回退、展示期间到期、真实连接配置和真机SQLCipher/二进制。具体依据为并排imboy cb95fa72的 `docs/design/2026-10-20-channel-group-ux/plan-v2.2.md`。不能删skip、改draft fixture、加豁免或仅为绿CI注册生产迁移。
3. 后端、Golden像素、设备/双端/Patrol、full无通过声明；仅用合成数据和隔离账号。Golden缺基线ENV_MISSING，不自动生成后宣称回归通过。
4. 当前本机无Flutter/Dart/adb；两个进程工具目标可能因ps起始时间预检受阻。依赖当前提交CI补足宿主Flutter和完整tooling验证，不能重用旧收据。
5. 发布前核验精确修改范围、当前归属/所有profile/PR覆盖率一致性/工具测试；发布后读取当前head对应plan、worker、coverage、summary并复核。不要只为记录进度发布docs-only提交。
6. 更新原PR描述及仓外checkpoint；已有验证包更新同一文件，勿复制Git源代码或混入其他提交的结果目录。分支保护选择稳定IMBoy Test Summary需维护者设置，保持Draft、不合并。
