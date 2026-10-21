// 路由烟雾测试注册表 / Route smoke-test registry
//
// 每条路由一条 SmokeRoute，location 已由 extract_routes.dart 经
// router.namedLocation() 解析（含嵌套子路由与 fake 动态参数），可直接 go()。
// One SmokeRoute per route. `location` is the navigable path resolved by
// router.namedLocation() (nested routes + fake dynamic params), ready for go().
//
// 维护规则 / Maintenance:
//   - 新增路由后，跑 `flutter test test/smoke/extract_routes.dart` 取新 location，
//     在此补一条 SmokeRoute；route_smoke_test.dart 的完整性守卫会强制不漏登记。
//   - 渲染会崩溃且短期无法 mock 的路由 → status: quarantine 并填 skipReason。

import 'package:imboy/store/model/feedback_model.dart';
import 'package:imboy/store/model/group_model.dart';

/// 路由状态 / Route status
enum RouteStatus { active, quarantine }

/// 单条烟雾测试路由定义 / Single smoke-test route entry
class SmokeRoute {
  const SmokeRoute({
    required this.name,
    required this.location,
    this.extra,
    this.status = RouteStatus.active,
    this.skipReason,
    this.expectedLocation,
    this.expectedRouteName,
  }) : assert(
         (expectedLocation == null) == (expectedRouteName == null),
         'redirect expectation requires both terminal location and route name',
       ),
       assert(
         status == RouteStatus.active || skipReason != null,
         'quarantine 路由必须填写 skipReason',
       );

  /// 路由 name（与 app_router.dart GoRoute.name 一致）
  final String name;

  /// 已解析的可导航 location（含 fake 参数）
  final String location;

  /// Explicit terminal route for an intentional alias. Defaults remain strict.
  final String? expectedLocation;
  final String? expectedRouteName;

  /// 需要非空 extra 强转的路由提供 fake 对象；多数路由为 null
  final Object? extra;

  /// active=纳入渲染断言；quarantine=skip（仍在报告中可见）
  final RouteStatus status;

  /// quarantine 原因（active 时为 null）
  final String? skipReason;
}

/// 2026-10-16 已恢复历史隔离项；新增隔离须附当前复现与替代验证说明。
const Set<String> leakyRoutesQuarantine = {};

/// 路由是否应被跳过（显式 quarantine 状态 或 异步泄漏名单）。
bool isQuarantined(SmokeRoute r) =>
    r.status == RouteStatus.quarantine ||
    leakyRoutesQuarantine.contains(r.name);

