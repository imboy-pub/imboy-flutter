# `page/user_tag/contact_tag_detail/select_tag_friend_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 0 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/user_tag/contact_tag_detail/select_tag_friend_page.dart` | 加载并展示全部好友列表 | 已通过 | 批次14 | 0 | 0 | 0 | |
| 无待办 | - | `page/user_tag/contact_tag_detail/select_tag_friend_page.dart` | 勾选好友并显示已选数量 | 已通过 | 批次14 | 0 | 0 | 0 | |
| 无待办 | - | `page/user_tag/contact_tag_detail/select_tag_friend_page.dart` | 取消勾选后已选计数递减 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 真机验证通过：勾选好友顶部按钮变「添加 (1)」计数+1，取消后计数递减（toggle 同源机制） |
| 回归复测 | 2026-08-07 | `page/user_tag/contact_tag_detail/select_tag_friend_page.dart` | 已在标签内的好友进页默认勾选 | 待重验 | - | 0 | 0 | 0 | |
| 无待办 | - | `page/user_tag/contact_tag_detail/select_tag_friend_page.dart` | 按拼音首字母分组并渲染吸顶头 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 真机验证通过：好友列表按拼音首字母分组（H/L/P/U/X 分组头），右侧索引条 ↑H# 渲染 |
| 阻塞 | substring 空串崩溃修复中 | `page/user_tag/contact_tag_detail/select_tag_friend_page.dart` | 右侧索引条拖动定位字母分组 | 未测 | - | 0 | 0 | 0 | 好友列表渲染被 substring 空串崩溃中断（本页61行），9处同类修复中 |
| 阻塞 | substring 修复上 APK + 需标签/好友数据 | `page/user_tag/contact_tag_detail/select_tag_friend_page.dart` | 下拉刷新重新拉取好友列表 | 未测 | 批次33 | 0 | 0 | 0 | 页面临时不可达：当前账号标签已删空；好友列表 substring 崩溃（本页61行）未上 APK |
| 阻塞 | substring 修复上 APK + 需标签/好友数据 | `page/user_tag/contact_tag_detail/select_tag_friend_page.dart` | 未选任何人时添加按钮不高亮 | 未测 | 批次33 | 0 | 0 | 0 | 同上入口阻塞 |
| 无待办 | - | `page/user_tag/contact_tag_detail/select_tag_friend_page.dart` | 点添加提交并更新标签成员数 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 真机验证通过：勾选好友提交 POST /user_tag_relation/set 成功，标签成员 0→1 更新 |
| 无待办 | - | `page/user_tag/contact_tag_detail/select_tag_friend_page.dart` | 提交成功与失败分别弹提示 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 真机验证通过：选人页勾选好友(HHH)→顶部「添加(N)」→提交 POST /user_tag_relation/set 成功，标签成员 0→1 更新并返回详情页显示成员；失败分支因 set 幂等（重复添加不报错）难构造，未覆盖 |
| 无待办 | - | `page/user_tag/contact_tag_detail/select_tag_friend_page.dart` | 点关闭按钮退出且不保存选择 | 已通过 | 批次32 | 0 | 0 | 0 | 返回详情页成员数无变化 |
| 阻塞 | substring 修复上 APK + 需标签/好友数据 | `page/user_tag/contact_tag_detail/select_tag_friend_page.dart` | 多选行暴露无障碍选中语义 | 未测 | 批次33 | 0 | 0 | 0 | 同上入口阻塞 |
