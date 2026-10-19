# CROSS_SESSION_RESUME — T28.m（真实跨会话接续验证）

> 状态：**MANUAL_PENDING**（诚实记账）。
> 本执行现场自 bootstrap（2026-10-19 T00）以来**未发生**真实的执行器
> 会话重启与同提示词接续——同进程内多次 checkpoint/resume 循环不属于
> RC「跨会话」语义（change 明示：同进程调用两次函数不是跨会话）。

## 当前可核对的静态事实（非跨会话证据）

| 项 | 值 |
|---|---|
| repo / common-dir | `/Users/leeyi/project/imboy.pub/imboyapp` / `…/imboyapp/.git` |
| 集成 worktree | `/Users/leeyi/project/imboy.pub/.worktrees/imboy-enterprise-uiux-v1` @ `ux/imboy-enterprise-uiux-v1-integration` |
| base_sha | `c61cd8d46e276496b2ddae8b89b17d6fe6856ddc` |
| HEAD（本记录时） | `04ac6dea4`（T28） |
| state | rev46，`check_state.py` valid=true |
| 下一卡 | T28.m（本卡）→ T29 最终门 |

## 触发条件与流程（未执行部分）

1. 原会话 checkpoint（admission → CHECKPOINTED，确认无活 worker）。
2. 用户/执行器**实际发起新会话**并粘贴同一 EXECUTION_PROMPT 全文。
3. 新会话核对（acceptance_assertions）：
   - before/after session_id **不同**；
   - repo/common-dir/integration/lane 路径与 base_sha **相同**；
   - 未额外新建工作树（`git worktree list` 数量不变）；
   - 未重复提交（HEAD 无意外新增）；
   - next_task 依据持久 state 正确（当前应为 T29）。
4. 两次会话的 checkpoint 证据（session_id、时间、HEAD、state rev）归档本文件。

## 记账

- `check_state.py --plan-id imboy-enterprise-uiux-v1` 已跑且 valid=true
  （C-STATE，见 T28 evidence）——这是状态机健康证据，**不是**跨会话证据。
- 未发生重启期间，本卡不阻塞 T29（卡 dependencies 仅要求 T04.c/T28）；
  真实重启发生时（计划任一安全 checkpoint 后），按上述流程补录本卡并
  翻转 MANUAL_PENDING。
