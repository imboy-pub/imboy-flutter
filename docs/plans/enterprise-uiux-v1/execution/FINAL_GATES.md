# FINAL GATES — T29（最终集成候选门禁记录）

> **K（冻结候选）= `571f7aaf7edfd990495fddf9324e7d15d161e1a8`**（工作区干净树）
> 执行日期：2026-10-20｜SDK：Flutter 3.47.7 stable（`/Users/leeyi/dev/flutter/bin`）
> **自动等级：PARTIAL_BLOCKED**（C-FULL 存在范围外失败套件，见 §3；
> 按 T29 change「历史失败可保留范围完成事实，但自动等级必须
> PARTIAL_BLOCKED」如实定级——**candidate_seal.json 未写入**，K 不构成
> 全自动通过候选。）

## 1. 逐门结果（全部对同一 K 运行；证据在 runtime evidence/final/）

| # | 门 | 命令（argv 摘要） | exit | 结果 |
|---|---|---|---|---|
| 1 | C-RECOVERY | `python3 tool/uiux/recovery_contract_test.py` | 0 | 25/25 PASS（RC01—RC24，RC17 拆 a/b） |
| 2 | C-STATE | `python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1` | 0 | valid=true |
| 3 | C-SCOPE | `python3 tool/uiux/check_scope.py --base c61cd8d46…` | 0 | 零违规（base 起全量树审查） |
| 4 | C-ANALYZE | `flutter analyze --fatal-infos --fatal-warnings` | 0 | **0 issues**（M0 基线 72 + 本计划新增 57 已全部清零） |
| 5 | C-TARGET-ALL | `flutter test test/uiux/contract test/uiux/p{1,2,3} --reporter json`（GOLDEN_BASELINE_ROOT=assembled-sealed） | 0 | **executed=143 success=143 failed=0 skipped=0** |
| 6 | C-FULL | `flutter test --reporter json`（全仓） | **1** | executed=10716 success=10699 **failed=17** skipped=0 |
| 7 | C-DIFF-CHECK | `git diff --check c61cd8d46… HEAD` + index/worktree | 0 | 无空白/冲突标记 |

## 2. C-FULL 17 失败的范围外证明

失败套件路径（全部）：
`test/unit_test/service/e2ee/*`（14 套件）+ `e2ee_release_harness_host_test` +
`group_session_service_test` + `store/attachment_outbox_sender_identity_test`
——全部为 **setUpAll 初始化失败**（E2EE 加密服务集成套件，依赖 crypto
种子/后端环境）。

- 与本计划 write_paths（lib/page/channel、lib/page/workspace*、
  lib/modules/{enterprise_oa,customer_service}/presentation、test/uiux/**）
  **零交集**；
- 失败形态为 setUpAll（环境初始化），非断言失败；
- 本计划全部目标门（C-TARGET-ALL 143/143，含 312 golden 的比较模式）
  独立全绿。

## 3. candidate_seal

**未写入**（`candidate_seal.json` 不存在）：C-FULL 未达 exit=0。
K 的树与证据已归档（`runtime evidence/final/`）；如需继续冲击全自动
通过，须先让 e2ee 套件在本机可运行（环境事项，范围外）或由计划所有者
裁决按 PARTIAL_BLOCKED 交付（T33 汇总时决定）。

## 4. 其他核对

- 原仓库（main）/后端/imboyadmin 未被修改（本计划只在集成 worktree 与
  runtime 区工作；`git worktree list` 稳定）；
- 312 golden：candidates + sealed 双目录齐全，比较模式零 diff；
- T28.m 跨会话：MANUAL_PENDING（未发生真实重启，见
  CROSS_SESSION_RESUME.md）。
