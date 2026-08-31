# `page/group/group_detail/group_detail_page.dart`

> 功能点 17 个 | bug 发现 4 / 解决 3 / 待处理 1
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
| 无待办 | - | `page/group/group_detail/group_detail_page.dart` | 群详情头部群头像：有自定义群图显示群图，无群图按成员头像拼图（group_info_card SmartGroupAvatar） | 已通过 | 批次W2R6 | 0 | 0 | 0 | 两分支实证：无群图→拼图(memberAvatars count=2)；DB设群图→detail sync落库(GroupRepo_update avatar=非空)→单图直出不查成员缓存。图源下载被F-13 SSRF加固拒环回/私网host(本地联调限制,生产域名不受影响)故渲染占位，分支与数据链路正确 |
| 无待办 | - | `page/group/group_detail/group_detail_page.dart` | 非好友成员头像出现在拼图中（驱动表 group_member，contact 仅补头像） | 已通过 | 批次W2R6 | 0 | 0 | 0 | UID_F与ACC_A user_friend=0行无本地contact，头像URL由group_member行(服务端page带u.avatar)驱动→拼图count=2含非好友格；同F-13环境限制真图渲染为占位，数据链路正确 |
| 无待办 | - | `page/group/group_detail/group_detail_page.dart` | 拼图排列按 user_id 恒定：重进页面/成员换头像均不漂移 | 已通过 | 批次W2R6 | 0 | 0 | 0 | 重进详情count恒2不漂移；成员区甲(uid…161)前己(uid…116)后=user_id升序与SQL契约一致；排序SQL由15个契约测试锁死(test/unit_test/page/group/group_avatar_compute_test.dart) |
| 无待办 | - | `page/group/group_detail/group_detail_page.dart` | 群主头像不缺席（is_join=0 行不被过滤，or user_id=自己兜底） | 已通过 | 批次W2R6 | 0 | 0 | 0 | owner甲格恒在拼图：2人时count=2含owner，移除非owner后count=1仍含owner；is_join=0不过滤由memberAvatarSql契约测试锁定(in(0,1) or user_id=自己) |
| 待修复 | 2026-08-31 | `page/group/group_detail/group_detail_page.dart` | 成员退群后本页拼图即时更新（GroupMemberUpdateEvent 失效缓存） | 有BUG待修 | 批次W2R6 | 1 | 0 | 1 | 本机移除成员本页即时更新OK：count 2→0→1(<1s,provider删行+fire失效缓存)。但新bug:S2C group_member_leave处理崩溃(message_s2c.dart:593 int as String强转)致跨设备退群推送分支失效(对方设备不删行不失效拼图,列表member_count也未减)。复现:两成员群本机移除另一在线设备收S2C即崩 |
