# 频道与空间切换设计提案 / Channel and Space Proposal

状态：已接入 Flutter，主要入口、布局与共享组件已实现；深层原型不等于全部业务交互已重写，不构成真机验收。遵循仓库根 DESIGN.md，本提案不替换全局规范。示例为虚构数据。
Status: primary Flutter entries, layouts and shared components are implemented; deep prototype screens do not imply every business interaction was rewritten or device-accepted. Root DESIGN.md remains authoritative. All sample data is fictional.

## 方向 / Direction

内容优先、原生排版、操作渐进呈现。保留品牌蓝、四栏导航、现有频道权限及发布能力；不增加装饰卡片、渐变或新业务流程。
Content first, native typography, progressive disclosure. Retain brand blue, four-tab navigation, permissions and publishing; avoid decorative cards, gradients and new business flows.

## 三个页面 / Three surfaces

- 频道入口：名称与最新内容是主要信息；时间显示内容时间，不误用频道 updatedAt。订阅人数放入资料页。无最新内容时使用简介或“暂无内容”，缺少未读数据不造未读角标。公开图标不每行重复，私密状态保留可访问说明。保留“已订阅／我管理的”筛选，创建与发现进入加号菜单；原型使用复选框演示管理筛选，正式端复用现有双 Tab 数据加载与权限逻辑。
- 频道详情：标题与订阅数合并进紧凑导航；点击标题进入资料。移除正文上方四个圆形操作。管理放资料页；通知放更多菜单；发送给好友与系统分享合并为分享面板的不同选项。搜索按需展开，并保留标签、精华筛选及返回后的阅读位置。内容保持 feed，不转成聊天气泡；时间不重复，点赞、评论与分享保留。原型的置顶条仅展示有效置顶数据时出现。
- 空间切换：“我”页入口为“当前空间：IMBoy / 切换”；选择页叫“切换空间”，分为个人空间与企业空间。企业角色为次级信息，创建与加入弱化到底部。选择后切换，成功才更新当前标记与返回，失败保留原空间并允许重试。切换影响范围须核实当前实际机制，不宣称所有消息或个人资料均隔离。企业详情入口按实际落点用“企业信息”或“我的企业”，不称“切换账户”。

- Channel list: prioritize name and latest content; timestamps refer to content, not channel updatedAt. Counts live in info. Fall back to description or empty copy; never fabricate unread state. Retain private visibility semantics, subscribed/managed filtering and existing loading. Prototype checkbox demonstrates filtering; production should reuse the current tabs.
- Channel reading: compact navigation; title opens info. Management lives in info, notification in overflow, forwarding and system sharing in a common share sheet. Search reveals existing tag/essence tools on demand and restores reading position. Retain feed presentation and reactions. Pinned strip appears only with actual pinned content.
- Space switcher: explicit current-space entry, separate personal and enterprise groups, secondary roles, subdued join/create actions. Update selection only after successful switching; retain old context on failure. Verify actual switching scope before explaining data separation. Enterprise info and account switching remain distinct concepts.

## 状态与约束 / States and constraints

| 场景 / State | 行为 / Behavior |
|---|---|
| 普通订阅者 / Subscriber | 阅读与允许的互动；隐藏发布栏 / Read and permitted reactions; no composer |
| 可发布成员 / Publisher | 按 canPublish 显示紧凑发布栏；保留媒体、文章、草稿与失败重试 / Compact composer by canPublish; retain media, articles, drafts and retries |
| 未订阅 / Visitor | 依现有规则显示订阅、申请或邀请，不显示发布栏 / Existing subscribe, approval or invite policy; no composer |
| 付费与私密 / Paid and private | 保留现有付费墙、权限、受限分享与退出规则 / Preserve paywall, access controls, restricted sharing and exit rules |
| 空、加载、失败 / Empty, loading, failure | 完整空态；首载骨架；有缓存时保留内容并局部重试，明确失败来源 / Explicit empty state, initial skeleton, cached content with scoped retry |
| 统计失败 / Stats failure | 显示已有可信计数或未知，不在正文上方孤立展示“重试” / Trusted cached count or unknown, no orphan retry button |
| 搜索 / Search | 只展示当前能力范围；保留已生效筛选提示和一键清除 / Respect available search scope; visible active filter and clear action |
| 切换中 / Switching | 防重复点击；失败保留原状态；有未保存内容时提示 / Prevent duplicate requests, preserve state on failure, guard unsaved work |
| 大字、暗色、窄屏 / Accessibility | 动态字号与多行布局；44pt 以上触达；遵循全局暗色映射 / Dynamic type, wrapping, 44pt+ targets and global dark palette |

