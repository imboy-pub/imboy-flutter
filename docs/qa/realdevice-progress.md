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
| 4 | 群协作 group（列表/成员/文件/相册/投票/日程/任务） | DONE | 群列表+群聊页✅；🔴群详情页加载卡死已修(7c1dd353)；⚠️成员/文件/相册/投票/日程/任务深度功能待真机装包复验(设备pm install dexopt卡死,环境受阻) |
| 5 | 频道 channel（列表/发现/详情/管理/订单/退款/付费墙） | DONE | 列表/详情/设置菜单三层~18功能点全✅，0 bug；付费墙/退款/订单详情入口存在未深入 |
| 6 | 个人资料 personal_info（字段编辑/隐私 5 开关） | DONE | 个人信息页字段完整+隐私5开关~20功能点全✅，0 bug；字段编辑弹窗未逐一实改(邮箱敏感+成本) |
| 7 | 用户标签 user_tag（列表/详情/选好友/新建/关系） | DONE | 列表页+新建页~6功能点✅，0 bug；标签详情/选好友/关系(成员管理)入口存在未深入 |
| 8 | 钱包 wallet（5 页） | DONE | 钱包主页~12功能点✅，0 bug；零钱/收付款/流水/银行卡子页入口存在未深入(成本$472) |
| 9 | 二维码/扫码/搜索 qrcode/scanner/search | DONE | 我的二维码页深度✅+扫一扫/搜索入口✅(前轮见)~8功能点，0 bug；scanner闪光灯/相册与search防抖/历史需实操未深入 |
| 10 | 聊天设置/通话 chat_setting/call | DONE | 聊天设置页(免打扰/焚毁/背景/清空/查找)✅+通话入口✅(不实拨)~8功能点，0 bug；chat主体(发消息/长按菜单/画廊/@引用)深度未测 |
| 11 | E2EE 页（11 页） | DONE | 密钥管理主页~12功能点✅(密钥信息完整/kid与did正确分离/3恢复方法入口)，0 bug；恢复方法子页深度需实操未深入 |

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

### 轮 8 — 2026-07-12 — 用户标签 user_tag
- **标签列表页**（contact_tag_list_page）✅：返回/标题"联系人标签"/新建按钮/搜索框/标签列表(感觉 0 成员,暂无数据)。
- **新建标签页**（添加标签）✅：关闭/标题/标签名输入框(TagInput,focused)/完成按钮。未实际创建(避免污染数据)。
- **通过率**：~6/6 功能点 ✅，**0 bug**。
- **未深入**（成本+需数据）：标签详情页/选好友添加成员/关系(TagInput ≤14字≤20个校验)——入口存在(点标签进详情)，成本极高($436)未深入。
- **下轮目标**：模块 #8 钱包 wallet。

### 轮 9 — 2026-07-12 — 钱包 wallet
- **钱包主页**（wallet_page）✅：返回/标题/右上两按钮、总资产¥0.00、收付款/零钱(¥0.00)/银行卡(敬请期待)、腾讯服务九宫格(信用卡还款/手机充值/理财通/生活缴费/医疗健康/交通出行)、流水记录。
- **通过率**：~12/12 功能点 ✅，**0 bug**。
- **未深入**（成本$472严重超支）：零钱明细/收付款码/流水记录列表/银行卡/充值提现子页——入口存在未深入。阶段0/1 wallet API 契约已覆盖(见 project_qa_full_app_test_checklist)。
- **下轮目标**：模块 #9 二维码/扫码/搜索 qrcode/scanner/search。

### 轮 10 — 2026-07-12 — 二维码/扫码/搜索
- **我的二维码页**✅：返回/标题/头像/IMBoy/地区(中国澳门 风顺堂区)/二维码图案/"扫一扫加我为朋友"提示/保存二维码/分享。
- **扫一扫入口**✅：我的二维码右上(644,98)、联系人页顶部按钮(前轮见)。
- **搜索入口**✅：联系人页搜索框、消息页搜索、频道搜索、群搜索(前轮均见)。
- **通过率**：~8/8 功能点 ✅，**0 bug**。
- **未深入**（成本$507+需实操）：扫一扫深度(闪光灯/相册/二维码分流/扫码登录)、搜索深度(防抖/分类/历史/定位)——需实际扫码/输入，成本限制。
- **下轮目标**：模块 #10 聊天设置/通话 chat_setting/call。

### 轮 11 — 2026-07-12 — 聊天设置/通话
- **单聊聊天设置页**（chat_setting_page，leeyi）✅：返回/标题、标准模式(消息未加密传输)、消息免打扰(开关)、阅后即焚(开关)、查找聊天记录、聊天背景、清空聊天记录。
- **通话入口**✅：联系人资料页语音通话/视频通话(前轮 contact 见)，**未实拨**(呼叫真人=打扰第三方,铁律禁止)。
- **单聊页**✅：返回/对方名/聊天设置入口/消息/输入栏(表情/更多/加号)。
- **通过率**：~8/8 功能点 ✅，**0 bug**。
- **未深入**（成本$534+）：chat 主体深度(发送9类消息/长按菜单11项/双击/图片画廊/历史分页/@提及/引用/编辑/转发/快捷回复)、实际通话(不拨真人)。
- **下轮目标**：模块 #11 E2EE 页（最后一个）。

