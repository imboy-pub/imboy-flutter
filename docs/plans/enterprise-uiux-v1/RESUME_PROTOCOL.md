# 同一提示词恢复原 worktree：V1.1 执行合同

版本1.1｜计划ID：`imboy-enterprise-uiux-v1`（不变）｜仅本机持久状态恢复，不承诺会话永不终止。

## 1. 不变项与适用条件

参考入口仍为 `/Users/leeyi/project/imboy.pub/imboyapp`。真实repo、remote、pubspec、common-dir与已登记worktree才是身份依据；目录名、会话标题、main当前SHA都不能替代。原worktree/分支/登记/证据必须仍可访问。源码、后端、数据库、原生设备权限沿用PRD；没有本地工具权限的网页会话不能执行本协议。

本协议是执行器要遵守的工程合同。包内静态校验器不负责操作用户Git，也不证明T04运行工具已经实现。T04.a/b/c在本机复用/补齐最小设施并测试；T28必须调用这些实际模块，不另造一个只会给出预期答案的模拟器。

### 1.1 启动路径补丁PATHFIX-R1

| 路径身份 | 固定/动态来源 | 允许用途 |
|---|---|---|
| 下载文档源 | `/Users/leeyi/project/imboy.pub/_task_packages/IMBoy_Enterprise_UIUX_V1_1` | 首次校验、归档、受控迁移输入；不是执行目录 |
| 源仓库发现入口 | `/Users/leeyi/project/imboy.pub/imboyapp` | 只读核验仓库、定位真实common-dir；不是直接修改main授权 |
| 生效合同 | `registry.active_package`记录的真实路径与hash | 已开工后优先读取；路径补丁不自动改登记 |
| 集成及页面worktree | 原registry与Git清单交叉确认 | 在原工作树继续；不由下载文档目录推导 |
| 运行状态 | `<真实 git-common-dir>/imboy-uiux/imboy-enterprise-uiux-v1/` | state、事务、证据的运行真源 |

首次没有旧登记时，校验下载文档源，再按本协议建立工作树并将发行文件归档到集成worktree的`docs/plans/enterprise-uiux-v1/`；登记生效路径与hash。已有登记优先恢复，下载源缺失但生效合同有效时不阻塞恢复；两处均不可用则BLOCKED_PACKAGE_LOCATION，不猜目录重建。

本补丁只补启动定位规则。发行hash变化仍要留迁移记录，不按“只是文案”跳过完整性核验；产品任务/测试义务未变化且输入hash仍匹配时，保留已有有效证据，不重做页面。不得用整目录复制覆盖`execution/`或任何runtime文件。

## 2. 三种身份，不得混为一个hash

| 身份 | 定义 | 更新规则 |
|---|---|---|
| plan_id | 固定为imboy-enterprise-uiux-v1 | 续跑和文档升级均不变 |
| package_release_hash | 本包SHA256SUMS文件的SHA-256；SHA256SUMS不含自身/包外文件 | 仅安装新包或明确计划修订时更新；执行报告变化不改变发布包身份 |
| contract_revision_hash | TASKS/COMMANDS/MATRIX/PRD等有效执行合同的清单hash | 修改任务或义务时递增contract_revision并迁移；不得覆盖旧证据 |

发行包归档到 `docs/plans/enterprise-uiux-v1/`；可变执行报告放其 `execution/`。运行中的state、日志、golden与原始证据放Git公共目录。`SHA256SUMS`只校验发行包，不用“整个目录含运行报告”的hash作为每次恢复的版本判断，避免每写一次STATUS就触发迁移。

## 3. 持久位置与唯一真源

```text
<真实 git-common-dir>/imboy-uiux/imboy-enterprise-uiux-v1/
  registry.json                 固定repo/分支/worktree/active_package映射
  state.json                    任务状态快照、revision、last_txid
  events.jsonl                  PREPARE/COMMIT事件；只追加
  locks/state.guard             本机短事务OS锁文件，禁止删后重建
  admission/coordinator.json    活跃协调器根进程身份
  admission/lanes/P1.json       P1/P2/P3独占admission
  intents/                      worktree创建、提交集成、版本迁移意图
  inbox/<task>/<attempt>/       B0并行调查或worker结果的独占邮箱
  evidence/<task>/<attempt>/    argv/日志/退出码/输入hash
  golden/pN/candidates/         未封存候选图，不覆盖旧baseline
  golden/pN/sealed/<hash>/      不可变工程基线与manifest
  candidate_seal.json           最终已验证候选K
  reports/                      即使失败也可生成的报告
  recovery/backups/             状态/事务原始快照，不是第二个活跃真源
```

