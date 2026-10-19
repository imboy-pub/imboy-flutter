# IMBoy 企业客户端 UI/UX V1.1 文档包

计划ID仍为 `imboy-enterprise-uiux-v1`｜日期2026-10-19｜启动路径补丁PATHFIX-R1。完整替代V1发行文档，但不替换已存在的执行状态/工作树。

## 文件入口

| 文件 | 内容 |
|---|---|
| [QUALITY_REVIEW.md](QUALITY_REVIEW.md) | 原版8.6、修订版约9.8静态自评；13项有定位的扣分与修复 |
| [PRD.md](PRD.md) | P1/P2/P3产品要求、数值、状态、权限/业务不变与取舍 |
| [TASKS.md](TASKS.md) | 5批51张文件级任务卡；每卡依赖、断言、命令ID、人工步骤、回滚和风险 |
| [EXECUTION_PROMPT.md](EXECUTION_PROMPT.md) | **首次与新会话续跑均全文复制同一份提示词** |
| [RESUME_PROTOCOL.md](RESUME_PROTOCOL.md) | 原worktree定位、owner/锁、状态事务、候选K/报告R、失败续跑 |
| [MIGRATION.md](MIGRATION.md) | V1已开工时保留原工作树/任务ID/提交/累计attempt迁移 |
| [TEST_CONTRACT.md](TEST_CONTRACT.md) | 每批门、312矩阵、基线存储/批准、skip、原生与结果判级 |
| [ACCEPTANCE.md](ACCEPTANCE.md) | 37项可逐条勾选的验收合同；实际结果另外记录 |
| [RESEARCH.md](RESEARCH.md) | 原产品/代码出处及本次工程补核；未取证内容仍待确认 |
| [PACKAGE_CHECK.md](PACKAGE_CHECK.md) | 本包真实静态检查结果与NOT_RUN边界 |

机器可读：TASKS.json、COMMANDS.json、ACCEPTANCE.json、MATRIX.json、NATIVE_CASES.json、RECOVERY_CASES.json。templates中是示例，不是用户运行记录。

## 固定安装位置与直接使用

整包固定放在：

```text
/Users/leeyi/project/imboy.pub/_task_packages/IMBoy_Enterprise_UIUX_V1_1/
```

这里是**下载文档源**，不是Flutter仓库、执行worktree或状态目录。所有文件/子目录一起保留；不要只复制PRD/TASKS，不要把STATE.example覆盖到运行state。

从本地执行器打开 `/Users/leeyi/project/imboy.pub/imboyapp`，读取本目录的 `EXECUTION_PROMPT.md`，全文复制并发送即可。提示词已经内置路径，不需要上一版说明中的额外路径前缀。Mac可执行：

```sh
pbcopy < "/Users/leeyi/project/imboy.pub/_task_packages/IMBoy_Enterprise_UIUX_V1_1/EXECUTION_PROMPT.md"
```

会话中断后重复同一条复制命令，并在新会话发送同一份全文。先定位旧registry与原worktree；已有记录时恢复，真正首次才安全创建。已登记active_package通过校验时优先于bootstrap目录，不能因为固定目录的存在/缺失而新建工作树。

本补丁压缩包外部文件名为 `IMBoy_Enterprise_UIUX_V1_1_PATHFIX.zip`，**内部顶层目录仍为 `IMBoy_Enterprise_UIUX_V1_1/`**。首次本地完全没有同名目录时，可解压到 `_task_packages/` 父目录；已经放过旧版或已经开工时按 [PATH_PATCH.md](PATH_PATCH.md) 操作，不将新旧文件混在一起，不用`unzip -n`合并更新旧包。

已有V1执行状态，仍先按MIGRATION迁移；已有V1.1只需审查本次启动文档差异，保留原worktree、任务ID、提交与累计attempt。使用旧包配合明确路径前缀仍然有效，不强制为了本补丁打断活跃任务。

正常中断可从持久checkpoint继续；进程/宿主身份不明、工作树丢失或外来冲突时必须安全阻塞，不能无条件接管。没有原文件无法保证恢复未提交修改。

## 校验命令（Python 3.9+，仅标准库）

在解压后的此目录执行：

```sh
python3 tools/plan_audit.py --package . --self-test
```

该命令只读本发行包，不连接后端、不修改Git、不运行Flutter、不占设备。输出PLAN_STATIC_CHECK_PASS只说明文档合同结构一致；不会把模板TODO改成PASS。

维护发行文档时先改JSON、再运行`python3 tools/render_plan.py --package .`生成TASKS/ACCEPTANCE，并重新计算SHA256SUMS。执行中的路径解析/合法拆卡写execution下resolved/overlay，由本机检查器核验；不修改发行包检查器的固定计数来伪造通过。checksum忽略execution运行区，报告变化不触发发行包版本漂移。

## 当前状态

已完成：修订文档与包静态校验器；真实检查结果见PACKAGE_CHECK。未完成且未声称完成：本地控制工具、Flutter实现/测试、312张真实golden、原生51个场景、真实跨会话恢复、CI/生产。

自动候选、原生UX、真实恢复三个结果分别记录。后端EUnit=N/A；只有Flutter展示范围，不借质量目标改权限/接口/数据库。原应用联调地址保持不变，不把隐藏URL当作生产OA已经交付。
