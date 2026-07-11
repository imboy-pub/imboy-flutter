# imboyapp 全量页面功能测试清单 / Full-App QA Test Checklist

> 生成日期：2026-07-11 ｜ 依据：`lib/page/**` 逐页编目 + `feature-status.md` 对齐 + 阶段 0/1 实跑
> 范围：Flutter 客户端全部路由页面、功能点、API 对接与数据结构合理性
> 用途：QA 手工回归 / 自动化 E2E 用例来源（每个「功能点」= 一条可自动化用例）

---

## 一、对齐总览

| 维度 | 数量 | 说明 |
|------|------|------|
| 页面源文件 | 148 | `find lib -name '*_page/_view/_screen.dart'` |
| 有效可测页面 | ~140 | 扣非 UI/静态页 |
| 功能模块（`lib/page/` 一级） | 22 | 见 §1.2 |
| GoRoute 路由 | 124 | `test/smoke/route_registry.dart` |
| 功能开关 | 11 | 仅 `live_room` 硬关闭 |
| 前端 API 模块 | 34 | ~234 端点调用 |
| fromJson 模型（store） | 33+ | 数据结构校验点 |
| 后端 `/api/v1` 路由 | ~309 | `imboy/src/imboy_router.erl` |

### 1.2 模块页面分布与深度测试现状

| 模块 | 页数 | 职责 | 深度测试 |
|------|------|------|---------|
| group | 26 | 群聊/协作(投票/日程/任务/相册/文件/公告/标签/分类/成员) | ⚠️ 仅群聊消息 |
| mine | 21 | 个人中心/设置/账号安全/设备/收藏/存储/反馈 | ❌ 仅改密 |
| channel | 12 | 频道 CRUD/发现/订阅/管理员/评论/订单/付费 | ✅ CRUD+发布 |
| contact | 12 | 联系人/新朋友/附近人/资料/黑名单/举报 | ⚠️ 好友管理 |
| settings | 11 | E2EE 密钥/备份/社交恢复/设备传输 | ❌ 全缺 |
| personal_info | 8 | 资料编辑/昵称/性别/地区/隐私 | ⚠️ 仅 profile |
| chat | 6 | 聊天/设置/音视频通话/转发/快捷回复 | ✅ 收发 |
| passport | 8 | 登录/注册/找回/引导/Web扫码 | ✅ 登录注册改密 |
| single | 6 | Markdown/视频/隐私/条款/升级/网络引导 | ❌ 全缺 |
| moment | 5 | 朋友圈流/详情/发布/可见性/通知 | ⚠️ 仅发布 |
| wallet | 5 | 钱包/提现/红包/转账/红包详情 | ❌（已解禁） |
| user_tag | 5 | 标签列表/详情/选好友/新建/关系 | ❌ 全缺 |
| qrcode | 4 | 个人/群/频道二维码 | ❌ 全缺 |
| scanner | 3 | 扫一扫/结果/扫码登录 | ❌ 全缺 |
| search | 3 | 单会话/全局/Web搜索 | ❌ 全缺 |
| live_room | 3 | 直播列表/推流/拉流（🔒） | ❌ 全缺 |
| conversation/bottom_navigation | 各1 | 会话列表/底部导航壳 | ✅ |
| mention | 1 | @提及列表 | ❌ |
| splash/welcome/web_shell | 各1 | 启动/引导/Web壳 | ⚠️ 冒烟 |

### 1.3 ⚠️ 文档与代码不一致

| 项 | feature-status.md | 代码实际 |
|----|------|------|
| wallet | 🔒 硬关闭「后端未实现」 | ✅ 已解禁，`/api/v1/wallet/*` 已实现，sandbox 充值闭环可走通 |
| live_room | 🔒 硬关闭 | 🔒 仍硬关（WHIP 待部署），GoRoute 可直达 |
| 红包/转账页 | 未记录 | 3 页，从 ChatPage 唤起 |

---

## 二、现有自动化覆盖

三层：Tier1 API 契约（`test/api/`，无设备可 CI）· Tier2 冒烟门控（`integration_test/smoke/`，真机）· Tier3 UI 流程（`integration_test/`，真机）· 路由冒烟（`test/smoke/`，124 路由）· Maestro（14 flow）。

深度用例仅覆盖 ~5 核心域：登录注册改密、C2C+群聊+会话、频道 CRUD+发布、好友管理、E2EE 收发。
无深度用例：mine 设置、E2EE 备份/社交恢复/传输、wallet、group 协作、moment 详情/评论/通知、personal_info 编辑、user_tag、qrcode、scanner、search、mention、live_room、single。

---

## 三A、阶段 0 基线（2026-07-11 实跑）