`@runtime/`在TASKS.json中只代表上述公共目录；`@package/`代表发行包目录。它们不是生产源码路径通配授权。linked worktree的`.git`可能是文件；用真实Git命令解析common-dir后规范化为绝对路径。Git工作树清单用NUL格式解析，路径含空格也不得拆坏。来源仓库只读检查使用 `GIT_OPTIONAL_LOCKS=0`，不能把“不改业务文件”混同于允许随意改其index。

registry至少包含：schema_version、plan_id、active_package路径及hash、contract_revision、repo_realpath、remote脱敏身份、git_common_dir、source_branch、base_sha、source_dirty_snapshot、integration路径/branch、lane路径/branch、所有创建意图、last_integrated_sha。state模板永不覆盖live文件。

## 4. 首次启动与B0并行

1. 读取适用AGENTS/CLAUDE与现有协调规则；运行包静态检查。只读核对Git根、worktree清单、源HEAD、remote与脏文件hash。SDK版本命令可能访问共享缓存：未取得相应资源使用权时，先记录SDK路径和现有版本文件，不为了取版本抢占缓存。
2. 先找本plan旧registry，再查创建意图、Git worktree清单、分支trailer和文档。只有唯一身份能恢复；多候选不按时间或路径排序猜一个。
3. 基线首次取核实的本机已提交HEAD。与本计划重叠的外来dirty修改保持原样，阻塞相关改动，不自动stash、复制、提交或丢弃。远端漂移可记录，非必要不fetch，更不自动pull/rebase。
4. 真正首次先取得已有可靠协调锁；若没有，仅用本机可用OS排他锁及进程身份建立最小bootstrap admission。T00—T03不调用尚未产生的T04工具。创建前写意图并落盘；创建后登记路径/分支/HEAD。建议集成路径`<repo父目录>/.worktrees/imboyapp-uiux-v1`；冲突先查旧资源，不随机加后缀绕过。
5. T01/T02/T03可并行**只读代码**，各写自己的inbox。它们不同时操作集成worktree的index/状态/文档；协调器逐份接收并各自提交。故不需要在B1前提前创建三个写lane。
6. T04冻结路径/资源/命令。T04.a、b、c分别实现范围、锁、状态薄层并测试。检查器形成后回查bootstrap记录；这不是T01/T02/T03完成前置，消除循环依赖。
7. T05结构harness与T06文案稳定，且guards可用后，只创建一次P1/P2/P3 lane，登记共同基础commit。T05.a缺视觉字体时仍可创建lane做实现/非视觉回归；不得宣称视觉通过。单代理时同样复用这些登记或既有单工作树串行模式，不为换执行器重开候选。

## 5. 写互斥与旧owner隔离