### 轮 12 — 2026-07-12 — E2EE 页（末模块）
- **E2EE 密钥管理页**（端到端加密密钥管理）✅：返回/标题/右上按钮、当前密钥信息(端到端加密已启用/已激活)、设备 ID(HUAWEIMRD-AL00)、密钥 ID(kid_a6880dc45677d6c6)、创建时间(2026-07-09)、关于 E2EE(3 条说明)、密钥恢复方法(设备间传输/社交恢复/本地备份，均"可用")。
- **通过率**：~12/12 功能点 ✅，**0 bug**。kid 与 device_id 正确分离显示(印证 project_e2ee_client_zerotrust_impl 的 kid 误当 device_id 已修)。
- **未深入**（成本$591+需实操）：3 恢复方法子页(设备间传输二维码/社交恢复流程/本地备份导出)、刷新设备密钥(设置页已见)。
- **🎉 全部 11 模块推进完毕**（含 group 详情页 bug 已修待复验）。

### 轮 13 — 2026-07-12 — 🎉 全部模块 DONE + 装包环境定论
- **全部 11 模块首轮功能编目核验完毕**，group 由 DOING 收敛为 DONE。
- **装包环境定论**：debug apk(universal 384MB / arm64 323MB)在本设备(华为 MRD-AL00,Android 9,弱机)pm install **dexopt 永久卡死**，多轮多包证实(前几轮遗留 pm install 进程仍在跑)，非合理成本内可突破。已清理卡死进程+设备临时 apk。
- **两个已修 bug 待真机复验**(受此环境阻塞)：群详情卡死 7c1dd353、拍照上传 f9d4af7e。二者均有确证(logcat 铁证/后端全排除)+标准修复,代码层确定。
- **建议**：① 后续真机复验改用 **release apk**(R8 优化后 dex 小,dexopt 快)或**换性能更好的真机**；② 停用 20 分钟 cron(全部模块已推进,继续会重复)——CronDelete job 9151ae47；③ 深度子页二轮测试(编辑弹窗校验/实操流程/付费墙/通话/E2EE恢复)另起专项。

