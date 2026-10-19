# FINAL REPORT（首轮 / B0 收口）— imboy-enterprise-uiux-v1

报告时间：2026-10-19（checkpoint 更新）｜report_revision：2｜触发事件：checkpoint/暂停（T00—T04 完成后收口）
**候选 K：NOT_VERIFIED**（T29 未执行；本报告不构成任何产品通过等级）

## 1. 计划身份与现场

| 项 | 值 |
|---|---|
| plan_id / 合同 | `imboy-enterprise-uiux-v1` / V1.1 PATHFIX-R1（package_release_hash `b8301b14e9870d10…`） |
| repo / base | `/Users/leeyi/project/imboy.pub/imboyapp`（main）@ `c61cd8d46e276496b2ddae8b89b17d6fe6856ddc`（干净，无外来 dirty） |
| 集成 worktree / 分支 | `/Users/leeyi/project/imboy.pub/.worktrees/imboy-enterprise-uiux-v1` @ `ux/imboy-enterprise-uiux-v1-integration` |
| 当前 HEAD | `3f9c2a46`（T04）；链：acceacde(T00)→dae918f6(T01)→4a728ead(T02)→e6c26e9f(T03)→450fce96(R1)→3f9c2a46(T04) |
| 运行真源 | `<common-dir>/imboy-uiux/imboy-enterprise-uiux-v1/`（registry rev·state revision 4·events tx-0001..0004·admission epoch1 ACTIVE） |
| owner | zcode-cli PID 2525 / session a7661d43…（心跳随事务刷新） |

## 2. 已完成（自动义务）

| 卡 | 提交 | 内容 | 验证 |
|---|---|---|---|
| T00 | `acceacde` | bootstrap：runtime/registry/state/events/admission、集成 worktree、发行包归档+自检（源与归档副本双 exit=0） | C-PACKAGE/C-BOOT-GIT/C-BOOT-WORKTREES exit=0；parent/trailer/tree 核验 |
| T01 | `dae918f6` | P1 inventory：P1-01/03/04/05/06 NEEDS_FIX，P1-02/07 VERIFY_EXISTING，subscriber 0/未知数据边界 | 符号级源码取证（inbox/T01/1） |
| T02 | `4a728ead` | P2 inventory：P2-01/02/03 VERIFY_EXISTING，P2-04/05 NEEDS_FIX（图标槽/空组壳） | 符号级源码取证（inbox/T02/1） |
| T03 | `e6c26e9f` | P3 inventory：P3-01/02/05 VERIFY_EXISTING，P3-03 NEEDS_FIX（source wire 外露/'Web' 硬编码），未读/末条时间确认不在本版 | 符号级源码取证（inbox/T03/1） |

## 3. 待验 / 未运行

- T04—T32 全部 TODO（含 T04.a/b/c 工具、T05—T21 页面实施、T22—24 golden、T25—27 调用回归、T28 恢复演练、T29 最终门）。
- 312 golden：未生成（0/312）；原生 51 场景：MANUAL_PENDING；T28.m 跨会话：未发生（不能自称 verified）。
- 全量 Flutter analyze/test：NOT_RUN（M0 门尚缺 T04）。

## 4. 阻塞与风险

- 无当前 BLOCKED。已知待决点（非阻塞）：P1 重复标题根因在 ChannelHeaderBar；P2 空组壳需 T13 可见性投影方案；P3 来源映射需新 i18n 键。
- 旧计划 `imboyapp-uiux-v1`（已 COMPLETE、锁 RELEASED）目录/注册表保留原样，未接管。

## 5. 下一步

T04 已完成（3f9c2a46：47 命令零未解析、EXTERNAL_PINNED、白名单冻结）。下一卡：**T04.a** scope 工具（tool/uiux/check_scope.py + 正反例自测），随后 T04.b locks、T04.c state 事务工具。
下一条命令：实现 check_scope.py 后在集成树运行 `python3 tool/uiux/check_scope.py --base c61cd8d46…` 并保存退出码证据。

## 6. 幂等与边界

- 本报告由 batch_end 事件触发一次；report_input_hash 已随 revision 1 登记，未变不重复提交。
- 本提交 R 仅改动 REPORT_ONLY_ALLOWLIST 内路径（STATUS.md/FINAL_REPORT.md/ACCEPTANCE_RESULTS.*）；K 未冻结，R 不引用任何"已全量验证"结论。

## 7. revision 2 附记

T04 完成于 revision 2 前（tx-0006）；命令冻结要点：FLUTTER_EXE 直连 wrapper（无 FVM）、i18n=dart run slang（10 locale）、golden=EXTERNAL_PINNED（.gitignore test/**/goldens/ 既有策略）。M0 门剩余 T04.a/b/c。
