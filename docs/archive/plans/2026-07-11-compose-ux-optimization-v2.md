# 发消息交互简化 · 第二轮执行清单（群 / 频道 / 朋友圈）

> 创建：2026-07-11 | 状态：待启动 | 范围：imboyapp 三处 compose 流程
> 前置：第一轮 `2026-07-10-compose-ux-optimization.md` 的 P0/P1 已落地并提交 `b60f44c5`
> 结论：第一轮解决了"入口断层 / 串行慢 / 可见性跳两层"，但用户仍反馈"不够简洁"。
> 经三面代码实证，残留摩擦的根因换成了三类：**真 bug（越用越卡）、该复用未复用（三处各写一套富输入）、半成品接线（挂了入口没做到"发起"、有函数没接线）。**

---

## 0. 总原则（延续第一轮）

- 减少步骤 / 复用现成能力 / 修真 bug 优先于视觉重绘。
- **全局约束（验收前置）**：
  - `dart analyze lib` 必须保持 **No issues found!**
  - 新文案走 `assets/i18n/zh-CN/<namespace>.i18n.yaml` → `dart run slang`，禁硬编码中文。
  - 颜色/间距/字号必须走 `AppColors` / `AppSpacing` / `FontSizeType` Token。
  - **功能验收必须真机**（iPhone 16e `00008140-000E30561E32801C`），禁模拟器。
- ⚠️ 并发会话隔离：`group_select_page.dart` 等 staged 改动为并发会话所有，本轮不动。

---

## 1. 残留摩擦诊断矩阵（证据锚点）

| 面 | 摩擦点 | 类型 | 代码证据 |
|---|---|---|---|
| 群聊 | `ChatKeyboardObserver` 每帧 build 新增、dispose 从不 remove → 长会话重建风暴、越用越卡 | 🐞真bug | `chat_input.dart:1043`（build 内调用）→ `:282-284`（每次 new+addObserver）→ `:546-574`（dispose 遗漏 removeObserver） |
| 群聊 | "表情"一名两义：`+`面板"表情"打开 16 个硬编码 emoji 的占位组件、点击即发；输入行表情打开完整 EmojiPicker、插入文本 | 认知割裂/死代码 | `extra_item.dart:233-237` + `sticker_picker.dart:21-40`（url 全空）+ `chat_page.dart:1094-1109` |
| 群聊 | 投票/日程/任务"伪直达"——点击只 push 到**列表页**，再点创建按钮才到表单；日程/任务还被分页切到第 2 页 | 半成品接线 | `extra_item.dart:283-301` push 列表；`group_vote_page.dart:120`/`group_schedule_page.dart:300`/`group_task_page.dart:146` 才是创建入口 |
| 群聊 | 面板"语义分组"只存在于源码注释，UI 无分区标题/分隔线；`perPage=8` 硬切打散群协作组 | 名存实亡 | `extra_item.dart:282`（注释）、`:342-352`（分页）、`:435-453`（无 header 渲染） |
| 群聊 | `showMentionPicker()` 已实现却零调用，输入行无可见 @ 按钮，大群靠手打 @ | 死代码/未接线 | `chat_input.dart:673-687`（定义），全仓零调用点 |
| 频道 | 多图各自单独 `publishMessage`，9 图=9 条独立帖；不能合并"图文帖"、不能附图注 | 能力缺口 | `channel_publish_bar.dart:231-245`（逐条发布），全程未读 `_messageController.text` 作图注 |
| 频道 | 发布栏是裸 `TextField`，无表情/@/字数上限，退化于聊天输入栏 | 该复用未复用 | `channel_publish_bar.dart:420-446` vs `chat_input.dart:54,506,763,846` |
| 频道 | 批量上传部分失败只弹"成功N失败M" SnackBar，无失败项列表、无单项重试 | 反馈缺口 | `channel_publish_bar.dart:229-255` |
| 朋友圈 | 可见性"公开/仅好友/仅自己"三种简单态仍强制整页 push + 无条件网络拉标签 + 二次确认点击 | 单页化不彻底 | `moment_create_page.dart:462-479`；`moment_friend_picker_page.dart:159-162,193-220,325-336` |
| 朋友圈 | 批量上传只渲染**一个**全局占位 spinner，看不出选几张/传到第几张/哪张失败，无单项重试 | 反馈缺口 | `moment_create_page.dart:280-309,580-602` |
| 朋友圈 | 无 App 生命周期自动保存，切后台被回收/划掉 App 丢失正在编辑内容（`_confirmExit`/`_saveFailedDraft` 覆盖不到） | 数据丢失 | `moment_create_page.dart` 全文无 `WidgetsBindingObserver`/`AppLifecycleState` |
| 朋友圈 | @提及是**假功能**：`extractMentions` 只在评论用，`createPost` 不传 `mentions`，用户手打 @ 服务端收不到 | 半成品/负体验 | `moment_create_page.dart:385-396`；`moment_facade.dart:12-26`（对比 addComment `:48-58` 有）；`moment_api.dart:19-47` |

