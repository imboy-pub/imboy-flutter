# ACCEPTANCE RESULTS — imboy-enterprise-uiux-v1

报告时间：2026-10-19T11:09:35Z｜report_revision 1｜候选K：NOT_VERIFIED（T29未执行）

> 本文件是 T33 首轮报告快照；REPORT_WRITTEN ≠ 产品通过。状态=当前真实进度。

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
| AC-Q-01 | auto | NOT_RUN | — |
| AC-Q-02 | auto | NOT_RUN | — |
| AC-Q-03 | auto | NOT_RUN | — |
| AC-Q-04 | auto | NOT_RUN | — |
| AC-Q-05 | auto | NOT_RUN | — |
| AC-Q-06 | auto | NOT_RUN | — |
| AC-Q-07 | auto | NOT_RUN | — |
| AC-R-01 | recovery | PASS | T00 registry/tx-0001; plan_id unique; common-dir verified |
| AC-R-02 | recovery | NOT_RUN | — |
| AC-R-03 | recovery | NOT_RUN | — |
| AC-R-04 | recovery | PASS-so-far | flock+admission+owner/epoch; events PREPARE/COMMIT tx-0001..0004; no reset/clean/stash |
| AC-R-05 | recovery | PASS-so-far | T00-T03 commits+evidence traceable; T33 reporting now; report!=pass stated |
| AC-M-P1 | auto | NOT_RUN | — |
| AC-M-P2 | auto | NOT_RUN | — |
| AC-M-P3 | auto | NOT_RUN | — |
| AC-Q-08 | auto | NOT_RUN | — |
| AC-Q-09 | auto | NOT_RUN | — |
| AC-Q-10 | auto | NOT_RUN | — |
| AC-R-06 | recovery | N/A-first-run | no prior V1 execution registry found; PATHFIX-R1 adopted at bootstrap |
| AC-R-07 | recovery | NOT_RUN | — |
| AC-R-08 | recovery | NOT_RUN | scheduling deps beyond B0 not yet exercised |

汇总：auto 0/29、manual 0/0、recovery 3/8、未运行 33。

AC-R-06 说明：本机未发现 imboy-enterprise-uiux-v1 旧版执行登记（V1 zip 从未执行）；PATHFIX-R1 发行包在 T00 首次安装归档，无迁移对象。