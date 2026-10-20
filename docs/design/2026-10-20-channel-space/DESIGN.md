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

## 深层页面 / Deep resource pages

本轮延伸到群文件、任务列表/详情/创建编辑、群成员列表/详情、企业成员/资料/部门/邀请/工作区成员/治理/协作资源，以及频道创建/编辑/管理员/订阅者/邀请/订单。共用 ResourcePageLayout 仅统一内容宽度、列表和表单表现，保留原有权限、数据源、分页、路由、附件授权和危险操作确认。未声明所有业务页完成真机验收。

- 文件：名称优先，类别/大小/时间为次级信息；长文件名允许两行，上传与删除继续遵循原权限。图片预览保留全屏缩放空间，不受列表内容栏宽度限制。
- 任务：轻分段与分隔列表；底部创建/编辑表单提供清晰字段，键盘避让并支持滚动；无标题不可提交。
- 成员：弱化角色筛选；资料与管理操作分组，取消多个实心按钮竞争。
- 企业治理：企业信息、邀请、工作区、资源分组，保留成员与治理权限的独立边界。
- 频道管理：同宽表单与列表，不更改付费、邀请、管理员和订阅权限合同。

交互布局示意见 [deep-preview.html](./deep-preview.html)；原型样例数据为虚构，不能用来证明真实网络/业务流程通过。

