# `page/bottom_navigation/bottom_navigation_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 点击底部标签切换对应主页面 | 已通过 | 批次26 | 0 | 0 | 0 | |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 消息标签展示未读消息数角标 | 已通过 | 批次85 | 0 | 0 | 0 | macOS(uid4)→Android(uid50) E2EE C2C 真机送达，消息 Tab 与会话条目均显红色角标「1」；99+ 上限未验 |
| 阻塞 | 需真实好友发起申请 | `page/bottom_navigation/bottom_navigation_page.dart` | 联系人标签展示新好友提醒角标 | 未测 | 批次26 | 0 | 0 | 0 | 造申请会打扰第三方，按规程跳过 |
| 阻塞 | 需订阅频道产生新消息 | `page/bottom_navigation/bottom_navigation_page.dart` | 频道标签汇总订阅未读数角标 | 未测 | 批次26 | 0 | 0 | 0 | 自己发的频道消息不给自己产生未读 |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 我的标签展示长连接三态指示点 | 已通过 | 批次26 | 0 | 0 | 0 | 仅验证绿(已连)态；橙/红需断网触发，历史上断网会触发 EMUI 防误触锁屏 |
| 阻塞 | 需关闭 channel FeatureFlag | `page/bottom_navigation/bottom_navigation_page.dart` | 频道开关关闭时隐藏频道标签 | 未测 | 批次26 | 0 | 0 | 0 | 开关开启态已验（频道标签在位） |
| 阻塞 | 需带参路由/deep link 进入 | `page/bottom_navigation/bottom_navigation_page.dart` | 路由参数指定进入时的初始标签 | 未测 | 批次26 | 0 | 0 | 0 | 冷启动默认落第一个标签已验 |
| 阻塞 | 需注入越界下标 | `page/bottom_navigation/bottom_navigation_page.dart` | 越界标签下标归一化到合法范围 | 未测 | 批次26 | 0 | 0 | 0 | UI 层无法构造越界值，宜补单测 |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 平板宽度改用侧边导航栏布局 | 已通过 | 批次26 | 0 | 0 | 0 | `wm density 160` 使逻辑宽 720px，侧栏正确出现、底栏消失，验后已 reset |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 按系统返回键不退出应用 | 已通过 | 批次26 | 0 | 0 | 0 | |
| 阻塞 | 需换设备或清一次性标记 | `page/bottom_navigation/bottom_navigation_page.dart` | 换设备后首屏弹一次密钥恢复引导 | 未测 | 批次26 | 0 | 0 | 0 | 当前设备标记已消费 |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 切换语言后标签文案同步刷新 | 已通过 | 批次26 | 0 | 0 | 0 | 中→英→中，四个标签文案即时刷新无需重启 |
