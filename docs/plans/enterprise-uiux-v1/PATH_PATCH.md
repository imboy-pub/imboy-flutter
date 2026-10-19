# V1.1 启动路径补丁 PATHFIX-R1

日期：2026-10-19。计划仍是 `imboy-enterprise-uiux-v1`；不新增任务、不重新评分、不修改产品范围。

## 1. 为什么补

旧提示词使用“本包”和“<包绝对路径>”，需用户额外提供路径前缀。旧版配合之前的前缀已可执行。本补丁把固定下载位置写入提示词与使用说明，使第一次和下一次均只复制同一份EXECUTION_PROMPT全文；不要求用户每次组合两段文本。

固定下载位置：`/Users/leeyi/project/imboy.pub/_task_packages/IMBoy_Enterprise_UIUX_V1_1`。包名PATHFIX只用于区分下载文件；ZIP内顶层名称保持`IMBoy_Enterprise_UIUX_V1_1`，无需改变固定目录。

## 2. 哪些变、哪些不变

操作说明变更：EXECUTION_PROMPT.md、README.md、RESUME_PROTOCOL.md、MIGRATION.md；新增本说明。更新PACKAGE_CHECK.md、静态结果记录与SHA256SUMS以对应实际补丁包。

PRD.md、TASKS.md/JSON、COMMANDS.json、ACCEPTANCE.md/JSON、MATRIX.json、NATIVE_CASES.json、RECOVERY_CASES.json、TEST_CONTRACT.md、运行模板及tools源码保持逐字不变。51张任务卡、37项AC、312个配置不变。此处固定的是下载源，不固定实际worktree。

## 3. 本地放置规则

### 尚未解压过旧包，也未执行

解压补丁ZIP到`/Users/leeyi/project/imboy.pub/_task_packages/`父目录。确认最终出现`/Users/leeyi/project/imboy.pub/_task_packages/IMBoy_Enterprise_UIUX_V1_1/EXECUTION_PROMPT.md`。整个目录只出现一层同名包目录；不要把包直接解压进同名目录再套一层。

### 已解压旧包，但确实尚未运行任务、没有registry/active_package

关闭正在读取旧包的编辑/执行会话；先将旧下载文档目录改为一个未占用的备份名，再将完整补丁解压到父目录，恢复固定目录名。保留备份，不执行删除，不覆盖源码仓库；本分支仅适用于确认没有执行登记的情况。不能确认时走下一分支。

### 已经执行或无法确认是否执行

不要覆盖、改名或移动旧包，也不要删除任何工作树。将新ZIP解压到独立临时待迁移目录，保留旧固定目录及active_package原样。可继续使用旧提示词配合原路径前缀推进，不必为了该补丁中断任务。

确需采用补丁时，在原协调器的安全checkpoint提供新候选包的真实位置；按MIGRATION.md §6检查旧登记与候选差异。只有确认没有活跃写者且旧包已安全归档后，才由原协调器安装至固定目录并更新active_package登记；任务历史、分支、原worktree和runtime始终保留。未完成迁移时不得用新hash替代旧登记。

## 4. 复制提示词

补丁正确安装并完成必要迁移后，Mac终端执行：

```sh
pbcopy < "/Users/leeyi/project/imboy.pub/_task_packages/IMBoy_Enterprise_UIUX_V1_1/EXECUTION_PROMPT.md"
```

在本地Codex/ZCODE会话粘贴发送。无需追加路径前缀；中断后还是这份全文。若已有有效active_package而下载源缺失，提示词先恢复原登记，不能重新开始。

## 5. 校验边界

本次只在当前文件环境制作/检查文档包，不访问用户Mac、不创建实际worktree、不运行Flutter或原生验收。静态检查与ZIP/checksum通过不等于续跑已实测。
