# `page/group/group_member/group_member_detail_page.dart`

> 功能点 11 个 | bug 发现 0 / 解决 0 / 待处理 0
> 索引：[../README.md](../README.md)

| 计划变化 | 计划时间 | 页面path | 功能介绍 | 测试状态 | 测试轮次 | 发现bug | 解决bug | 待处理bug | 备注 |
|---|---|---|---|---|---|---|---|---|---|
| 无待办 | - | `page/group/group_member/group_member_detail_page.dart` | 展示成员头像昵称与签名卡片 | 已通过 | 批次22 | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/group_member/group_member_detail_page.dart` | 展示禁言状态与剩余时间行 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/group_member/group_member_detail_page.dart` | 点禁言弹出时长选择底部弹层 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/group_member/group_member_detail_page.dart` | 点更多操作弹出管理操作表 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/group_member/group_member_detail_page.dart` | 普通成员看不到管理操作区 | 待重验 | - | 0 | 0 | 0 | |
| 回归复测 | 2026-08-07 | `page/group/group_member/group_member_detail_page.dart` | 返回时回传变更标记刷新列表 | 待重验 | - | 0 | 0 | 0 | |
| 阻塞 | 需可传任意 userId 的入口或 >20 人群（入口链=群详情成员行→成员列表→点成员，列表即本地库渲染必有记录） | `page/group/group_member/group_member_detail_page.dart` | 成员不存在时展示暂无数据 | 未测 | 批次29 | 0 | 0 | 0 | member==null→Text(noData) 代码证实 L281-283；本机三群均≤2人连成员列表入口都没有 |
| 阻塞 | 需授权影响第三方 | `page/group/group_member/group_member_detail_page.dart` | 选择时长提交禁言该成员 | 未测 | - | 0 | 0 | 0 | 直接影响他人发言权 |
| 阻塞 | 需授权影响第三方 | `page/group/group_member/group_member_detail_page.dart` | 二次确认后解除成员禁言 | 未测 | - | 0 | 0 | 0 | |
| 阻塞 | 需授权影响第三方 | `page/group/group_member/group_member_detail_page.dart` | 群主设置或取消成员管理员 | 未测 | - | 0 | 0 | 0 | 改权限影响全群 |
| 阻塞 | 需授权影响第三方 | `page/group/group_member/group_member_detail_page.dart` | 管理员确认后移出该成员 | 未测 | - | 0 | 0 | 0 | 不可逆踢人操作 |
