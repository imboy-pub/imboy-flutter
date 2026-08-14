# `page/group/group_detail/remove_member_page.dart`

> 功能点 10 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/group/group_detail/remove_member_page.dart` | 从群详情进入本页可正常打开 | 已通过 | 批次21 | 0 | 0 | 0 | |
| 无待办 | - | ``page/group/group_detail/remove_member_page.dart`` | 加载群成员列表并排除自己 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/group_detail/remove_member_page.dart`` | 点成员行切换勾选状态 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/group_detail/remove_member_page.dart`` | 完成按钮随选中数高亮变化 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/group_detail/remove_member_page.dart`` | 未选中时点完成不触发请求 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/group_detail/remove_member_page.dart`` | 点信息图标查看成员资料 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/group_detail/remove_member_page.dart`` | 点取消返回群详情页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 阻塞 | 需授权写生产数据（建仅含自己的群）或本地库构造 | `page/group/group_detail/remove_member_page.dart` | 成员为空时展示暂无数据空态 | 未测 | 批次29 | 0 | 0 | 0 | 空态需「排除自己+群主后为空」；本机唯一单人群「未命名」uid50 非管理员无「-」入口（isAdmin 才渲染 group_detail_page.dart L116），IMBoy 群可进但含 1 名可移除成员非空；代码证实 remove_member_page.dart L216-217 + provider L53-64 过滤 |
| 无待办 | - | `page/group/group_detail/remove_member_page.dart` | 移除失败时弹出错误提示 | 已通过 | 批次29 | 0 | 0 | 0 | 飞行模式构造接口失败：勾选 IMBoy→完成(1)→断网→点完成两次→页面不 pop（成功路径会 pop 回群详情）→res=false 走 L207 showError 失败分支；恢复网络点取消退出，未踢任何人 |
| 阻塞 | 需授权写生产数据 | `page/group/group_detail/remove_member_page.dart` | 提交移除成员并回传结果 | 未测 | - | 0 | 0 | 0 | 会真实踢人并通知第三方 |
