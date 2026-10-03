# 进度账本（四分母）— 2026-10-03T05:0xZ 快照

> execution-contract 第 7 节：进度同时报四个分母，1846 旧行、61 宏观 ID 和
> dispatch 卡数分别列，禁止互相替代完成率。
> Coordinator 汇总产物，暂挂 F00-S01 名下（RUN_ROOT 公共位置冻结中，解冻后迁移）。

## 四分母

| 分母 | 分子/分母 | 说明 |
|---|---|---|
| 1. 输入已映射 / 总输入 | **草案 1846/1846；owner 确认 0/1846** | 子卡级映射草案完成（HIGH 801/MEDIUM 644/LOW 401）；owner patch 确认 0，草案不算闭合 |
| 2. 用例已具备 / 冻结 required 格子 | **0 / 未冻结（分母未知）** | required 主键 `(case_id,platform,profile,role_variant)` 依赖 product-profiles 定稿（4 项产品决策待定）+ owner 确认归属 |
| 3. 预验通过 / required 格子 | **0 / 未冻结** | 未运行任何测试 |
| 4. FINAL 证据通过 / required 格子 | **0 / 未冻结** | ACCEPTANCE 通道未启动（上游 handoff 未收） |

## 三个独立计数（不可互替）

- **1846 旧种子行**：全部有子卡归属草案；22 歧义行清单已出待裁决；24 页面缺口待 NEW 编号。
- **61 宏观 Acceptance ID**：0 个 PASS（全部 PLANNED；能力面 F00-S01/S02、F15-S01/S02 有静态产出，但不等于任何 A 卡 PASS）。
- **dispatch 卡 55 张**：DONE（产物完成）5 张 = F00-S01、F00-S02（草案性质）、F15-S01、F15-S02（静态设计，运行时 BLOCKED_ENV）+ 本汇总挂靠 F00-S01；其余 50 张 PLANNED/WAITING。

## 五卡产物状态

| 卡 | scheduler | 性质 | 关键待办 |
|---|---|---|---|
| F00-S01 | DONE | 正式 | 无（移交 Coordinator 确认后即闭环） |
| F00-S02 | DONE | 草案 | owner patch 确认 1846 行 + 4 项产品决策 |
| F15-S01 | DONE | 正式静态 | 无 |
| F15-S02 | DONE | 静态设计 | 运行时验证（BLOCKED_ENV：后端+夹具+租约） |

## 外部输入阻塞清单（不自动轮询，execution-contract 第 5 节）

1. 域 owner 派发（实名+替补）——解锁 F00-S02 闭合与各域 case-map。
2. 产品决策 4 项——解锁 product-profiles.json 定稿与 required 分母冻结。
3. 并行执行者身份确认——解锁 RUN_ROOT 提升与公共位置解冻。
4. 上游 E2EE handoff——解锁 ACCEPTANCE 通道（当前 verified_stage=UNKNOWN）。
5. 设备/后端资源租约——解锁 F01-S03/S04、F15-S02 运行时。
