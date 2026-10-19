# IMBoy 企业客户端 UI/UX：证据与取舍登记册

版本：1.1｜产品/源码资料核验日期沿用2026-10-18｜关联计划：`imboy-enterprise-uiux-v1`

## 1. 证据口径

本包使用本次公开官方资料和公开仓库源码核验结果，**不将先前“已启动深度研究”的回复视为已经取得的研究报告**。未登录并实测所有竞品客户端，也未在用户本机运行 IMBoy。官方文档中的操作位置可以支持结构判断，但不能据此补写未测量的行高、暗色值、版本截图或返回键数量。

- **【事实】**：官方材料或固定提交源码直接支持。
- **【设计】**：本 PRD 为 IMBoy 作出的可测试决策；有参考依据，但不是竞品原样照搬。
- **【推断】**：从事实推得的适配建议，不能写成竞品已实现。
- **【待确认】**：本轮无足够证据；不作为任务 PASS 的替代品。

## 2. 内容型频道比较

| 编号 | 产品/页面级事实 | IMBoy 采用的设计与理由 | 明确未证实/不适用部分 |
|---|---|---|---|
| R01 | Slack：从频道会话头部添加 Canvas 标签，也可设为默认；移动端点频道名进入编辑。[S01][S02] | 频道身份归导航层，内容/元信息分区。P1 只保留一个负责返回的导航头。 | Canvas 可有独立文档标题；不能宣称 Slack 从来没有外层标题+内层内容标题。Canvas 编辑器不适用于 IMBoy 发布流。 |
| R02 | Teams：右上角打开频道详情侧栏，承载描述、成员、贡献者及置顶内容；私有/共享频道只列频道人员。[S03] | 不把全部元数据堆在正文上方。P1 常驻仅头像、现有角色标签、已有订阅数；不新增成员清单。 | 未验证 standard/private 的全部移动端头部差异及像素高度；不复制 360 宽不可用的常驻侧栏。 |
| R03 | Lark：公告具有独立发送/管理流程及权限。[S04] | 保留“内容发布”与“讨论群”边界；讨论横幅只导向原群入口。 | 群公告≠独立内容型频道，不把群聊天输入框迁入 P1；公告头部高度待确认。 |
| R04 | Telegram：频道是广播，订阅者与群组成员概念不同。[S05] | P1 订阅数不改名“成员数”；管理/订阅/静音沿用现有角色状态。 | 不复制公开订阅分发、身份披露和私有链接政策；当前客户端的返回键/头像行精确结构未测量。 |
| R05 | Discord：Announcement 的 Follow 与 Publish 具有不同目的；设置有独立入口。[S06] | 高频状态操作与更多设置可以并存，但各自有名称、状态和回调；本次保留动作行，不迁移静音逻辑。 | Follow 是跨服务器分发，不等价于 IMBoy 订阅；不新增发布分发机制或权限。 |

**导航结论的边界：**没有证据支持“所有产品、所有平台都必须只有一层头部”。本项目禁止的是**同一频道的重复返回职责和重复频道身份标题**，并不禁止桌面全局 rail、工作区上下文或正文文章标题。元信息的高度、搜索/标签是否默认展开，均按 PRD 的 IMBoy 数值与行为验收，不假称测得竞品数据。

## 3. 企业入口页比较