## 现有实现映射 / Implementation map

- `lib/page/channel/channel_list_page.dart`：列表与订阅／管理分页。频道 model 不承载最新内容；通过账号绑定的 provider 批量读取消息仓库缓存，缺失时用简介，不伪造未读数。
- `lib/page/channel/channel_detail_page.dart`、`widgets/channel_header_bar.dart`：紧凑标题、元信息与操作入口。保留 embedded 宿主导航兼容。
- `widgets/channel_message_feed.dart`：搜索／筛选、异常来源与内容滚动；不能把现有双滚动问题当纯视觉问题绕过。
- `widgets/channel_publish_bar.dart`：保留当前发布与附件能力，按权限收敛外观。

The files above own list, header, feed and composer behavior. Latest preview/unread needs verified aggregation; avoid per-row network calls. Preserve embedded navigation and existing publishing, search and access contracts.

## 参考与取舍 / References and adaptation

- [Telegram Channels FAQ](https://www.telegram.org/faq_channels?setln=en)：频道广播、可选评论；借鉴阅读与讨论分工，不照搬聊天气泡。
- [WhatsApp Channels](https://blog.whatsapp.com/introducing-whatsapp-channels-a-private-way-to-follow-what-matters)：关注更新与频道目录；借鉴订阅内容与发现入口的分工。
- [Slack Join a channel](https://slack.com/help/articles/205239967-Join-a-channel)：浏览与搜索频道；借鉴名称／描述查找，不照搬桌面侧栏。

Official references inform information architecture, not a claim of pixel-level visual benchmarking. Browser automation was unavailable; official pages were researched through web search. Prototype uses existing IMBoy tokens and original layout.

## 验证边界 / Validation

本轮包含原型与 Flutter 主要界面实现；未执行提交或部署。原型菜单、资料、筛选、选择与本地草稿可演示；搜索、发布、分享、加入和创建不接后端。静态检查不能替代浏览器渲染与 Flutter 真机检查。正式实现需覆盖频道角色／订阅／付费／私密状态、空间切换失败、大字号、暗色及恢复阅读位置。
Design prototypes and primary Flutter UI implementation are included; no commit or deployment was performed in this chat. Menus, info, selection, filtering and local draft are demonstrable. Search, publishing, sharing and join/create are unbound. Static validation does not replace browser rendering or Flutter device acceptance.


## 企业、群聊与工作台补充 / Enterprise, groups and workbench

本轮原型与 Flutter 实现并存，沿用原有业务流程与权限；已有 WIP 在共享工作区内保留。入口：`enterprise-preview.html`、`group-preview.html`、`workbench-preview.html`；`design-preview.html` 保留频道与空间联动。
Prototypes accompany Flutter implementation; existing flows, permission checks and shared-workspace WIP are preserved. All four previews link to one another.

### 当前空间、归属与访问范围 / Context, ownership and access

频道原型选择个人／企业后，列表、阅读标题、资料与“我”页入口同步变化。个人场景展示订阅企业公开频道，企业场景展示企业内部频道及可发布角色。归属与权限分别说明；不可据所处空间猜测频道可见性。
现有 `organization.i18n.yaml` 和企业治理实现将企业频道限定为免费、非公开、经工作区订阅。本次企业示例遵循这一约束；企业公开频道仅为个人场景中的发布主体示例，不代表当前企业托管频道已支持公开发布。正式实现不得新增该能力。
Channel context follows prototype space selection. Ownership and visibility are separate. Existing enterprise-managed channels are free and non-public with workspace subscription; a corporate publisher in the personal public-channel example does not imply enterprise-managed public publishing support.

### 企业概览与子页面 / Enterprise hierarchy

- 概览保留四个资源入口：通讯录、企业群、企业频道、协作空间。去掉长 Workspace 编号及技术性权限说明，企业资料中保留名称、角色、状态与可理解的默认工作区信息。
- “工具”和“企业协作工具”合并为“协作空间”，限定当前企业下我已加入／有权访问的工作区。全局跨企业选择仍保留，不能把合并入口做成越权资源全集。
- 通讯录覆盖部门逐级浏览、成员资料、邀请；协作覆盖工作区、项目、任务与现有协作入口；管理覆盖成员、部门、邀请、资源、客服与归档。
- 普通成员隐藏管理中心；管理员场景演示额外入口。工作区所有者、企业所有者的独立权限继续由既有规则裁决，不能简化成单个 admin 布尔值。
- 当前群／频道入口实际跳企业管理页，普通成员体验存在歧义。提案改成进入有权资源列表，落地须核对路由、查询权限与缺少工作区时的明确空态，不能只改文案。
- 退出企业放企业资料底部，明确影响后确认；企业所有者依既有移交规则处理。账号删除预检移到账户设置语境，称“注销前检查”。状态不可用时不呈现通过。

Overview uses four resource entries; tools unify under enterprise-scoped collaboration. Directory and collaboration lead into existing child flows. Management is role-scoped, preserving separate workspace/enterprise ownership rules. Fix misleading management destinations with verified readable-resource routes. Exit remains explicitly confirmed; account deletion checks belong to account settings.

### 群聊与子页面 / Group hierarchy

- 标题简化为“群聊”；不把当前加载数量冒充总数。保留全部／我加入／我管理／我创建四个现有查询语义，降低视觉重量，不自行合并角色集合。筛选为空时保持所选状态，不静默切回全部。
- 原顶部放大镜实际是公开群发现，列表搜索是本地群名过滤：分别明确为“发现群聊”和“搜索已加载的群名”。刷新收进菜单，触控仍保留下拉，桌面／读屏不失去刷新入口；刷新继续触发现有成员关系修复。
- 列表点击仍先进入聊天，聊天更多再进群资料。相同群名辅以可信归属／工作区信息；当前个人 GroupModel 无企业归属字段，正式落地先核实企业工作区映射与批量来源，不臆造或逐项网络查询。缺失时用已有成员数与备注等可信信息，必要时详情保留可区分标识。
- 群资料将九宫格收敛为成员与公告／内容／协作／个人设置分组，保留公告、文件、相册、投票、日程、任务、标签、二维码等现有入口。
- 子页面包含成员与管理、公告阅读／编辑、文件预览、相册／照片、投票、日程、任务及编辑、标签、昵称、备注、搜索、发现、发起、面对面建群、个人分组及危险操作说明。深层页面为流程与字段布局示意，未仿真全部业务交互。
- 成员、管理员、群主三种预览身份分开。端到端加密仅按功能开关展示，开启不可逆、仅群主确认，不设计成可逆 toggle。所有写动作仍以服务端权限为准。

Group filters retain current query semantics. Local name filtering differs from public discovery. Refresh preserves membership repair. List opens chat before info. Same-name disambiguation requires verified metadata absent from the personal GroupModel. Existing child capabilities remain grouped; deeper screens express layout and flow, not full behavior simulation. Separate member/admin/owner rights and irreversible owner-only E2EE activation.

### 工作台一致性 / Workbench alignment

`workbench-preview.html` 统一行布局为 16pt 内边距、32pt 图标容器、24pt 图标、12pt 图文间隔与 20pt 箭头列；分隔线对齐正文起点。客服入口复用同一行结构，有副标题时不改变左右坐标。桌面内容最大 680px，窄屏保留 16pt 外边距。度量说明仅用于设计评审，正式页面不显示。
明确企业与工作区各自归属，替换含混的“IMBoy · IMBoy”；二者同名时使用层级标签。客服资格来自既有有效坐席上下文；项目按开关，应用按实时配置与授权，工作区资源按当前工作区存在与资格展示。客服工作台与客服治理保持独立。
`EnterpriseWorkbenchPage`、宿主资源行及客服入口已统一复用 `ResourceEntryTile`；客服资格判定与点击目标保留。

Workbench shares one row grid across all entries, with identical icon, text, separator and chevron alignment. Context names reflect enterprise/workspace hierarchy. Existing seat, feature and application gates remain. Host and injected entries share ResourceEntryTile while preserving seat eligibility and existing WIP.

### 原型检查 / Prototype checks

所有示例为虚构数据。完成 HTML 链接目标、重复 ID、文档引用、JSON 格式及 diff 空白检查。浏览器控制连接失败，尚未验证实际渲染、动态字体、触屏或 Flutter 真机；CSS 暗色与窄屏规则只是设计实现，不能视为验收通过。
Fictional examples only. Static checks cover HTML link targets, unique IDs, document references, JSON and whitespace. Browser control failed; rendered appearance, dynamic type and real-device behavior remain unverified.
