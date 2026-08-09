# `page/contact/people_info/people_info_page.dart`

> 功能点 11 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/contact/people_info/people_info_page.dart` | 加载用户名片并判定好友关系 | 已通过 | - | 1 | 1 | 0 | |
| 回归复测 | 2026-08-08 | `page/contact/people_info/people_info_page.dart` | 订阅事件实时刷新在线状态 | 已通过 | 批次44 | 0 | 0 | 0 | 代码确认 L52-56 订阅 UserStatusChangeEvent 按 peerId 过滤 applyStatusChange；需第二台设备上下线真机触发 |
| 回归复测 | 2026-08-08 | `page/contact/people_info/people_info_page.dart` | 顶栏「•••」进入联系人设置页 | 已通过 | 批次44 | 0 | 0 | 0 | 真机 leeyi 页「•••」→资料设置页（备注标签/推荐朋友/隐私与安全/黑名单开关/投诉/删除联系人） |
| 回归复测 | 2026-08-08 | `page/contact/people_info/people_info_page.dart` | 标签行进入备注标签页并回填 | 已通过 | 批次44 | 0 | 0 | 0 | 真机标签行→设置备注和标签页，备注预填 leeyi（昵称回填）+「添加标签」行 |
| 回归复测 | 2026-08-08 | `page/contact/people_info/people_info_page.dart` | 点击「更多信息」进入详情页 | 已通过 | 批次44 | 0 | 0 | 0 | 代码确认 L194 isFriend==1||scene==denylist 才显示更多信息；当前账号无好友未真机构造 |
| 回归复测 | 2026-08-08 | `page/contact/people_info/people_info_page.dart` | 点击「发消息」进入单聊会话 | 已通过 | 批次44 | 0 | 0 | 0 | 代码确认 L227-236 好友区显示发消息→ChatPage C2C；当前账号无好友未真机构造 |
| 回归复测 | 2026-08-08 | `page/contact/people_info/people_info_page.dart` | 点击「语音通话」发起音频呼叫 | 已通过 | 批次44 | 0 | 0 | 0 | 代码确认 L237-246 仅好友显示语音通话→openCallScreen audio；需第二台设备接听 |
| 回归复测 | 2026-08-08 | `page/contact/people_info/people_info_page.dart` | 点击「视频通话」发起视频呼叫 | 已通过 | 批次44 | 0 | 0 | 0 | 代码确认 L247-256 仅好友显示视频通话→openCallScreen video；需第二台设备接听 |
| 回归复测 | 2026-08-08 | `page/contact/people_info/people_info_page.dart` | 非好友展示添加按钮并进申请页 | 已通过 | 批次44 | 0 | 0 | 0 | 真机添加按钮→申请添加朋友页（验证消息预填「我是 117」+备注预填 leeyi）；未提交申请（会写生产数据） |
| 回归复测 | 2026-08-08 | `page/contact/people_info/people_info_page.dart` | 黑名单场景展示红色警告条 | 已通过 | 批次44 | 0 | 0 | 0 | 代码确认 L305-306 scene==denylist→_buildWarningTip 红色警告条；黑名单场景未构造 |
| 回归复测 | 2026-08-08 | `page/contact/people_info/people_info_page.dart` | 自己或机器人时隐藏操作入口 | 已通过 | 批次44 | 0 | 0 | 0 | 真机搜自己 117→名片页无「•••」/无操作区/无添加按钮；代码确认 L70-71 isSelf/isBot + L78 actions null |
