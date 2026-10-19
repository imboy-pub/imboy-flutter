# P1 Inventory — 内容型频道详情（T01 勘察报告）

勘察基线（inbox 原稿）：integration HEAD `c61cd8d46e276496b2ddae8b89b17d6fe6856ddc`（=main 提交基线）。
方法：只读源码核对（C-BOOT-GIT 证据在 @runtime/evidence/T00/1/）；未运行应用、未占用设备。
判定词：NEEDS_FIX / VERIFY_EXISTING / BLOCKED_EVIDENCE。

## 0. 路由与真实父 shell

| 形态 | 路由 | 挂载 | 符号 |
|---|---|---|---|
| embedded | `/workspace/:workspaceId/channels/:channelId` | `workspace_routes.dart:178-186` → `WorkspaceChannelDetailPage(channelId)` | `lib/config/router/routes/workspace_routes.dart:179` |
| standalone | `/channel/:channelId` | `channel_routes.dart:53-62` → `ChannelDetailPage`（embedded=false，自带 GlassAppBar） | `lib/config/router/routes/channel_routes.dart:58` |
| 编译裁剪入口 | — | `compiledChannelDetailPage`（autoLoadStats:false） | `lib/config/router/generated_product_feature_routes.dart:92-93` |
| 真正父 shell | 工作区路由为根导航整页 CupertinoPage；企业体验 shell（`WorkspaceShellBootstrap`）经 ChatShellBootstrap 挂 `/bottom_navigation`（workspace_routes.dart 头注释 L12-14）；桌面 rail/框架见 `enterprise_shell_page.dart`（C06） | — | `lib/page/workspace_shell/enterprise_shell_page.dart` |

embedded 包装：`defaultWorkspaceChannelDetailEntry` = `ChannelDetailPage(autoLoadStats:false, embedded:true)`（`workspace_channel_detail_page.dart:126-131`）。

## 1. P1-01 消除重复头部 — **NEEDS_FIX**

- embedded 已收敛导航层：`ChannelDetailPage.embedded==true` 不渲染 GlassAppBar（`channel_detail_page.dart:162-168`）；`WorkspaceChannelDetailPage` 单 AppBar（标题+⋮+私聊，`workspace_channel_detail_page.dart:51-66`）；文档注释记录 2026-10-17 布局裁决（三层→一层）。
- **仍重复频道身份标题**：`ChannelHeaderBar` 渲染频道大标题 `widget.channel.name`（FontSizeType.large, w600, maxLines:2；`channel_header_bar.dart:140-149`），embedded 与 standalone 均在 AppBar 标题之外再现一次频道名 → 违反“频道身份标题1个”。
- 疑似双讨论入口（embedded 路由）：宿主 `_DiscussInGroupBanner`（`workspace_channel_detail_page.dart:69,80-122`）与内容页 `ChannelDiscussionEntry`（`channel_detail_page.dart:261-267` 引入；`channel_discussion_entry.dart:13-166`，microCommunityEnabled 才显示）可同时出现 → 两条“去讨论”通路，待 T10 结构裁决合并为一条。
- 既有测试：`workspace_channel_detail_page_test.dart`（无 ChatInput/横幅/群列表往返/默认内容区 5 例）。

## 2. P1-02 统计不是永久占位 — **VERIFY_EXISTING**

- `channel_header_bar.dart:122-123`：`stats?.subscriberCount ?? channel.subscriberCount` 直显兜底，无骨架；注释记录 2026-10-17 修复。
- embedded/编译入口均 `autoLoadStats:false`（`workspace_channel_detail_page.dart:129`、`generated_product_feature_routes.dart:93`）→ 不发统计请求，无 skeleton。
- 既有回归：`channel_header_bar_test.dart:47`「统计未返回时回退频道自带订阅数，不渲染永久骨架条」、`:76`、`:173`。
- **数据边界记录**：`subscriberCount` 为 `int`，`parseModelInt` 缺省解析为 0（`channel_model.dart:126,156,226`；`model_parse_utils.dart:22`），DTO 不保留 unknown presence → 展示层无法区分“0 订阅”与“未知”，按 PRD 记录边界、不重定义 0。

## 3. P1-03 错误能理解和恢复 — **NEEDS_FIX（文案/结构补齐）**

- 首屏错误：`channel_detail_page.dart:302-311` 与 `channel_message_feed.dart:518-531` 均走 `NoDataView(icon, text, retry)`；重试回调=原 `loadChannel`（一次点击一次重试 ✓）。
- error 内容为本地化友好文案（provider 侧 `t.common.loadError` / `t.channel.channelNotFound`，`channel_provider.dart:407,418,453`），**不含 raw exception/URL/Token** ✓。
- 缺口：未按 PRD 4.3 拆分「加载失败标题 + 安全说明」两段结构（现仅单 text；NoDataView 已支持 `description` 参数，`nodata_view.dart:16`）。分页失败保留已有内容：分页指示器为尾部 spinner（`channel_message_feed.dart:396-407`），未见分页错误态文案 → 待 T09 断言补齐。
- 分页失败具体视图未在本次静态勘察中定位到错误分支（loadMore 错误并入 state.error 且列表非空时不展示）→ 列为 T09 需验证项。