References: [Slack resources](https://slack.com/help/articles/32562841868307-Add-and-manage-tabs-in-channels-and-direct-messages), [Teams files](https://support.microsoft.com/en-gb/teams/teams-channels/add-content-and-notes-to-a-team-in-microsoft-teams), [Telegram profiles](https://telegram.org/blog/new-profiles-people-nearby?setln=ms). These inform resource hierarchy and progressive disclosure, not new product capabilities.

## 个人频道补充收敛 / Personal channel refinement

频道列表改为轻量下划线 Tab（保留 48pt 触达），搜索提升到导航栏、创建仍在加号；头像 40pt、图文距 12pt，去重复箭头；无最新内容和简介时省略空副标题，不逐行重复“暂无简介”。详情页导航栏承接搜索，嵌入场景仍保留可达的内部搜索；阅读列和发布栏统一宽度。讨论失败使用低强调信息行与重试图标，日期去灰色胶囊；署名行的更多操作按真实行宽对齐右侧。图文消息使用正文摘要，继续服从既有内容访问控制。

## 部门与建群权限建议（待产品规则确认） / Department and creation proposal

部门浏览默认采用搜索、可回退路径、本级部门/成员列表；组织图仅辅助概览。现有通讯录已具备逐级下钻，应复用其状态机和权限，不另造全量树查询。deep-preview.html 的部门导航为可交互示意，并非已替换客户端组织图。

建议普通 active 企业成员在其已加入且有创建资格的工作区发起普通协作群；Guest、未加入工作区、企业或工作区归档等情况继续拒绝。正式部门群/全员群与企业频道由相应管理者创建。当前服务端群和频道复用 ensure_can_create_resource，因此频道管理员限制不能只靠 App 隐藏入口；本轮未改动后端权限，也未实现新的企业级开关或自动授予工作区资格。

References: [Feishu directory visibility and display order](https://www.feishu.cn/hc/zh-CN/articles/360049067480-管理员管理组织架构可见范围), [DingTalk department navigation origin](https://open.dingtalk.com/tools/explorer/jsapi?id=10309), [Lark create groups](https://www.larksuite.com/hc/zh-CN/articles/360024343993-创建群组). The proposed IMBoy policy is a product recommendation, not a claim that every referenced product has identical defaults.

## 频道链接、二维码与进入闭环（设计与审查，尚未实施）

本节是对当前源码的静态审查和下一轮设计，不表示这些功能已经补齐。范围为频道分享、二维码、文章与相邻资源入口；不将静态审查当作全站或真机验收。原型：[channel-share-preview.html](./channel-share-preview.html)。所有原型数据为虚构，二维码不可扫描，操作不写入剪贴板或发起外部分享。

### 页面与权限

个人与企业频道共用“频道链接”页：频道名称、归属、可见范围、可换行的地址、访问说明，下接发送给好友、复制链接、系统分享、频道二维码。个人公开频道可增加“分享到动态”；企业内部与个人私密频道默认不提供公开动态入口。详情导航提供链接按钮，资料页保留“频道链接与二维码”，更多菜单作为补充。动作采用同一列表栅格，不恢复大圆形按钮或装饰性卡片。

频道地址负责定位，邀请凭证负责授予加入资格，两者必须分开。普通链接与二维码不能自动加入企业、工作区或频道，不能替代购买权益。企业频道继续由服务端根据真实归属和当前账号校验资格；不根据本机当前空间推断、不自动切换全局工作区。外部分享默认不附企业正文摘要。若需要企业外发开关，须有对应服务端规则，不能虚构一个仅前端有效的开关。

二维码应编码与频道链接一致的资源定位意图。是否将现有七天临时码改为稳定频道码，需要随解析入口和权限一起落实；不要只把现有有效期提示删掉。临时邀请则单独显示有效期、可用状态和管理权限，撤销能力必须由服务端支持，不放置无效的“重置链接”按钮。

打开链接／扫码后的状态至少覆盖：

| 状态 | 期望行为 |
|---|---|
| 有访问权限 | 重新读取频道，再进入真实内容页；不根据转发卡片上的名称直接建立权限 |
| 未登录 | 登录后继续原目标，保留频道／文章标识；不是回无关首页 |
| 当前账号无权限 | 安全文案与切换账号入口；不先暴露企业内部详情，不自动发起企业加入 |
| 私密／付费 | 依实际 joinPolicy 和购买权益呈现邀请、审批或付费入口，不把链接当资格 |
| 临时邀请过期／撤销 | 提示邀请失效并说明获取新邀请的方式，普通频道地址不替代失效凭证 |
| 已归档 | 现有规则允许时只读；不允许时显示不可用，不一律假定可读或可加入 |
| 已删除／不可用 | 明确不可用和返回路径，避免无限加载／原始异常 |
| 取消系统分享／发送 | 不显示“分享成功”；复制成功只代表复制，不代表对方已能访问 |

### 已核实的缺口与落点

P0 为“发得出但进不去／动作承诺不真实”，P1 为状态与一致性缺口，P2 为后续效率提升。以下为当前源码证据，不是对部署环境的全面断言。

| 优先级 | 页面／链路 | 实施前证据（2026-10-20） | 需要补齐 |
|---|---|---|---|
| P0 | 频道链接页／分享面板 | [channel_overflow_menu.dart](../../../lib/page/channel/widgets/channel_overflow_menu.dart#L31)：链接行标成“分享”，实际只复制；没有系统文字分享入口 | 独立链接页，复制与系统分享分别命名；个人／企业共用 |
| P0 | 频道二维码 → 扫码进入 | [scanner_page.dart](../../../lib/page/scanner/scanner_page.dart#L238)：响应分支处理 user/group，没有 channel；服务端实际返回 type=channel | 增加频道解析与正确落地，失败也可返回／重试；跨账号验证 |
| P0 | 二维码菜单保存 | [channel_qrcode_page.dart](../../../lib/page/qrcode/channel_qrcode_page.dart#L296)：菜单将 id 强制 as String，分享入口传入的是数字 channel.id | ID 统一规范化；覆盖数字／字符串与无效 ID，不能只测字符串夹具 |
| P0 | 文章分享与独立打开 | [channel_article_page.dart](../../../lib/page/channel/channel_article_page.dart#L371) 的链接图标实际复制 contentPreview；[channel_routes.dart](../../../lib/config/router/routes/channel_routes.dart#L117) 未将 messageId 交给文章页重新加载，仅依赖 extra | 建立频道＋消息标识的文章定位；重启、登录后、收到名片后都能重新加载 |
| P0，待部署核验 | 对外 HTTPS 链接 | 分享拼接 WEB_BASE_URL/channel/id，但 [deep_link_router_bridge.dart](../../../lib/service/deep_link_router_bridge.dart#L65) 只接 imboy scheme 且桥接只在 Android 初始化；仓内未据此证明完整浏览器／iOS 唤起链路 | 对外落地页、App 唤起、未安装回退和登录继续共同验收；本次网页抓取失败，不能据此宣称线上 404 |
| P1 | 频道／群／个人二维码分享 | [repaint_boundary.dart](../../../lib/component/helper/repaint_boundary.dart#L21)：生成分享图片也检查存储权限并可能跳设置；频道分享提示为“扫码添加好友” | 图片生成与保存相册权限分离；分享取消／失败反馈一致；改为频道语义并检查同类群码 |
| P1 | 二维码有效期与状态 | [channel_qrcode_page.dart](../../../lib/page/qrcode/channel_qrcode_page.dart#L38)：每次 build 重新计算七天有效期 | 对临时码固定本次签发时间，明确刷新操作；与稳定资源链接分开，不宣称已有服务端撤销能力 |
| P1 | 企业名片与资源跳转 | [channel_share_payload.dart](../../../lib/page/channel/channel_share_payload.dart#L4) 无 scope／workspace 上下文，[message_channel_card_builder.dart](../../../lib/component/chat/message_channel_card_builder.dart#L111) 统一跳个人样式的 /channel/id | 以服务端资源归属解析正确展示壳与返回路径；卡片携带的信息不能成为权限证明 |
| P1 | 通知入口 | [channel_header_bar.dart](../../../lib/page/channel/widgets/channel_header_bar.dart#L77)：读取静音状态失败被吞掉，默认显示未静音 | 将未知／加载／失败与开／关分开；切换成功后回读，失败不伪装成正常状态 |
| P1 | 企业群创建入口 | [workspace_groups_page.dart](../../../lib/page/workspace/workspace_groups_page.dart#L35) 只有列表；创建主要集中在企业治理入口 | 若采用普通成员可建协作群的建议，应在已加入的工作区补创建入口；需联动真实资格与后端权限，不能自动授予成员身份 |

不把已存在的能力写成缺口：二维码保存失败反馈已集中在 RepaintBoundaryHelper.savePhoto；登录路由已有 pendingLocation；企业频道详情服务端已有成员访问检查。上述建议应复用它们，补上未连接的入口和状态，而不是重造一套。

### 十维静态暂评（仅本节范围，0–10）

分数用于排序改进工作，不是实机测量或上线分。保留现有系统字体、品牌蓝和轻列表，不增加渐变、无用途毛玻璃、装饰性圆角或营销大卡片。

| 维度 | 暂评 | 证据与具体改进 |
|---|---:|---|
| 色彩一致性 | 8 | channel_qrcode_page.dart:263 的链接型操作用品牌色；与全局规则统一为系统链接色，导出码保留白底黑字 |
| 字体层级 | 7 | channel_qrcode_page.dart:265 的固定行内文字；长名称与大字体需要自然换行和可滚动布局 |
| 间距节奏 | 7 | channel_qrcode_page.dart:59 的页面 24/32 间距与通用页不同；外层复用 16pt 栅格、导出卡单独内边距 |
| 组件一致性 | 6 | channel_overflow_menu.dart:31 与二维码页、文章面板各自呈现；收敛同一动作列表与准确命名 |
| 响应式 | 6 | channel_qrcode_page.dart:255 的固定高度横排按钮；补 320pt、2–3 倍字体、长翻译与桌面内容列检查，尚未定向复现 |
| 深色模式 | 8 | channel_qrcode_page.dart:96 的导出卡固定黑字是有意设计；外围控件随主题，保证码与分享图对比度 |
| 动效 | 7 | 现有系统路由和弹层可复用；需验证 modal → QR → 返回不丢上下文，未做实机动效验收 |
| 可访问性 | 6 | channel_qrcode_page.dart:326 的好友语义用于频道；按钮、读屏、长名称、复制反馈一起修正 |
| 信息密度 | 7 | channel_overflow_menu.dart:31 缺独立链接面；用身份＋访问说明＋分组动作代替更多装饰按钮 |
| 完整度 | 4 | scanner_page.dart:238、channel_routes.dart:117 的接收端断点；优先完成跨账号、冷启动、登录继续与失效反馈 |

### 参考与验收边界

- [WhatsApp 频道说明](https://faq.whatsapp.com/794229125227200/?cms_platform=web)：同一频道具备链接与二维码，分享至会话、动态或其他应用。参考其动作组织，不照搬品牌颜色和“持链接即可查看”的权限承诺。
- [Telegram 频道说明](https://www.telegram.org/faq_channels?setln=en)与[邀请链接 API](https://core.telegram.org/api/invites)：公开地址与私密邀请分开，邀请状态单独管理。产品机制不能机械套到 IMBoy 企业内部频道。
- [Slack 频道说明](https://slack.com/help/articles/360017938993-What-is-a-channel)：公开／私密仍依工作区语境理解；IMBoy 应使用自己的企业与工作区访问规则。

闭环验收以两个不同账号走通“链接／扫码／好友名片／动态 → 打开 → 登录继续 → 权限判定 → 真实频道或文章”为准，并覆盖失败、过期、归档、取消。网页落地和原生关联需独立验证；原型点击、URL 字符串单测、已有页面渲染均不能替代这些证据。本轮只完成审查与可交互设计，没有修改业务权限或宣称分享链路已实现。


### 频道分享实施边界

共用频道链接页已接入个人／企业频道详情、资料及菜单入口，区分复制、系统分享、发送给好友和二维码；个人公开频道可预填动态草稿，私有／企业频道不显示动态入口。文章转发复用已注册频道卡片，并携带文章标识；外部打开不再依赖 route extra。扫码识别本站链接及旧频道二维码，旧二维码保留七天有效期且单页内不随重建续期。导出图片不再申请相册权限，保存失败仍由原有相册保存层反馈。

新增单篇读取 API 复用内容权益及工作区边界检查，校验文章属于目标频道。企业资源展示壳由服务端最新频道归属决定，不切换全局空间，也不把转发数据视为授权。通知读取失败显示重试；切换成功后回读。

网页落地页与网站反向代理配置为仓内实现，未部署；Android 桥接增加本站频道 HTTPS 识别。iOS／macOS 保留区未修改，Universal Links、跨账号／未安装／真实扫码与系统分享仍需在部署候选及真机验证。不得据本地组件测试宣称线上链路已验收。企业群创建权限与普通成员创建入口属于独立业务调整，本轮频道分享实现不更改既有授权策略。
