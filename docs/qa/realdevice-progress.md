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
| 4 | 群协作 group（列表/成员/文件/相册/投票/日程/任务） | DOING | 群列表+群聊页✅；🔴群详情页加载卡死(阻塞成员/文件/相册/投票/日程/任务全部深度功能)，待专门排查 |
| 5 | 频道 channel（列表/发现/详情/管理/订单/退款/付费墙） | TODO | |
| 6 | 个人资料 personal_info（字段编辑/隐私 5 开关） | TODO | |
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

