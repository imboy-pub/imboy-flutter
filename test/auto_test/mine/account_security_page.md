# `page/mine/account_security/account_security_page.dart`

> 功能点 9 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-08 | `page/mine/account_security/account_security_page.dart` | 回显已绑定邮箱的掩码文本 | 已通过 | 批次49 | 0 | 0 | 0 | 真机「绑定邮箱 11***@imboy.pub」；代码 L99-100 已绑定走 _maskEmail |
| 回归复测 | 2026-08-08 | `page/mine/account_security/account_security_page.dart` | 回显已绑定手机的掩码文本 | 已通过 | 批次49 | 0 | 0 | 0 | 代码确认 L102-104 已绑定走 hiddenPhone；117 未绑定走未绑定分支（无掩码可验） |
| 回归复测 | 2026-08-08 | `page/mine/account_security/account_security_page.dart` | 未绑定时显示未绑定文案 | 已通过 | 批次49 | 0 | 0 | 0 | 真机手机号行「未绑定」；代码 L102-104 hasBoundMobile false→notBound |
| 回归复测 | 2026-08-08 | `page/mine/account_security/account_security_page.dart` | 短用户名邮箱的掩码降级处理 | 已通过 | 批次49 | 0 | 0 | 0 | 代码确认 L177-178 name.length<=2→首字符*域名；真机 11***@imboy.pub 为 name≥3 分支与降级分支互斥成立 |
| 回归复测 | 2026-08-08 | `page/mine/account_security/account_security_page.dart` | 进入绑定或更改邮箱页 | 已通过 | 批次49 | 0 | 0 | 0 | 真机「修改邮箱」页：当前邮箱掩码+已绑定徽标+新邮箱/验证码输入+获取验证码+确认更换；未提交 |
| 回归复测 | 2026-08-08 | `page/mine/account_security/account_security_page.dart` | 进入绑定或更改手机页 | 已通过 | 批次49 | 0 | 0 | 0 | 真机「绑定手机号」页：未绑定+86 区号+手机号/验证码输入+获取验证码+立即绑定；未提交 |
| 无待办 | - | `page/mine/account_security/account_security_page.dart` | 进入修改登录密码页 | 已通过 | 批次17 | 1 | 1 | 0 | 仅验入口可达，未实际改密码 |
| 回归复测 | 2026-08-08 | `page/mine/account_security/account_security_page.dart` | 渲染登录凭证分组标题 | 已通过 | 批次49 | 0 | 0 | 0 | 真机「登录凭证」分组标题；代码 sectionLoginCredentials.toUpperCase() |
| 回归复测 | 2026-08-08 | `page/mine/account_security/account_security_page.dart` | 返回上级设置页 | 已通过 | 批次49 | 0 | 0 | 0 | 真机绑定手机页→账号安全页→设置页逐级返回；绑定邮箱页返回账号安全页 |
