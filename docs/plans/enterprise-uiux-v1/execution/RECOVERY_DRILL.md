# RECOVERY_DRILL — T28（临时仓库/副本注入，真实 runtime 只读）

| 案例 | 结果 | 说明 |
|---|---|---|
| RC09 | PASS | ALREADY_RUNNING 只读 |
| RC10 | PASS | 拒绝 PID 复用凭证 |
| RC11 | PASS | 不以时间抢锁 |
| RC13 | PASS | BLOCKED_LOCK_IDENTITY |
| RC14 | PASS | 拒绝陈旧释放 |
| RC12 | PASS | 拒绝同 lane 第二写者，不 kill |
| RC15 | PASS | 悬空 PREPARE 不被采纳（load 走快照链） |
| RC16 | PASS | COMMIT 已落，读回一致 |
| RC17 | PASS | 尾部撕裂隔离，读取成功 |
| RC17b | PASS | 中段损坏阻塞（fail-closed） |
| RC22 | PASS | accepted/attempts 保留 |
| RC07 | PASS | git 缺提交 → BLOCKED_RECOVERY（state 不被改 PASS） |
| RC03 | PASS | exit=0 dirty 保留不 reset |
| RC04 | PASS | exit=1 外来 dirty → BLOCKED |
| RC21 | PASS | 记录 main 漂移；base 仍指原 SHA，不 rebase |
| RC24 | PASS | 路径丢失 → BLOCKED（不伪造恢复） |
| RC01 | PASS | worktree 路径不变；最早可恢复卡=['T28'] |
| RC02 | PASS | 采纳已创建树一次，不新增随机后缀树 |
| RC05 | PASS | trailer/parent 验证通过，head=b73fcb57a |
| RC06 | PASS | 登记已有映射（无重复 cherry-pick） |
| RC08 | PASS | 无退出码 → INCOMPLETE（不得当 PASS） |
| RC18 | PASS | 输入变化 → STALE 可表达 |
| RC19 | PASS | report-only 白名单=['ACCEPTANCE_RESULTS.json', 'ACCEPTANCE_RESULTS.md', 'FINAL_REPORT.md', 'STATUS.md']；R 不获 K 冻结效力 |
| RC20 | PASS | 缺图失败→candidates 归档恢复（不 skip/update） |
| RC23 | PASS | 成功写阻塞报告，等级如实 |

## 现场核对

- 真实 worktree 列表未变化（RC01/RC02 断言于副本/计数）
- 真实 state events 行数不变（副本注入）
- 真实跨会话恢复（T28.m）：**MANUAL_PENDING**（未发生重启）

