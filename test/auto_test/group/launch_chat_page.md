# `page/group/launch_chat/launch_chat_page.dart`

> 功能点 12 个 | bug 发现 1 / 解决 1 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/group/launch_chat/launch_chat_page.dart` | 加载好友列表本地空则请服务端 | 已通过 | 批次20 | 1 | 1 | 0 | |
| 无待办 | - | `page/group/launch_chat/launch_chat_page.dart` | A-Z 索引栏动态生成并定位 | 已通过 | 批次20 | 0 | 0 | 0 | |
| 无待办 | - | ``page/group/launch_chat/launch_chat_page.dart`` | 点联系人切换勾选并给出反馈 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/launch_chat/launch_chat_page.dart`` | 顶部横滑展示已选成员头像 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/launch_chat/launch_chat_page.dart`` | 点预览头像移除该已选成员 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/launch_chat/launch_chat_page.dart`` | 未选人时完成按钮真正禁用 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/launch_chat/launch_chat_page.dart`` | 快捷入口跳转选择群聊页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/launch_chat/launch_chat_page.dart`` | 快捷入口跳转面对面建群页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 无待办 | - | ``page/group/launch_chat/launch_chat_page.dart`` | 点取消退出选择联系人页 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：IMBoy 有群(P0#2 重建验证,2成员)可访问群功能；本页功能批次详验真机/代码证据充分，稳定功能无回归 |
| 阻塞 | 需本地库零好友数据的测试账号或测试数据（构造需删好友，破坏性影响第三方） | `page/group/launch_chat/launch_chat_page.dart` | 无好友时展示暂无数据空态 | 未测 | 批次29 | 0 | 0 | 0 | items.isEmpty→NoDataView(noData) 代码证实 L255-256；uid50 本地 3 好友，删好友不可逆 |
| 阻塞 | 需授权写生产数据 | `page/group/launch_chat/launch_chat_page.dart` | 提交建群并防重复点击 | 未测 | - | 0 | 0 | 0 | 真实建群并拉人 |
| 阻塞 | 需授权写生产数据 | `page/group/launch_chat/launch_chat_page.dart` | 建群成功弹出双入口引导层 | 未测 | - | 0 | 0 | 0 | 依赖建群成功后才出现 |
