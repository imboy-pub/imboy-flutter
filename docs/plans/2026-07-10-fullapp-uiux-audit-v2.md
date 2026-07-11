# imboyapp 全站 UI/UX 审计 v2 —— 逐页矩阵 · 系统性反模式 · 跨端 · 链路对标

> 创建：2026-07-10 | 第二轮深审：142 页**逐页逐维度**矩阵（非抽样）+ 大屏/响应式专项 + 核心链路交互对标
> 与 v1（`2026-07-10-fullapp-uiux-audit.md`）的关系：v1 给"主题 + TOP 痛点"，v2 补齐"逐页覆盖 + 横切质量维度 + 跨端 + 链路级对标"。

---

## 0.0 实施进度 / Implementation Status（2026-07-11 更新）

> 本节记录 v2 计划的落地状态，使文档成为可追踪的活计划。

### ✅ 已实施并 `dart analyze` 验证（第一批：B0 急修 + B2 安全 + B3 token 根修）

12 个修复点落地，改动 22 个文件，全量 `dart analyze lib` 对本批改动**零告警**（唯一 1 条残留告警在并发会话 staged 的 `group_select_page.dart`，非本批引入，按并发隔离规则未动）。

| 条目 | 修复 | 主要文件 |
|---|---|---|
| N-1 | 宽屏点会话/联系人无反应（宿主判定 `_isWebShellHosted`） | conversation/contact_page |
| N-2 | 宽屏重开回手机布局（splash 按断点分流 + try/catch） | splash_page |
| N-3 | 资料地区假保存（接 `UserProfileService.updateField`） | app_router |
| N-4 | 删联系人数据丢失（API 先行，成功后才删本地） | contact_setting_provider |
| N-5 | 转发页非响应式 + 静默丢消息（改 Notifier + await 汇总成败） | send_to_page/provider |
| N-6 | 面对面建群 loading 卡死（try/finally 保证 dismiss） | face_to_face_page |
| SR-3 | 资金三流程二次确认 + 失败可见 + 提现 iosRed + 小数守卫 | wallet ×4 |
| SR-3 | 注销二次确认 + "清除聊天记录"接真实清空 + 隐私开关 await/回滚 | logout/privacy |
| SR-4 | 群 destructive 权限收窄（投票结束/群文件删/相册删+批量） | vote/file/album ×4 |
| 群桩 | 成员详情设管理员/移出群聊接线（`updateRole`/`leaveGroup`+确认） | group_member_detail |
| SR-1 | 搜索三态错误渲染（errorMessage 优先于空态 + 重试） | message_search/search_chat |
| SR-5 | token 层暗色根修（加性补 `getIosOrange/getIosPurple/getTextSecondary`） | app_colors |

**状态**：已提交 `51bdb1b9`（22 文件）。未真机验证（analyze 仅保证静态正确）。

### ✅ 第二批已实施并提交 `b60f44c5`（compose 全 P0/P1 + v2 剩余非阻塞项 · 21 路 agent · 76 文件）

> 更正：下方 B1/B4/B5-6 在第一批时标"未做"，第二批已做掉一大部分。当前真实状态：

| 计划条目 | 当前落地情况 |
|---|---|
| **compose P0/P1** | ✅ **全部完成**——P0-1 群工具面板 / P0-2 朋友圈多选批量传 / P0-3 频道并行上传 / P1-1 可见性单页+记忆 / P1-2 频道草稿 / P1-3 面板分组。|
| **B1 三态组件化**（AsyncStateView + SR-2 isLoading） | ✅ **基本完成**——新建 `AsyncStateView` 组件；SR-2 isLoading 死字段清扫 6 组页；三态错误态补齐 搜索 / 群功能页(category/tag/schedule/task) / 频道评论 / 朋友圈通知 / feedback / markdown / video_viewer / people_info_more / mine 多页。未做：全站逐页迁移（部分页仍就地处理）。|
| **B4 一致性收口**（SR-8） | 🟡 **大部完成**——settings E2EE 11 页 / scanner / mention / contact_tag_detail / people_info / bind_email·mobile / channel_comment / moment_notify 已 iOS 化。未做：聊天区（§0.5 阻塞）+ 少数残余页。|
| **B5/B6 性能** | 🟡 **部分完成**——p2p_call 页（`MediaQuery.sizeOf`/`FadeTransition`）、moment_detail（`Column→SliverList.builder`）已做。未做：`chat_input` observer 泄漏（§0.5 相邻暂缓）。|
| **附录 B 单点** | ✅ **大部完成**——语言即时生效 / 账号绑定状态 / 新朋友红点 / 订单币种 / 订阅真分页 / 发现防抖 / 提现校验 / 钱包死按钮禁用 / 欢迎+单页三态触达。|
| 第二批新真 bug | ✅ set_nickname finally 覆盖 / mention build 期 setState / feedback 状态色恒 default / profile 假成功写本地 / change·set_password 静默失败。|

