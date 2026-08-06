# `page/passport/signup_continue_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 需实际注册且用户授权 | `page/passport/signup_continue_page.dart` | 注册数据缺失时展示兜底页 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需实际注册且用户授权 | `page/passport/signup_continue_page.dart` | 兜底页返回注册页 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需实际注册且用户授权 | `page/passport/signup_continue_page.dart` | 展示验证码发送目标账号 | 未测 | - | 0 | 0 | 0 | 邮箱 / 手机文案分支 |
| 阻塞 | 需实际注册且用户授权 | `page/passport/signup_continue_page.dart` | 输入 6 位遮蔽验证码 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需实际注册且用户授权 | `page/passport/signup_continue_page.dart` | 重新发送注册验证码 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需实际注册且用户授权 | `page/passport/signup_continue_page.dart` | 提示账号已存在无法重复注册 | 未测 | - | 0 | 0 | 0 | `param_already_exist` 分支 |
| 阻塞 | 需实际注册且用户授权 | `page/passport/signup_continue_page.dart` | 提交注册成功后跳管理账户 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需实际注册且用户授权 | `page/passport/signup_continue_page.dart` | 提交注册失败错误提示 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需实际注册且用户授权 | `page/passport/signup_continue_page.dart` | 弹出结果 SnackBar 提示 | BUG已修待验 | - | 1 | 1 | 0 | 历史修复：SnackBar 弹出屏幕外断言失败，已改 `ScaffoldMessenger` + `SnackBarBehavior.fixed`，从未真机复验 |
| 阻塞 | 需实际注册且用户授权 | `page/passport/signup_continue_page.dart` | 页面滚动布局不溢出 | BUG已修待验 | - | 1 | 1 | 0 | 历史修复：RenderFlex 溢出 48px，已移除居中对齐 + 底部 80pt 留白，从未真机复验 |
| 阻塞 | 需实际注册且用户授权 | `page/passport/signup_continue_page.dart` | 语言切换实时重建页面 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需实际注册且用户授权 | `page/passport/signup_continue_page.dart` | 底部返回登录入口跳转 | 未测 | - | 0 | 0 | 0 | |