### Tier1 API 契约（本地后端 9800，凭证 13900001002/admin888）
修复后全绿。**⚠️ 抓到 1 个 P0 跨仓契约 bug 并修复**：后端 /api 前缀硬切换后 WS 只挂 `/api/v1/ws`，但 `sys.local.config`/`sys.pro.config` 下发的 `ws_url` 仍旧 `/ws` → **下次生产部署会让全部移动端 WS 404**。已修 2 个后端 config（未提交）；`config_ds:local_reload()` 热加载生效。排障：curl 带 Upgrade 头对比响应码（404=无路由，400=拒握手）。
> ⚠️ `ws_api_test.dart` fallback 应指 `/api/v1/ws`，曾被并发会话还原为 `/ws`，需重做。

### 路由冒烟（`run_smoke_isolated.sh`，无头 macOS）
TOTAL 112 / PASS 48 / SKIP 58 / FAIL 6。首轮曾报 24 FAIL 为假阳性（并发会话 i18n 编译断裂，`dart run slang` 已修）。

6 个真失败**全部为无头环境固有限制，非页面崩溃**：
| 路由 | 原因 |
|------|------|
| account_security | 缺登录态（`Bad state: User not logged in`） |
| people_nearby / moment_create | 缺 DI（`Service HttpClient not registered`） |
| map_location_picker | 无 webview 平台 |
| group_add_member / group_remove_member | 缺 extra 群数据/联系人 DI |

结论：无头冒烟对「需登录态/DI/原生平台/extra」的页面有天花板，功能验证须走真机 integration_test。

---

## 三B、阶段 1 进度（API 契约测试）

### 已完成（2026-07-11，全绿，无设备可 CI）
| 文件 | 用例 | 结果 |
|------|------|------|
| `test/api/contact_api_test.dart` | 好友列表(+TSID)、本人资料(uid/nickname)、用户搜索、黑名单分页 | 5 pass |
| `test/api/user_api_test.dart` | 用户设置、本人资料、**uid 一致性**、最近注册、**无token鉴权保护** | 5 pass |
| `test/api/group_api_test.dart` | 群分页(+group_id TSID)、群详情、无效gid容错、群成员分页 | 2 pass / 4 skip |

合计 12 pass / 4 skip。关键验证：TSID uid 逐字节一致无精度丢失；无 token 访问被正确拒绝。
4 个 skip 为诚实 skip——测试账号 `admin888` 本地库 0 群（待种子数据）。

跑法：`API_BASE_URL=http://127.0.0.1:9800 TEST_PHONE=13900001002 TEST_PASSWORD=admin888 dart test test/api/ --concurrency=1`

### API 契约测试矩阵（每模块 = 一个 `test/api/<name>_api_test.dart`）
> 每条验证：① 请求参数对齐 openapi.yaml；② 响应信封(code/msg/payload)字段类型匹配 fromJson；③ 边界(空/错误码/401/TSID 精度)。

| 优先级 | 模块 | 端点 | 现状 |
|-------|------|------|------|
| P0 | channel_api | 43 | ✅ 有 |
| P0 | group_api | 14 | ✅ 新增(page 验证；detail/member 待群种子) |
| P0 | user_api | 12 | ✅ 新增 |
| P0 | conversation_api | 6 | ✅ |
| P0 | contact_api | 4 | ✅ 新增 |
| P0 | msg+WS | WS | ✅ ws_api_test |
| P1 | e2ee_plus_api | 13 | ❌ |
| P1 | wallet_api | 12 | ❌（sandbox 可测） |
| P1 | moment_api | 11 | ❌ |
| P1 | group_task/album_api | 9/9 | ❌ |
| P1 | user_tag/group_vote/group_member_api | 8/8/8 | ❌ |
| P1 | user_device/group_schedule_api | 7/7 | ❌ |
| P2 | group_category/e2ee/live_room_api | 6/6/6 | ❌ |
| P2 | mention/group_tag/group_file/feedback/channel_order_api | 5×5 | ❌ |
| P2 | user_collect/location/denylist/app_version_api | 4/3/3/3 | ❌ |
| P2 | push/fts/report/agent_task | 2/2/1/1 | ❌ |

### 数据结构合理性校验规则（每个 fromJson 一组）
- [ ] TSID：JSON integer，走 `safeParseBigIntJson`→string，>2^53 无精度丢失
- [ ] 金额：分(int)为权威，`*_yuan` 仅展示
- [ ] 时间：毫秒时间戳 int（防 RFC3339 混入）
- [ ] 可空：fromJson 全 `as T?`+默认兜底，`{}`/`null`/缺 key 三态不崩
- [ ] 枚举/状态码：int 一一对应，未知值不崩
- [ ] 分页信封：total/page/size 存在且 int；空列表 `[]` 非 `null`
- [ ] MessageModel.id：String（Xid base32hex），禁 int.tryParse
- [ ] WS 帧：v2 帧头(IB magic)、in_reply_to(非 reply_to)、ERROR 帧结构

