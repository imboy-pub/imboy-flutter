# imboyapp 交互体验第三轮 —— 实施批次计划

**当前进度：下一个待实施批次 = 批1（全部批次 TODO，0/6 完成）**

> 创建：2026-07-16。来源：① `2026-07-10-fullapp-uiux-audit-v2.md` §0.0「⏳ 仍待后续」；② 2026-07-16 真机全量点击 QA 遗留；③ 2026-07-14 真机深度 QA 遗留。
> 所有 文件:行号 均已在 2026-07-16 用 grep/read 逐条核实，非凭空引用。行号会随前序批次实施漂移，实施时以「文件+锚点描述」重新定位。
> 批次串行执行（每批一个会话一个 commit）；批内条目文件不重叠可并行，批间少量重叠依赖串行顺序消解。SR-5 机械替换单独成批放最后，实施时以当时 grep 命中为准。

---

## 调查结论摘要（写批次前已核实的事实）

**两项遗留问题已在代码层根治，本轮无需实施，仅真机回归：**

| 遗留项 | 核实结论 |
|---|---|
| 日期 EEEE 无 locale 英文星期 | 全仓 `DateFormat` 已无任何语言性 pattern（EEEE/MMM 等），全部数字 pattern 并留规避注释（`lib/component/helper/datetime.dart:25`、`lib/component/helper/user_online_time_helper.dart:155`）；vendored flyer_chat 组件的 timeFormat 由项目侧 `RelativeDateFormat` 注入。**已根治，批7 真机回归即可。** |
| 收藏 uri 快照过期 | 收藏已存 object_key（`user_collect_provider.dart:1163` 存 `msg.source`=object_key），读取经 `normalizeCollectUri`（`user_collect_provider.dart:42-48`）归一后走 `cachedImageProvider` 渲染时现签。**已根治**；残留=旧完整 URL 快照兜底与 `user_collect_provider.dart:375` 缺 errorBuilder，并入批2。 |

**根层组件已存在（前两批已建），本轮只做调用方迁移/接线：**

- `AppBreakpoints` 已统一（`lib/theme/default/app_breakpoints.dart`，5 处调用方已接：contact/conversation/bottom_navigation/app_router/web_shell_breakpoint）→ B7 只剩 hover/右键/快捷键。
- `getIosOrange/getIosPurple/getTextSecondary(Brightness)` 已存在（`lib/theme/default/app_colors.dart:218-235`）→ SR-5 只剩调用方替换。
- `AsyncStateView` 已存在 → service 三态只需 service 层传出错误 + 页面消费。
- 撤回/编辑「需 debug 包定位」已免：双缺口已静态锁定（见批1）。
- 群主禁言/设管理员「产品缺口需新增页」不成立：`group_member_detail_page.dart` 已实现完整管理（禁言 `:83/:118`、设管理员 `:474`、移出 `:492`），仅入口断链（见批2）。

**排除项（按用户指令不入批次）**：§0.5 聊天气泡渲染类（等 AI Agent 路线图）；后端 #12 投票计数、群文件/群作业（imboy 59aedd4d 未部署）；#5 设备名（后端）。

---

## 批1｜聊天核心链路根修（共享 service/组件层） — 状态：TODO

**真机验证：未验证**

