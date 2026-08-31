# `page/conversation/conversation_page.dart`

> 功能点 12 个 | bug 发现 4 / 解决 4 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | — | `page/conversation/conversation_page.dart` | 加载并展示会话列表 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4 真机：甲/乙两账号列表加载正常（本地无个人 DM 显「无会话消息」空态无崩溃）；批次25 非空列表证据沿用。收敛改面核验：workspace 壳会话目的地新顶栏（左上切换 chip + 右上搜索/＋/头像 trailingActions）真机在位正常；chat 壳不传参形态不变 |
| 无待办 | - | ``page/conversation/conversation_page.dart`` | 下拉刷新拉取服务端权威列表 | 已通过 | 批次80 | 0 | 0 | 0 | 批次80 回归确认：批次详验真机/代码证据充分，稳定功能无回归；W2R4 未复测（Cupertino 下拉无法注入为本机怪癖），刷新控件代码未变 |
| 无待办 | - | ``page/conversation/conversation_page.dart`` | 顶部搜索框本地过滤会话 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4 真机：搜索框聚焦/输入/清除按钮工作正常（空库无结果态）；批次80 过滤证据沿用 |
| 无待办 | — | `page/conversation/conversation_page.dart` | 点击会话进入对应聊天页 | 已通过 | 批次25 | 0 | 0 | 0 | W2R4 不可复测（本地甲/乙均无个人会话数据），跳转代码未被收敛提交改动，批次25 证据沿用 |
| 无待办 | — | `page/conversation/conversation_page.dart` | 新建群会话进入会话列表 | 已通过 | 批次25 | 0 | 0 | 0 | W2R4 未复测（无数据），批次25 证据沿用，代码未变 |
| 无待办 | - | ``page/conversation/conversation_page.dart`` | 点击头像进入对方资料页 | 已通过 | 批次80 | 0 | 0 | 0 | W2R4 未复测（无会话）；批次80 证据沿用；注：workspace 壳头像已移至顶栏右侧（ea682e31），chat 壳本页形态不变 |
| 无待办 | - | ``page/conversation/conversation_page.dart`` | 侧滑标记已读/未读 | 已通过 | 批次80 | 0 | 0 | 0 | W2R4 未复测（无会话可滑），批次80 证据沿用，侧滑代码未变 |
| 无待办 | - | `page/conversation/conversation_page.dart` | 侧滑置顶与取消置顶会话 | 已通过 | 批次81 | 0 | 0 | 0 | W2R4 未复测（无会话可滑），批次81 证据沿用，侧滑代码未变 |
| 无待办 | - | ``page/conversation/conversation_page.dart`` | 侧滑删除会话并同步服务端 | 已通过 | 批次80 | 0 | 0 | 0 | W2R4 未复测（无会话可滑），批次80 证据沿用，侧滑代码未变 |
| 无待办 | — | `page/conversation/conversation_page.dart` | 展示与关闭 E2EE 恢复横幅 | 已通过 | 批次25 | 0 | 0 | 0 | W2R4 未复测（需换设备恢复态），批次25 证据沿用，横幅代码未变 |
| 无待办 | — | `page/conversation/conversation_page.dart` | 群名缺失时的标题兜底显示 | 已通过 | 批次61 | 0 | 0 | 0 | W2R4 未复测（需无名群数据），批次61 兜底证据沿用，computeTitle/displayTitle 未变 |
| 无待办 | - | ``page/conversation/conversation_page.dart`` | 空列表与搜索无结果空态 | 已通过 | 批次W2R4 | 0 | 0 | 0 | W2R4 真机：空列表「无会话消息」+ 搜索无结果两态均实测（甲/乙双账号）；批次80 证据沿用 |
