# `page/group/group_detail/group_detail_page.dart`

> 功能点 12 个 | bug 发现 3 / 解决 3 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/group/group_detail/group_detail_page.dart` | 点「＋」进入添加成员页 | 已通过 | 批次22 | 1 | 1 | 0 | |
| 无待办 | - | `page/group/group_detail/group_detail_page.dart` | 点「－」进入移除成员页（管理员） | 已通过 | 批次22 | 0 | 0 | 0 | |
| 无待办 | - | `page/group/group_detail/group_detail_page.dart` | 群成员数按服务端权威值显示 | 已通过 | 批次22 | 1 | 1 | 0 | |
| 无待办 | - | `page/group/group_detail/group_detail_page.dart` | 点成员头像按身份分流跳转 | 已通过 | 批次22 | 1 | 1 | 0 | |
| 无待办 | - | `page/group/group_detail/group_detail_page.dart` | 群应用九宫格九个入口跳转 | 已通过 | 批次22 | 0 | 0 | 0 | |
| 无待办 | - | ``page/group/group_detail/group_detail_page.dart`` | 点群信息卡片进入改群名页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/group_detail/group_detail_page.dart`` | 编辑我的群昵称并落库 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/group_detail/group_detail_page.dart`` | 编辑群备注并落库 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/group_detail/group_detail_page.dart`` | 切换消息免打扰开关 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 阻塞 | 需 20 人以上测试群 | `page/group/group_detail/group_detail_page.dart` | 展示查看全部成员入口 | 未测 | - | 0 | 0 | 0 | 入口条件 memberCount>20，现有测试群仅 2 人 |
| 阻塞 | 需授权不可撤销写操作 | `page/group/group_detail/group_detail_page.dart` | 群主开启群级 E2EE 加密 | 未测 | - | 0 | 0 | 0 | 0→1 单向不可逆，开了无法回退 |
| 阻塞 | 需授权写生产数据 | `page/group/group_detail/group_detail_page.dart` | 危险操作区清空记录与退群解散 | 未测 | - | 0 | 0 | 0 | 清空/投诉/解散均写生产且不可逆 |
