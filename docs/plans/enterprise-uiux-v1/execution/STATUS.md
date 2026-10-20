# 执行状态快照 — imboy-enterprise-uiux-v1

更新：2026-10-20 B4 收口（FULL_PASS 封存，交付候选汇总）｜state revision 60｜状态：CHECKPOINTED（51/51 卡 DONE；候选 K=d397d38c8；10 张 manual 性质卡验收待所有者）

| 批 | 卡 | 状态 |
|---|---|---|
| B0 | T00—T04.a/b/c 工具链 | DONE（PASS）：acceacde→1cee8eb3 |
| B0 | M0 基线 | DONE：analyze exit=1 / 72 存量（evidence/M0/1） |
| B1 | T05/T05.a/T06/T07/T08/T09 | DONE（PASS）：bd91a79dd / ff9ba066a / 47f02e3b3 / 5ef5366a3 / f529ddeb6 / bada01525 |
| B2 | T10 频道身份头部 | DONE（PASS，c3f98c4f9）：C-T10-1 4/4；P1-01 修复；回归 11/11+LEGACY |
| B2 | T11 统计非加载占位 | DONE（PASS，aff8b5ad5）：C-T11-1 5/5；P1-02 VERIFY_EXISTING 仅补测试 |
| B2 | T12 动作可用状态 | DONE（PASS，7c3ffd056）：C-T12-1 5/5；P1-04 空函数回退消除；对比度/命中/语义断言 |
| B2 | T13 讨论横幅方向指示 | DONE（PASS，e53e38248）：C-T13-1 4/4；P1-05 单 chevron；en deferred 经 runAsync |
| B2 | T14 折叠高级筛选 | DONE（PASS，fa9e833bf）：C-T14-1 5/5；P1-06 默认折叠；真门开（scope/manifest 测试接线） |
| B2 | T15 错误空态两段 | DONE（PASS，995527db5）：C-T15-1 5/5；P1-03/P1-07；回归 p1 39/39+LEGACY 300 |
| B2 | T16 工作台分组容器 | DONE（PASS，d11f87f64）：C-T16-1 5/5；P2-05 空壳消除（自然收缩） |
| B2 | T17 办公删除复验 | DONE（PASS，ae6f90d58）：C-T17-1 5/5；P2-02/03 VERIFY_EXISTING 仅补测试；webview fake |
| B2 | T18 资源入口对齐 | DONE（PASS，21cb90401）：C-T18-1 4/4；P2-04 24 槽/≥48 命中；ALLOWLIST 补录（T18 write_paths 授权） |
| B2 | T19/T20/T21 坐席行重构 | DONE（PASS，285537bb6 原子提交）：row_structure/preview/source_label 各 5/5；P3-04/P3-03；来源映射 widget→网页、未知/空→未知 |
| B2 | gate 修复（T04.a 追加） | DONE（PASS，688a5c8b3）：声明正则缩进回溯缺陷 + 双坐标语义；自测 6/6（含新回归用例） |
| B3 | T22 结构矩阵 | DONE（PASS，12255b9fe）：C-T22-1 4/4；16/16 配置 executed 0 skip；P1_MATRIX.md |
| B3 | T22.a P1 候选 golden | DONE（PASS，f9d83090b）：120 张生成+manifest；比较模式幂等 |
| B3 | T22.b 封存审查 | DONE（PASS，eb419705c）：零 diff 120/120；SELF_REVIEW_ONLY 诚实标注 |
| B3 | T23 矩阵 | DONE（PASS，da2db0f68）：C-T23-1 5/5；16/16；P2_MATRIX.md |
| B3 | T23.a/b P2 golden | DONE（PASS，86ccbdec7）：72 张候选+封存+零 diff；SELF_REVIEW_ONLY |
| B3 | T24 矩阵 | DONE（PASS，a879c3474）：C-T24-1 3/3；120/120；P3_MATRIX.md |
| B3 | T24.a/b P3 golden | DONE（PASS，86ccbdec7）：120 张候选+封存+零 diff |
| B3 | T25/T26/T27 行为回归 | DONE（PASS，1517c2b2f）：各 3/3 + LEGACY 45/46/62 pass；P*_REGRESSION.md |
| B4 | T28 恢复演练 | DONE（PASS，04ac6dea4）：recovery_contract_test 25/25（真实 plan_lock/plan_state/check_scope 注入 RC01—RC24） |
| B4 | T28.m 跨会话 | DONE 记账（cf6c36858）：MANUAL_PENDING（未发生真实重启，触发条件已备） |
| B4 | T29 最终门 | DONE（PASS，17696aa5/9412e5134）：七门对 K；首轮 PARTIAL_BLOCKED→根因修复（vodozemac 原生库路径）→**FULL_PASS，candidate_seal 写入**（C-FULL 10830/10830） |
| B4 | T30—T32.b 原生验收 ×9 | DONE 记账（27807b978）：MANUAL_PENDING×9（无真机/桌面目标与人工操作者；输入就绪清单见各 P*_MANUAL_*.md） |
| B4 | T33 交付候选 | DONE（PASS，6fd36c488/759e98366）：R7 汇总 + R8 FULL_PASS 更正；候选 K=d397d38c8 |