**贯穿三面的两条主线**：
1. **富输入能力三处各写各的**——`chat_input`（表情/@/字数）、`channel_publish_bar`（裸 TextField）、`moment_create`（无表情、@假功能）、`channel_comment_page`（又一套裸 TextField）。DRY 缺失。
2. **批量上传反馈两处各写各的且都很弱**——朋友圈与频道都是"全局 spinner + 整批失败"。

---

## 2. 行业对标（借鉴决策，不照搬）

| 场景 | 标杆 | 借鉴的交互决策 |
|---|---|---|
| 群工具发起 | 钉钉/飞书 | `+` 里点"投票/日程/任务"**直接进创建表单**，不是先看列表 |
| `+` 面板分组 | 飞书/钉钉 | 群工具单独可视分区（带标题条），常用项永远第一屏 |
| 富输入 | 微信/Telegram | 表情/@/字数三件套是发布/评论的标配，一处实现处处复用 |
| 频道图文 | Telegram 相册 / 公众号 | 多图合并为**一条**内容 + 附文字图注 |
| 上传反馈 | 微信/小红书 | 选中即逐张出缩略图 + 各自进度/失败重试 |
| 朋友圈可见性 | 微信 | 简单三态走 ActionSheet 原地选，仅名单模式才二级页 |
| 草稿保底 | 微信/小红书 | 任意退出方式（含被系统杀）内容都进草稿箱 |

---

## 3. 分批执行清单

### 🔴 批次 A｜真 bug + 纯前端极低成本（本轮先做，收益最大）

#### A-1 修复 `chat_input` 键盘 observer 泄漏（🐞真 bug，最高优先）— ✅ 已修复（2026-07-11 核实）
> **现状**：代码已闭环——`_setupKeyboardListener()` 仅在 `initState`（`chat_input.dart:170`）调一次；observer 存入 `_keyboardObserver` 字段、`addObserver` 仅在 `:291` 执行一次；`dispose`（`:557`）已 `removeObserver`；`build()` 内无重复注册。仅回归测试未补（`ChatInput` 依赖重，widget 测试脚手架成本高，暂不做；已预埋 `keyboardObserverAddCount` 计数器备用）。
- **问题（历史）**：`build()` 每帧调 `_setupKeyboardListener()`，每次 new 一个 `ChatKeyboardObserver` 注册且从不 remove，键盘每开合一次全部历史 observer 各触发一次 `setState` → 长群聊输入区越用越卡。
- **落地**：
  1. 从 `build()`（`chat_input.dart:1043`）移除 `_setupKeyboardListener()` 调用。
  2. `_setupKeyboardListener()` 里的 `addObserver` 保留在 `initState` 一次性执行；把 observer 实例存成字段。
  3. `dispose()`（`:546-574`）补 `WidgetsBinding.instance.removeObserver(_keyboardObserver)`。
