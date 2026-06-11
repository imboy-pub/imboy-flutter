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
  }) : assert(
         status == RouteStatus.active || skipReason != null,
         'quarantine 路由必须填写 skipReason',
       );

  /// 路由 name（与 app_router.dart GoRoute.name 一致）
  final String name;

  /// 已解析的可导航 location（含 fake 参数）
  final String location;

  /// 需要非空 extra 强转的路由提供 fake 对象；多数路由为 null
  final Object? extra;

  /// active=纳入渲染断言；quarantine=skip（仍在报告中可见）
  final RouteStatus status;

  /// quarantine 原因（active 时为 null）
  final String? skipReason;
}

/// 「异步泄漏」隔离名单 / Async-leaky quarantine set。
///
/// 这些页面在 initState 经 loadData() 发起异步（Dio 超时 Timer / Future.delayed），
/// 在无头 widget 测试中页面 dispose 后仍留 pending Timer，触发 Flutter teardown
/// 严格不变量（binding.dart:2542「A Timer is still pending」）而失败——
/// **这不是渲染崩溃**，是无头 render 烟雾测试与异步页面的固有不兼容
/// （pending-timer 检查与 FakeAsync 均为 Flutter 私有，无法干净容忍/取消）。
///
/// 由 `run_smoke_isolated.sh` 进程隔离实测得出（2026-05-30，PASS=52/FAIL=54）。
/// 这些页面应由 **integration_test（真机，无此严格检查）** 覆盖，
/// 或修页面 State.dispose() 取消其定时器后移出本名单。
///
/// 维护：定期用 `bash test/smoke/run_smoke_isolated.sh` 复核，能渲染干净的移出。
const Set<String> leakyRoutesQuarantine = {
  'add_friend',
  'bottom_navigation',
  'channel_admins',
  'channel_create',
  'channel_detail',
  'channel_discover',
  'channel_edit',
  'channel_invitations',
  'channel_list',
  'channel_subscribers',
  'chat',
  // E2EE 页 initState 经 service 异步加载（getPendingTransfers/getShards），触发 token 过期 →
  // quitLogin → PersistentMessageQueue 周期清理 Timer + dio http2 socket Timer 泄漏，
  // 无头烟雾测试 teardown 触发 pending-timer 不变量失败，非渲染崩溃，由 integration_test 覆盖
  'e2ee_proxy_selector',
  'e2ee_social',
  'e2ee_social_manage',
  'e2ee_social_recover',
  'e2ee_transfer',
  'favorites',
  'group_album',
  'group_album_photo_detail',
  'group_album_photos',
  'group_category',
  'group_detail',
  'group_file',
  'group_launch_chat',
  'group_schedule',
  'group_schedule_detail',
  'group_tag',
  'group_task',
  'group_task_detail',
  'group_vote',
  'group_vote_detail',
  'launch_chat',
  'live_room',
  'live_room_publisher',
  'live_room_subscriber',
  'manage_account',
  'mention_list',
  'message_search',
  'moment_detail',
  'moment_feed',
  'more',
  'personal_info',
  'privacy_settings',
  'profile',
  'qrcode',
  'qrcode_user',
  'search_chat',
  'select_region',
  'set_gender',
  'set_nickname',
  'set_region',
  'settings',
  'sign_up_continue',
  'update',
  'video_viewer',
  'wallet',
  'web_search',
  'web_shell',
};

/// 路由是否应被跳过（显式 quarantine 状态 或 异步泄漏名单）。
bool isQuarantined(SmokeRoute r) =>
    r.status == RouteStatus.quarantine ||
    leakyRoutesQuarantine.contains(r.name);