### ⛔ 仍阻塞（须等 AI Agent 路线图 Phase 1/2，见 §0.5）——按设计不做
- 聊天气泡渲染类：SR-5 中 `message_*_builder.dart` 暗色替换、SR-8 聊天区一致性、会话/群成员/@提及/联系人的 agent 身份呈现、`chat_input` observer 泄漏。

### ⏳ 仍待后续（无阻塞，但需串行协调，本会话未做）
- **B7 跨端**：`AppBreakpoints` 统一 / hover / 右键菜单 / 快捷键接线（当前仅 N-1/N-2 沾边）。
- **SR-6/7**：`IconHitButton`（44pt+label）全局组件 + 触达/a11y 全站迁移。
- **SR-5 调用方迁移**：textSecondary 15 / iosOrange 41 / iosPurple 11 处静态色替换。
- **service 层三态根治**：多个 service 吞异常返回 null 致页面 error 分支少触发。
- **i18n 债务**：`withdraw` / `red_packet_detail` 硬编码中文补键。
- **既有 bug**：`channel_message_item.dart:874` `shareToChat` 传裸 Map 会在路由 `as Message` 崩溃。

---

## 0. 第二轮为什么重要

v1 每簇只挖 TOP 3–5 且部分抽样，漏掉了**横切质量维度**（a11y / 三态 / 暗色 / 性能 / 手势 / 跨端）。v2 逐页逐维度过完 142 页后，结论变了：

- **真正的问题不是 100 个孤立单点，而是 10 类反复复制的反模式**——同一个根因在几十个页面重演。
- **按反模式批量整改**（建统一组件/lint/模板）比逐页修**高一个数量级的效率**，也是唯一能"根治"的方式。
- 第二轮还挖出多个**上轮完全遗漏的真 bug/数据丢失/卡死**（下文 §2）。

---

## 0.5 ⚠️ 执行依赖与顺序（跨计划协调 —— 启动整改前必读）

**本计划的"聊天渲染/身份呈现"相关批次依赖 `imboy/docs/planning/ai-agent-platform-roadmap.md`（AI Agent 载体路线图，另一会话在推进），须在其相关阶段的 imboyapp 部分落地后再执行。** 该路线图当前状态：Phase 3（对外 MCP，后端 + imboyadmin）✅ 已交付；**Phase 0–2 / 4 规划中**。

### 依赖的阶段（会改动 imboyapp 聊天区）
- **Phase 2 / T2.3｜Flutter 流式气泡渲染**（对标野火 content type 14/15/91，标记 `[新建]`、规模 L）——AI 回复逐字显示 / 定稿刷新，将新增或改动 `lib/component/chat/` 消息渲染组件。**规划中，未做。**
- **Phase 1｜Agent 一等参与者**——agent 以真实账号在 群 / 会话 / @提及 / 联系人 中出现，新增 bot 身份呈现表面（身份徽章、群成员标识等）。**规划中，未做。**

### 为什么要等
这两个阶段直接改动本审计**重叠面最大**的区域。抢先按本审计精修会导致：① Phase 2 加 stream 气泡时**返工**；② stream 气泡、agent 身份等**新表面漏审**（未纳入本审计立的标准）。

### 须等待 AI Agent 路线图的批次/条目
- 消息核心簇里的 **气泡样式 / 已读回执 / 各 `message_*_builder.dart`** 相关项
- **SR-5** 中 `message_red_packet_builder` / `message_transfer_builder` 等聊天气泡的暗色整改（Phase 2 新气泡应一并纳入同一 token 标准，避免两次改）
- **SR-8** 聊天区图标 / 组件一致性收口（消息操作菜单、聊天设置等）
- 会话列表 / 群成员 / @提及 / 联系人的**呈现类**优化（Phase 1 会引入 agent 态，届时一并处理）
- `compose-ux-optimization.md` 的聊天输入相关项（与 T2.3 流式输入交互相邻）

