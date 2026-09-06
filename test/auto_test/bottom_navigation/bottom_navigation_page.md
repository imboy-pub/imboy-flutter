# `page/bottom_navigation/bottom_navigation_page.dart`

> 功能点 12 个 | bug 发现 3 / 解决 3 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 点击底部标签切换对应主页面 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4 真机逐项实切复核（消息/联系人/频道/我的）；批次26 历史证据沿用。47461adc 底栏换血仅发生在 workspace 壳（消息/概览/频道/群组/项目），本页（chat 壳）未被触及 |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 消息标签展示未读消息数角标 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4 复核：无未读时无角标正常；批次85 E2EE C2C 全链路角标证据沿用；本页代码未被受检提交改动（git 核实） |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 联系人标签展示新好友提醒角标 | 已通过 | 批次W2R4 | 2 | 2 | 0 | W2R4 入口可达性实测：联系人标签仍在 chat 壳底栏第2位（收敛换血未移除该标签）；批次103 全链路造数证据沿用未重复。⭐BUG#136/#137 详见 git log 批次103 |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 频道标签汇总订阅未读数角标 | 已通过 | 批次W2R4 | 1 | 1 | 0 | W2R4 复核：频道标签仍在第3位；本地账号订阅为空显示正常；批次106 全链路证据沿用。⭐BUG#146 详见 git log 批次106 |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 我的标签展示长连接三态指示点 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4 三态实测：重启后绿(已连)、WS 瞬时断连红→重连绿均观测到；另观察历史既有现象：同会话退出重登后 WS 无法重连、点恒橙直至重启（quitLogin 清 wsUrl 缓存+initConfig 仅启动拉取，423da5c8 既有行为非受检提交引入，不计 bug）；橙(连接中)态为该场景表现 |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 频道开关关闭时隐藏频道标签 | 已通过 | 批次112 | 0 | 0 | 0 | 批次112 macOS 沙箱：AppFeatureRegistry 种子 channel=false 后挂载 BottomNavigationPage，tab_channel 与频道文案均未渲染、其余 tab 在位（web_search_acceptance_test.dart AT-BN1） |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 路由参数指定进入时的初始标签 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4 代码复核：本页与 resolveInitialIndex 未被受检提交触及；批次103 单测证据（query index=2→tab2；deep link 重定向 query 丢失 L96-108）沿用 |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 越界标签下标归一化到合法范围 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4 代码复核：normalizeIndex clamp 契约未变；批次103 单测 17 例证据沿用 |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 平板宽度改用侧边导航栏布局 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4 真机复测：wm density 160 侧栏正确出现（四项纵排+绿点）、底栏消失，验后已 reset |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 按系统返回键不退出应用 | 已通过 | 批次26 | 0 | 0 | 0 | W2R4 未复测（本机怪癖禁用 keyevent 4，一律页面内返回）；批次26 证据沿用，本页未改 |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 换设备后首屏弹一次密钥恢复引导 | 已通过 | 批次104 | 0 | 0 | 0 | W2R4 未重跑（需 run-as 注入 SharedPreferences 标记）；批次104 全链路证据沿用，触发链路 `_maybeShowE2EERecoveryGuide` 未被受检提交改动 |
| 无待办 | - | `page/bottom_navigation/bottom_navigation_page.dart` | 切换语言后标签文案同步刷新 | 已通过 | 批次26 | 0 | 0 | 0 | W2R4 复核：tab 文案源 chat i18n 未被受检提交改动（47461adc/ea682e31 仅增 workspace i18n 键）；批次26 证据沿用 |