/// 全部命名路由（与 extract_routes.dart 输出对应）。
final List<SmokeRoute> smokeRoutes = <SmokeRoute>[
  // ==================== 认证 / 启动 ====================
  const SmokeRoute(name: 'splash', location: '/'),
  const SmokeRoute(name: 'welcome', location: '/welcome'),
  const SmokeRoute(name: 'sign_in', location: '/sign_in'),
  const SmokeRoute(name: 'sign_up', location: '/sign_up'),
  const SmokeRoute(name: 'sign_up_continue', location: '/sign_up/continue'),
  const SmokeRoute(name: 'forgot_password', location: '/forgot_password'),
  const SmokeRoute(
    name: 'forgot_password_pin',
    location: '/forgot_password/pin',
  ),
  const SmokeRoute(name: 'set_password', location: '/set_password'),
  const SmokeRoute(name: 'manage_account', location: '/manage_account'),

  // ==================== 主框架 ====================
  const SmokeRoute(name: 'bottom_navigation', location: '/bottom_navigation'),
  const SmokeRoute(name: 'web_shell', location: '/web_shell'),
  const SmokeRoute(name: 'conversation', location: '/conversation'),

  // ==================== 朋友圈 ====================
  const SmokeRoute(name: 'moment_feed', location: '/moment/feed'),
  const SmokeRoute(
    name: 'assistant_plaza',
    location: '/contact/assistant_plaza',
  ),
  const SmokeRoute(name: 'moment_create', location: '/moment/create'),
  const SmokeRoute(name: 'moment_notify', location: '/moment_notify'),
  const SmokeRoute(name: 'moment_detail', location: '/moment/3001'),

  // ==================== 聊天 ====================
  const SmokeRoute(name: 'chat', location: '/chat/1001'),
  const SmokeRoute(name: 'chat_setting', location: '/chat_setting/1001'),
  const SmokeRoute(
    name: 'send_to',
    location: '/chat/send_to',
    extra: {
      'msg': {
        'id': 'smoke_message',
        'authorId': 'smoke_test_uid',
        'type': 'text',
        'text': 'Smoke fixture',
      },
    },
  ),
  const SmokeRoute(name: 'launch_chat', location: '/launch_chat'),

  // ==================== 联系人（嵌套） ====================
  const SmokeRoute(name: 'contact', location: '/contact'),
  const SmokeRoute(name: 'people_info', location: '/contact/people/1001'),
  const SmokeRoute(name: 'new_friend', location: '/contact/new_friend'),
  const SmokeRoute(name: 'add_friend', location: '/contact/add_friend'),
  const SmokeRoute(name: 'select_friend', location: '/contact/select_friend'),
  const SmokeRoute(name: 'people_nearby', location: '/contact/people_nearby'),
  const SmokeRoute(
    name: 'recently_registered_user',
    location: '/contact/recently_registered_user',
  ),
  const SmokeRoute(
    name: 'people_info_more',
    location: '/contact/people_info_more/1001',
  ),
  const SmokeRoute(
    name: 'contact_setting',
    location: '/contact/contact_setting/1001',
  ),
  const SmokeRoute(
    name: 'people_info_same_group',
    location: '/contact/people_info_same_group',
  ),
  const SmokeRoute(name: 'user_tag_list', location: '/contact/tags'),

  // ==================== 群组（嵌套） ====================
  const SmokeRoute(name: 'group', location: '/group'),
  const SmokeRoute(name: 'group_list', location: '/group/list'),
  const SmokeRoute(name: 'group_discovery', location: '/group/discover'),
  const SmokeRoute(name: 'group_detail', location: '/group/detail/2001'),
  // 0017 群资料编辑页：builder 对 extra 做 `as GroupModel` 强转，
  // 注册表须提供与生产群详情信息卡同构的最小实例。
  SmokeRoute(
    name: 'group_change_info',
    location: '/group/change-info',
    extra: GroupModel(
      groupId: 2001,
      type: 2,
      joinLimit: 1,
      contentLimit: 1,
      ownerUid: 0,
      creatorUid: 0,
      memberMax: 0,
      memberCount: 0,
      title: 'smoke-change-info',
      createdAt: 0,
    ),
  ),
  const SmokeRoute(name: 'group_member', location: '/group/member'),
  const SmokeRoute(
    name: 'group_member_detail',
    location: '/group/member_detail',
  ),
  const SmokeRoute(name: 'group_add_member', location: '/group/add_member'),
  const SmokeRoute(
    name: 'group_remove_member',
    location: '/group/remove_member',
  ),
  const SmokeRoute(
    name: 'group_announcement',
    location: '/group/announcement',
    extra: {'groupId': '2001'},
  ),
  const SmokeRoute(name: 'group_launch_chat', location: '/group/launch_chat'),
  const SmokeRoute(name: 'group_select', location: '/group/select'),
  const SmokeRoute(name: 'face_to_face', location: '/group/face_to_face'),
  const SmokeRoute(
    name: 'face_to_face_confirm',
    location: '/group/face_to_face_confirm',
  ),

  // ==================== 频道（3级嵌套） ====================
  const SmokeRoute(name: 'channel_list', location: '/channel'),
  const SmokeRoute(name: 'channel_discover', location: '/channel/discover'),
  const SmokeRoute(name: 'channel_create', location: '/channel/create'),
  const SmokeRoute(
    name: 'channel_invitations',
    location: '/channel/invitations',
  ),
  const SmokeRoute(name: 'channel_detail', location: '/channel/5001'),
  const SmokeRoute(name: 'channel_compose', location: '/channel/5001/compose'),
  const SmokeRoute(
    name: 'channel_article',
    location: '/channel/5001/article/9001',
  ),
  const SmokeRoute(
    name: 'channel_comments',
    location: '/channel/5001/message/9001/comments',
  ),
  const SmokeRoute(name: 'channel_edit', location: '/channel/5001/edit'),
  const SmokeRoute(name: 'channel_admins', location: '/channel/5001/admins'),
  const SmokeRoute(
    name: 'channel_subscribers',
    location: '/channel/5001/subscribers',
  ),
  const SmokeRoute(name: 'channel_orders', location: '/channel/orders'),
  const SmokeRoute(
    name: 'channel_order_detail',
    location: '/channel/order/ORD1001',
  ),

  // ==================== 我的 / 设置 ====================
  const SmokeRoute(name: 'mine', location: '/mine'),
  const SmokeRoute(name: 'mine_setting', location: '/mine/setting'),
  const SmokeRoute(name: 'wallet', location: '/wallet'),
  const SmokeRoute(name: 'wallet_withdraw', location: '/wallet/withdraw'),
  const SmokeRoute(name: 'billing_plans', location: '/billing/plans'),
  const SmokeRoute(name: 'red_packet_send', location: '/red_packet_send'),
  const SmokeRoute(name: 'red_packet_detail', location: '/red_packet_detail'),
  const SmokeRoute(name: 'transfer_send', location: '/transfer_send'),
  const SmokeRoute(name: 'favorites', location: '/favorites'),
  const SmokeRoute(name: 'denylist', location: '/denylist'),
  const SmokeRoute(name: 'storage_space', location: '/storage_space'),
  const SmokeRoute(name: 'devices', location: '/devices'),
  const SmokeRoute(name: 'settings', location: '/settings'),
  const SmokeRoute(name: 'account_security', location: '/account_security'),
  const SmokeRoute(name: 'language', location: '/language'),
  const SmokeRoute(name: 'dark_model', location: '/dark_model'),
  const SmokeRoute(name: 'font_size', location: '/font_size'),
  const SmokeRoute(name: 'logout_account', location: '/logout_account'),
  // R-04.1：处置与申诉（mine_page「处置与申诉」入口跳转目标）
  const SmokeRoute(name: 'appeal', location: '/mine/appeal'),

  // ==================== E2EE ====================
  const SmokeRoute(name: 'e2ee_key_recovery', location: '/e2ee_key_recovery'),
  const SmokeRoute(name: 'e2ee_backup_export', location: '/e2ee_backup_export'),
  const SmokeRoute(name: 'e2ee_backup_import', location: '/e2ee_backup_import'),
  const SmokeRoute(name: 'change_password', location: '/change_password'),

  // ==================== 反馈 ====================
  const SmokeRoute(name: 'feedback', location: '/feedback'),
  SmokeRoute(
    name: 'feedback_detail',
    location: '/feedback/detail/9001',
    extra: {
      'model': FeedbackModel.fromJson({
        'feedback_id': 9001,
        'body': 'Smoke fixture',
        'rating': 3,
        'status': 1,
        'created_at': 0,
        'updated_at': 0,
      }),
    },
  ),

  // ==================== Single / 工具页 ====================
  const SmokeRoute(name: 'select_region', location: '/select_region'),
  const SmokeRoute(name: 'markdown', location: '/markdown'),
  const SmokeRoute(name: 'video_viewer', location: '/video_viewer'),
  const SmokeRoute(name: 'upgrade', location: '/upgrade'),
  // ponytail: privacy_policy 无独立路由（app_router.dart:480 设计决策：走
  // _openMarkdown("asset://docs/privacy-policy.md")），注册表不留多余条目。
  const SmokeRoute(name: 'terms_of_service', location: '/terms_of_service'),
  const SmokeRoute(
    name: 'network_failure_guidance',
    location: '/network_failure_guidance',
  ),
  const SmokeRoute(
    name: 'map_location_picker',
    location: '/map_location_picker',
  ),

  // ==================== 直播 ====================
  const SmokeRoute(name: 'live_room', location: '/live_room'),
  const SmokeRoute(
    name: 'live_room_publisher',
    location: '/live_room/publisher',
  ),
  const SmokeRoute(
    name: 'live_room_subscriber',
    location: '/live_room/subscriber',
  ),

  // ==================== 扫码 / 二维码 ====================
  const SmokeRoute(name: 'scanner', location: '/scanner'),
  const SmokeRoute(name: 'scanner_result', location: '/scanner/result'),
  const SmokeRoute(name: 'qrcode', location: '/qrcode'),
  const SmokeRoute(name: 'qrcode_user', location: '/qrcode/user'),
  SmokeRoute(
    name: 'qrcode_group',
    location: '/qrcode/group',
    extra: {
      'group': GroupModel.fromJson({'group_id': 2001, 'title': 'Smoke group'}),
    },
  ),
  const SmokeRoute(
    name: 'qrcode_channel',
    location: '/qrcode/channel',
    extra: {'id': '5001', 'name': 'Smoke channel'},
  ),

  // ==================== 个人资料（嵌套） ====================
  const SmokeRoute(name: 'personal_info', location: '/personal_info'),
  const SmokeRoute(
    name: 'set_nickname',
    location: '/personal_info/set_nickname',
  ),
  const SmokeRoute(name: 'set_gender', location: '/personal_info/set_gender'),
  const SmokeRoute(name: 'set_region', location: '/personal_info/set_region'),
  const SmokeRoute(name: 'update', location: '/personal_info/update'),
  const SmokeRoute(name: 'more', location: '/personal_info/more'),
  const SmokeRoute(name: 'profile', location: '/personal_info/profile'),
  const SmokeRoute(
    name: 'privacy_settings',
    location: '/personal_info/privacy_settings',
  ),

  // ==================== 搜索 ====================
  const SmokeRoute(name: 'search_chat', location: '/search_chat'),
  const SmokeRoute(name: 'message_search', location: '/message_search'),
  const SmokeRoute(name: 'web_search', location: '/web_search'),

  // ==================== 群功能增强（扁平 + 多级参数） ====================
  const SmokeRoute(name: 'group_category', location: '/group/category'),
  const SmokeRoute(name: 'group_tag', location: '/group/2001/tag'),
  const SmokeRoute(name: 'group_file', location: '/group/2001/file'),
  const SmokeRoute(name: 'group_album', location: '/group/2001/album'),
  const SmokeRoute(
    name: 'group_album_photos',
    location: '/group/2001/album/4001/photos',
  ),
  const SmokeRoute(
    name: 'group_album_photo_detail',
    location: '/group/2001/album/4001/photo/4101',
  ),
  const SmokeRoute(name: 'group_vote', location: '/group/2001/vote'),
  const SmokeRoute(
    name: 'group_vote_detail',
    location: '/group/2001/vote/6001',
  ),
  const SmokeRoute(name: 'group_schedule', location: '/group/2001/schedule'),
  const SmokeRoute(
    name: 'group_schedule_detail',
    location: '/group/2001/schedule/7001',
  ),
  const SmokeRoute(name: 'group_task', location: '/group/2001/task'),
  const SmokeRoute(
    name: 'group_task_detail',
    location: '/group/2001/task/8001',
  ),

  // ==================== @提及 ====================
  const SmokeRoute(name: 'mention_list', location: '/mention'),

  // ==================== 工作区（WP5/T8，双体验 v2.5.2） ====================
  const SmokeRoute(name: 'workspace_picker', location: '/workspace'),
  const SmokeRoute(name: 'workspace_create', location: '/workspace/create'),
  const SmokeRoute(name: 'workspace_join', location: '/workspace/join'),
  const SmokeRoute(name: 'workspace_members', location: '/workspace/members'),
  const SmokeRoute(
    name: 'workspace_channel_detail',
    location: '/workspace/9001/channels/9002',
  ),
  const SmokeRoute(
    name: 'workspace_invite',
    location: '/workspace/9001/members/invite',
  ),
  const SmokeRoute(
    name: 'workspace_branding',
    location: '/workspace/9001/branding',
  ),

  // ==================== 工作区 Project/Tasks（WP6/T10a/T10b，W0） ====================
  const SmokeRoute(
    name: 'workspace_project_create',
    location: '/workspace/9001/projects/create',
  ),
  const SmokeRoute(
    name: 'workspace_project_detail',
    location: '/workspace/9001/projects/9101',
  ),
  const SmokeRoute(
    name: 'workspace_task_create',
    location: '/workspace/9001/projects/9101/tasks/new',
  ),
  const SmokeRoute(
    name: 'workspace_task_edit',
    location: '/workspace/9001/projects/9101/tasks/9102/edit',
  ),

  // ==================== 工作区 Project W2 协作（ZC-06，成员/里程碑/频道/聚合） ====================
  const SmokeRoute(
    name: 'workspace_project_members',
    location: '/workspace/9001/projects/9101/members',
  ),
  const SmokeRoute(
    name: 'workspace_project_milestones',
    location: '/workspace/9001/projects/9101/milestones',
  ),
  const SmokeRoute(
    name: 'workspace_project_channels',
    location: '/workspace/9001/projects/9101/channels',
  ),
  const SmokeRoute(
    name: 'workspace_project_insights',
    location: '/workspace/9001/projects/9101/insights',
  ),

  // ==================== 兼容旧路径 ====================
  const SmokeRoute(name: 'people_info_top', location: '/people_info/1001'),

  // ==================== 企业（app-amendment-001：A4 纵切） ====================
  const SmokeRoute(name: 'enterprise_home', location: '/enterprise'),
  const SmokeRoute(
    name: 'enterprise_conversation',
    location: '/enterprise/7001/conversations/7002?contact_name=e2e',
  ),

  // ==================== 客服工作台（CSM-01/02） ====================
  const SmokeRoute(
    name: 'cs_workspace',
    location: '/customer_service/workspace',
  ),
  const SmokeRoute(
    name: 'cs_session',
    location: '/customer_service/workspace/sessions/1',
  ),

  // ==================== 企业组织（ORG V1） ====================
  // location 按 router.namedLocation 形态补登（orgId 假参沿用 9001 惯例）。
  const SmokeRoute(name: 'organization_home', location: '/organization'),
  const SmokeRoute(name: 'organization_detail', location: '/organization/9001'),
  const SmokeRoute(
    name: 'organization_members',
    location: '/organization/9001/members',
  ),
  const SmokeRoute(
    name: 'organization_invitations',
    location: '/organization/9001/invitations',
  ),
  const SmokeRoute(
    name: 'organization_departments',
    location: '/organization/9001/departments',
  ),
  // APP-M02：邀请同事（?name= 可省略，分享文案回落通用文案；页内
  // 邀请码/企业详情异步加载失败走各自错误态，无头烟雾可渲染）。
  const SmokeRoute(
    name: 'organization_invite_colleagues',
    location: '/organization/9001/invite_colleagues',
  ),

  // ==================== 客服治理 / 企业工具（CS-APP-03 / ENT-APP-06） ====================
  // location 按 router.namedLocation 形态补登（orgId/wsId 假参沿用 9001 惯例）。
  const SmokeRoute(
    name: 'cs_governance',
    location: '/customer_service/governance/9001',
  ),
  const SmokeRoute(
    name: 'organization_tools',
    location: '/organization/9001/tools',
  ),
  const SmokeRoute(
    name: 'organization_ws_members',
    location: '/organization/9001/ws/9002/members',
  ),

  // ==================== 企业组织补充（GZAPP-04 G9/G10、GZAPP-C3、GZAPP-05） ====================
  // location 按 router.namedLocation 形态补登（orgId/uid 假参沿用 9001 惯例）；
  // 四页 initState 异步加载与 organization_home 同类，渲染烟雾实测可过。
  const SmokeRoute(
    name: 'organization_picker',
    location: '/organization/picker',
  ),
  const SmokeRoute(
    name: 'organization_directory',
    location: '/organization/9001/directory',
  ),
  const SmokeRoute(
    name: 'organization_member_detail',
    location: '/organization/9001/member/9003',
  ),
  const SmokeRoute(
    name: 'organization_manage',
    location: '/organization/9001/manage',
  ),

  // Talk record routes: active smoke coverage, no quarantine.
  const SmokeRoute(name: 'talk_record_list', location: '/talk_record'),
  const SmokeRoute(
    name: 'talk_record_prepare',
    location: '/talk_record/prepare',
  ),
  const SmokeRoute(
    name: 'talk_record_save_location',
    location: '/talk_record/save_location',
  ),
  const SmokeRoute(
    name: 'talk_record_invalid',
    location: '/talk_record/invalid',
  ),
  const SmokeRoute(
    name: 'talk_record_detail',
    location: '/talk_record/detail/9001',
  ),
  const SmokeRoute(
    name: 'talk_record_segment_edit',
    location: '/talk_record/detail/9001/segment/9002',
  ),
  const SmokeRoute(
    name: 'talk_record_speakers',
    location: '/talk_record/detail/9001/speakers',
  ),
  const SmokeRoute(
    name: 'talk_record_share',
    location: '/talk_record/detail/9001/share',
  ),
  const SmokeRoute(
    name: 'talk_record_grant_edit',
    location: '/talk_record/detail/9001/share/grant_edit',
  ),
  const SmokeRoute(
    name: 'organization_attachments',
    location: '/organization/9001/attachments',
  ),
  const SmokeRoute(
    name: 'talk_record_card_locator',
    location: '/talk-records/9001',
    expectedLocation: '/talk_record/detail/9001',
    expectedRouteName: 'talk_record_detail',
  ),
  const SmokeRoute(
    name: 'talk_record_export',
    location: '/talk_record/detail/9001/export',
  ),
  const SmokeRoute(
    name: 'talk_record_transfer',
    location: '/talk_record/detail/9001/transfer',
  ),
  const SmokeRoute(
    name: 'talk_record_cleanup',
    location: '/talk_record/detail/9001/cleanup',
  ),
];