### 不受影响、可立即先行的批次（与 AI Agent 无重叠）
- **B0 急修**：N-1 宽屏点不动、N-3 地区假保存、N-4 删联系人丢记录、N-5 转发虚设、N-6 面对面卡死
- **B2 安全兜底**：资金二次确认、群管理权限（SR-4）、注销 / 删密钥
- **B3 token 根修**：补 `getIosXxx(brightness)`、修 `textSecondary` getter（**根层可先做**；仅"聊天气泡替换裸 Colors"这一步等 Phase 2）
- **B7 跨端**：断点统一、宽屏分流、hover / 快捷键接线
- passport / 设置 / 钱包 / 扫码 / 直播 等与聊天渲染无关的簇

### 协调建议
待 AI Agent 路线图 **Phase 1 / T2.3 的 imboyapp 部分落地后**，对"消息核心簇 + 聊天组件"重跑一次审计增量，把 stream 气泡与 agent 身份纳入同一套标准，再统一整改这部分。**其余批次（B0/B2/B7 等）不必等，可即刻推进。**

---

## 1. 十大系统性反模式（← 本报告核心，按此批量整改）

### SR-1｜三态"错误静默 / 误判为无数据"（覆盖面最广）
**定义**：provider 已产出 `errorMessage` 但 UI 从不渲染；或 `try/finally` 无 `catch`。结果：网络失败被显示成"无结果/无数据"，用户无法区分、无重试。
**覆盖**（部分）：`message_search_page.dart:428`、`search_chat_page.dart:225`、`contact_provider.dart:55`、`moment_friend_picker_page.dart:110`、`conversation_provider.dart:592`、`mention_list_page.dart:57`、群组几乎全部功能页（相册/公告/分类/标签/文件/日程/投票/任务 service 层）、`storage_space`、`change_name`、E2EE 多页。
**统一改法**：建一个 `AsyncStateView`（loading/empty/error+retry 三态封装），所有列表/详情页强制走它；provider 的 error 必须有 UI 消费者。**一次组件化，全站受益。**

### SR-2｜`isLoading` 字段"定义但从未赋值"（模板复制病）
**定义**：state 里声明 `isLoading` 却从不置 `true`，加载态分支永不触发，首屏先闪"无数据"。
**覆盖**：`group_detail_page`、`add_member_page`、`remove_member_page`、`launch_chat_page`、`contact_tag_list/detail`、`recently_registered_user`。
**统一改法**：全项目 grep `isLoading` 死字段一次性排查；配合 SR-1 的 `AsyncStateView` 收口。

### SR-3｜危险 / 不可逆操作缺二次确认（安全）
**覆盖**：资金三流程（提现/转账/红包发送）、注销账号、删 E2EE 密钥、移出群成员、设管理员、拉黑、删联系人、清缓存、黑名单滑删。
**统一改法**：已有范本 `user_device_page.dart` 的 `CupertinoAlertDialog+isDestructiveAction`；资金/账号类追加支付密码或生物识别。**建 `confirmDestructive()` helper 统一调用。**

### SR-4｜群管理前端零权限校验（越权 UI）
**覆盖**：加成员入口(`group_detail_page.dart:111`)、移出成员、设管理员、结束投票(`group_vote_detail_page.dart:383`)、取消日程(`group_schedule_detail_page.dart:242`)、他人任务打勾(`group_task_page.dart:248`)、群文件/相册删除。
**统一改法**：照搬 `group_announcement_page.dart` 的 `canManage(role)`，未授权隐藏而非点击报错。**建 `GroupPermission` 统一判定。**

### SR-5｜暗色硬编码 + 不感知亮度的静态色（token 体系漏洞）
**覆盖**：资金气泡 18 处裸 `Colors.*`（`message_red_packet_builder`/`message_transfer_builder`）、`chat_background_manager` 多处、`welcome_page` 背景渐变不分支暗色、多簇 `iosBlue/iosGreen/iosOrange`。
**根因级**：① `AppColors.textSecondary` 是恒定浅色 getter，不随 Brightness 变化（**token 定义 bug**，`message_search_page` 12 处中招）；② `getIosOrange/getIosPurple` 亮度感知 helper **本身缺失**，调用方只能用静态常量。
**统一改法**：先修 token 层（补齐 `getIosXxx(brightness)` 全集、修 `textSecondary`），再全站替换裸 `Colors.*`。**先修根，再扫叶。**