| # | 条目 | 文件:行号（已核实） | 影响 | 成本 | 范围 | 状态 |
|---|---|---|---|---|---|---|
| 1.1 | 撤回/编辑发起方 ack 后 UI 不更新——**双缺口**：(a) `_receiveServerAck` 收到回执只 remove-retry + status→sent，从不调 `convertMessageToRevoked`/应用编辑，DB 撤回态(31)永不写入；(b) `message_revoke_ack`/`message_edit_ack` 路径 DB 正确但 fire tag `'List<Message>'`，被聊天页监听器（只收 `'MessageList'`/`'messages'`）丢弃，打开中的页面不刷新 | (a) `lib/service/message.dart:1154`（`_receiveServerAck`，`:1199` status→sent、`:1207` 唯一 fire `'messages'` 处）；(b) `lib/service/message_actions.dart:332`（`_processRevokeAck`→`:1162` fire `'List<Message>'`）、`:470`（`_processEditAck`→`:523` 同）；过滤器 `lib/page/chat/chat/mixin/chat_event_subscription_manager.dart:389`；同 tag 生产者另有 `message_actions.dart:296/630`、`chat_provider.dart:767/843`、`message_retry.dart:441/525/578`、`message.dart:272`、`chat_burn_service.dart:200`、`chat_network_service.dart:492` | 高 | M | 共享 service | TODO |
| 1.2 | chat 集成防御收口：`Chat` 未传 `avatarBuilder`（vendored flyer_chat `Avatar` 内部 `CachedNetworkImage` 直连不走 presign，`plugin/flutter_chat_ui/packages/flutter_chat_ui/lib/src/avatar.dart:135-149`），补 avatarBuilder 走自有 `imboy_ui.Avatar`；同文件 `customImageProvider` 调用点补 errorBuilder | `lib/page/chat/chat/chat_page.dart:1675`（Chat 未传 avatarBuilder）、`:1851`（customImageProvider 无 errorBuilder）；自有组件 `lib/component/ui/avatar.dart:103` | 中 | S | 单页 | TODO |
| 1.3 | `IconHitButton` 全局组件新建（44pt 最小命中 + semanticLabel/tooltip）+ 首迁：聊天发送按钮 32×32 | 新建 `lib/component/ui/icon_hit_button.dart`；首迁 `lib/page/chat/widget/chat_input.dart:1060`（`minimumSize: Size(32, 32)`，全仓唯一 <44 的 minimumSize） | 中 | M | 共享组件 | TODO |

实施要点：1.1 修法二选一并统一——生产方 tag 统一成 `'messages'`（范本：`message.dart:1206-1207` 注释处），或监听器补收 `'List<Message>'`；SERVER_ACK handler 须按原 action 语义分流（revoke→`convertMessageToRevoked`，edit→应用编辑）。1.1 是 2026-07-14 QA 遗留的根修，须真机验证发起方撤回/编辑即时刷新 + 重进会话持久正确。

---

## 批2｜图片 401/403 降级 + 频道崩溃 + 群管理入口（channel/moment/collect/group 簇） — 状态：TODO

**真机验证：未验证**

| # | 条目 | 文件:行号（已核实） | 影响 | 成本 | 范围 | 状态 |
|---|---|---|---|---|---|---|
| 2.1 | `dynamicAvatar` 401/403 零占位根修——`DecorationImage` 无 error 回调，所有走 `Avatar()` 的头像失败即空白（Provider 已抛 `ImageNotFoundException`，`imboy_cached_image_provider.dart:116-118/185` 对 401/403/404 已识别，只差 UI 兜底） | `lib/component/ui/avatar.dart:135` | 高 | S | 共享组件 | TODO |
| 2.2 | channel 簇 6 处 `cachedImageProvider` 无 error 回调补占位 | `lib/page/channel/channel_message_item.dart:275`、`widgets/channel_header_bar.dart:221`、`channel_discover_page.dart:379`、`channel_list_page.dart:304`、`channel_edit_page.dart:340`、`channel_comment_page.dart:321` | 中 | S | 单页×6 | TODO |
| 2.3 | moment×2 + 收藏 1 处补 errorBuilder（收藏项即「旧完整 URL 快照过期」的兜底） | `lib/page/moment/moment_create_page.dart:801`、`moment_feed_page.dart:1219`、`lib/page/mine/user_collect/user_collect_provider.dart:375` | 中 | S | 单页×3 | TODO |
| 2.4 | `shareToChat` 传裸 Map 路由 `as Message` 必崩（既有 bug） | 触发 `lib/page/channel/channel_message_item.dart:874`（`_shareMessage`，`:900-911` push 裸 Map）；崩溃点 `lib/config/router/app_router.dart:322`（`extra?['msg'] as Message`）；调用入口 `channel_message_item.dart:655/792` | 高 | S | 单页+路由 | TODO |
| 2.5 | 群主禁言/管理员入口断链接通——管理功能已全实现（`group_member_detail_page.dart` 禁言 `:83/:118/:177-183`、设管理员 `:474→:533 updateRole`、移出 `:492`；API `group_member_api.dart:78/101/128`），但群详情页成员头像点击跳 `/people_info` 而非成员详情页，管理入口仅「查看全部群成员」一条路径可达 | `lib/page/group/group_detail/group_detail_page.dart:717`（`onTapAvatar → /people_info`）；可达路径参照 `group_member_page.dart:284-287`（`→ /group/member_detail`）；权限规则 `lib/page/group/group_member/group_role_rules.dart`、`group_member_mute_rules.dart` | 高 | S | 单页 | TODO |