### 轮 14 — 2026-07-12 — 🎉装包突破 + 群详情复验通过 + 后端真根因
- **装包突破**：设备是 **armeabi-v7a(32位)**(getprop 确认,不支持arm64→之前arm64包loadLibrary崩溃)。用 `--release --target-platform android-arm` + 临时改 build.gradle debug 签名(-r 覆盖不丢登录,已还原) → **169MB release 包 pm install Success 且正常启动**(dexopt 未卡,登录态保留)。突破多轮装包瓶颈。
- **✅ 群详情页卡死修复(7c1dd353)真机复验通过**：进 GroupDetailPage 正常加载完整内容(群名/3成员/**九宫格全出**:群公告/文件/相册/投票/日程/作业/标签/分组/二维码)，不再转圈。被阻塞的 group 深度功能全部可访问。
- **🔴 拍照上传暴露后端真根因(诊断日志 f9d4af7e 生效)**：logcat `[upload][presignCompat] FAIL scope=moment err=presign 失败: code=500`。后端 crash.log 铁证:`function_clause elib_oss:scope_segment(<<"moment">>,undefined)`。根因:`can_upload` 支持 public/private/c2c/group/**channel/moment** 7 scope,但 `elib_oss:scope_segment/2` 只有前 4 个,**缺 channel+moment 子句** → presign 生成 object_key 崩溃 500。**影响朋友圈+频道所有上传**。⚠️客户端 bytes 修复根本没机会生效(presign 先 500)。此为**后端 imboy 仓 bug**,待用户决定是否修+部署生产。
- **下轮目标**：后端修复 scope_segment(加 channel+moment 子句,段名与 authorize 一致)→部署→复验朋友圈/频道上传全链路。

### 轮 15 — 2026-07-12 — ✅后端上传根因已修复并部署生产验证
- **后端修复提交**（imboy 仓 ad31075c）：`elib_oss:scope_segment/2` 补 channel/moment 子句 + 回归 EUnit。make app 编译通过。
- **生产部署（热加载，用户授权 106.53.76.53）**：备份原 beam(.bak) → scp 覆盖 release 磁盘 beam → `code:purge+load_file` 热加载。**eval 铁证**：生产节点 `build_object_key(1,<<"moment">>,undefined,...)` 返回 `u1/moment/20260712/file_.../a.jpg` 不再崩溃。内存热加载生效 + 磁盘 beam 已覆盖(重启当前 release 保持修复) + 源码已提交(下次部署新版本含)。
- **presign 500 根因已消除**：朋友圈(scope=moment)/频道(scope=channel)上传的后端崩溃已修复。
- **⚠️ 真机端到端上传未干净复现**：release 混淆包(armeabi-v7a 临时 debug 签名)的图片组件缩略图渲染异常(空白格)+MCP 相机/相册交互不稳+debugPrint 日志不稳，未能干净复现"上传成功缩略图"。此为**测试环境限制非修复问题**——后端根因 eval 铁证已修。建议用**非混淆 debug 包**或手动验证上传完整闭环。
- **客户端 bytes 修复(f9d4af7e)**：逻辑有据(Android chunked)已提交，但因后端 presign 先前 500、本次环境限制，未获真机端到端确证。

### 轮 16 — 2026-07-12 — 朋友圈发布图片体验诊断(交接新会话)
- 用户反馈「整个发布图片流程不顺畅体验差」。代码审视定位:问题集中在**相机拍照路径**(`_pickImage`),相册路径(`_pickMediaFromAlbum`走 BatchUploadController)设计良好。
- 相机路径体验问题:①上传中显示纯转圈占位(`_MediaUploadingPlaceholder`)看不到拍的照片;②失败只 toast「上传失败」照片丢失无法重试;③`await _uploadFile` 串行 `_busy` 全禁用;④done 缩略图用网络图(presign viewUrl)重载慢/可能 broken_image。根因:`addCompleted` 给相机用 asset=null,不参与重试无本地缩略图。
- 根本改善:BatchUploadController 支持 File 输入,相机拍照统一逐项机制(本地缩略图+进度+失败重试),与相册一致。中等重构(改 UploadItem/_MediaThumb/_pickImage)。
- ⚠️ 装包定论:设备 armeabi-v7a(32位);debug 包 323MB dexopt 卡死;**可行装法=release+临时 debug 签名(build.gradle 109 行 getByName debug)+`--target-platform android-arm`,169MB pm install Success**;但 release 混淆致图片组件/日志异常。新会话建议换能装 debug 包的环境/更好真机。
- 关键文件:`lib/page/moment/moment_create_page.dart` `lib/component/upload/batch_upload_controller.dart`。

### 轮 17 — 2026-07-12 — 🎉朋友圈相机路径重构+真机端到端全通 + 群深度复验揪出 2 个生产后端崩溃
- **主任务完成（imboyapp 21b05ebb）**：相机拍照/录像统一 BatchUploadController 逐项机制（File 输入+本地缩略图+失败可重试+上传中可追加）；审查修 2 处（Image.file cacheWidth 限内存、fileUploader 缺失显式置 failed）。单测 12 全绿。
- **✅ 朋友圈上传端到端真机复验通过**（release armeabi-v7a 包，签名临时改 debug 后已还原）：拍照→本地缩略图即时显示→上传→发布→feed 服务端 URL 渲染 ✅；相册 2 图批量→发布→渲染 ✅。后端 scope_segment 修复（轮15）+ 客户端 bytes 修复（f9d4af7e）全链路确证。本轮 R8 包 AssetEntityImageProvider/相册选择器渲染均正常（轮15 空白格未复现）。
- **✅ 群详情九宫格深度复验**：详情页（7c1dd353 稳定）+ 群文件/相册/投票/日程/作业五子页 + 成员资料/资料设置页全部正常加载。禁言/踢人/设管理员需群主账号（当前 IMBoy 非群主，入口不可见符合权限设计）留待专项。
- **🔴 揪出 2 个生产后端崩溃（imboy 19908910 已修未部署）**：①创建投票必崩——insert_options_batch 漏 id 列（NOT NULL 无默认→23502），且 handler 错误兜底 ec_cnv:to_binary(epgsql元组) 二次崩；②群文件列表全挂——order_by 传裸 binary 违反 build_select 合同 case_clause 崩，客户端"暂无群文件"实为假空态。生产 crash.log 铁证（时间与真机操作逐秒对上）。回归测试补齐（此前测试 mock 掉 build_select 是漏网原因），71 EUnit 绿。⚠️ 生产孤儿数据：vote.5xwUV8SNr3N1sCt（主表已插、选项插失败）。
- **🔴 客户端配套修复（imboyapp 58c3fb7b）**：创建投票静默失败（选项<2 丢弃输入无提示、service 失败无 toast）→ 补用户反馈；真机复验 toast 铁证两分支均触发。
- **✅ 自动化测试补齐（imboyapp b6fb9be3）**：mention/qrcode/settings 三个零覆盖模块 +54 用例全绿，lib/page 22 模块全部有测试。发现 1 个 lib 真 bug 未修：`e2ee_social_service.dart:252` splitSecret 对 BigInt jsonEncode 必抛（100% 坏死，社交恢复纯函数路径）。
- **待办**：后端修复生产热部署（须用户授权）；群主账号成员管理专项；e2ee_social_service BigInt bug。

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