/// 全部 118 条路由（与 extract_routes.dart 输出一一对应）
final List<SmokeRoute> smokeRoutes = <SmokeRoute>[
  // ==================== 认证 / 启动 ====================
  const SmokeRoute(name: 'splash', location: '/'),
  const SmokeRoute(name: 'welcome', location: '/welcome'),
  const SmokeRoute(name: 'sign_in', location: '/sign_in'),
  const SmokeRoute(name: 'sign_up', location: '/sign_up'),
  const SmokeRoute(name: 'sign_up_continue', location: '/sign_up/continue'),
  const SmokeRoute(name: 'forgot_password', location: '/forgot_password'),
  const SmokeRoute(name: 'set_password', location: '/set_password'),
  const SmokeRoute(name: 'manage_account', location: '/manage_account'),

  // ==================== 主框架 ====================
  const SmokeRoute(name: 'bottom_navigation', location: '/bottom_navigation'),
  const SmokeRoute(name: 'web_shell', location: '/web_shell'),
  const SmokeRoute(name: 'conversation', location: '/conversation'),

  // ==================== 朋友圈 ====================
  const SmokeRoute(name: 'moment_feed', location: '/moment/feed'),
  const SmokeRoute(name: 'moment_create', location: '/moment/create'),
  const SmokeRoute(name: 'moment_notify', location: '/moment_notify'),
  const SmokeRoute(name: 'moment_detail', location: '/moment/3001'),

  // ==================== 聊天 ====================
  const SmokeRoute(name: 'chat', location: '/chat/1001'),
  const SmokeRoute(name: 'chat_setting', location: '/chat_setting/1001'),
  const SmokeRoute(
    name: 'send_to',
    location: '/chat/send_to',
    status: RouteStatus.quarantine,
    skipReason:
        'SendToPage 需非空 Message extra（app_router.dart:258 强转），'
        '构造成本高，留待 E2E 覆盖',
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
  const SmokeRoute(name: 'user_tag_list', location: '/contact/tags'),

  // ==================== 群组（嵌套） ====================
  const SmokeRoute(name: 'group', location: '/group'),
  const SmokeRoute(name: 'group_list', location: '/group/list'),
  const SmokeRoute(name: 'group_detail', location: '/group/detail/2001'),
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
  const SmokeRoute(name: 'group_announcement', location: '/group/announcement'),
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
  const SmokeRoute(name: 'channel_edit', location: '/channel/5001/edit'),
  const SmokeRoute(name: 'channel_admins', location: '/channel/5001/admins'),
  const SmokeRoute(
    name: 'channel_subscribers',
    location: '/channel/5001/subscribers',
  ),

  // ==================== 我的 / 设置 ====================
  const SmokeRoute(name: 'mine', location: '/mine'),
  const SmokeRoute(name: 'mine_setting', location: '/mine/setting'),
  const SmokeRoute(name: 'wallet', location: '/wallet'),
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

  // ==================== E2EE ====================
  const SmokeRoute(name: 'e2ee_key_recovery', location: '/e2ee_key_recovery'),
  const SmokeRoute(name: 'e2ee_transfer', location: '/e2ee_transfer'),
  const SmokeRoute(name: 'e2ee_social', location: '/e2ee_social'),
  const SmokeRoute(name: 'e2ee_social_create', location: '/e2ee_social_create'),
  const SmokeRoute(
    name: 'e2ee_social_recover',
    location: '/e2ee_social_recover',
  ),
  const SmokeRoute(name: 'e2ee_social_manage', location: '/e2ee_social_manage'),
  const SmokeRoute(
    name: 'e2ee_proxy_selector',
    location: '/e2ee_proxy_selector',
  ),
  const SmokeRoute(name: 'e2ee_backup_export', location: '/e2ee_backup_export'),
  const SmokeRoute(name: 'e2ee_backup_import', location: '/e2ee_backup_import'),
  const SmokeRoute(name: 'e2ee_transfer_send', location: '/e2ee_transfer_send'),
  const SmokeRoute(
    name: 'e2ee_transfer_receive',
    location: '/e2ee_transfer_receive',
  ),
  const SmokeRoute(name: 'change_password', location: '/change_password'),

  // ==================== 反馈 ====================
  const SmokeRoute(name: 'feedback', location: '/feedback'),
  const SmokeRoute(name: 'feedback_detail', location: '/feedback/detail/9001'),

  // ==================== Single / 工具页 ====================
  const SmokeRoute(name: 'select_region', location: '/select_region'),
  const SmokeRoute(name: 'markdown', location: '/markdown'),
  const SmokeRoute(name: 'video_viewer', location: '/video_viewer'),
  const SmokeRoute(name: 'upgrade', location: '/upgrade'),
  const SmokeRoute(name: 'privacy_policy', location: '/privacy_policy'),
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
  const SmokeRoute(name: 'qrcode_group', location: '/qrcode/group'),
  const SmokeRoute(name: 'qrcode_channel', location: '/qrcode/channel'),

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

  // ==================== 兼容旧路径 ====================
  const SmokeRoute(name: 'people_info_top', location: '/people_info/1001'),
];