| 编号 | 产品/页面级事实 | IMBoy 采用的设计与理由 | 未证实/不采用 |
|---|---|---|---|
| R06 | Lark 工作台 App List 与 Favorites 面向不同应用集合。[S07] | 按资源与应用分组；同一入口不因“办公/应用”命名差异重复。 | 不照搬全应用市场、收藏或排序功能；官方资料未证明其每行固定高度或禁止混合容器。 |
| R07 | 钉钉公开自定义工作台文档支持配置型工作台。[S08] | 配置型产品不存在单一可照抄排版；IMBoy 选择一套统一 inset 卡片。 | 手机/桌面终端行样式、图标间距及空组规则【待确认】，不作为尺寸事实。 |
| R08 | 企业微信开发者发布说明涉及工作台常用应用。[S09] | 工作台优先显示可进入的业务对象，而非内部调试地址。 | 本轮未完成指定版本工作台截图测量；不声称其单入口组一定隐藏标题。 |
| R09 | Teams 应用可固定在左栏；Slack Apps 有独立发现/管理入口。[S10][S11] | 图标+用户可读名称可用于应用导航；“打开应用”和“管理应用”不混成一个入口。 | 桌面左栏不是 360 宽移动工作台。不能推导出通栏列表/卡片哪种是行业唯一正确方案。 |

**容器决策：**不同语义内容可以采用不同容器；本轮证据不支持“同页禁止混用”的普遍断言。P2 的资源和应用都是导航入口，选择统一 inset 卡片是**本产品设计**。不加重复分组标题；空资源组不保留空卡片；有 Android 确认登录入口时，保留业务并统一容器。行高及间距见 PRD D04，不从截图估算。

## 4. 客服坐席比较

| 编号 | 产品/页面级事实 | 本项目字段优先级/结构决策 | 不可照搬与证据缺口 |
|---|---|---|---|
| R10 | Zendesk Views 按条件筛选工单，可配置列、分组和排序。[S12] | 队列状态与行的信息骨架分离；待接/处理中/已关闭共享客户标识→摘要→来源顺序。 | 不引入自定义视图、工单生命周期、批处理；没有证据支持 Zendesk 所有视图固定相同行高。 |
| R11 | Intercom 同一 Inbox 支持聊天/表格布局、状态过滤和主题；表格一行对应一个会话，列可配置。[S13] | 统一信息槽位但允许状态相关动作不同；1280 窗口保持既有 shell，不新建多列业务表格。 | 不复制分配/优先级/时区设置；文章没有给出本项目可直接引用的行高和未读配色数值。 |
| R12 | Freshdesk 列表明确显示来源渠道图标、联系人/主题/状态等，并有 Card/Inbox/Table。[S14] | 来源用图标+本地化名称，不向终端暴露 wire 枚举；摘要是辨识同名会话的重要信息。 | Freshdesk“主题”不等于末条消息摘要；SLA 必须有后端依据，不把等待时长任意染红；版本差异已在官方说明中提示。 |
| R13 | Chatwoot 更新记录说明会话列表可用末条消息类型图标区分回复与备注。[S15] | 只显示现有安全摘要；有可信类型数据才允许类型标签，当前默认不新增。 | 不因字段缺失解析原消息、猜测附件类型或增加逐行请求；本轮未测当前默认列表所有字段。 |
| R14 | 美洽顾客排队帮助页入口可访问，但未取得足够坐席列表正文。[S16] | 本轮不把美洽作为具体行高、颜色、末条摘要格式的支持证据。 | 详细队列字段、未读/等待/关闭态规则【待确认】；不得用访客 SDK UI 代替坐席 UI。 |

**时间、未读与隐私裁决：**厂商的“等待客户回复”“客服待接”“未分配”不能混为一个状态。IMBoy 保留既有等待时长格式。只有现有 DTO、解析、页面输入均能证明时间/未读语义时才允许显示；不能拿 `waitingSince` 当末条时间，不能从本页列表长度推导未读。三态必须调用同一掩码函数，读屏/tooltip 也不得恢复姓名。

## 5. 跨产品可执行结论

