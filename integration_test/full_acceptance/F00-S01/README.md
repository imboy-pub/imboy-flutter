# F00-S01 输入与上游绑定 — 卡说明

> execution-contract 第 4 节行 1：Coordinator 交付「输入/hash/当前三仓HEAD/上游
> UNKNOWN 状态」。验收条件：可立即只读；输入快照和保护路径完整。

## 产物索引

| 文件 | 内容 |
|---|---|
| `input-snapshot.json` | 核心交付：六项哈希绑定（声明 vs 实测）、三仓 HEAD 与脏状态、基线漂移登记、上游 UNKNOWN/handoff 未收固化、全部分母实测、复用目标已知缺陷、共享资源状态、验收核对 |
| `e2ee-protected-paths.tsv` | E2EE 所有权只读候选清单 85 行（imboyapp/lib 54 + imboy/src 31），按名称族分类；F00-S02 以源码调用关系复核，**只能扩充不可缩小** |
| `state.json` | 卡状态：scheduler=DONE、无测试分母、OFFLINE_READY、PREPARATION |
| `WRITER-CLAIM.md` | 写者声明与并行协调记录（主计划并行执行时的双写者防护） |
| `proposed-run-root/` | RUN_ROOT 结构提案副本（公共位置冻结中，未提升） |

## 关键结论

1. **哈希链自洽**：acceptance-set.json 六项绑定（plan / contract / dispatch /
   seed / input-manifest / 上游 plan）全部实测一致。
2. **基线登记**：三仓代码基线 = sampled heads `imboy 33277f7f` /
   `imboyapp 826e1238` / `imboyadmin 997971a1`；imboy 当前 HEAD `c71e18c8`
   相对采样仅追加 docs/plans/ 计划文档 7 文件（DOCS_ONLY_PLAN_FILES），
   不构成代码 SHA_DRIFT。后续卡引用候选须显式注明用的是哪一层。
3. **上游状态固化**：IN_PROGRESS_USER_CONFIRMED / verified_stage=UNKNOWN /
   handoff=REQUIRED_NOT_RECEIVED → ACCEPTANCE 通道不可启动，仅 PREPARATION 合法；
   不得推定任何上游 C 卡 PASS。
4. **分母实测**：1846 种子（F08=374、F04+F05=293 待裁决组）、22 歧义行、
   188 页面候选、catalog pages=188、55 张 dispatch 卡全部 PLANNED、oracle 全部
   TO_BE_DEFINED（不继承历史 PASS）。
5. **已知复用目标缺陷**（移交 F01-S01）：`scripts/auto_test.py:203` 在线 run
   硬编码 `platform='android'`；`:719` capture `--platform` 无 macOS 选项。
6. **共享资源**：上游资源登记 NOT_FOUND（合同 2.2 降级条款生效）+ 主计划并行
   执行告警 → 本卡零资源占用，公共位置冻结，RUN_ROOT 仅提案。

## 边界（本卡不做）

不修改任何仓已跟踪文件；不触碰上游未跟踪目录；不建公共 RUN_ROOT/锁；
不做 F00-S02 分域映射（需派发域 owner）；不修 auto_test.py（F01-S01 职责）。

## git 状态

本目录全部为本卡新增未跟踪文件，位于 imboyapp 仓。**未提交**——是否入库、
以何种粒度入库（建议：F00 产物单独一个 commit）由用户或确认后的 Coordinator
决定。
