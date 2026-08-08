# `page/chat/chat/chat_page.dart`

> 功能点 21 个 | bug 发现 12 / 解决 8 / 待处理 4
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
| 待复验 | 2026-08-08 | `page/chat/chat/chat_page.dart` | 发送文件并确认打开 | 待重验 | 批次72 | 1 | 0 | 1 | 真机：系统选择器选 qa_audio_0804.mp3 发送成功；双击验证定性为代码 bug（BUG#140，推翻此前「工具限制」误判）：双击注入（79ms 间隔<300ms 窗口）→ 两次 `Message tapped`（onTap）立即触发 → onDoubleTap 从未触发 → confirmOpenFile 未弹。根因=Chat 组件（plugin/flutter_chat_ui chat.dart）构造函数缺 onMessageDoubleTap 参数且 Provider 未注册，chat_message.dart L126 消费断链；带双击绑定的 ChatMessageList 因 `_useOptimizedMessageList=false`（chat_page.dart L71）是死代码且为半成品（气泡占位渲染）不可启用。修复进行中：chat.dart 加 onMessageDoubleTap 参数+Provider，chat_page.dart Chat() 传 _onMessageDoubleTap；修复后双击文件消息弹 confirmOpenFile，双击文本弹 showTextMessage，需新 APK 复验 |
| 回归复测 | 2026-08-07 | `page/chat/chat/chat_page.dart` | 选点发送位置消息 | 待重验 | 批次25 | 0 | 0 | 0 | 需定位权限与真实 GPS |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 选择好友发送名片消息 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：附加项→个人名片→「选择朋友」页（A/I/L/# 分组渲染正常，佐证 BUG#131 修复）→ 选 IMBoy → 确认弹窗「发送给 IMBoy + [个人名片]小男孩」→ 发送 → 气泡「我发送的名片 IMBoy 个人名片」渲染正常，无错误日志 |
| 无待办 | - | `page/chat/chat/chat_page.dart` | 从收藏选内容发送到会话 | 已通过 | 批次72 | 0 | 0 | 0 | 真机：长按 AI 消息→快捷菜单→收藏；附加项→收藏（isSelect）→点收藏内容→确认弹窗「发送给小男孩」→发送→气泡渲染+日志 C2C_SERVER_ACK→sent，AI 回复佐证送达。⚠️观察项：对收到的 C2C 消息（数字 TSID）v2 二进制 ACK，服务端回 CLIENT_ACK_ERROR「缺 msgId, invalid_type」重试 4 次失败，是否系统性问题待后续批次确认 |
| 阻塞 | 解阻塞条件：备好测试账户余额且允许写生产资金流水 | `page/chat/chat/chat_page.dart` | 发送红包与转账 | 未测 | - | 0 | 0 | 0 | 涉及真实资金与生产数据写入 |
| 回归复测 | 2026-08-07 | `page/chat/chat/chat_page.dart` | 引用消息回复并跳回原文 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/chat/chat/chat_page.dart` | 撤回消息与本地删除消息 | 待重验 | 批次25 | 0 | 0 | 0 | 撤回窗口期有时限，需即时操作 |
| 回归复测 | 2026-08-07 | `page/chat/chat/chat_page.dart` | 发送失败消息点击重试 | 待重验 | 批次25 | 0 | 0 | 0 | 需断网构造失败态 |
| 阻塞 | 解阻塞条件：需可用群 + 至少两名成员在线 | `page/chat/chat/chat_page.dart` | 群内 @成员与 @所有人拦截 | 未测 | - | 0 | 0 | 0 | 非管理员 @所有人需真实多人群验证 |
| 阻塞 | 解阻塞条件：需换设备或清空密钥制造解密失败 | `page/chat/chat/chat_page.dart` | E2EE 解密失败引导与密钥重建 | 未测 | - | 0 | 0 | 0 | 重建密钥为不可逆操作 |
