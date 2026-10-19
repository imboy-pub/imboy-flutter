# T00 基线登记 — imboy-enterprise-uiux-v1（V1.1 / PATHFIX-R1）

生成时间：2026-10-19T10:35:48Z｜协调器：ZCode session a7661d43…（zcode-cli PID 2525）

## 仓库身份（只读核实）

| 项 | 值 |
|---|---|
| repo_realpath | `/Users/leeyi/project/imboy.pub/imboyapp` |
| git_common_dir | `/Users/leeyi/project/imboy.pub/imboyapp/.git` |
| source_branch | main @ `c61cd8d46e276496b2ddae8b89b17d6fe6856ddc` |
| 源工作区 dirty | 0 个路径（C-BOOT-GIT NUL 输出已存证据） |
| remotes（脱敏） | origin=gitee https / github=ssh / gitcode=ssh（无凭据） |
| 既有 worktree | 3 个（guangzhou-phase1 两批，非本计划，未触碰） |
| 遗留 stash | stash@{0}（并行会话 webview/pubspec，未触碰） |
| SDK 记录 | flutter/dart 二进制位于 `/Users/leeyi/dev/flutter/bin`（版本解析留给 T04，未抢占缓存） |

## 首次判定

- git-common-dir 内无 `imboy-uiux/imboy-enterprise-uiux-v1/` 登记；无 `ux/*` / `*enterprise*` 分支；
  仓库无 `docs/plans/enterprise-uiux-v1` 历史与目录 → **真正首次执行**，非恢复。
- 旧计划 `imboyapp-uiux-v1`（`.git/ux-runs/…/registry.json`）状态 EXECUTION_COMPLETE、锁已 RELEASED，
  其 worktree 已清理；与本计划 plan_id 不同，不接管、不复活。
- 发行源 `/Users/leeyi/project/imboy.pub/_task_packages/IMBoy_Enterprise_UIUX_V1_1` 静态自检 `PLAN_STATIC_CHECK_PASS`（exit=0，21 负例全部拒绝）。

## 集成工作树

| 项 | 值 |
|---|---|
| 路径 | `/Users/leeyi/project/imboy.pub/.worktrees/imboy-enterprise-uiux-v1` |
| 分支 | `ux/imboy-enterprise-uiux-v1-integration` |
| 基线 | `c61cd8d46e276496b2ddae8b89b17d6fe6856ddc`（本机已提交 main HEAD，未含任何未提交修改） |
| 创建意图 | `worktree-create-20261019T103548Z`（runtime intents/，EXECUTED） |

命名说明：RESUME_PROTOCOL §4.4 建议路径为 `<repo父目录>/.worktrees/imboyapp-uiux-v1`；
本次采用 plan_id 后缀 `imboy-enterprise-uiux-v1`，避免与已完成旧计划 `imboyapp-uiux-v1` 目录混淆
（T00 风险"误认目录/接管别的计划工作树"）。创建时无冲突，非随机后缀绕过。

## 合同归档与身份

| 身份 | 值 |
|---|---|
| plan_id | `imboy-enterprise-uiux-v1`（不变） |
| active_package | `/Users/leeyi/project/imboy.pub/.worktrees/imboy-enterprise-uiux-v1/docs/plans/enterprise-uiux-v1` |
| package_release_hash（SHA256SUMS 的 SHA-256） | `b8301b14e9870d10bb16961f0c10ad716338c0e9f0934e720ac147fe1ba921fb` |
| contract_revision | 1 |
| 归档完整性 | 归档副本内 `tools/plan_audit.py --self-test` exit=0 |

归档提交方式说明：仓库 `.gitignore` L160 忽略 `/docs/plans/`（main 的"一次性执行材料不入 Git"约定）。
本合同要求集成分支携带合同归档（专用分支，永不 merge main / push），故对
`docs/plans/enterprise-uiux-v1` 使用 `git add -f` 精确添加；未修改 `.gitignore`。

## 证据

- `@runtime/evidence/T00/1/package_selftest.out` — C-PACKAGE（发行源）exit=0
- `@runtime/evidence/T00/1/archive_selftest.out` — C-PACKAGE（归档副本）exit=0
- `@runtime/evidence/T00/1/boot-git.out` — C-BOOT-GIT NUL 输出（dirty=0）
- `@runtime/evidence/T00/1/boot-worktrees.out` — C-BOOT-WORKTREES porcelain NUL
- `@runtime/evidence/T00/1/worktree-add.out` — worktree 创建输出
- `@runtime/evidence/T00/1/commands.json` — argv/cwd/exitcode/输出hash 清单

## 不变承诺

源仓库 main 未被修改（0 业务文件改动；仅 .git 下新增本计划 worktree/refs 与 runtime 目录）。
未 fetch/pull/rebase/stash/reset；遗留 stash 与他人 worktree 原样保留。