---

## 四、逐页功能测试清单（动作级用例来源）

> 每个 `[ ]` = 一条测试用例；完整逐页功能点已在会话编目产出，按模块归总如下。

### P0 核心链路
- **认证**（passport 8）：登录三 Tab、注册两 Tab+验证码、找回密码、账户引导、Web 扫码登录
- **导航/会话**：底部 4 Tab+红点+WS三态点；会话左滑(已读/置顶/删除)/搜索/订阅频道条
- **聊天**（chat 6）：发送 9 类消息、长按菜单 11 项、双击、图片画廊、历史分页、@提及、引用、编辑、阅后即焚、E2EE 不匹配对话框；聊天设置(免打扰/焚毁/背景/清空)；音视频通话；转发；快捷回复
- **联系人**（contact 12）：列表 AZ/特殊入口、加好友/新朋友/申请/确认、资料页(通话/加好友/黑名单)、附近人、最近注册、联系人设置(黑名单/举报/删除)

### P1 高频
- **群协作**（group 26）：群列表/详情九宫格、成员(禁言/管理员/踢人)、增删成员、公告、建群/面对面、分类、标签、文件(上传/预览)、相册(多选/批量删)、投票(单多选/结束)、日程(参加/取消)、任务(提交/审核)
- **我的/设置**（mine 21）：设置项、账号安全(绑定邮箱/手机)、改密/设密、深色/字体/语言、注销(导出)、地区、存储清理、收藏(多选/标签)、设备(下线/删除)、反馈
- **频道**（channel 12）：列表/发现/创建/详情/编辑/管理员/订阅者/评论/邀请/订单/退款/付费墙
- **朋友圈**（moment 5）：流(点赞/菜单)、详情(评论/回复/删/举报)、发布(媒体/可见性/草稿)、可见性选择器、通知中心

### P2 长尾
- **个人资料**（personal_info 8）：各字段编辑+校验、隐私设置 5 开关
- **用户标签**（user_tag 5）：列表/详情/选好友/新建/关系(TagInput ≤14字≤20个)
- **二维码/扫码/搜索**：三类二维码、扫一扫(分流/闪光灯/相册)、结果、扫码登录、三类搜索(防抖/分类/历史/定位)
- **@提及/单页/E2EE/钱包/直播**：mention；markdown/video/upgrade(下载/校验)；E2EE 11 页；wallet 5 页；live_room 3 页(需开 flag)

---

## 五、自动化执行方案

### 环境（2026-07-11 实测）
Android MRD AL00（adb `XWE6R19916004085`）✅ ｜ iPhone 16e（`00008140-000E30561E32801C`）✅ ｜ macOS ✅ ｜ maestro ✅
本机网段 192.168.2.39；真机 Tier3 用 `--dart-define=API_BASE_URL_OVERRIDE=http://192.168.2.39:9800 --dart-define=WS_URL_OVERRIDE=ws://192.168.2.39:9800/api/v1/ws`

### 路径
- **C — flutter integration_test（真机）**：深度功能主力（P0/P1），可断言/深链
- **B — Maestro YAML**：冒烟+跨页导航广度（P2）
- **A — mobile-mcp**：探索式临时验证
- 路由冒烟：回归护栏（无头有天花板）

### 分阶段
- **阶段 0（基线）**：✅ 完成——API 契约全绿(修 1 P0 bug)、124 路由冒烟(6 真失败均无头限制)
- **阶段 1（P0）**：🔄 进行中——API 已补 contact/user/group；剩 UI chat_setting/通话/send_to/contact 全套（待并发会话稳定）
- **阶段 2（P1）**：UI group 协作/mine 设置/moment/channel 管理；API e2ee_plus/wallet/moment/group 8 模块
- **阶段 3（P2）**：UI wallet(sandbox)/E2EE 恢复/user_tag/search/qrcode/scanner；API 其余 + 数据结构断言
- **阶段 4（条件）**：live_room 需临时移出 `_localDisabledKeys`

---

## 六、结论
- 规模：22 模块 / ~140 可测页 / 124 路由 / 34 API 模块 ~234 端点 / 11 开关（仅 live_room 关）。
- 文档需修正：feature-status.md 关于 wallet 硬关闭已过时。
- 阶段 0 完成：API 契约全绿并修复 1 个会炸生产的 P0 WS 契约 bug；路由冒烟 6 真失败均无头环境固有限制。
- 阶段 1 进行中：新增 contact/user/group 三个 API 契约测试（12 pass/4 honest-skip），验证 TSID 精度与鉴权保护。
- 深度缺口：~100+ 页无深度功能测试，最大空白在 group 协作、mine 设置、E2EE 恢复、wallet。