### SR-6｜触控区 <44pt（违反自身 DESIGN.md 红线）
**覆盖**：PinField 宽 40（passport 多页）、发送按钮 32×32(`chat_input.dart:1020`)、各类删除/勾选/关闭按钮 16–40pt、色块、分段控件。
**统一改法**：建 `IconHitButton`（内建 44pt 最小命中区 + tooltip），替换裸 `GestureDetector/IconButton(padding:zero)`。

### SR-7｜a11y 图标按钮无 tooltip/Semantics（近乎全站）
**覆盖**：几乎所有纯图标按钮（更多操作/删除/发送/刷新/拍照/翻页…）。
**统一改法**：随 SR-6 的 `IconHitButton` 一并带上 `semanticLabel`，一次收口。

### SR-8｜Material / Cupertino 视觉双轨（重构未收口）
**覆盖**：settings E2EE 11 页、频道全簇、群文件/相册/日程/分类、扫码、@提及、标签详情、隐私设置、mine 二级页、moment 通知页、各处 `ElevatedButton`/`AlertDialog`/`InkWell`（违反 DESIGN.md §13.2 Cell 禁 Ripple）混入 Cupertino 页。
**统一改法**：定组件基线（页模板=`IosPageTemplate`、弹窗=`CupertinoAlertDialog`、按钮/列表统一），渐进迁移；可加 lint 禁止 Material 组件混入。

### SR-9｜build 期副作用（崩溃/重复加载风险）
**覆盖**：`mention_list_page.dart:180` build 期 `setState` 分页（"setState during build"崩溃风险）、`group_announcement_page.dart:83` itemBuilder 命中末尾同步 `onLoadMore`。
**统一改法**：分页触发移到 `ScrollController` 监听或 `addPostFrameCallback`。

### SR-10｜性能：重建 / 泄漏 / 串行 IO
**覆盖**：`chat_input.dart` **每次 build 重复 addObserver 且 dispose 从不 removeObserver（Observer 泄漏，真回归）**；`chat_page` composerHeight 与核心 state 耦合致整页重建；串行 `await` 未 `Future.wait`（`moment_utils`、`e2ee_proxy_selector` N+1）；长列表用 `Column+.map` 未 builder（moment 评论）；背景图 `Image.file` 无 `cacheWidth/Height`。
**统一改法**：逐条修（性能类难以组件化统一），但 observer 泄漏与整页重建优先。

---

## 2. 第二轮新增真 Bug / P0（v1 未发现，逐条可复现）

