# `page/personal_info/update/update_page.dart`

> 功能点 11 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/personal_info/update/update_page.dart` | input模式单行输入框自动聚焦 | 已通过 | 第八批 | 0 | 0 | 0 | |
| 无待办 | - | `page/personal_info/update/update_page.dart` | 内容为空时完成按钮置灰禁用 | 已通过 | 第八批 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/personal_info/update/update_page.dart` | 内容变更后完成按钮高亮可点 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/personal_info/update/update_page.dart` | 点完成提交回调成功后退栈 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/personal_info/update/update_page.dart` | 键盘回车直接提交当前内容 | 已通过 | 批次30 | 0 | 0 | 0 | 实测 input 模式深链（?field=input&apiField=sign&maxLength=56）输入 117Test → 键盘回车（keyevent 66）：logcat 08:02:04.117 PUT /api/v1/user/update → 退栈回个人信息页（inputField onFieldSubmitted L181-190 直接 callback 无空值还原分支）；测试后签名已恢复 117 |
| 无待办 | - | `page/personal_info/update/update_page.dart` | text模式多行输入与字数计数器 | 已通过 | 批次30 | 0 | 0 | 0 | 实测 text 模式深链（?field=text&maxLength=10）：maxLines 6/minLines 4 多行输入框（L245-248）+ 内建计数器「还可输入 N 个字符」实时更新（L248 maxLength 自带） |
| 无待办 | - | `page/personal_info/update/update_page.dart` | text模式达最大长度时截断 | 已通过 | 批次30 | 0 | 0 | 0 | 实测 maxLength=10 输入 14 字符被硬截断为「1abcdefghi」+ 计数器「还可输入 0 个字符」（L248 maxLength 内建 LengthLimiting 字素簇截断+计数） |
| 无待办 | - | `page/personal_info/update/update_page.dart` | gender模式三项单选切换 | 已通过 | 批次30 | 0 | 0 | 0 | 实测 gender 模式深链（?field=gender&value=1）：点女→选中切换、点保密→切换、点男→回初始选中；三项 RadioListTile 单选互斥正常（L333-409，值 '1'/'2'/'3'）；未提交 BACK 退出避免改写账号性别 |
| 无待办 | - | `page/personal_info/update/update_page.dart` | gender选中项显示对勾并放大字号 | 已通过 | 批次30 | 0 | 0 | 0 | 实测选中项 get_ui desc 含「√」（secondary 对勾渲染 L348）+ checked 属性；选中项字号放大为 extraLarge vs 未选中 medium（L337-345 代码证实） |
| 无待办 | - | `page/personal_info/update/update_page.dart` | 提交失败时停留当前页不退栈 | 已通过 | 批次30 | 0 | 0 | 0 | 实测断网（Active default network: none）input 模式点完成：logcat 0 次 user/update（http_client 网络检查拦截 fail-open 不发请求）→ 停留 update 页不退栈（get_ui 标题「个人签名」+完成按钮+输入框仍在）+ showError toast（EasyLoading 不进语义树，代码证实 L75-101 成功才 pop）；恢复网络同位置 PUT 08:05:22 成功退栈，点击链路有效；测试后签名已恢复 117 |
| 回归复测 | 2026-08-07 | `page/personal_info/update/update_page.dart` | 进页把原值回填到输入控制器 | 待重验 | - | 0 | 0 | 0 | |
