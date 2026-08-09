# `page/mine/user_collect/user_collect_detail_page.dart`

> 功能点 12 个 | bug 发现 4 / 解决 4 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_detail_page.dart` | 展示收藏来源与收藏时间 | 已通过 | 批次59 | 0 | 0 | 0 | 真机「来自 117 刚刚」（来源+相对时间，停留后自动刷新为 1分钟前）；代码时间实时刷新 |
| 无待办 | - | `page/mine/user_collect/user_collect_detail_page.dart` | 备注卡片展示最新备注内容 | 已通过 | 第八批 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_detail_page.dart` | 按收藏类型渲染内容主体 | 已通过 | 批次59 | 0 | 0 | 0 | 真机文本类(kind=1)渲染内容主体「qa-collect-59-test」；造数据=聊天长按消息→收藏（logcat 实锤 user_collect/add） |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_detail_page.dart` | 点击更多打开底部操作面板 | 已通过 | 批次59 | 0 | 0 | 0 | 真机「操作选项」面板 5 项（复制/转发给朋友/编辑标签/设置备注/删除）+副标题+取消 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_detail_page.dart` | 复制文本类收藏到剪贴板 | 已通过 | 批次59 | 0 | 0 | 0 | 真机点复制后面板关闭；代码 L93-107 仅 kind==1 显示+Clipboard.setData+showToast(copied)；剪贴板 Android10+ 无法 dump 验证 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_detail_page.dart` | 转发收藏给好友并推断消息类型 | 已通过 | 批次59 | 0 | 0 | 0 | 代码确认 L109-180 类型推断链：顶层 msg_type→payload→kind 映射(1文本/2图片/3语音/4视频/5文件/6位置/7名片)+Xid 新 ID+SendToPage |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_detail_page.dart` | 转发构造失败时兜底错误提示 | 已通过 | 批次59 | 0 | 0 | 0 | 代码确认 L185-188 catch→AppLoading.showError(operationFailedAgainLater)；转发页未真机进入（需选好友写数据） |
| 无待办 | - | `page/mine/user_collect/user_collect_detail_page.dart` | 编辑标签并回写到收藏列表 | 已通过 | 批次28 | 2 | 2 | 0 | 批次28 真机复验通过（先收藏一条消息造数据）：编辑标签页正常加载，不再报「加载标签数据失败」；logcat 显示 `user_tag/page?scene=collect` 正常返回，零 UnmountedRefException。原修复记录： 批次27 真机复验受阻并挖出第二个 bug：编辑标签页报「加载标签数据失败」，根因是 updateTagStatistics 缺 ref.mounted 守卫，`user_tag/page` 已 200 数据齐全却抛两次 UnmountedRefException（第二次从 catch 逃逸）。已修 + 补反证单测，待装机复验 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_detail_page.dart` | 设置备注并回写到收藏列表 | 已通过 | 批次59 | 0 | 0 | 0 | 真机「设置备注」页（输入框+还可输入 100 个字符+完成）；代码 L240-283 remark→updateItem 回写（批次8 备注卡片 bug 已修） |
| 无待办 | — | `page/mine/user_collect/user_collect_detail_page.dart` | 删除收藏成功后给出结果反馈 | 已通过 | 批次27 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_detail_page.dart` | 点击取消关闭底部操作面板 | 已通过 | 批次59 | 0 | 0 | 0 | 真机点「取消」面板关闭回详情页 |
| 回归复测 | 2026-08-07 | `page/mine/user_collect/user_collect_detail_page.dart` | 删除项使用 iosRed 破坏色 | 已通过 | 批次59 | 0 | 0 | 0 | 代码确认 L322 AppColors.getIosRed（操作面板删除项）；删除功能批次27 已验证未重验 |