实施要点：2.1-2.3 统一占位样式（复用已有范式，参照 `lib/component/chat/message_image_builder.dart:141` 等 19 处已传 errorBuilder 的写法）。2.4 修法取小：`_shareMessage` 处构造真 `Message` 对象，或 send_to 路由防御解析（Map→Message 转换），二选一，勿两头都改。2.5 修法：有管理权限者（`canManage`/role 判定）头像点击改跳 `/group/member_detail`，无权限者维持 `/people_info`。

---

## 批3｜service 层三态根治（8 文件 76 方法，同一复制粘贴模板） — 状态：TODO

**真机验证：未验证**

grep 已确认全部 76 处为同一模板 `catch (e) { iPrint('...失败 - $e'); return null/[]/false/空Map; }`，无 rethrow、无错误事件。仓内正确范式：`channel_service.dart:314/370`（`syncUnreadSummary` catch 里 `fireTracked(ChannelUnreadSummarySyncEvent(success:false))` 再返回空）。修法按文件成批套用：读取类传出错误态（页面 `AsyncStateView` error 分支才能触发），写入类让 UI 能区分网络失败 vs 业务拒绝。

| # | 条目 | 文件:行号（已核实，逐方法清单） | 影响 | 成本 | 范围 | 状态 |
|---|---|---|---|---|---|---|
| 3.1 | group_album(9) + group_category(6) + group_tag(5) | `lib/service/group_album_service.dart:28,51,63,82,94,109,118,130,139`；`group_category_service.dart:24,45,66,81,106,121`；`group_tag_service.dart:24,47,65,80,90` | 高 | M | 共享 service | TODO |
| 3.2 | group_file(5) + group_schedule(7) | `lib/service/group_file_service.dart:34,51,70,94,103`；`group_schedule_service.dart:53,66,88,108,146,170,200` | 高 | M | 共享 service | TODO |
| 3.3 | group_vote(8) + group_task(9) | `lib/service/group_vote_service.dart:45,58,78,88,115,140,160,180`；`group_task_service.dart:111,125,148,162,181,215,245,274,306` | 高 | M | 共享 service | TODO |
| 3.4 | channel_service(27) | `lib/service/channel_service.dart:77,87,116,147,166,201,241,396,418,443,458,470,491,501,513,523,535,547,571,583,601,623,970,992,1008,1021,1037` | 高 | M | 共享 service | TODO |

实施要点：先定一次错误传出契约（沿用 `syncUnreadSummary` 事件式，或读取类改抛异常由调用方 catch 进 error state），四个条目套同一契约，勿各造一套。每条目至少对一个代表页面接通 error→`AsyncStateView` 并断网验证「加载失败+重试」而非「无数据」。

---

## 批4｜B7 跨端接线（web_shell 簇；AppBreakpoints 已完成不重做） — 状态：TODO

