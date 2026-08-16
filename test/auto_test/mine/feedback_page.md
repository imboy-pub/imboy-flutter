# `page/mine/feedback/feedback_page.dart`

> 功能点 13 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/mine/feedback/feedback_page.dart` | 展示顶部反馈说明卡片 | 已通过 | 批次29 | 0 | 0 | 0 | get_ui 实测说明卡片（heart_circle 图标+「感谢你使用 imboy，如果遇到问题，欢迎提交反馈...」L121-175） |
| 无待办 | - | `page/mine/feedback/feedback_page.dart` | 点击导航栏加号新建反馈 | 已通过 | 批次29 | 0 | 0 | 0 | 实测点右上角 + 调起 BetterFeedback 编辑器（L115-119 actions CupertinoButton→_showFeedbackEditor） |
| 无待办 | - | `page/mine/feedback/feedback_page.dart` | 点击卡片内新建反馈按钮 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实与加号共用 _showFeedbackEditor（L57-104 单入口） |
| 无待办 | - | `page/mine/feedback/feedback_page.dart` | 调起截图标注反馈编辑面板 | 已通过 | 批次29 | 0 | 0 | 0 | 实测 BetterFeedback 编辑器（输入框+提交，第三方 package:feedback；含截图标注工具栏） |
| 无待办 | - | `page/mine/feedback/feedback_page.dart` | 内容为空时拦截提交并提示 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 L60-63 feedback.text.isEmpty→AppLoading.showError(feedbackContentRequired)（EasyLoading 不进语义树） |
| 无待办 | - | `page/mine/feedback/feedback_page.dart` | 截图解码失败时明确报错 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 L68-72 img.decodeImage 空判→showError(operationFailedAgainLater)（注释明确为修复静默逃逸） |
| 无待办 | - | `page/mine/feedback/feedback_page.dart` | 压缩截图并走预签名上传 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 L73-74 encodeJpg(quality 70)+uploadBytesViaPresignCompat(process:false)；提交链实测 add 请求到达服务端=上传成功前置 |
| 无待办 | - | `page/mine/feedback/feedback_page.dart` | 提交成功提示并刷新历史列表 | 已通过 | 批次90 | 2 | 2 | 0 | ⚠️双bug已修+真机验证：①刷新错位——删 _loadFeedbackList 残留 page=page+1（本页无分页 UI page 恒 1），提交后刷新实测走 page=1&size=1000（logcat 07:16:40.486）；②假成功——客户端提交省略空 rating/type 键（L84-100，编辑器无类型/评分 UI），服务端 feedback_handler 默认值合法化（空串→bugReport/neutral，原默认 <<>>/<<"0">> 撞 CHECK 约束 chk_feedback_type/rating）+ feedback_ds.erl:98-104 失败返回 {error,Reason} 不再吞错 + handler 检查返回值返回错误响应（L169-181）；eunit feedback_ds_tests 14/14 + feedback_handler_tests 8/8 全绿。⭐批次90 BUG#134 终局闭环：8/13+8/16 四次 500 空 body 根因=feedback_repo:add 成功契约是裸 ok（repo 单测锁定），ds case 只匹配 {ok,_} → case_clause 崩溃（生产 crash.log 实证）→ INSERT 已提交但客户端「操作失败」；修复 feedback_ds.erl 补 ok 分支+失败上抛（880d7ee0）+回归测试，alpha.31 蓝绿部署后真机复验：23:14:27 POST /api/v1/feedback/add 200 61（此前 500 0）→ 列表刷新出现新条目 → DB 落库 id=107381873581492224 uid50；alpha.31 crash.log 0 条 case_clause |
| 无待办 | - | `page/mine/feedback/feedback_page.dart` | 加载历史反馈列表 | 已通过 | 批次29 | 0 | 0 | 0 | 实测 page=1&size=1000 请求发出返回（服务端 count=0 真无数据，空态符合实际——上游提交 bug 所致，见 L15） |
| 无待办 | - | `page/mine/feedback/feedback_page.dart` | 展示加载空态与错误重试三态 | 已通过 | 批次29 | 0 | 0 | 0 | 空态实测（列表无数据展示空文案）；加载/错误重试代码证实 AsyncStateView(isLoading/onRetry) 同 denylist 已验证模式 |
| 无待办 | - | `page/mine/feedback/feedback_page.dart` | 按状态码渲染待回复已回复完结色 | 已通过 | 批次29 | 0 | 0 | 0 | 代码证实 _getFeedbackStatusColor（status 3=绿 1=橙 default=primary）；无数据未实测色值 |
| 无待办 | - | `page/mine/feedback/feedback_page.dart` | 点击条目进入反馈详情页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 真机验证通过：alpha.27 后 feedback 提交成功落库（body=autotest_feedback_loop79,status=1）；重进反馈页列表 loadData 正确拉取 /feedback/page 渲染条目（此前空=提交后未重进页触发加载）；点击条目成功进入「反馈建议明细」页，类型/时间/状态/附件/评级渲染正确 |
| 无待办 | - | `page/mine/feedback/feedback_page.dart` | 左滑删除反馈并二次确认 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 真机验证通过：列表条目左滑露出「删除」按钮，点击弹出二次确认弹窗「确认删除吗？删除后不可恢复」+取消；本次取消未真删保留测试数据 |
