# `page/contact/new_friend/new_friend_page.dart`

> 功能点 11 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 解阻塞条件：需第二个账号发起真实好友申请 | `page/contact/new_friend/new_friend_page.dart` | 拉取好友申请列表并落库渲染 | BUG已修待验 | 批次27 | 1 | 0 | 1 | 批次27 装机复验受阻：uid50 当前零好友申请，页面只能验到空态「没有新的好友」，avatar 兜底路径无数据可打 |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 顶部搜索账号并跳转用户详情 | 已通过 | 批次29 | 0 | 0 | 0 | |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 搜索无结果与网络异常提示 | 已通过 | 批次29 | 0 | 0 | 0 | |
| 阻塞 | 需测试环境或自主测试账号（会写生产数据，删除不可恢复） | `page/contact/new_friend/new_friend_page.dart` | 左滑删除单条申请记录 | 未测 | 批次29 | 0 | 0 | 0 | 当前零申请无数据可删；需非生产数据 |
| 阻塞 | 需第二账号发起真实好友申请 | `page/contact/new_friend/new_friend_page.dart` | 点击「接受」进入确认好友页 | 未测 | 批次29 | 0 | 0 | 0 | uid50 零申请，空态无法触达 |
| 阻塞 | 需真实好友发起一条待处理申请 | `page/contact/new_friend/new_friend_page.dart` | 收到他人申请后渲染待处理项 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需第二账号发起真实好友申请 | `page/contact/new_friend/new_friend_page.dart` | 点击列表项进入对方资料页 | 未测 | 批次29 | 0 | 0 | 0 | 零申请，列表无项可点 |
| 阻塞 | 需第二账号发起真实好友申请 | `page/contact/new_friend/new_friend_page.dart` | 已添加/已过期/等待验证状态展示 | 未测 | 批次29 | 0 | 0 | 0 | 需真实申请数据 |
| 阻塞 | 需自主可控的第二账号（发申请会打扰第三方） | `page/contact/new_friend/new_friend_page.dart` | 自己发起的申请显示「已发送」标签 | 未测 | 批次29 | 0 | 0 | 0 | 生产账号不可随意发申请 |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 无申请时展示空态与说明文案 | 已通过 | 批次29 | 0 | 0 | 0 | |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 切换语言后页面文案即时刷新 | 已通过 | 批次29 | 0 | 0 | 0 | |