| # | 严重 | 问题 | 证据 |
|---|---|---|---|
| N-1 | 🔴 阻断 | **宽屏(>800px)点会话/联系人条目无反应**——派发到没人渲染的 `webShellProvider` | `conversation_tap_dispatcher.dart:91`、`bottom_navigation_page.dart`(不消费该 provider) |
| N-2 | 🔴 | 宽屏/桌面/Web 重开 App 永远回手机布局（splash 硬编码跳 `/bottom_navigation`） | `splash_page.dart:139-151` |
| N-3 | 🔴 数据丢失 | **个人资料"地区"保存假成功**——可达路径命中路由空桩 `onSave:()=>true`，数据从不落地；正确实现封在**不可达死代码** | `profile_page.dart:117`、`app_router.dart:643` |
| N-4 | 🔴 数据丢失 | 删除联系人**先删本地聊天记录再调 API**，API 失败则记录不可逆丢失 | `contact_setting_provider.dart:72-98` |
| N-5 | 🔴 功能虚设 | 转发页 `SendToLogic` 非响应式——**搜索不过滤、点联系人不显示选中**；且 `sendMsg` 未 await 即关页，转发失败静默丢消息 | `send_to_page.dart:114-206`、`send_to_provider.dart:36-101` |
| N-6 | 🔴 卡死 | 面对面建群网络异常无 try/catch → `AppLoading.dismiss()` 永不执行，**loading 遮罩卡死**须强退 | `face_to_face_page.dart:41-44` |
| N-7 | 🔴 泄漏 | `chat_input` 每次 build 新增 `WidgetsBindingObserver`，dispose 从不移除 | `chat_input.dart:162,282-284,1043` |
| N-8 | 🔴 崩溃风险 | `mention_list` build 期 `setState` 分页（setState during build） | `mention_list_page.dart:180-184` |
| N-9 | 🔴 状态 bug | `set_nickname` finally 用过期 `currentState` 覆盖最新态，失败回滚失效 | `set_nickname_provider.dart:185-211` |
| N-10 | 🔴 欺骗反馈 | 隐私设置 5 开关无即时反馈/无失败回滚；聊天设置禁言/焚毁持久化失败仍弹"已启用"成功 | `privacy_settings_page.dart:41-93`、`chat_setting_page.dart:85-110` |
| N-11 | 🔴 资源 | 直播 publisher/subscriber `autoDispose`+手动异步清理竞态，摄像头/麦克风/PeerConnection 可能不释放 | `publisher_page.dart:55`、`subscriber_page.dart:44` |
| N-12 | 🔴 | scanner 相机权限被拒**零 UI 反馈**（仅 debugPrint），无法自救 | `scanner_page.dart:63-76` |
| N-13 | 🔴 死代码 | `help_page.dart` 无 `HelpPage` 类（孤立死文件）；web_shell 深链解析 + 桌面快捷键**完整实现但零接线**（文档声称支持，实际不工作） | `help_page.dart`、`web_shell_route_params.dart`、`web_shell_keyboard_intent.dart` |
| N-14 | 🟡 | `recently_registered` 加载态永不触发；`提现`确认按钮用品牌蓝非 iosRed | `recently_registered_user_provider.dart:47`、`withdraw_page.dart:214` |
| N-15 | 🟡 | 频道订单金额硬编码 `¥` 未读 `order.currency`（多币种符号错） | `channel_order_detail_page.dart:124` |

> N-1/N-3/N-4/N-5/N-6 属**功能阻断或数据丢失**级，优先级高于一切体验优化。

---

## 3. 大屏 / 响应式 / 跨端专项结论

- **断点散落 4 处口径不一**（600/800/900/1200），无统一 `AppBreakpoints`；800 与 900 的 100px 灰区直接导致 N-1。
- **宽屏默认进不了三栏壳**：仅 `/web_shell` 显式路由可达，且重开即掉回移动端（N-2）。≥900px 桌面窗口下 `BottomNavigationPage` 是拉伸手机单列 + 移动端底部 Tab。
- **桌面交互整体缺失**：全站 `MouseRegion` 命中 0（列表零 hover/光标反馈，仅 WebNavRail 例外）；`onSecondaryTap` 命中 0（无右键菜单）；聊天气泡不可鼠标选中文字；已写好的 Cmd/Ctrl+K/N/, 快捷键零接线。
- **跨端能力差 70%**：Web `_WebChatInput` 仅文本，无图片/语音/@/引用；桌面频道详情是 `PlaceholderPanel`。
- **发送键不统一**：移动端 Ctrl/Cmd+Enter，Web 靠多行 `onSubmitted`（Enter 换行下大概率不触发），两端都不是"Enter 发送/Shift+Enter 换行"行业标准。

**统一改法**：建 `AppBreakpoints` 单一来源 → splash/router 按屏宽+kIsWeb 分流 → `BottomNavigationPage` ≥600 常驻 Rail 或重定向 web_shell → 列表控件补 hover/cursor → 接线已有快捷键与深链。

---

## 4. 核心链路交互步骤级对标（作者亲审，非 agent）

> 说明：无法抓取竞品 App 截图（能力受限），以下为**交互步骤逐步拆解**对标，基于已读代码 + 成熟竞品公开交互范式。

### 链路 A — 登录
| 步骤 | imboyapp | 微信 / Telegram | 差距 |
|---|---|---|---|
| 进入 | 启动→welcome→login | 启动→登录 | ≈持平 |
| 方式 | 账号/手机/邮箱**三 Tab** 手动切 | 微信手机号+密码/一键；TG 手机号→OTP自动读取 | Tab 心智重、无一键/生物登录 |
| 空字段 | **零反馈死点击**（三 Tab 均是） | 即时输入框下红字校验 | ❌ 明显落后 |
| 防重复 | 无 loading/禁用，可连点 | 按钮 loading + 禁用 | ❌ |
| 二次登录 | 每次重输 | 生物识别/记住 | 缺快捷登录 |

