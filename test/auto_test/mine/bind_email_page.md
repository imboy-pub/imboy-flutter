# `page/mine/account_security/bind_email_page.dart`

> 功能点 12 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/mine/account_security/bind_email_page.dart` | 展示当前邮箱与绑定状态徽标 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测「当前邮箱 11***@imboy.pub」+「已绑定」徽标（uid50 已绑定，掩码 _maskEmail） |
| 无待办 | - | `page/mine/account_security/bind_email_page.dart` | 已绑定时标题切换为更改邮箱 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测标题「修改邮箱」（hasBound→changeEmail 分支） |
| 无待办 | - | `page/mine/account_security/bind_email_page.dart` | 输入邮箱并实时同步到状态 | 已通过 | 批次29 | 0 | 0 | 0 | 输入 user@example.com 后校验行实时变「正确」（listener→updateEmail 驱动状态） |
| 无待办 | - | `page/mine/account_security/bind_email_page.dart` | 限制验证码为六位纯数字 | 已通过 | 批次29 | 0 | 0 | 0 | 输入 abc12345678 后框中仅剩 123456（digitsOnly 过滤字母+6位截断 inputFormatters） |
| 无待办 | - | `page/mine/account_security/bind_email_page.dart` | 判定获取验证码按钮可用态 | 已通过 | 批次29 | 0 | 0 | 0 | 禁用态实测：无效邮箱点击无网络请求（onPressed=null 拦截）；可用态代码证实 provider L88-93（有效邮箱时未点击防真实发信） |
| 阻塞 | 待环境恢复执行（批次146 解锁：本地邮箱验证码照常落库不外发（passport_logic L684），发码成功即倒计时，码从 verification_code 表读） | `page/mine/account_security/bind_email_page.dart` | 发送验证码后倒计时回显 | 未测 | - | 0 | 0 | 0 | 需真实发信；批次146 口径经查不成立：email 发码无开关（elib_email:send 无条件外发）且本地 smtp_option 为真实 QQ 邮箱——测试将从用户真实邮箱发信，维持阻塞（批次157 红线评估） |
| 阻塞 | 待环境恢复执行（adapterForTest 拦 getcode 注入失败，配方=WIV1 同款） | `page/mine/account_security/bind_email_page.dart` | 发送验证码失败弹出错误提示 | 未测 | - | 0 | 0 | 0 | 需真实发信；批次146:注入口径解锁 |
| 无待办 | - | `page/mine/account_security/bind_email_page.dart` | 邮箱格式校验行实时反馈 | 已通过 | 批次29 | 0 | 0 | 0 | test→「待输入」、user@example.com→「正确」实时切换（emailOk 驱动） |
| 无待办 | - | `page/mine/account_security/bind_email_page.dart` | 验证码长度校验行回显进度 | 已通过 | 批次29 | 0 | 0 | 0 | 过滤后 123456 → 长度检查实时 6/6（codeLength 驱动） |
| 无待办 | - | `page/mine/account_security/bind_email_page.dart` | 判定提交按钮启用与禁用态 | 已通过 | 批次29 | 0 | 0 | 0 | 禁用态实测：点击无请求（onPressed=null）；可用态代码证实 canSubmit 公式 updateEmail L95-100/updateCode L117-122（未点击防真实改绑） |
| 阻塞 | 待环境恢复执行（可弃用本地测试账号：改绑目标用本地新邮箱、码查表，改动仅及本地账号非生产） | `page/mine/account_security/bind_email_page.dart` | 提交成功后自动返回上一页 | 未测 | - | 0 | 0 | 0 | 会改动账号绑定关系；批次146:本地一次性账号口径解锁 |
| 阻塞 | 待环境恢复执行（同上本地账号口径；失败分支另可 adapterForTest 注入 bind 接口错误） | `page/mine/account_security/bind_email_page.dart` | 提交失败展示后端错误文案 | 未测 | - | 0 | 0 | 0 | 会改动账号绑定关系；批次146:本地口径解锁 |
