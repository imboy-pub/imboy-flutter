# `page/workspace/workspace_create_page.dart`

> 功能点 10 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/workspace/workspace_create_page.dart` | 无任何工作区的空态页创建入口进入 /workspace/create，页头标题与说明文案正常渲染 | 已通过 | 批次W2R3 | 0 | 0 | 0 | F空态页「+ 创建工作区」进创建页，标题「创建工作区」+自动完成说明完整 |
| 无待办 | - | `page/workspace/workspace_create_page.dart` | 名称输入框可输入且上限 200 字符，展示标签与占位提示 | 已通过 | 批次W2R3 | 0 | 0 | 0 | 未输入时hint占位；输入后label浮起+计数；250字符截断于200/200 |
| 无待办 | - | `page/workspace/workspace_create_page.dart` | 模板说明卡片渲染三行（公告频道/全体群/创建者权限） | 已通过 | 批次W2R3 | 0 | 0 | 0 | 「将自动初始化」三行：Announcements频道/General群/你成为Owner |
| 无待办 | - | `page/workspace/workspace_create_page.dart` | 名称留空点创建按钮 toast 提示名称必填且不发请求 | 已通过 | 批次W2R3 | 0 | 0 | 0 | toast「工作区名称不能为空」；logcat零请求 |
| 无待办 | - | `page/workspace/workspace_create_page.dart` | 提交创建时按钮转圈禁用防重复提交 | 已通过 | 批次W2R3 | 0 | 0 | 0 | 挂起注入：按钮灰禁+转圈图标；双击仅1个POST（logcat） |
| 无待办 | - | `page/workspace/workspace_create_page.dart` | 创建成功 toast 提示成功并跳转 /bottom_navigation 挂载工作区壳进入新工作区 Overview | 已通过 | 批次W2R3 | 0 | 0 | 0 | toast「工作区创建成功」+顶栏新工作区名+概览Tab高亮 |
| 无待办 | - | `page/workspace/workspace_create_page.dart` | 创建成功后壳内当前工作区切换为新建工作区（模板含 Announcements 频道与 General 群） | 已通过 | 批次W2R3 | 0 | 0 | 0 | 概览1频道1群+频道Tab Announcements+群组Tab General；区名AT-ji-linshi-W2R3（中文名adb不可输改ASCII） |
| 阻塞 | 待环境恢复执行（批次145 解锁+批次148 wire 实测：同名同/异 request_id 再创建均返回 status=existing 且 workspace/channel/group id 一致；⚠紧邻重试（10ms）撞「在处理中」在途锁 code=1，实测 >1.5s 过窗，测试两次创建需留间隔） | `page/workspace/workspace_create_page.dart` | 服务端幂等命中时 toast 提示幂等命中文案并同样进入 Overview | 未测 | 批次W2R3 | 0 | 0 | 0 | UI无法控制request_id（每次提交新生成），幂等命中不可复现；request_id 级仍不可控，但语义键级幂等（owner+name）本地可造；fixture=AT-WS-IDEM-148（id 111613416917174272） |
| 阻塞 | 待环境恢复执行（批次145 解锁：上限=?MAX_WORKSPACES_PER_OWNER=100（workspace_ds L45），bob 现有 2 个，测试 setUpAll 用 API 循环建 98 个即触 409；W2R3 判「不经济」是手工口径，curl/API 循环为平凡操作） | `page/workspace/workspace_create_page.dart` | 服务端错误（409 数量上限/980 归档等）toast 原样透出服务端消息 | 未测 | 批次W2R3 | 0 | 0 | 0 | W2R3核实：上限=100区/Owner不经济；980不适用创建端点；400被maxLength=200前置拦截；仅连接失败路径（走通用catch非服务端错误） |
| 无待办 | - | `page/workspace/workspace_create_page.dart` | 提交失败后按钮恢复可点击可重试 | 已通过 | 批次W2R3 | 0 | 0 | 0 | 挂起注入超时+3次重试耗尽→按钮恢复蓝色可点；恢复网络后重试成功创建 |
