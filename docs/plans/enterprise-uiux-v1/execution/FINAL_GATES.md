# FINAL GATES — T29（最终集成候选门禁记录）

> **K（冻结候选）= `d397d38c80911bfdd60934bb5417cfdaec2821e0`**（工作区干净树）
> 执行日期：2026-10-20｜SDK：Flutter 3.47.7 stable（`/Users/leeyi/dev/flutter/bin`）
> **自动等级：FULL_PASS（candidate_seal.json 已写入）**
>
> 首轮 C-FULL 曾 exit=1（17 个 e2ee 套件 setUpAll 失败）并如实定级
> PARTIAL_BLOCKED。随后根因定位为 vodozemac Rust 原生库未编译进
> worktree 可见路径——设置
> `FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR` 指向源仓库已编译的
> `spikes/e2ee-group/rust/target/release/` 后复跑：**exit=0，
> 10830/10830 全过、0 failed、0 skipped**（此前因 setUpAll 失败未执行
> 的 114 个用例全部实际跑过）。七门全绿，候选按合同封存。

## 1. 逐门结果（全部对同一 K 运行；证据在 runtime evidence/final/）

| # | 门 | 命令（argv 摘要） | exit | 结果 |
|---|---|---|---|---|
| 1 | C-RECOVERY | `python3 tool/uiux/recovery_contract_test.py` | 0 | 25/25 PASS（RC01—RC24，RC17 拆 a/b） |
| 2 | C-STATE | `python3 tool/uiux/check_state.py --plan-id imboy-enterprise-uiux-v1` | 0 | valid=true |
| 3 | C-SCOPE | `python3 tool/uiux/check_scope.py --base c61cd8d46…` | 0 | 零违规（base 起全量树审查） |
| 4 | C-ANALYZE | `flutter analyze --fatal-infos --fatal-warnings` | 0 | **0 issues**（M0 基线 72 + 本计划新增 57 已全部清零） |
| 5 | C-TARGET-ALL | `flutter test test/uiux/contract test/uiux/p{1,2,3} --reporter json`（GOLDEN_BASELINE_ROOT=assembled-sealed） | 0 | **executed=143 success=143 failed=0 skipped=0** |
| 6 | C-FULL | `flutter test --reporter json`（全仓；vodozemac env） | 0 | **executed=10830 success=10830 failed=0 skipped=0** |
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

**已写入** `runtime candidate_seal.json`（level=FULL_PASS，
K=`d397d38c80911bfdd60934bb5417cfdaec2821e0`）：七门全过（含 C-FULL 在
vodozemac 原生库环境修复后复跑）。e2ee 套件的"失败"根因为**测试环境
原生库路径缺失**（非产品缺陷）：源仓库已有编译产物，运行时以环境变量
提供路径即可。

## 3b. Android lane BLOCKED 补充（2026-10-20 深入探测）

自动会话曾尝试推进 Android 原生验收（发现真机 MRD-AL00 在线、本地后端
节点起至 9801 端口变体、release 组装完成），但节点 strict secret 校验链
（password_salt → login RSA 文件 → pg 密码非默认 → payment/plugin）
需要所有者的部署密钥资产——自动会话不得代为生成生产性凭据。T30.a/
T31.a/T32.a 记 BLOCKED（交接步骤已写入各 P*_MANUAL_android.md），
Owner 预计 15 分钟可用既有密钥接手。该 BLOCKED 不影响本文件 §1 的
七门自动证据（143/143 目标门与 312 golden 均为 widget 级，无后端依赖）。

## 4. 其他核对

- 原仓库（main）/后端/imboyadmin 未被修改（本计划只在集成 worktree 与
  runtime 区工作；`git worktree list` 稳定）；
- 312 golden：candidates + sealed 双目录齐全，比较模式零 diff；
- T28.m 跨会话：MANUAL_PENDING（未发生真实重启，见
  CROSS_SESSION_RESUME.md）。