| 编号 | 依据 | IMBoy 约束 |
|---|---|---|
| R15 | Carbon Loading；当前 embedded 频道不自动请求统计。[S17][C01][C03] | 没有统计请求就不显示统计骨架。已知订阅数直接显示，未知省略，不伪造 0，不加计时器假装请求结束。 |
| R16 | Carbon 空态 anatomy 区分空数据、搜索无结果和错误；图与 CTA 可选。[S18] | P1 首屏错误固定“图标+标题+说明+重试”；无权限/只读空态不制造无效 CTA；分页错误不替换已有列表。 |
| R17 | W3C 非文本对比度与 Flutter 无障碍。[S19][S20][S21] | 可操作图标/状态视觉信息 3:1，普通正文4.5:1；统一48逻辑像素触控目标；2倍字不截断布局。禁用组件不是 WCAG 强制3:1，产品另要求可读标签及 disabled semantics。 |
| R18 | Git worktree 的共享仓库/独立目录和锁边界。[S22] | 续跑以持久化注册表定位原 worktree；额外进程锁负责写互斥；不能以 worktree lock 冒充写锁。具体恢复事务是本计划的工程设计。 |

## 6. 本次源码校正

研究提交仅用于溯源：`362240ce9a162e31fa2b710fdc06691bea663b48`。首次执行取本地真实已提交基线；不能以此 SHA reset、checkout 或覆盖现场。

| 原始问题 | 源码观察 | 本计划动作 |
|---|---|---|
| P1 三层导航 | 已有 embedded 单 AppBar；HeaderBar 仍有频道大标题。[C01][C02][C03] | 复验真实完整路由的导航层数，消除本页重复身份标题；不能仅测注入的假内容。 |
| P1 永久骨架 | HeaderBar 已使用频道自带订阅数兜底。[C03] | 增加“autoLoadStats=false 仍无永久骨架”回归；通过则 test-only，不重写统计流程。 |
| P1 双箭头 | 当前 banner 源码未见尾部 chevron。[C01] | 核对各语言文案后只保留一种指示，已有合规版本不重复添加。 |
| P2 办公/URL/容器 | 已移除办公列表及 URL 副标题，资源和应用已 insetGrouped。[C05] | 验证现状，保留正确实现；确认隐藏 URL 不等于已替换联调目的页。 |
| P2 裸文本行 | shell 当前资源构建已出现多个图标。[C06] | 验证全部实际可见行和暗色/大字，不宣称仍全是裸文本。 |
| P3 缺摘要 | active/closed 已调用队列摘要函数。[C07][C08] | 优先补回归证据和统一槽位；字段不可用不伪造摘要。 |
| P3 原枚举 | widget 已改 Web；其他非空原值仍可能外露。[C07][C08] | 加入可读名称映射与未知值安全兜底，wire 值不变。 |

## 7. 公开来源目录

以下均于 2026-10-18 核验链接/可读取内容；“待确认”来源只证明入口存在，不证明未取得的页面行为。

### S01 · Slack｜Use a canvas in Slack

