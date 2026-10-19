# 执行状态快照 — imboy-enterprise-uiux-v1

更新：2026-10-19 B0 收口（M0 门关闭）｜state revision 10｜状态：ACTIVE（B0 完成；下一批 B1，下一卡 T05）

| 批 | 卡 | 状态 |
|---|---|---|
| B0 | T00—T03 | DONE（PASS）：acceacde / dae918f6 / 4a728ead / e6c26e9f |
| B0 | T04 合同冻结 | DONE（PASS，3f9c2a46） |
| B0 | T04.a scope 门 | DONE（PASS，233bfa2d）：自测 5/5 + 真实树 PASS |
| B0 | T04.b 进程锁 | DONE（PASS，bbb53562）：自测 7/7（跨进程实弹） |
| B0 | T04.c 状态事务 | DONE（PASS，1cee8eb3）：自测 7/7 + 真实 runtime valid rev10 |
| B0 | M0 基线 | DONE：analyze exit=1 / 72 存量问题（改动前，evidence/M0/1） |
| B1 | T05 结构harness / T05.a 字体环境 / T06 文案 | TODO（**下一卡组**） |
| B1+ | T07—T32 | TODO |

- base：`c61cd8d46`｜集成 HEAD：`1cee8eb3`｜运行真源 events tx-0001..0010（rev10）
- 环境注记：新 worktree 已初始化子模块 `plugin/flutter_chat_ui`（固定 7df955eb）；`flutter analyze` 依赖解析曾因未初始化子模块失败，初始化后基线 72 存量问题（env 生成物缺失为主），worktree 保持干净
- 无 BLOCKED；golden=EXTERNAL_PINNED 已冻结；P1/P2/P3 关键 NEEDS_FIX 清单见 execution/P*_INVENTORY.md

## 下一卡与下一条命令

- 卡：**T05**（结构 harness：test/uiux/contract/harness_test.dart 冻结时钟/360×800/1280×800/亮暗/TextScaler 装载能力；T05.a 视觉字体环境探测独立记账）
- 命令（T05 完成后）：`flutter test test/uiux/contract/harness_test.dart --reporter json`（C-T05-1，argv 已在 commands.resolved.json 冻结）
