# `page/workspace/project/home/project_detail_page.dart`

> 功能点 11 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 待首测 | - | `page/workspace/project/home/project_detail_page.dart` | 工作区项目列表点项目卡片进入详情（路由 /workspace/:wsId/projects/:projectId），页标题「项目详情」 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_detail_page.dart` | 详情加载中显示加载视图；加载失败显示错误视图，点重试重新拉取详情 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_detail_page.dart` | 基本信息卡渲染：项目名（文件夹图标）、描述（有则显示）、状态标签（进行中/已完成）、负责人（owner 昵称/账号）与我的角色徽章 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_detail_page.dart` | Owner/Member 点「标记完成」：项目状态变 done，成功 toast，按钮切换为「重新开启」图标 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_detail_page.dart` | done 项目点「重新开启」：状态回 active，成功 toast，详情与列表第 1 页同步刷新 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_detail_page.dart` | 状态切换防抖：流转中按钮禁用，重复点击只发一次请求 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_detail_page.dart` | Guest 或角色未就绪（工作区成员列表未加载完成）时状态切换整卡不渲染（保守只读，服务端 403 兜底） | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_detail_page.dart` | 任务区块渲染：四态筛选与任务列表；可写时区块标题栏「+」按钮进入新建任务表单 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_detail_page.dart` | 「项目协作」入口区显示成员/里程碑/项目频道/内容聚合四个入口行，点击分别 push 对应子页并可返回 | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_detail_page.dart` | 归档工作区下详情顶部显示归档横幅且状态切换禁用（写操作被服务端 980 拒绝兜底） | 未测 | - | 0 | 0 | 0 | |
| 待首测 | - | `page/workspace/project/home/project_detail_page.dart` | 下拉刷新：详情页下拉重新拉取项目详情数据 | 未测 | - | 0 | 0 | 0 | |
