# `page/workspace/project/home/project_create_page.dart`

> 功能点 9 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/workspace/project/home/project_create_page.dart` | 工作区项目列表页创建入口进入创建表单（路由 /workspace/:workspaceId/projects/create），页标题「新建项目」 | 已通过 | 批次W2R1 | 0 | 0 | 0 | 实测标题为「新建项目」非「创建项目」 |
| 无待办 | - | `page/workspace/project/home/project_create_page.dart` | 表单渲染：名称输入框（上限 200 字，hint「项目名称」+计数）与描述输入框（上限 2000 字、多行，hint「项目描述（选填）」+计数） | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
| 无待办 | - | `page/workspace/project/home/project_create_page.dart` | 名称为空点提交：显示名称必填错误 toast，不发起请求 | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
| 无待办 | - | `page/workspace/project/home/project_create_page.dart` | 填写名称（描述可空）提交：显示创建成功 toast 并自动返回上一页 | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
| 无待办 | - | `page/workspace/project/home/project_create_page.dart` | 创建成功后返回项目列表第 1 页，新创建的项目出现在列表中 | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
| 无待办 | - | `page/workspace/project/home/project_create_page.dart` | 提交防抖：提交中按钮禁用并显示转圈，连续快速点击只创建一次 | 已通过 | 批次W2R1 | 0 | 0 | 0 | 3 连点仅 1 个 POST（logcat） |
| 无待办 | - | `page/workspace/project/home/project_create_page.dart` | 名称/描述提交前自动去除首尾空格（纯空格名称按空名校验拦截） | 已通过 | 批次W2R1 | 0 | 0 | 0 | |
| 无待办 | - | `page/workspace/project/home/project_create_page.dart` | Workspace Guest 提交创建项目：被服务端 403 拒绝，toast 原样透出服务端消息（不静默失败） | 已通过 | 批次W2R1 | 0 | 0 | 0 | toast「Guest 角色不能创建工作区资源」与服务端一致 |
| 无待办 | - | `page/workspace/project/home/project_create_page.dart` | 归档（archived）工作区下「新建项目」入口置灰禁用；直发 API 被服务端 980「工作区已归档，写操作被拒绝」兜底 | 已通过 | 批次W2R1 | 0 | 0 | 0 | 入口禁用即防提交，980 由 curl 验证 |