### 链路 B — 群聊发消息 + 用群工具
| 步骤 | imboyapp | 微信 / 钉钉/飞书 | 差距 |
|---|---|---|---|
| 发文本 | 输入→发送（发送键 32×32 偏小） | 输入→发送 | ≈持平，触达小 |
| 发图/文件 | +面板 8/页**轮播翻页**找 | +面板分组、常用置顶 | 查找成本高 |
| 用群投票/接龙/日程 | **聊天内不可达**，须退出→群详情→功能区 | 聊天 +面板一级可达 | ❌ 断层（v1 已列） |
| 引用回复 | 长按→菜单→引用（3 步） | 侧滑气泡即回复 | 多 2 步 |
| 已读 | 已发送=已送达同图标，群聊无"谁已读" | 三态明确 + 谁已读 | ❌ |

### 链路 C — 建群
| 步骤 | imboyapp | 微信 | 差距 |
|---|---|---|---|
| 发起群聊 | 通讯录→群聊→发起→多选→建群→引导 | 通讯录→发起群聊→多选→完成 | ≈持平（体验较完整）|
| 面对面建群 | 数字码高保真，但**网络异常 loading 卡死**(N-6) | 稳定 | ❌ 有卡死 bug |

### 链路 D — 发朋友圈
| 步骤 | imboyapp | 微信 / 小红书 | 差距 |
|---|---|---|---|
| 选媒体 | **4 项 ActionSheet**，单选单传 | 统一多选网格、图视频混选批量 | ❌（v1 已列，且删按钮 18pt 触达过小）|
| 可见性 | ActionSheet→再跳独立好友页（**两跳**）| "谁可以看"单页多选+记忆 | ❌ |
| 发布 | 支持草稿恢复（优点） | 草稿 | ✅ 持平 |

### 链路 E — 转账 / 支付
| 步骤 | imboyapp | 微信支付 | 差距 |
|---|---|---|---|
| 转账 | +面板→转账→金额+备注→**直接转出**(无密码/无摘要确认) | 金额→确认→**支付密码/指纹** | ❌ 高危缺口(N/SR-3) |
| 收款 | 点气泡**秒收**（无详情确认） | 进详情→点"收钱"，24h 未收退还 | ❌ 缺确认与退还 |
| 失败反馈 | **静默 dismiss**，零提示 | 明确失败原因 | ❌ |
| 危险色 | 提现按钮用品牌蓝(N-14) | 危险操作红色 | ❌ |

---

## 5. 整改批次建议（按系统性反模式批量修）

| 批次 | 内容 | 为什么这样批 |
|---|---|---|
| **B0 阻断/数据丢失急修** | N-1〜N-6（宽屏点不动、地区假保存、删联系人丢记录、转发虚设、面对面卡死） | 功能级/数据级，先止血 |
| **B1 组件化根治三态** | SR-1+SR-2：建 `AsyncStateView`，全站列表/详情收口 | 一个组件消灭最广的一类缺陷 |
| **B2 安全兜底** | SR-3+SR-4：`confirmDestructive()` + `GroupPermission` + 资金支付密码 | 照搬已有范本，风险最高 |
| **B3 token 根修** | SR-5：补 `getIosXxx(brightness)`、修 `textSecondary` getter，再扫裸 Colors | 先修根再扫叶 |
| **B4 触达+a11y 组件化** | SR-6+SR-7：`IconHitButton`(44pt+label) 替换裸图标按钮 | 两类缺陷一次收口 |
| **B5 一致性收口** | SR-8：组件基线 + lint 禁 Material 混入；渐进迁移 | 工作量大，可持续推进 |
| **B6 性能/健康** | SR-9+SR-10：observer 泄漏、整页重建、build 期副作用、串行 IO | 逐条修 |
| **B7 跨端** | 大屏专项：`AppBreakpoints` + 分流 + hover/右键/快捷键接线 | 桌面/Web 体验成形 |

---

## 6. 验收标准（沿用 v1 §6 DoD，追加专项）

- **反模式类专项验收**：
  - SR-1：随机断网，所有列表/详情页显示"加载失败+重试"而非"无数据"。
  - SR-2：全项目无 `isLoading` 死字段（grep + 首屏无"闪无数据"）。
  - SR-3：资金/注销/删密钥/移成员提交前必有确认+身份校验，真机逐条验。
  - SR-5：暗色模式逐页扫，无裸 `Colors.*` 残留；`textSecondary` 随主题变化。
  - SR-6/7：全站图标按钮命中区 ≥44pt 且有 semanticLabel。
