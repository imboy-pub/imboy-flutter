# `page/group/group_detail/add_member_page.dart`

> 功能点 11 个 | bug 发现 3 / 解决 3 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/group/group_detail/add_member_page.dart` | 从本地库加载可选联系人列表 | 已通过 | 批次21 | 1 | 1 | 0 | |
| 无待办 | - | `page/group/group_detail/add_member_page.dart` | 首帧后加载并正常结束转圈 | 已通过 | 批次21 | 1 | 1 | 0 | |
| 无待办 | - | `page/group/group_detail/add_member_page.dart` | 联系人列表剔除功能入口占位 | 已通过 | 批次21 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/group_detail/add_member_page.dart` | 点联系人切换勾选状态 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/group_detail/add_member_page.dart` | 已是群成员的行禁选并标注 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/group_detail/add_member_page.dart` | 顶部展示已选人数提示条 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/group_detail/add_member_page.dart` | A-Z 索引栏拖动定位联系人 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/group_detail/add_member_page.dart` | 未选中时完成按钮置灰禁用 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/group_detail/add_member_page.dart` | 点左上角关闭退出选人页 | 待重验 | - | 0 | 0 | 0 | |
| 阻塞 | 需本地库零好友数据的测试账号或测试数据（构造需删好友，破坏性） | `page/group/group_detail/add_member_page.dart` | 无联系人时展示暂无数据空态 | 未测 | 批次29 | 0 | 0 | 0 | uid50 本地库 3 好友；选人页列表/禁选/完成钮已正常 |
| 阻塞 | 需授权写生产数据 | `page/group/group_detail/add_member_page.dart` | 提交添加选中成员入群 | 未测 | - | 0 | 0 | 0 | 会真实拉人入群并通知第三方 |