**真机验证：未验证**（本批用桌面/宽屏窗口验证）

现状核实：全站 `MouseRegion` 命中 0、`onSecondaryTap` 命中 0；`web_shell_keyboard_intent.dart` 纯函数（`WebShellShortcut` sealed 变体 + Cmd/Ctrl+K/N/, 解析）已写好，仅被 barrel export，全仓无 `Shortcuts(`/`CallbackShortcuts` 接线点。

| # | 条目 | 文件:行号（已核实） | 影响 | 成本 | 范围 | 状态 |
|---|---|---|---|---|---|---|
| 4.1 | 快捷键接线：在 WebShellPage 挂 `Focus`+`CallbackShortcuts`（或 Shortcuts/Actions）消费 `resolveWebShellShortcut`，接 Cmd/Ctrl+K（全局搜索）/N（新会话）/,（设置） | `lib/page/web_shell/web_shell_page.dart:26`（`class WebShellPage`，当前无任何键盘处理）；决策内核 `web_shell_keyboard_intent.dart:17`（sealed `WebShellShortcut`） | 中 | M | 单页 | TODO |
| 4.2 | 列表 hover/cursor 反馈：web_shell 中栏与 nav rail 条目补 `MouseRegion(cursor)`+hover 高亮 | `lib/page/web_shell/web_middle_panel.dart:17`（`class WebMiddlePanel`）、`web_nav_rail.dart` | 中 | S | 单页×2 | TODO |
| 4.3 | 右键菜单：web_shell 会话条目 `onSecondaryTap` 弹出操作菜单（复用已有 `web_message_actions.dart` 的动作集） | `lib/page/web_shell/web_middle_panel.dart`、动作集 `web_message_actions.dart` | 中 | M | 单页 | TODO |

实施要点：本批只做 web_shell 簇（桌面表面成形），移动端页面不加 hover。`AppBreakpoints` 统一已由前批完成（`lib/theme/default/app_breakpoints.dart`），本批禁止重复动断点。

---

## 批5｜i18n 债务 + SR-6/7 触达迁移第二波（wallet/passport/channel 零散页） — 状态：TODO

**真机验证：未验证**

| # | 条目 | 文件:行号（已核实） | 影响 | 成本 | 范围 | 状态 |
|---|---|---|---|---|---|---|
| 5.1 | withdraw 硬编码中文补键（10 语言）：校验文案 ×2、账号 hint 括注、手续费说明 | `lib/page/wallet/withdraw_page.dart:92`（'请输入正确的支付宝邮箱或手机号'）、`:96`（'请输入正确的微信号…'）、`:278-279`（'（邮箱或手机号）/（微信号）'括注）、`:295`（'免手续费，预计 T+1 到账…'） | 中 | S | 单页 | TODO |
| 5.2 | red_packet_detail 硬编码中文补键（10 语言） | `lib/page/wallet/red_packet_detail_page.dart:154`（'🈲 零信任端解密'）、`:185/:310`（'元'）、`:193`（'未领到该红包'）、`:214-215`（'共…个红包已抢光/已抢…'）、`:293`（'手气最佳'） | 中 | S | 单页 | TODO |
| 5.3 | SR-6/7 第二波迁移到 `IconHitButton`（批1 已建组件）：channel 发布栏零 padding IconButton、注册/忘记密码 PinField（宽 40）、搜索组件 40 宽点击件 | `lib/page/channel/widgets/channel_publish_bar.dart:483-484`（IconButton padding zero）、`lib/page/passport/signup_continue_page.dart:213` + `forgot_password_pin_code_page.dart:142`（MaterialPinField）、`lib/component/search.dart:225`（width:40） | 中 | M | 单页×4 | TODO |
| 5.4 | SR-7 语义补齐抽查：为本批触达的图标按钮统一补 semanticLabel/tooltip（现状：全仓 `tooltip:` 仅 85 处 vs 43 个含 IconButton 的文件） | 随 5.3 文件走，实施时 grep 本批文件内裸图标按钮 | 低 | S | 单页 | TODO |

