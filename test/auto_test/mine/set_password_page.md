# `page/mine/change_password/set_password_page.dart`

> 功能点 11 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/mine/change_password/set_password_page.dart` | 展示账号安全说明卡片 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测 shield 图标卡片：「设置登录密码」+「提升账号安全性」+「为了提升账号安全，同时防止因无法获取验证码导致无法登录，请设...」（L46-129） |
| 无待办 | - | `page/mine/change_password/set_password_page.dart` | 展示密码长度要求提示 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测「密码长度为4-32的任意字符」（L117；passwordValidator L50 4-32 位，注意与 change_password 页 8 位不同） |
| 无待办 | - | `page/mine/change_password/set_password_page.dart` | 输入新密码字段 | 已通过 | 批次29 | 0 | 0 | 0 | 实测输入 abcdefgh → EditText text="••••••••" 掩码显示（PasswordTextField L175-190） |
| 无待办 | - | `page/mine/change_password/set_password_page.dart` | 切换新密码明文密文显示 | 已通过 | 批次29 | 0 | 0 | 0 | 实测点眼睛按钮 → text 变明文 abcdefgh，再点恢复掩码（双向，toggleNewPwdObscure L73-75） |
| 无待办 | - | `page/mine/change_password/set_password_page.dart` | 输入重复确认密码字段 | 已通过 | 批次29 | 0 | 0 | 0 | 实测输入 abcdefgh → 掩码显示；⚠️键盘弹出时确认框被遮挡需先收起键盘再点击（无 bug，布局正常） |
| 无待办 | - | `page/mine/change_password/set_password_page.dart` | 切换确认密码明文密文显示 | 已通过 | 批次29 | 0 | 0 | 0 | 实测点眼睛 → 明文 abcdefgh，再点恢复掩码（双向，toggleRetypePwdObscure） |
| 无待办 | - | `page/mine/change_password/set_password_page.dart` | 点击返回退出设置密码页 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 GlassAppBar automaticallyImplyLeading 仅在 Navigator.canPop 时渲染返回按钮（common_bar.dart L111-112）；深链 go('/set_password') 独立路由栈 canPop=false 无返回按钮（实测点 (30,126) 无响应、BACK 直退桌面），正常 push 流程（注册引导）可 pop |
| 无待办 | - | `page/mine/change_password/set_password_page.dart` | 点击确认提交设置登录密码 | 已通过 | 批次120 | 1 | 1 | 0 | AT-AS2/AS3 实证提交链（md5+RSA-OAEP 密文+rsa_encrypt='1'）。⚠️修复 P0 契约 bug：UserApi.setPassword 原写死 rsa_encrypt='0'，服务端把 RSA 密文当明文直接 hash，UI 设密的密码任何登录形态都验证不过（账号锁死级）；curl md5 传输 code=0 回归 |
| 无待办 | - | `page/mine/change_password/set_password_page.dart` | 未绑手机邮箱时跳转引导页 | 已通过 | 批次120 | 0 | 0 | 0 | AT-AS2：email 空→设密成功 toast→ManageAccountPage「提升账户安全」渲染断言；载体 SmokeEmpty(51730) |
| 无待办 | - | `page/mine/change_password/set_password_page.dart` | 已绑定时直接进入主导航页 | 已通过 | 批次120 | 1 | 1 | 0 | AT-AS3：quitLogin 重登刷缓存→测试内 PG 清密→设密成功→BottomNavigationPage。⚠️修复后端 bug：login_resp 漏发 mobile 致登录缓存 mobile 恒空、needGuide 恒真、本分支原永不可达（imboy c5921d61 补字段+curl 回归） |
| 无待办 | - | `page/mine/change_password/set_password_page.dart` | 提交异常时兜底错误提示 | 已通过 | 批次120 | 0 | 0 | 0 | AT-AS1：已设密账号提交→后端「已设置过密码，请使用修改密码」原样透出（非通用兜底文案）；UserApi 错误消息本地化通道修复后断言 |