## 4. P1-04 动作可见且状态准确 — **NEEDS_FIX（缺回调回退空函数）**

- `_buildCircleActionItem`（`channel_header_bar.dart:351-427`）：48 圆形命中区（`AppSpacing.xxxLarge`）、`Semantics(label, button)`、pending→禁用+spinner、`isActive` 状态色，均存在 ✓。
- 静音为可切换状态（`_toggleMute`，`channel_header_bar.dart:90-113`，bell/bell_slash + isActive）✓；未迁移业务状态机 ✓。
- **缺口**：缺回调回退 `?? () {}`（`channel_header_bar.dart:232,251-252,260,267,304-307,340-341`）→ 无效点击表现为有效。需改为缺回调禁用/隐藏。

## 5. P1-05 讨论引导只有一个方向符号 — **NEEDS_FIX（译文箭头）**

- Banner 结构：icon + Expanded text，**无尾部 chevron**（`workspace_channel_detail_page.dart:100-116`）；整行单个 onTap 导航 ✓。
- **全部 10 个 locale 的 `workspace.discussInGroupGuide` 文案含箭头字符**（zh-CN:75、zh-Hant:52、en-US:53、ja-JP:52、ko-KR:51、fr-FR:45、de-DE:53、ru-RU:52、it-IT、ar-SA(←)；源文件 `assets/i18n/*/workspace.i18n.yaml`）→ 违反“翻译字符串不含箭头”。
- 既有测试：`workspace_channel_detail_page_test.dart:47,54`。

## 6. P1-06 工具区不常驻堆叠 — **NEEDS_FIX（默认展开）**

- `contentToolsAvailable`（`channel_message_feed.dart:53-56`）：microCommunityEnabled + managed/hasContentAccess；false 时整区隐藏 ✓。
- **默认常驻展开**：`enabled` 即渲染完整搜索框+标签输入+全部/精华分段（`channel_message_feed.dart:177-187` → `_buildPostFilters` L198-257），无展开/收起状态 → 违反“默认不显示标签/分段输入；一次点击展开”。
- 提交语义：搜索 onSubmitted / 标签 onSubmitted / 分段 onValueChanged 时 `_page=1` 重新查询（L213-251），query 清空即时复位（L205-211）✓ 不变约束保留。

## 7. P1-07 日期只属于实际内容 — **VERIFY_EXISTING**

- 日期分隔仅在消息 ListView 内按条渲染（`_shouldShowDate` L534-541；`if (showDate) _buildDateDivider` L418）；空态/加载/错误/搜索无结果走独立 NoDataView/spinner 分支（L263-381），**不含日期节点**。
- 需 T11 补充断言证据（空/无结果/加载/错误时日期分隔节点=0）。

## 8. 既有测试索引（P1 相关）

| 文件 | 覆盖 |
|---|---|
| `test/unit_test/page/workspace/workspace_channel_detail_page_test.dart` | 无 ChatInput、横幅存在、群列表往返、默认内容区、注入渲染 |
| `test/unit_test/page/channel/channel_header_bar_test.dart` | 统计兜底无骨架、pending 禁用、真实统计、暗色+动态字号、管理者动作、角色矩阵、统计口径、头像失败 |
| `test/unit_test/page/channel/channel_detail_layout_test.dart` | 内容/互动入口、说明与标签可达、单份角色徽标、空态动作路由 |
| `test/unit_test/page/channel/channel_message_feed_test.dart` | 访客/订阅者/已购买/管理者空态 CTA |
| `test/micro_community/micro_community_contract_test.dart` | 微社区功能门契约 |

## 9. 判定汇总

| 项 | 判定 | 一句话依据 |
|---|---|---|
| P1-01 | NEEDS_FIX | ChannelHeaderBar 仍渲染频道大标题（embedded/standalone 均重复）；疑似双讨论入口 |
| P1-02 | VERIFY_EXISTING | stats null→channel.subscriberCount 直显，无骨架；数据边界=缺省解析为 0 |
| P1-03 | NEEDS_FIX | 有图标+文案+重试且无敏感信息，但缺“标题+安全说明”两段结构；分页错误态待证 |
| P1-04 | NEEDS_FIX | 48 命中/状态/Semantics 齐；缺回调回退空函数造成假有效点击 |
| P1-05 | NEEDS_FIX | widget 无 chevron ✓，但 10 locale 文案全部带箭头字符 |
| P1-06 | NEEDS_FIX | 工具区默认常驻展开，无折叠态 |
| P1-07 | VERIFY_EXISTING | 日期节点仅在消息项内渲染；需补断言证据 |

未核验（设备依赖，MANUAL_PENDING 性质，不阻塞本卡）：运行时真机渲染、暗色截图、大字实测。