- **涉及文件**：`chat_input.dart`。
- **验收**：
  - [ ] 键盘反复开合 20+ 次后，输入区无累积卡顿（真机可感知）。
  - [ ] `WidgetsBinding.instance` 上不再有重复 `ChatKeyboardObserver`（可加断言/日志验证注册次数=1）。
  - [ ] 键盘高度"丝滑锁定"动画行为不回退。
  - [ ] `dart analyze lib` 零告警。
- **成本**：XS（移一行 + dispose 补一行）。**留一个 widget 测试**：pump 后多次触发 build，验证 observer 只注册一次。

#### A-2 群 `+` 面板：投票/日程/任务改"直达创建表单"
- **问题**：点击只到列表页，还要再找创建按钮；日程/任务被分页切到第 2 页。
- **落地**：
  1. `extra_item.dart:283-301` 的 `onPressed` 从 push 列表路由改为直开创建态——两条路线择一：
     - (a) 各列表页支持 `?create=1` query 或新增 `/create` 子路由，进入即弹创建表单；
     - (b) 若创建表单已是独立 widget，直接 push 到表单页。优先 (b)，避免改列表页状态机。
  2. 把"投票/日程/任务"三项在 `allItems` 中挪到群协作组**连续且落在第 1 页**（调整顺序或 `perPage`）。
- **涉及文件**：`extra_item.dart`、必要时群三功能页路由。
- **验收**：
  - [ ] 群聊点 `+` → 点"群投票"→ **直接看到创建表单**（≤2 步），日程/任务同。
  - [ ] 三项在同一屏可见，无需翻页。
  - [ ] C2C/C2S 不出现群工具项（回归）。
- **成本**：S。

#### A-3 `+` 面板加可视分组标题 + 常用置顶
- **问题**：分组只在注释，UI 无分区；8/页硬切打散组。
- **落地**：`_buildItemsGrid`（`extra_item.dart:435-453`）按"媒体 / 群协作 / 资金"分段渲染，每段一个轻量标题条（走 Token）；常用项固定首屏；窄屏（iPhone SE）不溢出（沿用固定格高）。
- **涉及文件**：`extra_item.dart`（+ i18n 分组标题键）。
- **验收**：
  - [ ] 面板出现可感知的分区标题/分隔。
  - [ ] 常用功能首屏可见。
  - [ ] iPhone SE 不溢出。
- **成本**：S。

#### A-4 输入行加可见 @ 按钮（接死代码）
- **问题**：`showMentionPicker()` 已实现零调用，大群靠手打 @。
- **落地**：群聊（C2G）输入行工具区加一个 @ 图标按钮，`onPressed` 调已有 `showMentionPicker()`（`chat_input.dart:673`）；C2C 不显示。
- **验收**：
  - [ ] 群聊输入行可见 @ 按钮，点击弹出选人（复用现成 `MentionListWidget`）。
  - [ ] 大群选人可搜索（沿用现有能力）。
  - [ ] C2C 会话不显示 @ 按钮。
- **成本**：XS。

---

### 🟡 批次 B｜DRY 复用（消除"三处各写一套"，一次收口多面受益）

#### B-1 抽共享富输入组件 `ComposerField`（表情 + 字数 + 可选 @）
- **目标**：把 `chat_input` 已打磨的表情面板 / 字数计数 / `maxLength` 抽成可复用组件，供**频道发布栏、频道评论、朋友圈**复用，消除三处退化的裸 `TextField`。
- **落地**：
  1. 从 `chat_input.dart` 抽取 emoji 面板 + 计数逻辑为 `lib/component/chat/composer_field.dart`（不含语音/群工具等聊天专属职责）。
  2. `channel_publish_bar.dart:420-446`、`channel_comment_page.dart:39,519`、`moment_create_page.dart` 撰写区改用 `ComposerField`。
  3. `chat_input` 自身也切到该组件（顺带缓解 1233 行超限，见 D-0）。
