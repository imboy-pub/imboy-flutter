# 执行状态快照 — imboy-enterprise-uiux-v1

更新：2026-10-19 B2 收口（P1/P2/P3 实现与验证全绿）｜state revision 30｜状态：ACTIVE（B2 完成；下一批 B3，下一卡 T22）

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
| B3 | T22—T24.b golden / T25—T27 调用回归 | TODO（**下一卡组**；deps 全满足） |
| B4 | T28—T32 恢复演练/最终门 | TODO |

- base：`c61cd8d46`｜集成 HEAD：`285537bb6`｜运行真源 events tx-0001..0030（rev30）
- B2 提交链：…bada01525(T09)→714f4a481(R4)→c3f98c4f9(T10)→aff8b5ad5(T11)→7c3ffd056(T12)→e53e38248(T13)→fa9e833bf(T14)→995527db5(T15)→d11f87f64(T16)→ae6f90d58(T17)→21cb90401(T18)→688a5c8b3(gate)→285537bb6(T19-21)
- ALLOWLIST 修订 2 次（T18/T19-21 补录，均按 TASKS.json write_paths 授权，非扩权）
- 无 BLOCKED；golden 仍未生成（B3 开始）；K 未冻结

## 下一卡与下一条命令

- 卡：**T22**（P1 结构矩阵与无障碍验证；deps T10—T15/T05.a 全 DONE）
- 命令：T22 卡 test_command（见 COMMANDS.json C-T22-*）
