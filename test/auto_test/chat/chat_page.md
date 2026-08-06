# `page/chat/chat/chat_page.dart`

> 功能点 21 个 | bug 发现 10 / 解决 6 / 待处理 4
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 待修复 | 2026-08-06 | `page/chat/chat/chat_page.dart` | 加载历史消息并向上翻页 | 有BUG待修 | 批次25 | 1 | 0 | 1 | BUG#119 所有会话打开后「暂无数据」，history 拉回本地仍 0 条 |
| 无待办 | — | `page/chat/chat/chat_page.dart` | 输入文本并发送消息 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | — | `page/chat/chat/chat_page.dart` | 消息落库与送达状态标记 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 无待办 | — | `page/chat/chat/chat_page.dart` | 顶栏展示对端标题与头像 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | — | `page/chat/chat/chat_page.dart` | 长按消息弹出操作菜单 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | — | `page/chat/chat/chat_page.dart` | 转发消息到其他会话 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | — | `page/chat/chat/chat_page.dart` | 发送并播放视频消息 | 已通过 | 批次25 | 3 | 3 | 0 | |
| 待修复 | 2026-08-06 | `page/chat/chat/chat_page.dart` | 打开表情面板插入表情 | 有BUG待修 | 批次25 | 2 | 0 | 2 | P3 面板缺退格删除键；P3 搜索 FAB 悬浮位置突兀 |
| 待修复 | 2026-08-06 | `page/chat/chat/chat_page.dart` | 清理已到期的阅后即焚消息 | 有BUG待修 | 批次25 | 1 | 0 | 1 | `chat_provider.dart:623` 清理函数是只打日志的空实现 |
| 回归复测 | 2026-08-07 | `page/chat/chat/chat_page.dart` | 发送图片并多图滑动预览 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/chat/chat/chat_page.dart` | 录制并播放语音消息 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/chat/chat/chat_page.dart` | 发送文件并确认打开 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/chat/chat/chat_page.dart` | 选点发送位置消息 | 待重验 | 批次25 | 0 | 0 | 0 | 需定位权限与真实 GPS |
| 回归复测 | 2026-08-07 | `page/chat/chat/chat_page.dart` | 选择好友发送名片消息 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/chat/chat/chat_page.dart` | 从收藏选内容发送到会话 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 阻塞 | 解阻塞条件：备好测试账户余额且允许写生产资金流水 | `page/chat/chat/chat_page.dart` | 发送红包与转账 | 未测 | - | 0 | 0 | 0 | 涉及真实资金与生产数据写入 |
| 回归复测 | 2026-08-07 | `page/chat/chat/chat_page.dart` | 引用消息回复并跳回原文 | 待重验 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/chat/chat/chat_page.dart` | 撤回消息与本地删除消息 | 待重验 | 批次25 | 0 | 0 | 0 | 撤回窗口期有时限，需即时操作 |
| 回归复测 | 2026-08-07 | `page/chat/chat/chat_page.dart` | 发送失败消息点击重试 | 待重验 | 批次25 | 0 | 0 | 0 | 需断网构造失败态 |
| 阻塞 | 解阻塞条件：需可用群 + 至少两名成员在线 | `page/chat/chat/chat_page.dart` | 群内 @成员与 @所有人拦截 | 未测 | - | 0 | 0 | 0 | 非管理员 @所有人需真实多人群验证 |
| 阻塞 | 解阻塞条件：需换设备或清空密钥制造解密失败 | `page/chat/chat/chat_page.dart` | E2EE 解密失败引导与密钥重建 | 未测 | - | 0 | 0 | 0 | 重建密钥为不可逆操作 |
