# 执行状态快照 — imboy-enterprise-uiux-v1

更新：2026-10-19 会话 checkpoint｜state revision 6｜状态：ACTIVE（T00—T04 完成；下一卡 T04.a）

| 批 | 卡 | 状态 |
|---|---|---|
| B0 | T00—T03 | DONE（PASS）：acceacde / dae918f6 / 4a728ead / e6c26e9f |
| B0 | T04 合同冻结 | DONE（PASS，3f9c2a46）：47 命令零未解析；golden=EXTERNAL_PINNED |
| B0 | T04.a scope 工具 / T04.b locks / T04.c state 工具 | TODO（**下一卡组**，M0 门剩余） |
| B1+ | T05—T32 | TODO |
| B4 | T33 | 可重复报告：rev1（batch_end）+ rev2（本次 checkpoint） |

- base：`c61cd8d46`｜集成 HEAD：`3f9c2a46`（链：acceacde→dae918f6→4a728ead→e6c26e9f→R 450fce96→3f9c2a46）
- 运行真源：`<common-dir>/imboy-uiux/imboy-enterprise-uiux-v1/`（events tx-0001..0006；admission epoch1 ACTIVE）
- 关键判定：P1-01/03/04/05/06、P2-04/05、P3-03 = NEEDS_FIX；其余 VERIFY_EXISTING
- 无 BLOCKED；源仓库 main 干净未动；旧计划 imboyapp-uiux-v1 现场保留未接管。

## 下一卡与下一条命令

- 卡：**T04.a**（实现 `tool/uiux/check_scope.py`：以 ALLOWLIST.json 校验 diff，含正反例自测；随后 T04.b/T04.c）
- 命令（T04.a 验收）：`python3 tool/uiux/check_scope.py --base c61cd8d46e276496b2ddae8b89b17d6fe6856ddc`（在集成 worktree；工具产出后运行并记录退出码）
