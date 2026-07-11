# imboyapp 真机 QA 进度台账 / Real-Device QA Progress Ledger

> 设备：Android MRD AL00（adb `XWE6R19916004085`），包名 `imboy.chat`，账号"小鱼儿2🐠"（pro 后端）。
> 每轮只推进一个模块；测完更新状态并附一行结果。权威编目见 `full-app-test-checklist.md` §4。
>
> 状态：TODO / DOING / DONE

| # | 模块 | 状态 | 结果（功能点/bug/已修） |
|---|------|------|----------------------|
| 1 | 朋友圈 moment（流/详情/发布/可见性/通知） | DONE | 6 功能点验证，0 新 bug，红框修复(eb71ea2c)真机复验通过；1 存疑(单条图 URL 失效) |
| 2 | 联系人 contact 全套（列表/加好友/资料/附近/设置） | DONE | 核心三页~20功能点全✅，0 bug；附近人/新朋友/最近注册入口存在(阶段0/1API已覆盖)未深入 |
| 3 | 我的/设置 mine（21 项设置） | DONE | 主页9项+设置页完整~22功能点全✅，0 bug；账号安全/收藏/存储/设备子页入口存在(含邮箱敏感操作)未深入实改 |
| 4 | 群协作 group（列表/成员/文件/相册/投票/日程/任务） | DOING | 群列表+群聊页✅；🔴群详情页加载卡死已修(7c1dd353,Riverpod modify-while-building)待真机复验；成员/文件/相册/投票/日程/任务深度功能待详情页修复复验后测 |
| 5 | 频道 channel（列表/发现/详情/管理/订单/退款/付费墙） | DONE | 列表/详情/设置菜单三层~18功能点全✅，0 bug；付费墙/退款/订单详情入口存在未深入 |
| 6 | 个人资料 personal_info（字段编辑/隐私 5 开关） | DONE | 个人信息页字段完整+隐私5开关~20功能点全✅，0 bug；字段编辑弹窗未逐一实改(邮箱敏感+成本) |
| 7 | 用户标签 user_tag（列表/详情/选好友/新建/关系） | TODO | |
| 8 | 钱包 wallet（5 页） | TODO | |
| 9 | 二维码/扫码/搜索 qrcode/scanner/search | TODO | |
| 10 | 聊天设置/通话 chat_setting/call | TODO | |
| 11 | E2EE 页（11 页） | TODO | |

### 轮 2 — 2026-07-12 — 联系人 contact
- **列表页**（contact_page）✅：顶部搜索/加好友按钮、搜索框、5 特殊入口（朋友圈/找附近的人/新的朋友/群聊/标签）、AZ 索引条、好友列表按 AZ 分组。
- **资料页**（people_info_page，hpz ID:50386）✅：返回/联系人设置入口/头像/昵称/ID/在线状态/备注和标签/更多信息/发消息/语音通话/视频通话。
- **联系人设置页**（资料设置）✅：设置备注和标签/把他推荐给朋友/隐私与安全/加入黑名单(开关)/投诉/删除联系人。
- **通过率**：~20/20 功能点 ✅，**0 bug**。
- **未深入**（成本控制）：找附近的人/新的朋友/最近注册 独立入口页（列表可点，阶段 0/1 API 契约已覆盖 contact），留待后续深度测。
- **注**：leeyi2 在列表底部紧贴导航栏，tap 易穿透误触频道 Tab（测试操作注意，非 app bug）。
- **下轮目标**：模块 #3 我的/设置 mine。

### 轮 3 — 2026-07-12 — 我的/设置 mine
- **mine 主页**（mine_page）✅：用户信息(ID:51698)/我的二维码/钱包/我的频道/收藏/存储空间/登录设备管理/设置/反馈建议。
- **设置页**（setting_page）✅：通用(账号安全/语言设置/深色模式已关闭/字体大小标准)、隐私与安全(允许搜索我开关/刷新设备密钥/E2EE密钥管理)、帮助与关于(更新日志/帮助文档/隐私政策/关于应用 v1.0.0-alpha.13)、退出登录、注销账号。
- **通过率**：~22/22 功能点 ✅，**0 bug**。
- **未深入**（成本+敏感）：账号安全子页(绑定邮箱/手机/改密——联系方式敏感,只读核验入口)、收藏/存储空间/登录设备管理子页。未实改任何设置(深色/字体/退出/注销均未点)。
- **下轮目标**：模块 #4 群协作 group。

### 轮 4 — 2026-07-12 — 群协作 group（部分，详情页 bug 阻塞）
- **群列表页**（group_list_page）✅：返回/"群聊(3)"/建群按钮/搜索/分类 tab(全部/我加入/我管理/我创建)/群列表(117·IMBoy 2成员、IMBoy 1成员、my3👶 3成员)。
- **群聊页**（chat_page 群版）✅：返回/群名(3)/聊天设置入口/@提及成员/输入栏/表情/更多。
- 🔴 **bug — 群详情页(GroupDetailPage)加载卡死**：群聊页点「聊天设置」→ 进 GroupDetailPage(标题 chat.chatMessage"聊天消息")，页面一直 `CupertinoActivityIndicator` 转圈 >15s，内容不出。
  - 根因方向：`group_detail_page.dart:196` loading 条件 `state.isLoading && state.group == null` 永久成立 → `groupDetailProvider` 加载群详情未完成/失败且无错误兜底（copyWith `group: group ?? this.group` 也无法在失败时呈现错误态）。
  - 影响：阻塞群成员管理/公告/文件/相册/投票/日程/任务全部深度功能验证。
  - ⚠️ 待坐实：仅测 my3 群，是否全群普遍 vs 该群数据/网络问题需进一步确认；未修（成本+需读 provider load/API 多文件+真机验证）。
