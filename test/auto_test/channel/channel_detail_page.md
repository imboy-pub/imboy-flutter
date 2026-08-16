# `page/channel/channel_detail_page.dart`

> 功能点 13 个 | bug 发现 11 / 解决 11 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/channel/channel_detail_page.dart` | 频道消息图片附件渲染（view_url 授权） | 已通过 | 批次90 | 1 | 1 | 0 | ⭐BUG#124b 真机复验闭环（08-16 alpha.32）：qa-batch84-admin 发图全链路证据——nginx 23:36:36 `presign?scope=channel&scope_ref=106933346608875520` 200 402B（客户端上传带 channel scope）→ 23:36:37 confirm 落库（attachment id=107384663800285184 scope=channel scope_ref=频道ID creator=50）→ 23:36:38 `view_url?object_key=u50/channel/20260816/...` 200 352B（渲染授权成功）→ 消息流 ImageView 渲染 + 点击全屏预览正常；头像 view_url 亦 200。代码侧：读鉴权 channel 分支 has_channel_attachment_access（创建者 role 短路/订阅者放行）+ can_upload channel 分支 + EUnit 34 用例全绿（d891c6fd，随 alpha.32 上线）。遗留：存量「干饭」两条 private 附件生产回填 SQL（scope→channel+scope_ref）仍待人工拍板（历史数据修复，不影响本功能点） |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 频道详情加载、头部渲染与未读清零 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 头部统计加载与发布后权威刷新 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 消息卡片点赞落库与计数回显 | 已通过 | 批次25 | 2 | 2 | 0 | |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 发布栏文本发布与键盘避让 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 发布栏语音录制发送与发送反馈 | 已通过 | 批次25 | 3 | 3 | 0 | |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 发布栏附件上传 scope 传参授权 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 头部订阅/退订按钮与确认弹窗防重入 | 已通过 | 批次81 | 1 | 1 | 0 | |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 消息流首屏加载、下拉刷新与加载更多 | 已通过 | 批次39 | 0 | 0 | 0 | 真机首屏 3 条+下拉刷新正常；10 条<20 未触发加载更多，分页链代码确认 |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 更多菜单管理项（编辑/写文章/管理员/订阅者） | 已通过 | 批次39 | 0 | 0 | 0 | 当前账号 editor 无管理项(渲染条件 isManaged 代码确认)；管理项需 admin/creator 账号另验 |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 分享面板复制链接、二维码与转发聊天 | 已通过 | 批次39 | 0 | 0 | 0 | 真机：复制链接关闭面板；二维码页渲染(7天有效+保存按钮)；发送给好友→聊天页 |
| 无待办 | - | `page/channel/channel_detail_page.dart` | 菜单退订与创建者删除频道确认 | 已通过 | 批次39 | 0 | 0 | 0 | 菜单退订弹窗同头部已验证；删除频道 isCreator 专属+不可逆需专用测试频道，代码确认不执行 |
| 阻塞 | 付费功能开启后 | `page/channel/channel_detail_page.dart` | 付费频道 paywall 锁定与购买后刷新 | 未测 | - | 0 | 0 | 0 | 付费功能未开，无法构造付费频道 |
