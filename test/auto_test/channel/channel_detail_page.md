# `page/channel/channel_detail_page.dart`

> 功能点 12 个 | bug 发现 11 / 解决 9 / 待处理 2
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 阻塞 | 需后端发布 | `page/channel/channel_detail_page.dart` | 频道消息图片附件渲染（view_url 授权） | 代码已修待发布 | 批次65 | 1 | 0 | 1 | BUG#124b 代码侧已闭环（2026-08-08）：根因=批次36 旧客户端上传未传 scope 落 default private（非上传者 view_url 400）；读鉴权 channel 订阅者可访问已就位；工作区 can_upload channel 分支（订阅者判定）核实正确 + 新增 EUnit authorize_channel_uploader_subscribed_grants_test 共 34 用例全绿。真机复验待后端发布（含并发未提交改动，commit/push/发布需人工确认）；存量「干饭」两条 private 附件需生产回填 SQL（scope→channel+scope_ref，生产数据待人工拍板） |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 频道详情加载、头部渲染与未读清零 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 头部统计加载与发布后权威刷新 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 消息卡片点赞落库与计数回显 | 已通过 | 批次25 | 2 | 2 | 0 | |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 发布栏文本发布与键盘避让 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 发布栏语音录制发送与发送反馈 | 已通过 | 批次25 | 3 | 3 | 0 | |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 发布栏附件上传 scope 传参授权 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/channel/channel_detail_page.dart` | 头部订阅/退订按钮与确认弹窗防重入 | 已通过 | 批次39 | 1 | 0 | 1 | 真机退订成功(订阅者 2→1)+弹窗取消/确认正常；退订后按钮仍「已订阅」=BUG#125 服务端 is_subscribed 用 user_role 推断(editor role≠0 恒 true)；agent 已修(role==3 恒 true 其余查订阅)+4/4 测试反证，待发布真机复验 |
| 回归复测 | 2026-08-07 | `page/channel/channel_detail_page.dart` | 消息流首屏加载、下拉刷新与加载更多 | 已通过 | 批次39 | 0 | 0 | 0 | 真机首屏 3 条+下拉刷新正常；10 条<20 未触发加载更多，分页链代码确认 |
| 回归复测 | 2026-08-07 | `page/channel/channel_detail_page.dart` | 更多菜单管理项（编辑/写文章/管理员/订阅者） | 已通过 | 批次39 | 0 | 0 | 0 | 当前账号 editor 无管理项(渲染条件 isManaged 代码确认)；管理项需 admin/creator 账号另验 |
| 回归复测 | 2026-08-07 | `page/channel/channel_detail_page.dart` | 分享面板复制链接、二维码与转发聊天 | 已通过 | 批次39 | 0 | 0 | 0 | 真机：复制链接关闭面板；二维码页渲染(7天有效+保存按钮)；发送给好友→聊天页 |
| 回归复测 | 2026-08-07 | `page/channel/channel_detail_page.dart` | 菜单退订与创建者删除频道确认 | 已通过 | 批次39 | 0 | 0 | 0 | 菜单退订弹窗同头部已验证；删除频道 isCreator 专属+不可逆需专用测试频道，代码确认不执行 |
| 阻塞 | 付费功能开启后 | `page/channel/channel_detail_page.dart` | 付费频道 paywall 锁定与购买后刷新 | 未测 | - | 0 | 0 | 0 | 付费功能未开，无法构造付费频道 |
