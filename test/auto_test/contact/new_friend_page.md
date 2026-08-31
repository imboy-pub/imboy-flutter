# `page/contact/new_friend/new_friend_page.dart`

> 功能点 11 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 拉取好友申请列表并落库渲染 | 已通过 | 批次W2R7 | 1 | 1 | 0 | API 对端（AT乙，本地库 RPC 重置密码后登录）向 ACC_A 发真实申请→apply_friend S2C 实时送达（logcat action=apply_friend）→联系人入口红点→列表渲染「走查AT乙/W2R7 复验好友申请/接受」；avatar 空串兜底占位路径实证正常（批次27 阻塞点已解） |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 顶部搜索账号并跳转用户详情 | 已通过 | 批次29 | 0 | 0 | 0 | |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 搜索无结果与网络异常提示 | 已通过 | 批次29 | 0 | 0 | 0 | |
| 阻塞 | 需测试环境或自主测试账号（会写生产数据，删除不可恢复） | `page/contact/new_friend/new_friend_page.dart` | 左滑删除单条申请记录 | 未测 | 批次29 | 0 | 0 | 0 | 当前零申请无数据可删；需非生产数据 |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 点击「接受」进入确认好友页 | 已通过 | 批次W2R7 | 0 | 0 | 0 | 接受→通过好友验证页（验证消息/备注预填走查AT乙/标签）→底部确认→回列表变「已添加」；DB user_friend 双向行 status=1 实证 |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 收到他人申请后渲染待处理项 | 已通过 | 批次W2R7 | 0 | 0 | 0 | AT乙 API 发申请→apply_friend S2C 实时送达→联系人入口红点+列表待处理项「接受」按钮，处理全程 logcat 无 type cast/异常 |
| 阻塞 | 需第二账号发起真实好友申请 | `page/contact/new_friend/new_friend_page.dart` | 点击列表项进入对方资料页 | 未测 | 批次29 | 0 | 0 | 0 | 零申请，列表无项可点 |
| 阻塞 | 需第二账号发起真实好友申请 | `page/contact/new_friend/new_friend_page.dart` | 已添加/已过期/等待验证状态展示 | 未测 | 批次W2R7 | 0 | 0 | 0 | 「已添加」状态已批次W2R7实证（接受确认后列表展示）；已过期/等待验证仍无数据 |
| 阻塞 | 需自主可控的第二账号（发申请会打扰第三方） | `page/contact/new_friend/new_friend_page.dart` | 自己发起的申请显示「已发送」标签 | 未测 | 批次29 | 0 | 0 | 0 | 生产账号不可随意发申请 |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 无申请时展示空态与说明文案 | 已通过 | 批次29 | 0 | 0 | 0 | |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 切换语言后页面文案即时刷新 | 已通过 | 批次29 | 0 | 0 | 0 | |