- **涉及文件**：新增 `composer_field.dart`；改上述四处。
- **验收**：
  - [ ] 频道发布/评论、朋友圈撰写均有表情面板与字数上限提示。
  - [ ] 频道正文超 280 字（消费侧折叠阈值 `channel_message_item.dart:394`）时撰写侧有提示，消除"生产/消费信息不对称"。
  - [ ] 四处输入行为一致（心智统一），`dart analyze lib` 零告警。
- **成本**：M。**留一个 widget 测试**：`ComposerField` 达 maxLength 时计数变警示色。

#### B-2 抽共享批量上传反馈 `MediaUploadTracker`（逐项进度 + 单项重试）
- **目标**：替换朋友圈与频道各自的"全局 spinner + 整批失败"为"逐张缩略图 + 各自进度/失败态 + 单项重试"。
- **落地**：
  1. 抽一个由 per-item completer 驱动的上传状态模型（每项：pending/uploading/done/failed + 原始 `AssetEntity`）。
  2. 朋友圈 `moment_create_page.dart:280-309,580-602`：选中即逐张占位入网格，各自转圈；失败项显示重试角标复用原 `AssetEntity` 重传。
  3. 频道 `channel_publish_bar.dart:229-255`：保留失败项，SnackBar 旁提供"重试失败项"，走现有 `_uploadConcurrency=3` 管道。
- **涉及文件**：新增上传追踪工具；改朋友圈与频道两处。
- **验收**：
  - [ ] 选 9 张图立即逐张出占位，各自独立进度。
  - [ ] 任一张失败可单独重试，不影响其余成功项。
  - [ ] 弱网下无"孤零零全局 spinner"体感。
- **成本**：M。

#### B-3 朋友圈可见性简单三态改 ActionSheet 原地选
- **问题**：三种无名单可见性仍整页跳转 + 拉标签网络请求。
- **落地**：`moment_create_page.dart:462-479` 参照同文件 `_showMediaPicker`（`:424-458`）的 `CupertinoActionSheet` 模式——公开/仅好友/仅自己原地选中即关闭；仅"部分可见/不给谁看"才 push `MomentFriendPickerPage`；后者的 `_loadFriends`/`_loadTags` 只在名单模式触发。
- **涉及文件**：`moment_create_page.dart`、`moment_friend_picker_page.dart`（延迟加载）。
- **验收**：
  - [ ] 简单三态原地选完，无跳转、无标签网络请求。
  - [ ] 名单模式仍跳整页且带上次记忆（回归第一轮 P1-1）。
  - [ ] 五种可见性与后端字段映射不变。
- **成本**：S。

---

### 🟢 批次 C｜接线半成品 + 数据保底

#### C-1 朋友圈草稿加 App 生命周期自动保存
- **问题**：切后台被杀/划掉 App 丢内容。
- **落地**：`_MomentCreatePageState` 实现 `WidgetsBindingObserver`，`didChangeAppLifecycleState` 到 `paused/inactive` 时防抖调已有 `buildMomentDraft` 落盘；`dispose` remove observer（勿重犯 A-1 同类泄漏）。
- **验收**：
  - [ ] 编辑中切后台再回来，文字/已选媒体恢复。
  - [ ] 划掉 App 重进，草稿仍在。
  - [ ] 发布成功后草稿清除。
- **成本**：S。

#### C-2 朋友圈 @提及真接线（消除假功能）
- **问题**：手打 @ 服务端收不到，是负体验。
- **落地**：
  1. 撰写区接入现成 `mention_list_widget`/`mention_provider`（聊天已用，`chat_page.dart:1312-1333`）。
  2. `moment_facade.createPost`（`moment_facade.dart:12-26`）与 `moment_api.createPost`（`moment_api.dart:19-47`）加 `mentions` 参数；发布时 `extractMentions(content)` 上报。
  3. ⚠️ **需确认后端 `createPost` 是否已接收/推送 `mentions` 字段**——若无则本项降级为"先移除误导性 @ 输入"，待后端补齐再接（避免继续维持假功能）。
