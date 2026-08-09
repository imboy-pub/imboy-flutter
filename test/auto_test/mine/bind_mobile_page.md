# `page/mine/account_security/bind_mobile_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 展示当前手机号与绑定徽标 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui「当前手机号 未绑定」+「未绑定」徽标（uid50 未绑定；英文下 Current mobile number/Not bound） |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 已绑定时标题切换为更改手机 | 已通过 | 批次29 | 0 | 0 | 0 | 未绑定分支标题「绑定手机」（hasBound=false→bindMobile）；已绑定分支代码证实 L51 三元（uid50 未绑定无法实测） |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 选择国际区号并输入手机号 | 已通过 | 批次29 | 0 | 0 | 0 | 点 +86 弹 BOTTOM_SHEET 国家列表（含搜索框），搜 China 选中关闭；输入 13800138000 自动格式化「11 380 013 8000」 |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 手机号格式校验行实时反馈 | 已通过 | 批次29 | 0 | 0 | 0 | 短号 123→「待输入」，11 位→「正确」实时切换（mobileOk=长度>8） |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 限制验证码为六位纯数字 | 已通过 | 批次29 | 0 | 0 | 0 | 输入 abc12345678 后仅剩 123456（digitsOnly+6位截断） |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 判定获取验证码按钮可用态 | 已通过 | 批次29 | 0 | 0 | 0 | 禁用态实测：手机号无效时点击无网络请求（onPressed=null 拦截）；可用态代码证实 L93-98（未点击防真实发短信） |
| 阻塞 | 待可用测试手机号与短信通道 | `page/mine/account_security/bind_mobile_page.dart` | 发送验证码后倒计时回显 | 未测 | - | 0 | 0 | 0 | 需真实发短信 |
| 阻塞 | 待可用测试手机号与短信通道 | `page/mine/account_security/bind_mobile_page.dart` | 发送验证码失败弹出错误提示 | 未测 | - | 0 | 0 | 0 | 需真实发短信 |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 验证码长度校验行回显进度 | 已通过 | 批次29 | 0 | 0 | 0 | 过滤后 123456 → 长度检查实时 6/6（codeLength 驱动） |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 判定提交按钮启用与禁用态 | 已通过 | 批次29 | 0 | 0 | 0 | 禁用态实测：点击无请求（onPressed=null）；可用态代码证实 canSubmit 公式 L100-105/L122-127（未点击防真实改绑） |
| 阻塞 | 待专用可改绑测试账号 | `page/mine/account_security/bind_mobile_page.dart` | 提交成功后自动返回上一页 | 未测 | - | 0 | 0 | 0 | 会改动账号绑定关系 |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 表单标签本地化随语言切换 | 已通过 | 批次72 | 1 | 1 | 0 | 真机复验通过（APK 已含 eeaacbd4）：切 English 后全页无中文残留——Mobile/Verification code/Get verification code/Format check/Pending input/Bind now 全英文化 |
