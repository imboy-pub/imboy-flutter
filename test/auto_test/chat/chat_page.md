# `page/chat/chat/chat_page.dart`

> 功能点 21 个 | bug 发现 12 / 解决 12 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/chat/chat/chat_page.dart` | 加载历史消息并向上翻页 | 已通过 | 批次72 | 1 | 1 | 0 | 真机复验：打开「小男孩」会话历史回填正常（日志 `归档为空但会话有消息(lastMsgId=...)，标记 historyUnavailable`），本地有缓存时正常展示消息列表，不再显示误导性「暂无数据」 |
| 无待办 | — | `page/chat/chat/chat_page.dart` | 输入文本并发送消息 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | — | `page/chat/chat/chat_page.dart` | 消息落库与送达状态标记 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | — | `page/chat/chat/chat_page.dart` | 顶栏展示对端标题与头像 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | — | `page/chat/chat/chat_page.dart` | 长按消息弹出操作菜单 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | — | `page/chat/chat/chat_page.dart` | 转发消息到其他会话 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | — | `page/chat/chat/chat_page.dart` | 发送并播放视频消息 | 已通过 | 批次25 | 3 | 3 | 0 | |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 打开表情面板插入表情 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：表情按钮打开面板（9 个 tab+emoji 网格），tab 切换正常，点 😘 插入输入框，右下退格键删除成功（批次26 疑点已复核：退格键存在） |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 清理已到期的阅后即焚消息 | 已通过 | 批次72 | 1 | 1 | 0 | 真机复验：设置页开阅后即焚 30s → 发送 qa-burn72 → 日志 `14:58:43 addMessage` → `14:59:13 removeMessageById`（恰 30s 整销毁），UI 列表同步移除；AI 回复消息不受影响 |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 发送图片并多图滑动预览 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：系统选择器选图发送成功（shot.png+tapcheck.png 两张均渲染「我发送的图片」），单图预览打开，多图预览左滑/右滑切换无崩溃无错误日志，AI 回复佐证送达 |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 录制并播放语音消息 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：授权录音后按住说话录 1s 发送成功（「我发送的语音 00:01」渲染），点击播放无崩溃无错误日志（播放动画 a11y 不可见，logcat 干净） |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 发送文件并确认打开 | 已通过 | 批次105 | 2 | 2 | 0 | 真机全链路闭环（0817 批次105）：单击文件气泡 → 「确定要打开文件吗？」对话框（语义树 bounds 取消 (320,773)-(448,869) / 确认 (464,773)-(592,869)）→ 确认 → getSingleFile(object_key) presign 授权下载 82191 bytes → 华为系统打开方式选择器（HwResolverActivity）→ 选华为视频 → FullscreenActivity + `player state:started` 播放成功。⭐BUG#141 单击无反应：文件消息渲染走 `fileMessageBuilder → FlyerChatFileMessage`（vendored 纯展示组件**零点击处理**），CustomMessageBuilder/MessageFileBuilder 是死路径；打开逻辑仅挂在双击（_onMessageDoubleTap L1160）；修复=chat_page._onMessageTap 加 FileMessage 分支 `confirmOpenFile(context, message.source)`（最小 diff，保留双击路径与 _e2ee_failed 引导优先级） |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 选点发送位置消息 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：附加项→地点→系统定位权限弹窗（点「始终允许」）→WebView 高德地图加载+**真实 GPS 定位成功**（深圳院子 88m/万科都会四季 228m/充电站 236m，此前「无 GPS 阻塞」顾虑排除）→选「万科·都会四季花园西区」→发送→气泡「我发送的位置消息」+地点卡片+地图缩略图渲染→日志 [C2C/location/PLAIN] 505B→C2C_SERVER_ACK→sent，缩略图 presign+Garage 下载成功（125KB） |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 选择好友发送名片消息 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：附加项→个人名片→「选择朋友」页（A/I/L/# 分组渲染正常，佐证 BUG#131 修复）→ 选 IMBoy → 确认弹窗「发送给 IMBoy + [个人名片]小男孩」→ 发送 → 气泡「我发送的名片 IMBoy 个人名片」渲染正常，无错误日志 |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 从收藏选内容发送到会话 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：长按 AI 消息→快捷菜单→收藏；附加项→收藏（isSelect）→点收藏内容→确认弹窗「发送给小男孩」→发送→气泡渲染+日志 C2C_SERVER_ACK→sent，AI 回复佐证送达。⚠️观察项：对收到的 C2C 消息（数字 TSID）v2 二进制 ACK，服务端回 CLIENT_ACK_ERROR「缺 msgId, invalid_type」重试 4 次失败，是否系统性问题待后续批次确认 |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 发送红包与转账 | 已通过 | 批次164 | 0 | 0 | 0 | 原阻塞理由（写生产资金流水）已被批次144/159 本地资金配方推翻：topup 仅打本地 9801+imboy_v1，无生产写。红包侧批次159 单聊实证；转账侧批次164 macOS 全链绿：附加面板转账项（仅 C2C）→发起转账页（余额条非0）→¥5.00+二次确认（金额摘要+收款人 Alice）→transfer_order 落库（pending/500分/默认备注）+wallet 精确扣 500 分+msg_c2c msg_type=transfer+聊天页转账卡片；测试=wallet/transfer_acceptance_batch164_test.dart。「转账金额下限不一致」待拍板 bug 不在本行范围 |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 引用消息回复并跳回原文 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：长按 AI 消息→快捷菜单「引用」→输入框上方出现引用块（内容摘要+关闭按钮）→输入 quote_test_72 发送→气泡「我发送的引用 quote_test_72 小...」→点击气泡触发日志「触发消息高亮」且列表滚动到原文位置 |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 撤回消息与本地删除消息 | 已通过 | 批次75 | 1 | 1 | 0 | BUG#141 真机复验通过：批次75 给 leeyi(C2C 好友)发 fix27 入库 msg_c2c(PLAIN)→长按撤回→logcat `处理撤回消息 status=31`+`撤回更新数据库结果:1`+服务端 CLIENT_ACK_CONFIRM 回环，revoke action 帧(e2ee="")被 alpha.27 接受。前置：定位并修复 effective_view 漏 IMBOY_E2EE_MODE override（imboy 01ffd329 部署 pro），app/policy 返回 disabled，客户端不再 fail-closed 拒发 |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 发送失败消息点击重试 | 已通过 | 批次75 | 1 | 1 | 0 | BUG#141 真机复验通过：批次75 点 toly27「发送失败」标签重试→logcat `开始重试`+`消息加入重试队列`（不再触发 MANUAL_RETRY「未加密不得重发」拦截，policy=disabled 放行）→`消息已发送 [C2C/text/PLAIN]`→`C2C_SERVER_ACK`→`消息状态已更新为 sent`。与撤回同根因（imboy bd330cbd），依赖同批次的 effective_view override 修复（01ffd329） |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 群内 @成员与 @所有人拦截 | 已通过 | 批次160 | 0 | 0 | 0 | macOS：bob 在产品研发群 role=1（DB 实证）→打 @ 弹提及列表（候选=李/李思远/林/林潇/周/周舟），点选成员输入框插入 @昵称；**非 admin 列表无「所有人」选项**（mention_list_widget isAdmin UI 层拦截；发送侧 resolveMentionsForSend→DeniedAll 由纯函数单测+服务端 check_admin 双兜底）；测试=misc/acceptance_batch160_test.dart AT-MN1 |
| 无待办 | - | `page/chat/chat/chat_page.dart` | E2EE 解密失败引导与密钥重建 | 已通过 | 批次165 | 0 | 0 | 0 | macOS 全链：向本地 msg_c2c 注入与 _handleE2EEMessage 失败分支同构的失败行（payload _e2ee_failed/_e2ee_reason=olm_decrypt_error，等价「历史消息由已失密钥加密」终态）→聊天页渲染「[加密消息]」占位气泡→点按弹「无法解密此消息」引导框（稍后可关/去恢复可达）→密钥恢复中心生成新密钥→不可逆警告→成功弹窗→去备份→收尾密钥非空自愈（批次161 同链）；解密引擎本身由 e2ee 单测/集成域覆盖；测试=settings/e2ee_decrypt_guide_acceptance_batch165_test.dart。⚠️顺带观察：真实离线密文行 payload 非法 JSON 时走 encrypted_payload 分支，metadata 无 _e2ee_failed，点按无动作（见 run1，属另一 UX 缺口未立项） |
