# `page/bottom_navigation/bottom_navigation_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 点击底部标签切换对应主页面 | 已通过 | 批次26 | 0 | 0 | 0 | |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 消息标签展示未读消息数角标 | 已通过 | 批次85 | 0 | 0 | 0 | macOS(uid4)→Android(uid50) E2EE C2C 真机送达，消息 Tab 与会话条目均显红色角标「1」；99+ 上限未验 |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 联系人标签展示新好友提醒角标 | 已通过 | 批次103 | 2 | 2 | 0 | 真机全链路闭环：服务端 eval 造数（friend_ds:insert_pending+msg_s2c_ds:write_msg+message_ds:assemble_msg+send_next，MsgId af_qa103g_7_50）→ WS receivedAddFriend 落库 → countReminders → BadgeWidget「1 条未读 联系人」语义树+934px #FF3B30 双铁证 → 「接受→通过好友验证→完成」→ confirm 后角标即时消失（重启后也不复现）。⭐BUG#136 落库失败：receivedAddFriend 传 DateTime 对象，save() 对已存在 from/to 走 update 分支 `(json[createdAt] as num)` 强转抛 TypeError → 事务回滚 → 同 from/to 重复申请静默失败（首条走 insert 分支不暴露）；修复=createdAt 传 DateTimeHelper.millisecond() 毫秒整数。⭐BUG#137 角标 stale：confirmNewFriendProvider 是 autoDispose，confirm 后页面 pop → provider 立即 dispose → `Future.delayed(1s)` 回调里 ref.mounted 恒 false → countReminders 永远跳过 → 角标保留到重启/切页；修复=confirm() 内同步调用 countReminders（notifier 存活期 ref 有效且 update 已 await），S2C accept 路径（new_friend_provider.receivedConfirmFriend）同步补刷新 |
| 阻塞 | 需订阅频道产生新消息 | `page/bottom_navigation/bottom_navigation_page.dart` | 频道标签汇总订阅未读数角标 | 未测 | 批次26 | 0 | 0 | 0 | 自己发的频道消息不给自己产生未读 |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 我的标签展示长连接三态指示点 | 已通过 | 批次26 | 0 | 0 | 0 | 仅验证绿(已连)态；橙/红需断网触发，历史上断网会触发 EMUI 防误触锁屏 |
| 阻塞 | 需关闭 channel FeatureFlag | `page/bottom_navigation/bottom_navigation_page.dart` | 频道开关关闭时隐藏频道标签 | 未测 | 批次26 | 0 | 0 | 0 | 开关开启态已验（频道标签在位） |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 路由参数指定进入时的初始标签 | 已通过 | 批次103 | 0 | 0 | 0 | 单测证实：resolveInitialIndex 纯函数（query index=2→tab2；deep link 真机不可达=经 Splash 重定向 query 丢失，L96-108 代码核实） |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 越界标签下标归一化到合法范围 | 已通过 | 批次103 | 0 | 0 | 0 | 单测证实：normalizeIndex clamp 契约（99→末tab/ -1→0 / abc→0），unit_test 17 例全过 |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 平板宽度改用侧边导航栏布局 | 已通过 | 批次26 | 0 | 0 | 0 | `wm density 160` 使逻辑宽 720px，侧栏正确出现、底栏消失，验后已 reset |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 按系统返回键不退出应用 | 已通过 | 批次26 | 0 | 0 | 0 | |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 换设备后首屏弹一次密钥恢复引导 | 已通过 | 批次104 | 0 | 0 | 0 | 真机（0817 批次104）：adb run-as sed 注入 SharedPreferences 标记 `flutter.e2ee_new_device_guide_pending`=true（复现换设备条件）→ 冷启动底部导航 postFrame `_maybeShowE2EERecoveryGuide` 触发 → 像素铁证弹窗在位（半透明遮罩 87 灰 + 中央白面板 y=480~1048 + 双品牌蓝按钮 y≈960；华为 uiautomator 对 Flutter overlay dump 不完整故语义树不可见，须像素分析）→ 点「稍后」遮罩消失关闭 → 标记自动消费为 false → 重启冷启动不再弹（一次性消费语义闭环） |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 切换语言后标签文案同步刷新 | 已通过 | 批次26 | 0 | 0 | 0 | 中→英→中，四个标签文案即时刷新无需重启 |
