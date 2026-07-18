# imboyapp 交互体验第三轮 —— 直接复制可用的提示词

> 创建：2026-07-16。三条提示词按顺序用：①生成批次计划（跑一次）→ ②批次实施（每批一个新会话，重复贴同一条）→ ③真机走查（每 2-3 批做一次）。
> 全部零填空。②③自动定位"下一个未完成批次"，不需要改任何数字。
> 前置事实：全量审计已完成（`docs/plans/2026-07-10-fullapp-uiux-audit-v2.md`），前两批已提交 `51bdb1b9` + `b60f44c5`，本轮只做剩余项，**不要重新审计**。

---

## 提示词 ①：生成第三轮批次计划（新会话跑一次）

```
cd ~/project/imboy.pub/imboyapp（确认在 git 仓库内）。

任务：汇总以下三处的全部遗留交互问题，生成第三轮实施批次计划，写入
docs/plans/2026-07-16-ux-round3-batches.md。只读代码不改代码，不 commit。

来源一：docs/plans/2026-07-10-fullapp-uiux-audit-v2.md 的 §0.0 中
「⏳ 仍待后续」全部条目，逐条展开为可实施项：
- B7 跨端：AppBreakpoints 统一 / hover / 右键菜单 / 快捷键接线
- SR-6/7：IconHitButton（44pt+label）全局组件 + 触达/a11y 全站迁移
- SR-5 调用方迁移：textSecondary 15 处 / iosOrange 41 处 / iosPurple 11 处静态色替换
- service 层三态根治：grep 各 service 吞异常返回 null 的方法，列出具体文件:行号
- i18n 债务：withdraw / red_packet_detail 硬编码中文补键
- 既有 bug：channel_message_item.dart:874 shareToChat 传裸 Map 路由 as Message 崩溃

来源二：2026-07-16 真机全量点击 QA 遗留（前端可修项）：
- flutter_chat_ui 的 Avatar 等第三方组件裸加载头像不走 presign，须替换为项目自有
  Avatar 组件（走 AssetsService.viewUrl），先 grep 找出所有裸用第三方 Avatar 的渲染点
- 日期格式 EEEE 无 locale 显示英文星期，全局排查 DateFormat 无 locale 的调用
- 图片 401/403 时降级占位图（排查 cachedImageProvider / errorWidget 链路）
- 收藏 uri 快照过期未根治（收藏时存 object_key 而非签名 URL）

来源三：2026-07-14 真机深度 QA 遗留（前端可修项）：
- 消息撤回/编辑：后端成功但发起方 ack 后 UI 不更新（已收窄范围，需 debug 包定位）
- 群主无禁言/管理员管理入口（产品缺口，需新增入口页）

排除项（不要放进批次）：
- §0.5 阻塞的聊天气泡渲染类（等 AI Agent 路线图，按设计不做）
- 后端项：#12 投票计数、群文件/群作业（imboy 59aedd4d 未部署，另行处理）
- #5 设备名（后端）

输出要求：
1. 每条落到具体 文件:行号（用 grep/read 核实，不许凭空写）
2. 每条标注：影响(高/中/低)、成本(S/M/L)、共享组件/单页
3. 按「文件不重叠」原则分批，每批 3-5 项，共享组件项排前面的批次；
   SR-5 调用方迁移这类纯机械替换单独成批
4. 文档格式：每批一节，含条目表格 + 状态列（TODO/DONE），
   顶部写「当前进度」一行，供后续会话自动定位
```

---

## 提示词 ②：批次实施（每批开一个新会话，原样贴这条即可）

```
cd ~/project/imboy.pub/imboyapp。读 docs/plans/2026-07-16-ux-round3-batches.md，
找到第一个状态为 TODO 的批次，实施该批全部条目。

硬约束：
1. 只做该批条目，不顺手重构不扩散；发现新问题追加记录到台账「新发现」节，不当场修
2. 颜色/间距/字号必须走 AppColors/AppSpacing/FontSizeType token，禁止硬编码
   （lefthook design-tokens 钩子会拦截）
3. 附件/头像 URL 必须经 AssetsService.viewUrl 授权，禁止裸 URL
4. 不新增 pub 依赖；先 grep 复用已有组件（AsyncStateView、ComposerField、
   BatchUploadController、项目自有 Avatar 等）
5. 改共享组件前 grep 全部调用方评估影响面；禁改 plugin/r_upgrade、ios/*、macos/*
6. 如派多个 agent：文件有重叠的任务必须串行；每个 agent 完成后你亲自
   git status + git diff 对磁盘核实，不信 agent 回执
7. staged 区可能有并发会话的改动，只 add 本批文件，勿全量 add、勿 restore 他人改动

流程：
1. 逐项先读现有实现和调用链，再写最小 diff
2. 每项完成跑 flutter analyze lib，对本批改动必须零告警
3. 有非平凡逻辑的项补最小 widget/unit test 并跑绿
4. 全批完成：台账该批状态改 DONE、记录改动文件清单和待真机验证步骤
5. 精确 add 本批文件后一个 commit（fix:/feat: 前缀），不 push；
   commit 后 git log -1 --stat 核实落盘

结束时输出：本批做了什么、动了哪些文件、哪些项需要真机验证及具体验证步骤。
```

---

## 提示词 ③：真机走查（每 2-3 批做一次，原样贴）

```
cd ~/project/imboy.pub/imboyapp。对 docs/plans/2026-07-16-ux-round3-batches.md
中状态为 DONE 但「真机验证」列为空/未验证的批次做真机验收。禁止模拟器。

1. 汇总各批台账里的「待真机验证步骤」生成 checklist
2. 用 mobile MCP 连真机（mcp__mobile__list_devices 选真机）逐项走查：
   每项给出 操作步骤 → 预期 → 实际 → PASS/FAIL + 截图
3. FAIL 项先 git log 追溯判断是本轮引入还是预存缺陷，写回台账标注归属，不当场修
4. 全部走查完把各批「真机验证」列更新为 ✅ 或 ❌+缺陷编号，不 commit 代码

已知环境：测试账号见 scripts/test.env；admin888 本地无群、朋友圈为空，
涉群/朋友圈用例先跑 scripts/setup_test_data.sh 播种；
flutter_chat_ui 第三方组件裸加载不走 presign 是已知类缺陷，重点验证替换后是否根治。
```

---

## 使用节奏

| 步骤 | 会话 | 产出 |
|---|---|---|
| ① 跑一次 | 1 个 | `2026-07-16-ux-round3-batches.md` 批次计划 |
| ② 重复贴 | 每批 1 个 | 每批一个 commit（不 push） |
| ③ 每 2-3 批 | 1 个 | 台账真机验证列更新 |

全部批次 DONE 且真机 ✅ 后，再决定是否统一 push。