Git `worktree lock`防prune/move/remove，不是写互斥。每个worktree有自己的HEAD/index，但共同Git数据仍共享。[Git官方文档](https://git-scm.com/docs/git-worktree)

**短事务锁**保护“读取owner/revision→验证→写入状态/登记”。采用同机可靠OS排他锁；固定锁文件不删除重建，避免两个进程锁住不同inode。**admission记录**保护长任务期间的lane所有权。两者不能互相替代。

owner身份包含host、boot/process-start标识、根CLI PID、session_id、epoch；PID存在不能单独证明是原进程。每次写state、提交集成、发任务、释放admission时都在短事务锁内校验当前epoch和owner。仅在锁外检查一次fencing token不算防陈旧写者。

| 情况 | 处理 |
|---|---|
| 原根进程仍活跃 | 第二协调器只读状态并退出为ALREADY_RUNNING，不派发第二worker |
| heartbeat超时但进程可验证活跃 | 不接管；超时只是提示 |
| 原根进程已死但worker/测试子进程仍活跃 | 不写该lane；确认/接收已有结果或局部等待；不擅自kill |
| PID被复用、root CLI无法识别、只有短命tool-shell PID | 不能声明可靠旧owner死亡；歧义恢复BLOCKED_LOCK_IDENTITY |
| 同机确认owner及相关写进程均退出 | OS锁内递增epoch，登记接管；旧epoch后续写/释放均拒绝 |
| 异机共享盘/无法核验另一host | 不自动抢锁；不声称本机协议支持分布式互斥 |

锁等待属于资源未就绪，不消耗代码修复attempt；不反复高频轮询。没有可安全接管的任务就checkpoint并报告。默认重型Flutter命令全计划最多1个，代码仍可三lane并行。resource锁key按实际SDK路径、设备ID、端口生成，不按“本计划名称”生成假隔离；其他计划不遵守本锁时不宣称已隔离，优先接入现场共同协议。未获设备归属就不使用。

## 6. 状态事务与崩溃恢复顺序

在短事务锁内，对单个变更分配`txid`、`revision=n+1`、`previous_snapshot_hash`、`next_snapshot_hash`、owner epoch：

1. 追加PREPARE事件并flush/fsync；保存下一个snapshot的完整内容或已落盘位置。
2. 写同目录临时snapshot，flush/fsync，再原子rename为state.json；支持时fsync父目录。
3. 追加COMMIT(txid,revision,next_hash)并flush/fsync。释放短事务锁。

恢复严格按事务号和hash，不按mtime：

| 中断位置 | 唯一允许处理 |
|---|---|
| PREPARE不存在 | 无状态变更；Git等外部效果另按intents核对 |
| PREPARE存在，snapshot仍旧 | 该状态未提交；验证外部Git效果后决定补记或终止事务，不直接变PASS |
| snapshot为next_hash，COMMIT缺失 | 核验next及Git/证据；补一个COMMIT，不重做外部操作 |
| COMMIT存在且snapshot匹配 | 已提交，幂等采纳 |
| JSONL最后一行半写 | 备份尾部，忽略未完成行；只有末尾损坏可这样处理，中段损坏BLOCKED_STATE_CORRUPTION |
| hash/revision链冲突或COMMIT超前 | 备份、停止写入并报告，不“选最新文件” |

Git提交/cherry-pick不是state事务的一部分：先写外部操作意图，执行Git后按trailer+父提交+patch/tree核对，再记账。提交存在但state未更新不得重新实现；集成提交已存在不得重复cherry-pick。只有trailer相同而diff不同，不自动认为等价。

## 7. 每卡提交与集成

任务状态按 `templates/STATE.example.json` 的维度记录：work_state、verification_state、manual_state、block_reason，不能以一个DONE覆盖一切。`execution attempt`、`verification attempt`、`environment probe`和`resource wait`分开累计；新会话不得清零。

开始卡片前登记输入SHA、写集合与owner；测试前保存完整待提交tree或规范化内容清单，含index/worktree与本卡未跟踪输入。日志写runtime，禁止把当前提交hash写回本提交从而形成自引用。

测试成功后若文件又变化，证据STALE；提交时精确暂存本卡文件，并确认提交tree与测试输入一致。Conventional Commit附：

```text
UIUX-Plan: imboy-enterprise-uiux-v1
UIUX-Task: Txx（或登记的Txx.a）
```

协调器串行集成并记录source→integration SHA。子worker只提交自己lane与inbox，不更新总state。共享i18n/support变动需要先停相应写者，形成独立协调提交，再同步到原lane；不rebase公共main，不把整个新集成树随意混进未提交lane。集成冲突属于当前卡失败/阻塞，不静默复制文件绕过Git历史。

## 8. 最终候选K与报告R，防止验收自循环

T29开始：集成树无未提交代码，已纳入全部实现/测试/封存manifest，冻结 `K=candidate_sha` 与 `K_tree`。所有最终门都针对K；执行前后tree相同，日志与结论写外置runtime。任一源/测试/配置/环境变化使对应门失效；不在测试运行过程中提交STATUS。

门结束后T33可以提交报告R：R的祖先包含K，差异只能落在本计划明确的REPORT_ONLY_ALLOWLIST，且只写报告数据，不改任何测试、源码、配置、字体、golden、执行工具或验收规则。证书清楚写“已全量验证K；R为报告附件提交”。不说R已经完整跑过Flutter。若交付要求必须验证HEAD=R，则显式新开候选验证，不声称能豁免。

报告字段不需要包含自身R SHA；它引用K，实际R由外置state记录，消除hash自引用。报告diff单独校验。改变PRD/TASKS、测试清单或模板不是report-only；需要版本迁移与影响复验。

## 9. 局部失败、预算与可执行调度

同lane单写，mutex不是业务依赖。调度优先已开始可恢复卡→已满足真实前置的READY卡。T13/T14不因T12颜色阻塞而停工；T25—27调用回归不因golden字体缺失停工；T28恢复测试可在页面完成前运行。

单卡实施最多3个累计attempt；同失败指纹在无新证据情况下最多重试2次；环境探测最多2次；超过0.5人日实施规模先拆已登记子卡。失败指纹包含测试ID、失败类型、输入/环境版本；修复重跑不是换名字清零。只有环境确实变化或新增可核验证据才能新增budget_epoch，并保留旧累计。

范围内缺陷必须修复/回归；范围外失败写defects，不能改接口/数据库/域逻辑以追求全绿。可以完成其他范围内任务，但只要最终必需门仍失败就PARTIAL_BLOCKED。历史全量失败可以记录“实现卡已完成”，不能改为LOCAL_CANDIDATE_PASS。

T33是可重复报告操作，T00以后随时可执行；暂停、资源阻塞、无READY卡、任一批结束都允许报告。**不依赖T29通过。** `REPORT_WRITTEN`不等于任何产品通过等级。

## 10. 原现场恢复分支

| 现场 | 操作 |
|---|---|
| RUNNING且有本卡dirty | 校验owner/范围/hash后继续；不reset/clean/stash |
| 已commit未记账 | 读取Git与trailer/父提交/diff/测试证据，采纳一次 |
| 测试只有passed输出，无真实exitcode | 标INCOMPLETE；旧测试进程退出后重跑最小集合 |
| origin/main前进 | 保留原base与worktree，记录未来集成风险 |
| worktree移动 | 用Git清单/登记/身份唯一核对；repair或路径迁移仅在确认安全后登记；确实丢失BLOCKED_RECOVERY |
| 本包升级 | 按MIGRATION.md迁移contract，不覆盖state，不重编号原卡 |
| 缺/损坏sealed golden | 只从登记的hash归档恢复；恢复失败阻塞视觉门，不update、不skip |
| 新增未知文件/他人修改 | 阻塞对应lane，保留原内容，其他lane可继续 |
| 多会话同时启动同提示词 | 一个可获得admission；另一个只读ALREADY_RUNNING，不增加worktree |

## 11. 恢复演练与结果名称

T28在临时Git夹具使用实际T04模块，覆盖RECOVERY_CASES.json；通过只能写 `RECOVERY_PROTOCOL_TEST_PASS`。T28.m在真实执行器两个不同会话完成后，才能写 `CROSS_SESSION_RESUME_VERIFIED`。模拟两个函数调用、两次同进程运行、临时Git测试均不能替代真实会话。

`LOCAL_CANDIDATE_PASS`不要求已完成T28.m或真机卡；`UX_ACCEPTED`要求九张平台卡；跨会话状态始终独立显示。若T28.m实际失败且揭示安全/正确性缺陷，创建缺陷并使受影响自动恢复证据失效，不能用“人工非必需”忽略真实失败。

## 12. 每次结束必须保留

计划/合同版本、K与当前HEAD、原集成和lane绝对路径、base、owner/admission、任务状态、累计预算、最后命令/退出码/证据路径、未完成/阻塞、下一卡与下一条命令。安全退出只能释放自己epoch且无活跃写worker的admission；未确认者保留并记录。不得push、merge main、部署、删除worktree或声称会话结束后仍在后台执行。

### 运行目录与GUI宿主补充

运行目录采用仅当前用户可写的权限；注册/状态写入拒绝逃逸路径与不明符号链接，日志不得保存生产Token或客户原文。GUI执行器根进程可能长期存在，不能仅凭GUI PID存活判断旧会话仍在执行：优先用可验证的宿主session/运行状态适配器。宿主没有该能力且旧admission未正常释放时，安全结果是BLOCKED_LOCK_IDENTITY，不谎称可以无条件自动抢锁。正常checkpoint会保存可恢复状态并安全释放已停止的会话admission。

### 发行合同与本机解析/拆卡

发行包的TASKS.json及其生成Markdown是原始结构真源，SHA256SUMS只覆盖发行文件，不包含execution/。本机路径解析、未冲突子ID映射与合法拆卡写execution/TASKS.resolved.json和追加overlay，记录parent_release_hash、contract_revision和差异；check_state验证其有效DAG。拆卡时父卡变为聚合义务，只有所有子卡覆盖并满足原验收才满足父卡，禁止父子重复计数、丢失AC或清零旧预算。不可通过overlay放宽产品要求、删除必需golden或增加业务写权限。包内plan_audit只验证固定51卡发行合同；运行中的扩展合同由T04检查器与RC22案例验证，不能修改发行检查器的期望数来伪造运行通过。

### 完整状态词表与报告幂等

状态词表以templates/STATE.schema.json为准：work_state=`TODO/READY/RUNNING/IMPLEMENTED/COMMITTED/INTEGRATED/DONE/BLOCKED/SUPERSEDED_AGGREGATE/REVERTED`；verification_state=`NOT_RUN/RUNNING/PASS/FAIL/STALE/INCOMPLETE/BLOCKED`；manual_state=`NOT_APPLICABLE/MANUAL_PENDING/PASS/FAIL`。VERIFY_EXISTING是implementation_mode，不与验证结果混用。BLOCKED_OWNER等作为block_reason。schema只校验结构，Git/证据/所有权仍须运行检查器实证。

自动卡DONE必须有集成事实、当前输入验证PASS及所需证据；人工卡DONE必须manual=PASS且有真实记录；聚合父卡不重复计完成数。T33的DONE仅属于该次报告事件，不改变产品等级。

T33从默认READY轮询队列中排除，只在batch_end、block_change、checkpoint、manual_evidence_change、final事件触发。以非报告任务状态/当前代码候选/新证据/真实阻塞组成report_input_hash，同hash已汇报则幂等返回，不新写commit。report_revision、heartbeat、报告R的SHA、REPORT_WRITTEN事件不作为触发输入；写报告不能触发自己，避免全部阻塞后无限报告。