- **跨端专项**：宽屏点会话/联系人有反应；桌面重开进三栏；列表有 hover；快捷键生效。
- 通用 7 条 DoD 见 v1 §6（真机 / analyze 零告警 / i18n 完整 / token / 危险色 / 触达 / DCO）。

---

## 附录 A：整改主线说明

- 本报告（v2）为**唯一权威整改主线**：10 系统性反模式（SR）+ 新增真 bug/P0（N）+ 大屏 5 项 + 5 链路对标。
- 原 v1 报告已**合并进本文件**（见附录 B），v1 文件已删除，不再单独维护。
- 优先级：先 **B0 急修**（功能/数据阻断）→ 再按 SR 反模式批量整改。

## 附录 B：单点补充清单（合并自原 v1，非反模式类的独立优化项）

> 这些是"能力补齐 / 单点体验"，不属于 §1 的系统性反模式，但仍需逐项跟进。反模式类（三态/权限/暗色/触达/a11y/一致性）已在 §1 收口，此处不重复。

### B-1 能力落后于已就绪后端（服务层已具备，仅 UI 未采集）
- 创建投票补 匿名 / 单多选 / 截止时间 · `group_vote_page.dart:52`
- 创建日程补 地点输入框 · `group_schedule_page.dart:53`
- 创建任务补 指派人 / 截止时间 · `group_task_page.dart:59`
- 频道订阅者接真分页（当前硬编码关闭）· `channel_subscriber_page.dart:93`
- 频道点赞"我是否已反应"字段（刷新归零根因）· `channel_message_item.dart:76`
- 群任务审批入口（`reviewTask` 已存在未接 UI）· `group_task_detail_page.dart:169`

### B-2 缺失能力 / 体验补强
- **移动端全局搜索入口**（复用 WebSearchPage 四路 provider，当前只有会话内搜索）
- 已读/送达**三态区分** + 群聊"谁已读"列表 · `message_status_icon_rules.dart:40`
- 频道列表"最新内容摘要 + 未读数"（当前像静态目录）· `channel_list_page.dart:288`
- 频道详情**多图九宫格**（当前退化单图，朋友圈已支持）· `channel_message_item.dart:434`
- 频道发现**搜索防抖联想**（当前须敲回车）· `channel_discover_page.dart:173`
- 新的朋友入口**未读红点** · `contact_page.dart:65`
- 账号安全一级页**展示绑定状态** · `account_security_page.dart:56`
- 语言切换**即选即生效**（对齐深色/字体）· `language_page.dart:241`
- 群详情"分类"入口**语义错位**（跳全局非本群）· `group_detail_page.dart:453`
- 提现**账号格式校验 + 手续费/到账时效展示** · `withdraw_page.dart:195`
- 桌面/Web **右键菜单对齐移动端能力** · `chat_page.dart:1160`
- 红包气泡**终态回显 + isSentByMe 判断** · `message_red_packet_builder.dart:42`
- 引用**滑动手势直达 + 跳转定位原消息**
- 朋友圈**"转发到聊天"**（能力倒挂：频道有、朋友圈无）
- 直播**互动层（点赞/聊天）+ 观众侧"正在直播"发现页**
- 收藏"置顶"仅存 SharedPreferences，换机/重装丢失 · `user_collect_page.dart:46`

### B-3 打磨（P2）
- splash 双 logo 尺寸跳变 · `splash_page.dart:28`；welcome"跳过"触达 <44 · `welcome_page.dart:263`
- 忘记密码/注册 OTP 重发无 60s 倒计时
- 撤回气泡 FutureBuilder 滚动重复查询 · `message_revoked_builder.dart:81`
- 全站 i18n 硬编码残留（群列表"群聊信息"/成员"成员"/直播按钮/红包详情等 TODO 未补）

---

## 附：问题总量

- **v2（本文件，权威主线）**：10 系统性反模式 + 新增真 bug/P0 15 条 + 大屏 5 项 + 5 链路对标 + 附录 B 单点补充（合并自 v1）。
- 配套：`2026-07-10-compose-ux-optimization.md`（发消息 compose 细粒度落地计划，与本报告互补）。
</content>