- base：`c61cd8d46`｜集成 HEAD：`543e4256` 后续（T30.a 真机执行 + 收尾增补，见 FINAL_REPORT rev9）｜运行真源 events 至 tx-0083（rev83）｜封存候选 K=d397d38c8 不变
- 2026-10-20 增补：T30.a 真机执行 PASS（6+1PARTIAL）；T31.a/T32.a 探测后维持 MANUAL_PENDING；T28.m 仍需真实跨会话；manual 余 8
- 2026-10-20 增补 2：golden 覆盖修正落地（P2 scene 轴修复 + CJK 字形）——新候选 K=95dc3cddf 重封存，唯一图 80/312；详见 GOLDEN_COVERAGE_CORRECTION.md
- B2 提交链：…bada01525(T09)→714f4a481(R4)→c3f98c4f9(T10)→aff8b5ad5(T11)→7c3ffd056(T12)→e53e38248(T13)→fa9e833bf(T14)→995527db5(T15)→d11f87f64(T16)→ae6f90d58(T17)→21cb90401(T18)→688a5c8b3(gate)→285537bb6(T19-21)
- ALLOWLIST 修订 2 次（T18/T19-21 补录，均按 TASKS.json write_paths 授权，非扩权）
- 无 BLOCKED；golden 仍未生成（B3 开始）；K 未冻结

## 下一卡与下一条命令

- 计划内自动任务全部完成。剩余为所有者人工义务：
  1. T28.m——真实新会话粘贴同一 EXECUTION_PROMPT 的接续验证（流程：CROSS_SESSION_RESUME.md）；
  2. T30—T32.b——三 lane × iOS/Android/macOS 原生逐 case 验收（就绪清单：各 P*_MANUAL_*.md；候选 K=d397d38c8）。
- 复跑命令（如需）：`python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1`

## 合并后收口（2026-10-20 追记）

- 集成分支已合并 main（merge commit 32dd2e919，--no-ff，零冲突；任务分支
  ux/imboy-enterprise-uiux-v1-integration 与 worktree、runtime truth 已清理；
  golden 基线 312 张迁至主工作树 test/uiux/golden/goldens/ 并 312/312 复核）。
- 本计划零数据库迁移/Schema 变化（SQLite schema v21 不变，后端仓零提交）。
- 多 agent 收口：P1/P3 scene 轴修复（唯一图 P1 24→64、P3 24→48）、图标
  tofu 根因修复（family 前缀名 + Directionality，见
  GOLDEN_COVERAGE_CORRECTION.md「合并后收口」）、工作台行对齐回归修复
  （用户验收反馈，客服行 contentPadding 对齐 Cupertino _kPadding 20/14）。
  收口后唯一图合计 144/312。
- macOS debug 构建可行性实证通过（flutter build macos --debug 一次成功，
  flutter_vodozemac.framework 注入成功）——三张 P*_MANUAL_macos 卡的构建
  前置已就绪。
- 更正：2026-10-20 增补所记「manual 余 8」为算术笔误，实为 **9**
  （T28.m、T30/T30.b、T31/T31.a/T31.b、T32/T32.a/T32.b，与枚举一致）。
- 复跑命令（如需）：`python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1`
  （runtime truth 已随收尾清理删除，该命令不再适用；状态账本以本目录
  文档与 git 历史为准。）
