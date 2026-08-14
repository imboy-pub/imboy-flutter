# `page/group/group_select/group_select_page.dart`

> 功能点 9 个 | bug 发现 2 / 解决 2 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/group/group_select/group_select_page.dart` | 加载可选群会话列表 | 已通过 | §二十四 | 1 | 1 | 0 | |
| 无待办 | - | `page/group/group_select/group_select_page.dart` | 无名群走 displayTitle 兜底渲染 | 已通过 | §二十四 | 1 | 1 | 0 | |
| 无待办 | - | ``page/group/group_select/group_select_page.dart`` | 点群条目跳转对应群聊天页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/group_select/group_select_page.dart`` | 向下游传不兜底的 resolvedTitle | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/group_select/group_select_page.dart`` | 加载中展示居中转圈指示器 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/group_select/group_select_page.dart`` | 展示群头像合成九宫格图 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/group_select/group_select_page.dart`` | 长列表滚动与分隔线渲染 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/group_select/group_select_page.dart`` | 点返回退回发起聊天页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 阻塞 | 需本地库零群会话的测试账号或测试数据（构造需退群，破坏性不可逆）+ 该页无活入口 | `page/group/group_select/group_select_page.dart` | 无群会话时展示暂无数据空态 | 未测 | 批次29 | 0 | 0 | 0 | items.isEmpty→NoDataView(noData) 代码证实 L59-60；全仓无 push 调用 /select 路由（仅路由定义），页面不可达；本机 3 群会话 |
