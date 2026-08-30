# `page/workspace/project/home/project_create_page.dart`

> 功能点 9 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 待首测 | - | `page/workspace/project/home/project_create_page.dart` | 工作区项目列表页创建入口进入创建表单（路由 /workspace/:workspaceId/projects/create），页标题「创建项目」 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_create_page.dart` | 表单渲染：名称输入框（上限 200 字，label+hint）与描述输入框（上限 2000 字、2~5 行多行） | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_create_page.dart` | 名称为空点提交：显示名称必填错误 toast，不发起请求 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_create_page.dart` | 填写名称（描述可空）提交：显示创建成功 toast 并自动返回上一页 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_create_page.dart` | 创建成功后返回项目列表第 1 页，新创建的项目出现在列表中 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_create_page.dart` | 提交防抖：提交中按钮禁用并显示转圈，连续快速点击只创建一次 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_create_page.dart` | 名称/描述提交前自动去除首尾空格（纯空格名称按空名校验拦截） | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_create_page.dart` | Workspace Guest 提交创建项目：被服务端 403 拒绝，toast 原样透出服务端消息（不静默失败） | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_create_page.dart` | 归档（archived）工作区下提交创建：被服务端 980 拒绝，错误提示透出 | 未测 | - | 0 | 0 | 0 | |
