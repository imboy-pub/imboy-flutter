# V1 → V1.1：不中断原 worktree 的合同迁移

计划ID仍为 `imboy-enterprise-uiux-v1`；仓库内目录仍为 `docs/plans/enterprise-uiux-v1/`。V1.1压缩包名称变更不是重建计划授权。

## 1. 迁移边界

旧T00—T33全部保留ID；新增17个子卡，总计51张：40张必需自动卡（含T29）、9张原生平台卡、1张真实跨会话卡、1张可重复报告卡。原B0—B4仍为5批。迁移只改变执行合同/验证义务，不改变P1/P2/P3产品范围、接口、权限、OA、掩码或数据模型。

本包不含用户本机state；STATE.example仅结构示例。任何复制安装都不得覆盖原registry/state/events/golden/证据。

## 2. 唯一迁移步骤

1. 从真实common-dir定位原registry与worktree，核对plan/repo/base/branch；先使用旧合同的可靠锁停止新派发。活worker存在时只checkpoint，不强行升级它正在消费的合同。
2. 在runtime的recovery/backups保存旧包清单hash、registry/state/events尾部和任务索引。保存未提交文件的路径与hash，不把生产秘密复制到报告。
3. 对比新旧合同，为每张已有执行卡记录 `UNCHANGED / VERIFY_ADDED_OBLIGATION / SPLIT_ADOPT / BLOCKED_CONFLICT`；不以“版本不同”全部置TODO。
4. 保留每个旧任务的commit、worktree、owner、失败指纹、全部attempt、已验自动/人工证据。新增子卡默认TODO；能够证明旧证据完整覆盖的子卡走VERIFY_EXISTING，不再改UI或造空提交。
5. 写MIGRATION_PREPARE意图→原子更新新contract及映射→COMMIT事件。只有两份hash与映射一致后更新registry.active_package。中断按RESUME_PROTOCOL事务规则恢复；不能一半合同一半状态继续派发。
6. 审查受影响证据并复验，随后仍在原集成/P1/P2/P3工作树继续。原prompt已要求读取注册合同的，继续使用也会读取V1.1；推荐此后固定粘贴V1.1 EXECUTION_PROMPT全文，不再按会话改提示词。

## 3. 原卡与新增义务映射

| 旧卡 | V1.1处理 | 已完成时如何采纳 |
|---|---|---|
| T00—T03 | 去掉对T04后置检查器的首次验收依赖；B0报告走独占inbox | 源码调查、基线、创建意图仍有效；补核路径，不重建worktree |
| T04 | 仅冻结路径/命令/能力；新增T04.a scope、T04.b locks、T04.c state事务 | 旧工具若已完整实现，原commit可供子卡逐项复验；不复制第二套工具 |
| T05 | 结构harness与视觉字体拆开；新增T05.a字体环境 | 保留原harness；已有字体hash/许可证据可直接复用，缺证据只阻塞视觉 |
| T06 | 不再依赖视觉字体；仍由协调器独占本地化 | 已生成文案不重复生成，除非输入合同变动 |
| T10—21 | UI目标保持；部分非必要前置移为资源mutex | 原功能提交不重写；补不存在的断言即可 |
| T22—24 | 原卡做结构；各新增.a生成golden、.b审查封存 | 旧312张图与review有hash和环境证明时逐张映射；不得仅因旧状态ACCEPTED批量放行 |
| T25—27 | 调用回归不再等待golden；依赖实际页面实现 | 原trace可按输入证据复验，不能去掉org/version等字段归一化 |
| T28 | 自动演练前移并必须调用实际控制模块；新增T28.m真实跨会话 | 临时Git自动证据与真会话记录分别采纳，不相互替代 |
| T29 | 最终测试绑定K；结果外置，不在测试中写报告 | 旧候选确有完整通过证据时可登记为K；缺完整tree或退出码必须重跑受影响门 |
| T30/31/32 | 原ID保留为各页iOS；各新增.a Android、.b macOS | 旧卡已含三平台真实证据可分别引用同一归档；只有一平台不能推为另外两平台PASS |
| T33 | 报告可在任何成功/失败/阻塞时触发；只依赖T00 | 旧报告保留历史revision；新报告引用K，不改旧结果/原worktree |

## 4. 状态schema迁移

V1的单status保存在`legacy_status`，不丢失。V1.1拆为work_state、verification_state、manual_state、block_reason。ACCEPTED/TESTED等只有关联证据仍匹配时才赋PASS；否则保留实施commit并标STALE或待复验。manual_status、attempts_total和failure_fingerprints逐字保存到迁移附件；细分attempt字段不得以0冒充“历史未尝试”。不确定分类时保留legacy_attempts_total并纳入总体预算。

运行状态中存在本包之外已登记Txx.a/b时，先比对含义与写集合。同ID不同含义不能覆盖；将本包新增义务映射到未冲突的明确子ID，并更新TASKS/COMMANDS/AC/MATRIX的全部引用后进行静态校验。旧ID不更名、旧证据不丢；冲突无法唯一判定为BLOCKED_CONTRACT_MIGRATION。

## 5. 禁止操作

禁止改plan_id、清零attempt、新建随机worktree、删除旧树、自动同步main、重写原提交历史、用模板覆盖state、将旧图更新后当原证据、把外来dirty归给本计划。迁移失败时保留旧合同和状态，可读报告说明阻塞，不猜测修复。


## 6. V1.1 → V1.1 PATHFIX-R1（仅启动路径）

本补丁固定下载源目录并内置到EXECUTION_PROMPT；产品PRD、TASKS/COMMANDS/AC/MATRIX、恢复案例与控制工具源文件不变，计划ID不变。新版发行hash与旧版不同，不能仅因版本号仍为1.1就忽略校验。

没有执行登记时使用完整补丁包首次启动；已经开工时先读取原active_package，活跃协调器/worker未停止就不替换包。到安全checkpoint后，保留旧发行清单和原包、核验补丁差异，按本文件既有锁/备份/事务规则登记此次启动说明修订；不清空state、不改base、不新建worktree。

迁移时逐文件确认核心产品合同字节未变，所有旧commit/attempt/有效输入证据保留；补丁校验记录不能冒充Flutter或真实恢复证据。仍按原输入依赖判断是否复验，不因下载源路径固定而自动废弃所有测试。若本机有效合同已有不同的产品修订/执行overlay，不用本发行包覆盖；先保留原合同并解决差异。

下载目录与active_package可能是同一路径，不能直接覆盖。因此旧包与新包先并存为独立发行候选，待所有者确认安全后才切换登记。具体放置方法见PATH_PATCH.md；不得对本任务任何runtime/state/events/golden执行覆盖。
