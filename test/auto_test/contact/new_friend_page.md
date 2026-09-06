# `page/contact/new_friend/new_friend_page.dart`

> 功能点 11 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 拉取好友申请列表并落库渲染 | 已通过 | 批次W2R7 | 1 | 1 | 0 | API 对端（AT乙，本地库 RPC 重置密码后登录）向 ACC_A 发真实申请→apply_friend S2C 实时送达（logcat action=apply_friend）→联系人入口红点→列表渲染「走查AT乙/W2R7 复验好友申请/接受」；avatar 空串兜底占位路径实证正常（批次27 阻塞点已解） |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 顶部搜索账号并跳转用户详情 | 已通过 | 批次29 | 0 | 0 | 0 | |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 搜索无结果与网络异常提示 | 已通过 | 批次29 | 0 | 0 | 0 | |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 左滑删除单条申请记录 | 已通过 | 批次116 | 1 | 1 | 0 | 本地 SQLite 造数（NewFriendRepo().save 直插，键名对齐 repo 列名）；Slidable 左滑→删除→行消失+列表持久化；挖出客户端真 bug=delete 的 uk 拼接缺下划线（`${from}+${to}` 与模型 `${from}_${to}` 不一致恒 miss → removeAt(-1) 删除无响应）已修+index==-1 防御 |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 点击「接受」进入确认好友页 | 已通过 | 批次W2R7 | 0 | 0 | 0 | 接受→通过好友验证页（验证消息/备注预填走查AT乙/标签）→底部确认→回列表变「已添加」；DB user_friend 双向行 status=1 实证 |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 收到他人申请后渲染待处理项 | 已通过 | 批次W2R7 | 0 | 0 | 0 | AT乙 API 发申请→apply_friend S2C 实时送达→联系人入口红点+列表待处理项「接受」按钮，处理全程 logcat 无 type cast/异常 |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 点击列表项进入对方资料页 | 已通过 | 批次116 | 0 | 0 | 0 | 点申请行→GMSmoke07 资料页挂载（对端=申请人） |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 已添加/已过期/等待验证状态展示 | 已通过 | 批次116 | 0 | 0 | 0 | 三种状态共存实证：已添加/已过期渲染终态标签；等待验证行无终态标签+msg 副标题 |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 自己发起的申请显示「已发送」标签 | 已通过 | 批次116 | 0 | 0 | 0 | from=bob 的 fromSelf 申请渲染「已发送」（本地造数，无生产账号打扰） |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 无申请时展示空态与说明文案 | 已通过 | 批次29 | 0 | 0 | 0 | |
| 无待办 | - | `page/contact/new_friend/new_friend_page.dart` | 切换语言后页面文案即时刷新 | 已通过 | 批次29 | 0 | 0 | 0 | |
