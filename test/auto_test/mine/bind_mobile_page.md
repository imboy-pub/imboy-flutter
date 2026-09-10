# `page/mine/account_security/bind_mobile_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 展示当前手机号与绑定徽标 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui「当前手机号 未绑定」+「未绑定」徽标（uid50 未绑定；英文下 Current mobile number/Not bound） |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 已绑定时标题切换为更改手机 | 已通过 | 批次29 | 0 | 0 | 0 | 未绑定分支标题「绑定手机」（hasBound=false→bindMobile）；已绑定分支：批次158 实测旁证——51730（已绑 +8619900001234）点行走 hasBoundMobile 分支弹解绑 action sheet（account_security_page L105）不进绑定页，行为与设计一致 |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 选择国际区号并输入手机号 | 已通过 | 批次29 | 0 | 0 | 0 | 点 +86 弹 BOTTOM_SHEET 国家列表（含搜索框），搜 China 选中关闭；输入 13800138000 自动格式化「11 380 013 8000」 |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 手机号格式校验行实时反馈 | 已通过 | 批次29 | 0 | 0 | 0 | 短号 123→「待输入」，11 位→「正确」实时切换（mobileOk=长度>8） |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 限制验证码为六位纯数字 | 已通过 | 批次29 | 0 | 0 | 0 | 输入 abc12345678 后仅剩 123456（digitsOnly+6位截断） |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 判定获取验证码按钮可用态 | 已通过 | 批次29 | 0 | 0 | 0 | 禁用态实测：手机号无效时点击无网络请求（onPressed=null 拦截）；可用态代码证实 L93-98（未点击防真实发短信） |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 发送验证码后倒计时回显 | 已通过 | 批次157 | 0 | 0 | 0 | 真机：notifier.updateMobile 构造手机号（PhoneInputWidget onChanged 回调控制器直写不触发）→tap 获取验证码 → 按钮倒计时回显 + verification_code 落库（id 带 +86 前缀；sms.switch=off 不外发）；测试=misc/acceptance_batch157_test.dart AT-BM1 |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 发送验证码失败弹出错误提示 | 已通过 | 批次158 | 0 | 0 | 0 | macOS：HttpClient.client.dio 直换单例 adapter 拦 /passport/getcode 注入业务失败（静态 adapterForTest 仅构造时生效，对 serviceContainer 单例无效=新注入口径）→失败 toast 透出注入串+无倒计时+DB 零落库；载体=smoke_bob（已绑账号点行弹解绑 sheet 按设计不可达绑定页，51730 实证）；测试=passport/forgot_password_entry_acceptance_test.dart AT-BM2 |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 验证码长度校验行回显进度 | 已通过 | 批次29 | 0 | 0 | 0 | 过滤后 123456 → 长度检查实时 6/6（codeLength 驱动） |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 判定提交按钮启用与禁用态 | 已通过 | 批次29 | 0 | 0 | 0 | 禁用态实测：点击无请求（onPressed=null）；可用态代码证实 canSubmit 公式 L100-105/L122-127（未点击防真实改绑） |
| 阻塞 | 解阻塞条件（批次167 收敛）：signup 建一次性账号被 402 用户配额拦（rpc 实证 license max_users=100 且 is_valid=false，库 68856 用户）；需本地重签 license（放大/取消 max_users，属授权机制需拍板）或提供已知密码的可弃用账号；测试文件已就绪（integration_test/mine/bind_mobile_auto_return_acceptance_batch167_test.dart，analyze 零问题，全链=API 建号→app 改绑→自动返回断言→DB 断言，signup 通即绿） | `page/mine/account_security/bind_mobile_page.dart` | 提交成功后自动返回上一页 | 未测 | - | 0 | 0 | 0 | 会改动账号绑定关系；批次146:本地一次性账号口径解锁；批次167:配额墙定性+测试就绪 |
| 无待办 | - | `page/mine/account_security/bind_mobile_page.dart` | 表单标签本地化随语言切换 | 已通过 | 批次72 | 1 | 1 | 0 | 真机复验通过（APK 已含 eeaacbd4）：切 English 后全页无中文残留——Mobile/Verification code/Get verification code/Format check/Pending input/Bind now 全英文化 |
