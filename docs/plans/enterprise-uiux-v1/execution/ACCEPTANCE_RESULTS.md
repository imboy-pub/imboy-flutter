# ACCEPTANCE RESULTS — imboy-enterprise-uiux-v1

报告时间：2026-10-19T12:28:41Z｜report_revision 3｜候选K：NOT_VERIFIED（T29未执行）

> B0 收口快照；REPORT_WRITTEN ≠ 产品通过。

| ID | 维度 | 状态 | 依据 |
|---|---|---|---|
| AC-P1-01 | auto | NOT_RUN | — |
| AC-P1-02 | auto | NOT_RUN | — |
| AC-P1-03 | auto | NOT_RUN | — |
| AC-P1-04 | auto | NOT_RUN | — |
| AC-P1-05 | auto | NOT_RUN | — |
| AC-P1-06a | auto | NOT_RUN | — |
| AC-P1-06b | auto | NOT_RUN | — |
| AC-P2-01 | auto | NOT_RUN | — |
| AC-P2-02 | auto | NOT_RUN | — |
| AC-P2-03 | auto | NOT_RUN | — |
| AC-P2-04 | auto | NOT_RUN | — |
| AC-P2-05 | auto | NOT_RUN | — |
| AC-P3-01 | auto | NOT_RUN | — |
| AC-P3-02 | auto | NOT_RUN | — |
| AC-P3-03 | auto | NOT_RUN | — |
| AC-P3-04 | auto | NOT_RUN | — |
| AC-Q-01 | auto | PASS | T04.a check_scope: forbidden-file/index/worktree/untracked coverage; self-test 5/5, real-tree PASS |
| AC-Q-02 | auto | PASS | T04.a frozen-symbol overlap + banned presentation escapes rejected; negative cases exit non-zero |
| AC-Q-03 | auto | NOT_RUN | — |
| AC-Q-04 | auto | NOT_RUN | — |
| AC-Q-05 | auto | NOT_RUN | — |
| AC-Q-06 | auto | NOT_RUN | — |
| AC-Q-07 | auto | NOT_RUN | — |
| AC-R-01 | recovery | PASS | T00 registry tx-0001; T04.b owner/epoch lock tests; plan_id unique; no random paths |
| AC-R-02 | recovery | NOT_RUN | — |
| AC-R-03 | recovery | NOT_RUN | — |
| AC-R-04 | recovery | PASS | flock+admission+epoch; events tx-0001..0010 PREPARE/COMMIT verified; scope gate covers untracked; no reset/clean/stash/push |
| AC-R-05 | recovery | PASS | T00-T04.c commits+evidence traceable; T33 rev3; report!=pass stated; next step explicit |
| AC-M-P1 | auto | NOT_RUN | — |
| AC-M-P2 | auto | NOT_RUN | — |
| AC-M-P3 | auto | NOT_RUN | — |
| AC-Q-08 | auto | NOT_RUN | — |
| AC-Q-09 | auto | NOT_RUN | — |
| AC-Q-10 | auto | NOT_RUN | — |
| AC-R-06 | recovery | N/A-first-run | no prior V1 execution registry existed; PATHFIX-R1 adopted at bootstrap, documented |
| AC-R-07 | recovery | PASS | T04.b test_lock_contract 7/7 + T04.c test_state_contract 7/7 run against the actual modules; real runtime check_state valid rev10 |
| AC-R-08 | recovery | NOT_RUN | — |

汇总：auto 2/29、recovery 4/8、未运行 30。

M0 基线：flutter analyze --fatal-infos exit=1 / 72 存量问题（改动前记录，evidence/M0/1）；子模块 flutter_chat_ui 已按固定 commit 初始化；Erlang EUnit=N/A。