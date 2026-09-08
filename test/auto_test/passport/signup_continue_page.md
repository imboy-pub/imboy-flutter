# `page/passport/signup_continue_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/passport/signup_continue_page.dart` | 注册数据缺失时展示兜底页 | 已通过 | 批次119 | 0 | 0 | 0 | AT-SU0：冷启动直进 continue 断言兜底页+返回按钮 |
| 无待办 | - | `page/passport/signup_continue_page.dart` | 兜底页返回注册页 | 已通过 | 批次119 | 0 | 0 | 0 | AT-SU0：返回按钮 go(/sign_up) 回注册页 |
| 无待办 | - | `page/passport/signup_continue_page.dart` | 展示验证码发送目标账号 | 已通过 | 批次119 | 0 | 0 | 0 | AT-SU1：目标账号在 RichText TextSpan（断言需 findRichText:true） |
| 无待办 | - | `page/passport/signup_continue_page.dart` | 输入 6 位遮蔽验证码 | 已通过 | 批次119 | 0 | 0 | 0 | AT-SU3：宿主注入真码 enterText；万能码 abc12345 8 位字母无法过 6 位数字 PinField |
| 无待办 | - | `page/passport/signup_continue_page.dart` | 重新发送注册验证码 | 已通过 | 批次119 | 1 | 1 | 0 | AT-SU2：60s 频控窗重发原裸显 per_minute_once 英文码——已修本地化为「操作频率过高，请稍后再试」 |
| 无待办 | - | `page/passport/signup_continue_page.dart` | 提示账号已存在无法重复注册 | 已通过 | 批次119 | 0 | 0 | 0 | AT-SU4：已注册号码 getcode 直接拒「该手机号已注册」 |
| 无待办 | - | `page/passport/signup_continue_page.dart` | 提交注册成功后跳管理账户 | 已通过 | 批次119 | 0 | 0 | 0 | AT-SU3：提交→操作成功!→go(/manage_account) |
| 无待办 | - | `page/passport/signup_continue_page.dart` | 提交注册失败错误提示 | 已通过 | 批次119 | 0 | 0 | 0 | AT-SU4 宿主层：signup 端返回「手机号已经被占用了」透出 |
| 无待办 | - | `page/passport/signup_continue_page.dart` | 弹出结果 SnackBar 提示 | 已通过 | 批次119 | 0 | 0 | 0 | 历史修复（ScaffoldMessenger+fixed）复验：成功/频控 toast 均正常弹出可视 |
| 无待办 | - | `page/passport/signup_continue_page.dart` | 页面滚动布局不溢出 | 已通过 | 批次119 | 0 | 0 | 0 | 历史修复（居中对齐+底部留白）复验：全流程无 RenderFlex 溢出异常 |
| 阻塞 | 待环境恢复执行（批次146 解锁：本地注册=批次119 AT-SU1~3 沙盒注码配方（真码从 verification_code 表注入），非生产注册无授权顾虑；注册成功页内切语言断言重建） | `page/passport/signup_continue_page.dart` | 语言切换实时重建页面 | 未测 | - | 0 | 0 | 0 | 批次119 同文件 10 场景已全绿，仅语言切换一条因当时注册授权顾虑遗留 |
| 无待办 | - | `page/passport/signup_continue_page.dart` | 底部返回登录入口跳转 | 已通过 | 批次119 | 0 | 0 | 0 | AT-SU5：「登录」入口 go(/sign_in) 跳转成功 |
