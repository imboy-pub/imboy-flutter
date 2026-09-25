/// ENT-APP-06 — Organization 治理面 → 既有业务页深链 adapter。
///
/// 职责：把「企业工具/群/频道/工作区成员」的治理目标映射为**已注册的
/// 既有路由路径**（workspace_routes / channel_routes / group_routes）。
/// 本文件只拼路径，不新建路由、不新建页面、不承载业务语义——深链落点
/// 页面自身的权限与数据自治（服务端 403/404 是唯一裁决，客户端按服务端
/// 错误诚实降级，不本地伪装过滤）。
///
/// 路径真源：
/// - lib/config/router/routes/workspace_routes.dart
/// - lib/config/router/routes/channel_routes.dart
/// - lib/config/router/routes/group_routes.dart
library;

/// 工作区成员邀请向导（既有 WorkspaceInvitePage；仅 Owner 可发起，
/// 向导内部自治）。
String orgWorkspaceInvitePath(String workspaceId) =>
    '/workspace/$workspaceId/members/invite';

/// 项目详情（既有 ProjectDetailPage；任务/里程碑/成员/频道四聚合都在
/// 其子路由内，本 adapter 不重复展开）。
String orgProjectDetailPath({
  required String workspaceId,
  required String projectId,
}) => '/workspace/$workspaceId/projects/$projectId';

/// 项目内新建任务（既有 TaskFormPage）。
String orgProjectTaskCreatePath({
  required String workspaceId,
  required String projectId,
}) => '/workspace/$workspaceId/projects/$projectId/tasks/new';

/// 群详情（既有 GroupDetailPage：群设置 + 成员列表 + 成员角色治理收口
/// 在此页，org 治理面只负责把人送过去）。
String orgGroupDetailPath(String groupId) => '/group/detail/$groupId';

/// 频道详情（既有 ChannelDetailPage）。
String orgChannelDetailPath(String channelId) => '/channel/$channelId';

/// 频道编辑/重命名（既有 ChannelEditPage；channel 不传 extra 也能自取）。
String orgChannelEditPath(String channelId) => '/channel/$channelId/edit';

/// 频道管理员治理（既有 ChannelAdminPage：addAdmin/removeAdmin/
/// updateAdminRole 收口在此页）。
String orgChannelAdminsPath(String channelId) => '/channel/$channelId/admins';

/// 频道订阅者治理（既有 ChannelSubscriberPage：getSubscribers/
/// removeSubscriber 收口在此页；canInvite 由目标页按服务端事实判定，
/// 这里不传 extra 即保守缺省 false）。
String orgChannelSubscribersPath(String channelId) =>
    '/channel/$channelId/subscribers';
