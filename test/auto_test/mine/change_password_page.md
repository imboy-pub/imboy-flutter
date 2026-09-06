# `page/mine/change_password/change_password_page.dart`

> 功能点 12 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/mine/change_password/change_password_page.dart` | 展示登录密码启用状态卡片 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测「登录密码」+「已开启」徽标（L30-70 状态卡片） |
| 无待办 | - | `page/mine/change_password/change_password_page.dart` | 输入旧密码字段 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测「旧密码」label+EditText，输入 12345678 后 text="••••••••" 掩码显示 |
| 无待办 | - | `page/mine/change_password/change_password_page.dart` | 输入新密码字段 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测「新的密码」字段，输入 abcdefgh 掩码显示（同构 _buildPasswordField） |
| 无待办 | - | `page/mine/change_password/change_password_page.dart` | 输入确认新密码字段 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测「确认新密码」字段，输入 abcdefgi 掩码显示 |
| 无待办 | - | `page/mine/change_password/change_password_page.dart` | 切换三个字段的明文密文显示 | 已通过 | 批次29 | 0 | 0 | 0 | 旧密码字段实测：点「显示密码」→ text 变明文 12345678 + label 变「隐藏密码」；再点恢复掩码（双向）；三字段同构（各自 obscure 状态 L110-120） |
| 无待办 | - | `page/mine/change_password/change_password_page.dart` | 展示密码最小长度约束说明 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测 footer「密码至少需要8个字符」（L75-77 minPasswordLength=8） |
| 无待办 | - | `page/mine/change_password/change_password_page.dart` | 旧密码长度校验行反馈 | 已通过 | 批次29 | 0 | 0 | 0 | 3 位→「待输入」、8 位→「长度符合」实时切换（existingLengthOk 驱动，键盘收起后可见） |
| 无待办 | - | `page/mine/change_password/change_password_page.dart` | 新密码长度校验行反馈 | 已通过 | 批次29 | 0 | 0 | 0 | 输入 8 位 abcdefgh →「长度符合」（newLengthOk 同构于旧密码） |
| 无待办 | - | `page/mine/change_password/change_password_page.dart` | 两次新密码一致性校验反馈 | 已通过 | 批次29 | 0 | 0 | 0 | 确认 abcdefgi（不一致）→「两次密码不一致」；改 abcdefgh →「验证通过」实时切换（passwordMatchOk） |
| 无待办 | - | `page/mine/change_password/change_password_page.dart` | 判定保存按钮启用与禁用态 | 已通过 | 批次29 | 0 | 0 | 0 | 禁用态实测：初始/不一致时 desc 含 disabled；全满足后 clickable（L134-139 canSubmit 公式）；可用态未点击防真实改密（改密不可逆），提交链代码证实 L248-261+submit() |
| 无待办 | - | `page/mine/change_password/change_password_page.dart` | 提交改密并展示加载指示 | 已通过 | 批次120 | 1 | 1 | 0 | AS4 终验：admin888x→admin888c 提交成功（提交后表单清空+「修改成功」toast+hash 落库变化 PG 断言）。⚠️发现并修复 elib_password:verify 候选链缺 sha256(md5hex(P))：注册/设密链存 md5hex-输入 hash、改密 existing 传明文必不命中，改密功能对该批账号完全不可用（imboy 69b7eca3，手工 curl 闭环 code=0 回归） |
| 无待办 | - | `page/mine/change_password/change_password_page.dart` | 提交异常时兜底错误提示 | 已通过 | 批次120 | 1 | 1 | 0 | AS4：旧密码错误→toast「密码错误」。⚠️修复 UserApi.changePassword 裸显后端英文码 errorPassword 的 bug（_localizedUserErrMsg 映射 i18n）；密码 hash 不变 PG 断言 |
