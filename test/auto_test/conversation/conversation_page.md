# `page/conversation/conversation_page.dart`

> 功能点 12 个 | bug 发现 4 / 解决 3 / 待处理 1
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | — | `page/conversation/conversation_page.dart` | 加载并展示会话列表 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-08 | `page/conversation/conversation_page.dart` | 下拉刷新拉取服务端权威列表 | 已通过 | 批次61 | 0 | 0 | 0 | 真机下拉触发 logcat 实锤 GET conversation/mine 拉取服务端权威列表 |
| 回归复测 | 2026-08-08 | `page/conversation/conversation_page.dart` | 顶部搜索框本地过滤会话 | 已通过 | 批次61 | 0 | 0 | 0 | 真机输入 leeyi 列表只剩该会话；zzzz-no-result 显示无搜索结果空态（本地过滤） |
| 无待办 | — | `page/conversation/conversation_page.dart` | 点击会话进入对应聊天页 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 无待办 | — | `page/conversation/conversation_page.dart` | 新建群会话进入会话列表 | 已通过 | 批次25 | 1 | 1 | 0 | |
| 回归复测 | 2026-08-08 | `page/conversation/conversation_page.dart` | 点击头像进入对方资料页 | 已通过 | 批次61 | 0 | 0 | 0 | 真机点 leeyi 会话头像进入资料页（昵称/ID 50075/地区/备注标签/发消息/音视频通话） |
| 回归复测 | 2026-08-08 | `page/conversation/conversation_page.dart` | 侧滑标记已读/未读 | 已通过 | 批次61 | 0 | 0 | 0 | 真机侧滑面板标记未读→IMBoy 出现 1 条未读徽标+底部未读总数 4→5；再点标记已读还原 |
| 回归复测 | 2026-08-08 | `page/conversation/conversation_page.dart` | 侧滑置顶与取消置顶会话 | 有BUG待修 | 批次61 | 1 | 0 | 1 | BUG#129：历史真机 logcat 记录过 POST conversation/pin 后按钮仍「置顶」+列表未重排；根因曾指向客户端 TSID 字符串与服务端整数契约不一致。2026-08-09 生产错误边界复核中，pin/unpin/delete/restore 对无效 ID 均结构化拒绝；有效会话写入仍未在隔离环境复验，暂不宣称修复。 |
| 回归复测 | 2026-08-08 | `page/conversation/conversation_page.dart` | 侧滑删除会话并同步服务端 | 有BUG待修 | 批次61 | 0 | 0 | 0 | BUG#129 有效会话删除仍未在隔离环境执行（不可逆）；2026-08-09 仅完成无效 ID 错误边界复核，不能替代真实删除后恢复/列表同步证据。 |
| 无待办 | — | `page/conversation/conversation_page.dart` | 展示与关闭 E2EE 恢复横幅 | 已通过 | 批次25 | 0 | 0 | 0 | |
| 待复验 | 2026-08-08 | `page/conversation/conversation_page.dart` | 群名缺失时的标题兜底显示 | 已通过 | 批次61 | 1 | 1 | 0 | 真机「未命名 11小时前」兜底文案实锤；代码确认 computeTitle（provider L300-330）无名群回落成员昵称拼接且只写内存不落库+displayTitle（model L66-73）TSID 不进 UI 缺名统一 main.unnamed |
| 回归复测 | 2026-08-08 | `page/conversation/conversation_page.dart` | 空列表与搜索无结果空态 | 已通过 | 批次61 | 0 | 0 | 0 | 真机搜索 zzzz-no-result 显示无搜索结果空态；空列表态需清空全部会话不可构造（当前 6 会话） |