- **验收**：
  - [ ] @ 触发好友下拉，选中正文高亮。
  - [ ] 被 @ 用户真实收到提醒（真机双端验证）。
  - [ ] 后端字段缺失时不留假功能。
- **成本**：M（含跨仓确认）。

---

### ⚪ 批次 D｜需后端配合 / 大改（立项后置，非本轮）

- **D-0**｜`chat_input.dart`（1233 行）按职责拆分——随 B-1 抽 `ComposerField` 后顺势拆语音/群工具/键盘动画，收敛到 800 行内。纯技术债，非交互直接可见。
- **D-1**｜频道多图合并"图文帖" + 图注——需改 payload 结构（复用 `imageMulti` 常量 `message_type_constants.dart:96,227`）+ 发布栏加图注框。**改动内容模型，需后端配合**。
- **D-2**｜频道发布后可编辑/撤回——`channel_service`/`channel_provider` 无 `editMessage`，删除重发会丢点赞/评论/阅读量。**需后端新增编辑 API**。
- **D-3**｜频道链接预览 / 付费段落（试读+流内解锁）——`ChannelMessageType.link` 常量在但无渲染分支（`channel_message_item.dart:369-392`），付费段落类型不存在。**需 og:meta 抓取 + 付费解锁链路**。
- **D-4**｜朋友圈话题 # / 位置——前端 UI + facade + api + 后端字段/索引/搜索全缺。**跨仓大改**。
- **D-5**｜删除/替换 `sticker_picker.dart` 占位组件为真实贴纸包，统一"表情"心智（A 批已先接可见 @，此项决定贴纸产品形态）。

---

## 4. 里程碑

| 里程碑 | 内容 | 完成标志 |
|---|---|---|
| M1（本轮首发） | 批次 A（A-1 真 bug + A-2/A-3/A-4） | 真机：群聊不再越用越卡、群工具直达创建、面板分组可感知、@按钮可见；analyze 零告警 |
| M2 | 批次 B（B-1 富输入 / B-2 上传反馈 / B-3 可见性原地选） | 三处输入一致、逐项上传反馈、可见性无跳转，真机回归 |
| M3 | 批次 C（草稿保底 + @真接线） | 任意退出不丢草稿、@ 真达；跨仓确认后端字段 |
| M4（后置） | 批次 D | 各项单独立项，需后端协同 |

**建议先做 M1**：A-1 是真 bug（越用越卡的根因），XS 成本、全群聊用户受益；A-2~A-4 兑现第一轮"群工具快捷发起"名不副实的部分。

---

## 5. 风险与回归清单

- **A-1 observer 改动** —— 务必保留 `initState` 首帧检查（`addPostFrameCallback`）与丝滑动画，只删 build 内重复注册。
- **B-1 抽组件** —— `ComposerField` 不得把聊天专属职责（语音/群工具/禁言态）带进频道/朋友圈；边界要干净。
- **B-3 延迟加载** —— 名单模式仍需正常拉好友/标签，勿误删。
- **C-2 假功能** —— 后端未接前，宁可移除 @ 输入也不留误导。
- **i18n 完整性** —— 新增键 10 语言同步（`dart run slang` 后无 `_missing`）。

---

## 6. 每项通用 DoD

1. 功能真机验证通过（iPhone 16e）。
2. `dart analyze lib` → No issues found!
3. 新文案 i18n 完整（zh-CN 源 + slang 生成，无硬编码）。
4. 无 Token 硬编码。
5. 相关既有功能回归无退化。
6. 非平凡逻辑留一个可跑校验（widget/单元测试）。
7. 变更走 DCO 提交（`-s`），conventional commits。