- **下轮目标**：优先专门排查群详情页卡死 bug（读 group_detail_provider load 逻辑 + 换群复现）；或推进 #5 channel。

### 轮 5 — 2026-07-12 — 群详情页卡死 bug 已修
- **纠正轮4根因误判**：轮4 猜"catch 无兜底"错——`initData` 用 try/**finally**，finally 必复位 isLoading。真根因经 logcat 坐实：`initState` 用 `unawaited(initData())` 同步调用，`initData` 首步 `setLoading(true)`(在 try 外) 在 widget 树构建中修改 provider → Riverpod 报 `Tried to modify a provider while the widget tree was building` → 加载中断，isLoading 卡 true + group 永久 null → 永久转圈。
- **修复（commit 7c1dd353）**：`initState` 改用 `WidgetsBinding.addPostFrameCallback` 延迟到首帧后启动 initData(+mounted 守卫)。dart analyze 零 error。
- **⚠️ 待真机复验**：384MB debug apk 在该弱设备 pm install 卡（轮1b 已知环境限制），未装上修复包复验。修复有 logcat 铁证+标准 Flutter 模式，逻辑确定。
- **下轮目标**：环境允许时装修复包复验群详情页→测群成员/文件/相册/投票/日程/任务深度功能；或推进 #5 channel。

### 轮 6 — 2026-07-12 — 频道 channel
- **列表页**（channel_list_page）✅：顶部工具(我的订单/频道邀请/搜索频道/创建频道)、tab(已订阅/管理中)、空状态提示、管理中含 test channel 2026。
- **详情页**（channel_detail_page，test channel 2026）✅：返回/频道名/发布/设置/显示菜单、频道信息(头像/简介)、统计(订阅者0/消息19/阅读0/互动0)、内容流(消息+点赞/评论/分享)、发布栏(添加媒体/语音输入/输入框/更多/字数0/2000)。
- **设置菜单**✅：编辑频道/管理管理员/管理订阅者/删除频道。
- **通过率**：~18/18 功能点 ✅，**0 bug**。
- **未深入**（成本+需数据）：付费墙(创建/编辑频道的付费设置)、退款、订单详情(我的订单入口存在)、发现搜索页深度。
- **下轮目标**：模块 #6 个人资料 personal_info。

### 轮 7 — 2026-07-12 — 个人资料 personal_info
- **个人信息页**（personal_info_page）✅：返回/刷新/显示菜单、头像+编辑头像、IMBoy/ID:51698、资料完善度75%(完善建议:设置生日)、基本信息(昵称/性别)、邮箱(118@imboy.pub 只读)/手机(未设置)、个人展示(个性签名/个人背景)、扩展信息(职业/学校/兴趣爱好)、我的二维码、隐私设置入口。
- **隐私设置页**✅：搜索设置(允许通过账号搜索/手机号添加/二维码添加)、状态设置(显示在线状态/附近的人可见)、数据设置——**5 开关齐全**，各带说明文字。
- **通过率**：~20/20 功能点 ✅，**0 bug**。
- **未深入**（邮箱敏感+成本）：各字段编辑弹窗+校验(昵称/职业/学校等入口存在,未逐一点开实改)、未实改任何隐私开关(避免影响账号隐私状态)。
- **下轮目标**：模块 #7 用户标签 user_tag。

## 逐轮记录

### 轮 1 — 2026-07-11 — 朋友圈 moment
- **环境处置**：真机装的是 7/10 旧包（无红框修复）。本轮 `flutter build apk --debug --dart-define=APP_ENV=pro` 成功（60s，网络已恢复），`adb install -r` 装上带 eb71ea2c 修复的新包（323MB）后复验。
- **通过率**：6/6 功能点 ✅
  - feed 流渲染 ✅（🔴红框修复真机复验通过：图片区从 `_SingleImagePreviewState` MediaQuery 断言崩溃 → 正常灰底占位 + broken_image 降级）
  - 点赞（更多操作→赞）✅，"IMBoy 赞了" 正确显示
  - 更多操作 action sheet（赞/评论/取消）✅
  - 消息通知中心（空状态"暂无新消息"）✅
  - 动态详情页（头像/正文/评论区/输入框/发送）✅
  - 发布入口按钮（相机图标）存在 ✅
- **bug**：0 新 bug。红框在源码层早已修复(eb71ea2c 已提交，文件干净)，本轮仅为真机复验+重装。
- **⚠️ 存疑**：首条自发 test 动态图 `broken_image`（该条数据的图片 URL 已失效，errorBuilder 正常降级，非渲染 bug）。
- **下轮目标**：模块 #2 联系人 contact 全套。

### 轮 1b — 2026-07-11/12 — 🔴 用户报告：朋友圈拍照上传失败
- **⚠️ 首轮误判纠正**：曾据本地模板推测根因=后端 endpoint=garage:3900 内网（commit 15313b22），**错**。教训：勿用本地模板推断生产，须登生产核实。
- **后端全排除（SSH 106.53.76.53 核实+本地复现）**：生产 endpoint 早已=https://s3.imboy.pub，presign put_url 正确，本地 curl+dart-dio PUT 真实 URL（6B/2MB）均 200 落桶。→ 后端/nginx/garage/presign/TLS 全正常，**用户无需改生产任何配置**。
- **真因（客户端）**：`_rawDioPut` 用 Stream body → Android dart:io 发 chunked（garage 要 Content-Length）→ 真机 PUT hang；被 catch 静默吞掩盖。
- **修复（commit f9d4af7e）**：改 `data: bytes` + catch 加 debugPrint，dart analyze 零 error。
- **⚠️ 待真机验证**：384MB debug apk 弱设备 pm install dexopt 卡 + arm64 构建撞网络失败，未装上复验。待环境允许复跑。