实施要点：i18n 流程照既有规约——先改 `assets/i18n/zh-CN/` 源 → `dart run slang` → 同步其余 9 语言（slang 裸 bool 崩溃先 grep 预检）。PinField 迁移注意别破坏 OTP 自动聚焦行为。

---

## 批6｜SR-5 调用方静态色机械替换（单独成批，最后执行） — 状态：TODO

**真机验证：未验证**（暗色模式逐页扫）

根层 helper 已齐（`app_colors.dart:218-235`）。以下计数为 2026-07-16 grep 快照（排除 `lib/theme/` 内定义），**实施时须重新 grep 以当时命中为准**（前批会增删调用点；审计文档旧计数 15/41/11 已漂移）。

| # | 条目 | 核实快照 | 影响 | 成本 | 范围 | 状态 |
|---|---|---|---|---|---|---|
| 6.1 | `AppColors.textSecondary` → `getTextSecondary(brightness)`：16 处（12 处集中在 message_search_page） | `lib/page/search/message_search_page.dart:187,210,217,393,401,472,479,533,546,623,767,778`；`lib/page/settings/e2ee_backup_export_page.dart:251`、`e2ee_backup_import_page.dart:169,535`；（`lib/component/ui/nodata_view.dart:45` 为说明注释，顺手清理） | 中 | S | 机械替换 | TODO |
| 6.2 | `AppColors.iosOrange` → `getIosOrange(brightness)`：67 处 / 40 文件 | 集中文件：`e2ee_key_recovery_page.dart`(10)、`e2ee_backup_export_page.dart`(7)、`e2ee_backup_import_page.dart`(5)、`moment_feed_page.dart`(3)、`storage_space_page.dart`(3)、`contact_menu_decoration.dart`(3)、其余 34 文件各 1-2 处（实施时 `rg -n "AppColors\.iosOrange" lib/ \| grep -v lib/theme/` 全量取） | 中 | M | 机械替换 | TODO |
| 6.3 | `AppColors.iosPurple` → `getIosPurple(brightness)`：8 处 | `lib/component/helper/user_online_time_helper.dart:194`、`contact_setting_page.dart:103`、`add_friend_page.dart:66`、`group_vote_page.dart:220,226`、`wallet_page.dart:352`、`group_detail_page.dart:466`、`mine_page.dart:96` | 中 | S | 机械替换 | TODO |

实施要点：纯机械但须逐点确认拿得到 `Brightness`（const 上下文/无 context 的 helper 需小改签名或就地 `Theme.of(context).brightness`）；`user_online_time_helper.dart` 等纯函数 helper 是唯一非机械点。替换后暗色模式逐页扫（DoD 沿用审计 §6：无裸静态色残留、随主题变化）。

---

## 批7｜真机回归（不改代码，配合提示词③执行） — 状态：TODO

| # | 验证项 | 依据 |
|---|---|---|
| 7.1 | 日期星期显示随系统语言（EEEE 问题回归确认） | 代码已根治（见顶部摘要），QA 报告项关闭前须真机确认 |
| 7.2 | 头像/图片 401/403 显示占位而非空白（批2 产物） | 可配合过期签名 URL 或断网复现 |
| 7.3 | 发起方撤回/编辑即时刷新 + 重进会话持久正确（批1 产物） | 2026-07-14 QA 遗留关闭条件 |
| 7.4 | 群主经群详情头像直达成员管理（禁言/设管理员）（批2 产物） | 2026-07-14 QA 遗留关闭条件 |
| 7.5 | 收藏旧快照图片可显示或有占位（批2 产物） | 2026-07-16 QA 遗留关闭条件 |

---

## 新发现（实施批次时追加，不当场修）

（空）
