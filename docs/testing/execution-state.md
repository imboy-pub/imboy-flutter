# 测试执行治理续跑状态

## 先核对工作区和授权

- 工作区：`/workspace/scratch/c02895233621/imboy-flutter`；分支 `fix/test-execution-governance`。不要创建第二个任务分支/worktree。
- remote：`https://github.com/imboy-pub/imboy-flutter.git`；Draft PR：[#41](https://github.com/imboy-pub/imboy-flutter/pull/41)。用户明确要求本任务所有代码提交到该 PR，已授权发布；没有授权合并。
- 先运行 `git status --short --branch`、`git log -1`、`git worktree list --porcelain`，读 PR 当前 head 与最新 CI。保留其他 worktree 和未提交内容；不用 reset/clean/强推。
- 最初基于 main `9f5d36e5b852f0a3dc20c94a0997fde82d9852d2`。2026-11-05 再次 fetch 的 main 为 `2e06c75ebf9885920d6809d4f4581be103aec49a`。本补丁前的 task head 是 `306ef36da5664129d4b39b773114f4f5359dbb12`；发布后的 head 以 Git/PR 为准。
- 已读 AGENTS/CLAUDE 与测试说明。ios/macOS/plugin 保留区没有修改。并排 imboy `cb95fa72`、imboyadmin `202de6b` 只用于源码合同，不连接服务。
- CLI push 没有凭证；已授权发布使用 GitHub Git database 接口，必须对比创建 tree 与本地 index tree，并用 expected_sha、非 force 更新原分支。同步本地 ref 前核对 parent/tree/无未暂存差异。不寻找额外凭证。

## 当前实现和计数

继续复用 `auto_test.py` / `auto_test_lib`：Git 跟踪发现、唯一主套件、13 profiles、平台/产品/角色/variant 实例、可靠 machine events/result、逐实例证据与最终对账。驱动/聚合/辅助文件显式分类；合法目录新增自动接管，未知/冲突/悬空/无 runner 失败。

- 发现 1,522 个 Dart/Python 源文件；1,420 独立目标，102 辅助等，0 未归属。辅助口径：helper 92、fixture 3、driver 5、aggregate 1、included-test 1。
- 套件：unit 580、widget 292、component 117、sqlite-ffi 129、crypto-ffi 21、backend-contract 45、golden 11、route-smoke 1、device-single 158、device-pair 18、native-ui 2、tooling 46。
- PR：1,180 个目标 / 2,359 个已选实例；Linux 1,179，macOS 1,180。full：1,420 个目标 / 3,284 个实例。13 profiles 均可生成非空计划，PR/coverage 已选 ID 相同。
- CI 从冻结 PR plan 生成 12 个 platform × suite worker；并集 2,359，遗漏/重复均 0。Linux coverage_eligible 为 1,132；覆盖率按实例对账后合并 LCOV，只检查一次原 38% 阈值。
- 唯一新增归属修正：font_contract_test.dart 从 unit/Linux+macOS 改为 component/macOS，声明既有授权字体依赖。全部 5 用例仍在 PR/full macOS 执行；Linux PLATFORM_NA，不删除 Mac 义务。未改字体、Dart 断言、skip 或像素基线。
- 非零退出、零执行、全/部分未批准 skip、缺结果/证据均不通过。覆盖率核验原始进程、收集参数、路径与 SHA256；一个 worker 的 LCOV 不能掩盖另一个 worker 缺结果/未收集。
- Flutter 原生 error 字段现在保留为失败正文，兼容旧 message。聚合 job 失败不会把每个子门禁伪称为失败；具体收据保留，没有独立收据记 missing，实际聚合失败仍阻断最终结果。

## 本轮本地验证（2026-11-05，提交前源码快照）

报告根：`/workspace/scratch/c02895233621/pr-ci-followup/worker-fix-validation/`。报告中的 commit/source_fingerprint 标识被验证的快照，发布后重新冻结计划，不能混用旧结果。

| 验证 | 实际结果 |
|---|---|
| `PYTHONPATH=test/tooling/auto_test python3 -m unittest discover -s test/tooling -p 'test_*.py'` | 651 tests PASS；随后新增聚合门禁回归由下两项覆盖，不累加重复用例 |
| `PYTHONPATH=scripts:test/tooling/auto_test python3 -m unittest test_execution_runner test_execution_entrypoints` | 最终 76 tests PASS |
| `execution-run --profile tooling --platform linux` | 46/46 有收据；44 PASS、2 ENV_MISSING；719 passed / 0 failed / 0 skipped，exit 2 |
| `execution-summary` 对 tooling-final 的实际文件/hash/事件再对账 | 同样 44 PASS、2 BLOCKED；无缺结果 |
| `scripts/check_auto_test_framework.sh --checks-only` | 静态框架/归属/规格/catalog/产品合同 PASS，exit 0 |
| `.github/scripts/validate_ci_test_paths.sh`、13 profiles、matrix/coverage 选择检查 | PASS；清单不是业务执行证明 |
| Python compileall、workflow YAML 接线测试、文件行数门、git diff --check | PASS |

本地两项环境阻塞：`tool/uiux/recovery_contract_test.py`、`tool/uiux/test_lock_contract.py` 需要可靠查询父/子进程启动时间的 ps。当前没有 Flutter/Dart，不能声称本机运行了 Flutter。

关键文件：ownership.json/md、ownership-delta.json、migration.json、profile-checks.json、pr/full-plan.json、host-matrix.json、tooling-final/、tooling-reconciled.json。比较原选择规则：297 newly-selected、883 retained、38 moved-to-specialist、202 specialist-owned；这是范围迁移，不是历史执行证明。

## 已取得的真实 CI 证据

- 第三轮 [42007621614](https://github.com/imboy-pub/imboy-flutter/actions/runs/42007621614)，task head a045b78，实际 merge checkout `de2f298e2bb58376895fc5292d05bbc862697993`，parent 为 main 2e06c75 + task head。
- 该轮 Linux 1,180/1,180 有收据：1,051 PASS / 128 FAIL / 1 BLOCKED，12,456 passed / 2 failed / 2 skipped。只有字体目标产生 2 个真实断言失败；另外 127 个目标因同批非零退出/done=false 不能 PASS。运行器原大批次超时已解除，本轮所有 batch 完成。
- 该轮 macOS 1,180/1,180：1,179 PASS / 1 BLOCKED，12,458 passed / 0 failed / 2 skipped。两个平台各 46 个 tooling 目标 / 723 用例全部 PASS，证明本地 ps 阻塞可在正常 CI 解除。
- Linux 主执行 55 分 48 秒；Mac 也逼近 job 60 分钟上限，最终 job 记录 cancelled，但完整收据已成功上传。最终稳定 summary 实际运行，对账 2,360/2,360、无缺结果，并保持失败。近一小时主要来自真实 Flutter 批次累计；哈希/报告不是主因，因此本轮按 suite 并行，原进程预算/阈值不增加。
- 第五轮 [42010636599](https://github.com/imboy-pub/imboy-flutter/actions/runs/42010636599)，task head 306ef36，实际 merge `bf5adcc51cabebcf2c97ccd772357e4014dc59cf`。质量门全部 PASS：Flutter 3.47.5 / Dart 3.13.4，2792 个文件格式 0 changed，分析 0 error/warning/info，合并后的准备页测试 870 行 <= 原 886 基线。
- 第五轮 macOS 已下载、核验 ZIP SHA 并逐实例重放：1,179 PASS / 1 FTS BLOCKED；12,458 passed / 0 failed / 2 skipped。准备页目标 21/21 PASS，字体合同 5/5 PASS。该证据验证先前 helper 重构，不能代替本轮新矩阵与覆盖率实现的 CI。
- 原始证据：`pr-ci-followup/run3/`、`run5/`；时长/失败归因：`receipt-performance-audit.json`、`run3/linux-failure-and-timing-audit.json`。旧运行记录和失败保留，不通过重试断言洗绿。

## 继续执行的顺序

1. 核对本轮 platform × suite / font / coverage 补丁是否已发布至 PR #41；已发布就继续其最新 run，不重复创建分支、提交或恢复旧计划。
2. 新 CI 完成后下载 plan、各 worker、coverage 和 summary，先核验 archive SHA，再按同一 merge checkout/源指纹对账。检查每个 worker 及字体/准备页目标，确认 coverage 失败原因；不把旧候选收据当新候选验证。
3. 若发现新的编排问题，保留全部实例和业务断言，只修本任务范围并补适当正反向验证，仍提交原 PR。不要为记录进度单独发 docs-only 提交触发重复全跑；更新 PR 描述和仓外状态即可，必要代码提交再带上状态文档。
4. 报告分级：静态、工具、Flutter 子集/全部、后端、设备/双端、full 必须分开。未得到所有适用实例与公共前置的成功证据前，complete_regression 必须为 false。

## 已知未解除条件

- FTS current-schema C2C/C2G 两用例仍 UNEXPECTED_SKIP。dbVersion/注册 inventory 37，v38 仍是 draft；draft 12/12 PASS 不等于当前 schema 验收。不要删用例、改为 draft fixture、加豁免或仅为 CI 注册生产迁移。
- 既定前置见 sibling imboy cb95fa72 的 `docs/design/2026-10-20-channel-group-ux/plan-v2.2.md` 及 app 提交 `1ae24621590ae4b285419731c1f871f71034561d`：时效/远端回退/展示期间到期语义、实际应用连接 recursive_triggers、目标 Web/SQLCipher 二进制隔离验证，然后按迁移流程注册。
- 没有真实后端、设备/双端、Patrol、Golden 像素或完整回归通过证据。使用合成数据、临时数据库和隔离账号，准备要求见 `docs/testing/execution.md`、`specialist-fixtures.md`；不访问生产。
- Golden 缺环境/基线为 ENV_MISSING，不自动生成后声明回归通过。j16c/j28b companion、MC owned context、验收冻结输入/租约仍须真实准备。
- 分支保护选择稳定的 IMBoy Test Summary 仍需维护者设置；保持 Draft，不合并。
