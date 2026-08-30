# `page/workspace/project/w2/project_members_page.dart`

> 功能点 13 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 待首测 | - | `page/workspace/project/w2/project_members_page.dart` | 项目详情「项目协作」区点「成员」入口进入（路由 …/members），页标题「项目成员」 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_members_page.dart` | 数据三态：首屏加载视图 / 加载失败错误视图+重试 / 无成员空态视图 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_members_page.dart` | 成员行渲染：头像（无头像显示人形图标）、显示名、@账号，有写权限的行尾显示删除/转移图标按钮 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_members_page.dart` | 非项目成员直访：403 显示无权限专属视图（锁图标 + 文案 + 重试），不缓存豁免 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_members_page.dart` | Project Owner 点「邀请成员」：对话框输入数字 UID 确认后邀请成功 toast + 列表刷新；UID 为空/非数字给校验提示不发请求 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_members_page.dart` | 重复邀请已是成员的 UID：显示「已是成员」幂等 toast，不报错不重复入库 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_members_page.dart` | 移除成员：成员行删除图标 → 底部确认弹层 → 确认后移除成功 toast + 列表刷新 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_members_page.dart` | 重复移除已不在项目的成员：显示「已移除」幂等 toast，不报错 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_members_page.dart` | 转移 Owner：Project Owner 对其他成员点转移图标 → 确认弹层 → 成功 toast + 列表刷新，转移后原 Owner 失去邀请/转移入口 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_members_page.dart` | 写入口权限矩阵：邀请/转移仅 Project Owner 可见；移除 Project Owner 或 Workspace Owner 可见；自己所在行不显示删除/转移按钮 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_members_page.dart` | Workspace Guest 进入：显示只读说明行，邀请/移除/转移入口全部隐藏（服务端 403 兜底） | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_members_page.dart` | 归档工作区下进入：写入口全部隐藏禁用（写操作被服务端 980 拒绝兜底） | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/w2/project_members_page.dart` | 分页加载更多：成员超过一页时显示「加载更多」按钮追加下一页，加载中底部显示转圈 | 未测 | - | 0 | 0 | 0 | |
