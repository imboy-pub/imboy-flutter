# `page/passport/forgot_password_pin_code_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | 本地 9801（sms.switch=off 不外发）| `page/passport/forgot_password_pin_code_page.dart` | 展示验证码发送目标账号 | 已通过 | 批次124 | 0 | 0 | 0 | AT-FP1 query 深链直达（路由增强：extra 优先/query 兜底），断言 RichText「验证码已发送到手机+8619900001234」 |
| 无待办 | 本地 9801（sms.switch=off 不外发）| `page/passport/forgot_password_pin_code_page.dart` | 输入 6 位遮蔽验证码 | 已通过 | 批次124 | 0 | 0 | 0 | AT-FP2 enterText 6 位后 obscuringWidget 以 shield 图标遮蔽（码值从 verification_code 表直读，万能码 abc12345 为 8 位字母 number 键盘物理无法输入） |
| 无待办 | 本地 9801（sms.switch=off 不外发）| `page/passport/forgot_password_pin_code_page.dart` | 验证码不足 6 位触发错误态 | 已通过 | 批次124 | 0 | 0 | 0 | AT-FP3 输 3 位提交，「请把方格填满」红字出现且停留本页 |
| 无待办 | 本地 9801（sms.switch=off 不外发）| `page/passport/forgot_password_pin_code_page.dart` | 重新发送重置验证码 | 已通过 | 批次124 | 1 | 1 | 0 | AT-FP4 节流窗内重发弹本地化「操作频率过高」且 DB 断言码不刷新。发现并修复真 bug：pin 页为 CupertinoPageScaffold，重发失败走 notifier.snackBar 时 ScaffoldMessenger 栈中无 Material Scaffold 断言崩溃（用户看不到失败原因）——已加降级 toast 通道 |
| 无待办 | 本地 9801（sms.switch=off 不外发）| `page/passport/forgot_password_pin_code_page.dart` | 重发成功展示确认提示 | 已通过 | 批次124 | 0 | 0 | 0 | AT-FP5 窗外（>55s）重发提示「验证码已发送到+86...」+ DB 断言码值刷新（服务端防穷举治理一律重新生成） |
| 无待办 | 本地 9801（sms.switch=off 不外发）| `page/passport/forgot_password_pin_code_page.dart` | 输入新密码并切换明文 | 已通过 | 批次124 | 0 | 0 | 0 | AT-FP6 按字段定位 suffixIcon 眼睛：obscure→明文 eye_slash，再切回密文 |
| 无待办 | 本地 9801（sms.switch=off 不外发）| `page/passport/forgot_password_pin_code_page.dart` | 输入确认密码并切换明文 | 已通过 | 批次124 | 0 | 0 | 0 | AT-FP7 同 FP6 第二字段独立断言 |
| 无待办 | 本地 9801（sms.switch=off 不外发）| `page/passport/forgot_password_pin_code_page.dart` | 校验两次密码是否一致 | 已通过 | 批次124 | 0 | 0 | 0 | AT-FP8 不一致提交被客户端本地拦截（不发 HTTP），snackBar 反馈且停留本页 |
| 无待办 | 本地 9801（sms.switch=off 不外发）| `page/passport/forgot_password_pin_code_page.dart` | 重置成功提示并跳登录页 | 已通过 | 批次124 | 1 | 1 | 0 | AT-FP9 真码提交「密码修改成功。」→跳登录页→HTTP 新密码登录闭环（code=0）→tearDownAll 恢复原 hash（curl 复验 admin888c 可登录）。发现并修复真 bug：服务端 find_password 只有 email 分支，UI 手机链(type=mobile)走到提交才报「不支持的注册类型」——已加 mobile/sms 分支+find_password_by_mobile（imboy 仓，热更 9801 冒烟通过） |
| 无待办 | 本地 9801（sms.switch=off 不外发）| `page/passport/forgot_password_pin_code_page.dart` | 重置失败展示错误提示 | 已通过 | 批次124 | 0 | 0 | 0 | AT-FP10 假码 000000 提交，服务端「验证码无效」snackBar 透出且停留本页 |
| 无待办 | 本地 9801（sms.switch=off 不外发）| `page/passport/forgot_password_pin_code_page.dart` | 语言切换实时重建页面 | 已通过 | 批次124 | 0 | 0 | 0 | AT-FP11 LocaleSettings.setLocale zh↔en 文案实时切换（localeStream 监听） |
| 无待办 | 本地 9801（sms.switch=off 不外发）| `page/passport/forgot_password_pin_code_page.dart` | 底部返回登录入口跳转 | 已通过 | 批次124 | 0 | 0 | 0 | AT-FP12 点登录跳 sign_in（落地页按窗口宽度分流：宽屏 WebLoginPage/窄屏 LoginPage，测试窗口走 LoginPage 分支） |