来源：[Slack｜Use a canvas in Slack](https://slack.com/help/articles/203950418-Use-a-canvas-in-Slack)。

支持范围：频道标题区域可添加 Canvas 标签；可将 Canvas 设为默认展示；独立 Canvas 列表有搜索及更多操作。

### S02 · Slack｜Rename a channel

来源：[Slack｜Rename a channel](https://slack.com/help/articles/201654073-Rename-a-channel)。

支持范围：移动端从会话头部频道名进入编辑流程；不能据此推导所有版本只有一层头部。

### S03 · Microsoft Teams｜Show channel info

来源：[Microsoft Teams｜Show channel info](https://support.microsoft.com/en-gb/teams/teams-channels/show-channel-info-in-microsoft-teams)。

支持范围：频道右上角打开详情侧面板；描述、成员、贡献者和置顶内容在面板中；私有/共享频道只显示其频道人员。

### S04 · Lark｜Send and manage group announcements

来源：[Lark｜Send and manage group announcements](https://www.larksuite.com/hc/en-US/articles/360024356913-send-and-manage-group-announcements)。

支持范围：公告有发送和管理入口及权限设置；不是独立内容频道布局的完整证据。

### S05 · Telegram｜Channels FAQ

来源：[Telegram｜Channels FAQ](https://telegram.org/faq_channels)。

支持范围：频道用于广播，发布者、管理员、订阅者与群组讨论概念有区别；FAQ 不提供移动端像素尺寸。

### S06 · Discord｜Announcement Channel FAQ

来源：[Discord｜Announcement Channel FAQ](https://support.discord.com/hc/en-us/articles/360032008192-Announcement-Channel-FAQ)。

支持范围：Announcement 有 Follow，并支持 Publish 向关注的服务器分发；频道设置与发布动作分开。

### S07 · Lark｜Admin: Use the App List block

来源：[Lark｜Admin: Use the App List block](https://www.larksuite.com/hc/en-US/articles/143562534080-admin-use-the-app-list-block)。

支持范围：Favorites 面向常用应用，App List 面向应用列表；说明功能分组，不证明固定卡片尺寸。

### S08 · 钉钉｜自定义工作台文档入口

来源：[钉钉｜自定义工作台文档入口](https://open.dingtalk.com/document/dashboard)。

支持范围：官方支持配置工作台；本轮未取得可测量的终端行结构证据，具体容器与尺寸待确认。

### S09 · 企业微信｜官方开发者 App Store 页面

来源：[企业微信｜官方开发者 App Store 页面](https://apps.apple.com/us/app/%E4%BC%81%E4%B8%9A%E5%BE%AE%E4%BF%A1/id1087897068?l=zh-Hans-CN)。

支持范围：开发者发布说明涉及工作台常用应用；版本截图不能自动代表所有平台/租户；未进行像素测量。

### S10 · Teams｜Pin an app

来源：[Teams｜Pin an app](https://support.microsoft.com/en-us/teams/apps-service/pin-an-app-in-microsoft-teams)。

支持范围：应用可固定到左侧应用栏并调整位置；侧栏不是移动端工作台列表。

### S11 · Slack｜Add apps to your workspace

来源：[Slack｜Add apps to your workspace](https://slack.com/help/articles/202035138-Add-apps-to-your-Slack-workspace)。

支持范围：通过 Agents & tools / Apps 等入口发现和添加应用；不同导航版本可能不同。

### S12 · Zendesk｜Creating views

来源：[Zendesk｜Creating views](https://support.zendesk.com/hc/en-us/articles/4408888828570-Creating-views-to-build-customized-lists-of-tickets)。

支持范围：Views 按条件组织工单，可排序、分组和配置列；不是统一固定行高的依据。

### S13 · Intercom｜The Inbox explained

来源：[Intercom｜The Inbox explained](https://www.intercom.com/help/en/articles/6258745-the-inbox-explained)。

支持范围：2026-09-17 文档：会话表格列可配置，支持聊天/表格布局切换、状态过滤、主题切换。

### S14 · Freshdesk｜Understand the Ticket List View

来源：[Freshdesk｜Understand the Ticket List View](https://support.freshdesk.com/support/solutions/articles/37559-understand-the-ticket-list-view)。

支持范围：2025-12-05 文档：Card/Inbox/Table 三种布局；条目包括来源图标、联系人、主题、状态等；不同版本体验可能不同。

### S15 · Chatwoot｜Changelog

来源：[Chatwoot｜Changelog](https://www.chatwoot.com/changelog)。

支持范围：公开更新记录说明会话列表增加末条消息类型图标以区分回复/内部备注；本轮不据此断言当前默认行高。

### S16 · 美洽｜顾客排队帮助入口

来源：[美洽｜顾客排队帮助入口](https://www.meiqia.com/help/article/customer-queuing/)。

支持范围：本轮可访问帮助入口，但没有取得足以验证坐席列表字段、颜色、行高的正文；页面级细节待确认。

### S17 · Carbon｜Loading

来源：[Carbon｜Loading](https://www.carbondesignsystem.com/building-blocks/core/patterns/loading)。

支持范围：骨架屏属于加载反馈；不能把没有进行中的请求解释为持续加载。

### S18 · Carbon｜Empty states

来源：[Carbon｜Empty states](https://www.carbondesignsystem.com/building-blocks/core/patterns/empty-states)。

支持范围：空态包含简短标题和说明；图片及操作可选；区分首次无数据、搜索无结果和错误；替代不存在的数据容器。

### S19 · W3C｜Understanding Non-text Contrast

来源：[W3C｜Understanding Non-text Contrast](https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html)。

支持范围：有意义的可操作控件视觉信息通常需与相邻颜色达到 3:1；不可用控件有例外，不能宣称禁用图标强制达到 3:1。

### S20 · Flutter｜Accessibility testing

来源：[Flutter｜Accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing)。

支持范围：提供可测试的触控目标、标签和对比度检查方法；自动测试不能替代真实读屏验证。

### S21 · Flutter｜Accessibility UI design and styling

来源：[Flutter｜Accessibility UI design and styling](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling)。

支持范围：涉及文本缩放、文本对比度以及 Android 48 / iOS 44 的目标尺寸建议；本 PRD 统一选择 48。

### S22 · Git｜git-worktree

来源：[Git｜git-worktree](https://git-scm.com/docs/git-worktree)。

支持范围：worktree 有独立工作目录/HEAD/index，共享仓库公共数据；worktree lock 防清理/移动，不是并发写互斥锁。

## 8. 源码来源目录

文件范围为本次实际读取/定位区块，不是全仓审计。

### C01 · `lib/page/workspace/workspace_channel_detail_page.dart`

[固定提交文件](https://github.com/imboy-pub/imboy-flutter/blob/362240ce9a162e31fa2b710fdc06691bea663b48/lib/page/workspace/workspace_channel_detail_page.dart)；区块：`WorkspaceChannelDetailPage / defaultWorkspaceChannelDetailEntry / _DiscussInGroupBanner`。

观察：已存在 embedded:true、autoLoadStats:false；外层 AppBar；当前 banner 未见尾部 chevron。

### C02 · `lib/page/channel/channel_detail_page.dart`

[固定提交文件](https://github.com/imboy-pub/imboy-flutter/blob/362240ce9a162e31fa2b710fdc06691bea663b48/lib/page/channel/channel_detail_page.dart)；区块：`ChannelDetailPage / build / _loadStats`。

观察：embedded 时无自身 AppBar；频道加载、未读清零、统计请求和发布栏保持原样。

### C03 · `lib/page/channel/widgets/channel_header_bar.dart`

[固定提交文件](https://github.com/imboy-pub/imboy-flutter/blob/362240ce9a162e31fa2b710fdc06691bea663b48/lib/page/channel/widgets/channel_header_bar.dart)；区块：`ChannelHeaderBar.build / _buildActionRow`。

观察：仍渲染频道大标题；统计已使用 stats ?? channel.subscriberCount；部分缺回调动作回退空函数。

### C04 · `lib/page/channel/widgets/channel_message_feed.dart`

[固定提交文件](https://github.com/imboy-pub/imboy-flutter/blob/362240ce9a162e31fa2b710fdc06691bea663b48/lib/page/channel/widgets/channel_message_feed.dart)；区块：`_buildPostFilters / contentToolsAvailable / _filter`。

观察：搜索、标签、精华筛选存在；保留微社区功能门、提交时机、过滤参数和分页。

### C05 · `lib/modules/enterprise_oa/presentation/enterprise_workbench_page.dart`

[固定提交文件](https://github.com/imboy-pub/imboy-flutter/blob/362240ce9a162e31fa2b710fdc06691bea663b48/lib/modules/enterprise_oa/presentation/enterprise_workbench_page.dart)；区块：`build / _openApps / _issueBridgeAuthCode`。

观察：已删除办公列表及 URL 副标题，使用 insetGrouped；appsUrl 仍指向 test_oa.html；Android 确认登录入口存在。

### C06 · `lib/page/workspace_shell/enterprise_shell_page.dart`

[固定提交文件](https://github.com/imboy-pub/imboy-flutter/blob/362240ce9a162e31fa2b710fdc06691bea663b48/lib/page/workspace_shell/enterprise_shell_page.dart)；区块：`_page / _resourceEntry / _frame`。

观察：资源由 enterprise shell 注入，当前已出现项目/群组/频道图标；保留工作区与 feature 条件及桌面 rail。

### C07 · `lib/modules/customer_service/presentation/cs_queue_view.dart`

[固定提交文件](https://github.com/imboy-pub/imboy-flutter/blob/362240ce9a162e31fa2b710fdc06691bea663b48/lib/modules/customer_service/presentation/cs_queue_view.dart)；区块：`_QueueTile / csQueuePreviewText / _claim`。

观察：已有安全摘要展示；widget 显示 Web，其他 source 仍可能直接显示；接单/CAS/刷新禁止变更。

### C08 · `lib/modules/customer_service/presentation/cs_session_list_view.dart`

[固定提交文件](https://github.com/imboy-pub/imboy-flutter/blob/362240ce9a162e31fa2b710fdc06691bea663b48/lib/modules/customer_service/presentation/cs_session_list_view.dart)；区块：`_SessionTile / _open`。

观察：active/closed 共用摘要函数；姓名已走掩码；来源仍有原值回退。

### C09 · `lib/modules/customer_service/domain/cs_seat_gate.dart`

[固定提交文件](https://github.com/imboy-pub/imboy-flutter/blob/362240ce9a162e31fa2b710fdc06691bea663b48/lib/modules/customer_service/domain/cs_seat_gate.dart)；区块：`csMaskContactName / csEntryVisibleFromContexts`。

观察：姓名掩码与坐席权限门是既有规则，本计划只调用，不改算法。

### C10 · `lib/theme/default/app_spacing.dart`

[固定提交文件](https://github.com/imboy-pub/imboy-flutter/blob/362240ce9a162e31fa2b710fdc06691bea663b48/lib/theme/default/app_spacing.dart)；区块：`AppSpacing`。

观察：已核实 4/8/12/16/20/24/32/48 的间距 Token。

### C11 · `lib/theme/default/app_breakpoints.dart`

[固定提交文件](https://github.com/imboy-pub/imboy-flutter/blob/362240ce9a162e31fa2b710fdc06691bea663b48/lib/theme/default/app_breakpoints.dart)；区块：`AppBreakpoints`。

观察：已核实 mobile=600、wide=900、ultraWide=1200；不新增冲突的导航断点。

## 9. V1.1工程补核（2026-10-19）

本次质量复核没有重新读取用户Mac，也没有宣称上述研究SHA是本机最新代码。竞品未测量项目仍保留【待确认】，不为达到评分编造截图或像素。

| 工程来源 | 已补核事实 | 设计落点 |
|---|---|---|
| [Git worktree](https://git-scm.com/docs/git-worktree) | worktree拥有独立工作目录/HEAD/index；lock防清理/移动/删除，不是并发写锁。 | 保留原worktree登记，另建短事务锁与admission；不因worktree lock就允许多个执行器并写。 |
| [Flutter matchesGoldenFile](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html) | golden可更新；字体/Flutter版本/OS不同可能改变渲染；默认Ahem并非正常中文字形。 | 固定渲染环境，update与review分开，缺字体不得签视觉验收。 |
| [Flutter accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing) | 提供触控目标、标签、文本对比度的自动检查；原生还有相应检查方式。 | 结构/语义/对比自动断言与真机读屏分别记账。 |

PREPARE/snapshot/COMMIT、固定候选K和报告R、缺图失败、有限重试等属于本计划工程设计，不是以上产品官方对本项目作出的保证。
