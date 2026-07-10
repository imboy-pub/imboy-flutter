import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/app_core/routing/route_feature_guard.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/service/user_profile_service.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_breakpoints.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

// ============================================================================
// 页面 Barrel exports - 统一导入所有页面
// ============================================================================
import 'barrel/pages_barrel.dart';

// 组件
import 'package:imboy/component/location/widget.dart';

// 数据模型
import 'package:imboy/store/model/live_room_model.dart';

// 分域路由
import 'routes/group_routes.dart';
import 'routes/channel_routes.dart';
import 'routes/mine_routes.dart';
import 'routes/group_feature_routes.dart';

bool _matchesPublicPath(String currentPath, String publicPath) {
  if (publicPath == AppRoutes.initial) {
    return currentPath == AppRoutes.initial;
  }
  return currentPath == publicPath || currentPath.startsWith('$publicPath/');
}

bool _isPublicPath(String currentPath) {
  const publicPaths = [
    AppRoutes.initial,
    AppRoutes.signIn,
    AppRoutes.signUp,
    '/welcome',
    AppRoutes.forgotPassword,
    AppRoutes.privacyPolicy,
    AppRoutes.termsOfService,
  ];
  return publicPaths.any((path) => _matchesPublicPath(currentPath, path));
}

/// 深链接资源 URL host 白名单校验。
///
/// `/markdown`、`/video_viewer`、`/upgrade` 的 url/downLoadUrl 查询参数可被外部
/// 深链接（universal link）或群消息内容任意构造，未经校验直接传给页面会被用于
/// 渲染钓鱼内容或诱导下载恶意安装包。这里只信任：
/// - Garage object_key（如 `u123/xxx.mp4`，由 [AssetsService.isObjectKey] 识别）；
/// - host 命中当前环境后端域名（[Env().apiBaseUrl]）或公开资源域名
///   （[Env.publicBaseUrl]）及其子域。
/// 其余一律拒绝，调用方应回退为空字符串。
bool isTrustedResourceUrl(String rawUrl) {
  if (rawUrl.isEmpty) return false;
  if (AssetsService.isObjectKey(rawUrl)) return true;

  final uri = Uri.tryParse(rawUrl);
  if (uri == null || uri.host.isEmpty) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;

  final trustedHosts = <String>{
    Uri.tryParse(Env().apiBaseUrl)?.host ?? '',
    Uri.tryParse(Env.publicBaseUrl)?.host ?? '',
  }..removeWhere((host) => host.isEmpty);

  return trustedHosts.any(
    (host) => uri.host == host || uri.host.endsWith('.$host'),
  );
}

/// GoRouter 路由配置
///
/// 此配置文件已添加路由守卫，实现自动登录检查
///
/// 路由规范：
/// - 使用 RESTful 风格的路径命名
/// - 参数通过 GoRoute 的 path 参数或 state.extra 传递
/// - 所有路由必须有清晰的 name 用于程序化导航
final goRouterProvider = Provider<GoRouter>((ref) => createAppRouter());

/// 创建应用 GoRouter / Create the app GoRouter.
///
/// 生产环境用默认参数（initialLocation=/，全局 navigatorKey）。
/// 测试可注入 [initialLocation] 与独立 [navigatorKeyOverride]，
/// 以便对单条路由做「无 splash、无跨用例 GlobalKey 污染」的烟雾测试。
GoRouter createAppRouter({
  String initialLocation = AppRoutes.initial,
  GlobalKey<NavigatorState>? navigatorKeyOverride,
}) {
  return GoRouter(
    navigatorKey: navigatorKeyOverride ?? navigatorKey,
    initialLocation: initialLocation,
    debugLogDiagnostics: kDebugMode, // 仅开发环境开启路由日志
    // 路由重定向（认证守卫）
    redirect: (context, state) {
      final isLogin = UserRepoLocal.to.isLoggedIn;
      final currentPath = state.matchedLocation;

      if (_isPublicPath(currentPath)) {
        return null;
      }

      if (!isLogin) {
        Future<dynamic>.delayed(const Duration(seconds: 1), () {
          if (context.mounted) {
            final t = context.t;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t.chat.loginExpiredMessage),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });

        return AppRoutes.signIn;
      }

      final blocked = RouteFeatureGuard.checkBlocked(
        isLoggedIn: isLogin,
        currentPath: currentPath,
      );
      if (blocked != null) {
        RouteFeatureGuard.notifyBlocked(context, (
          reason: blocked.reason,
          name: blocked.name,
        ));
        return blocked.redirect;
      }

      return null;
    },

    routes: [
      // ==================== 认证和启动页面 ====================
      GoRoute(
        path: AppRoutes.initial,
        name: 'splash',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const SplashPage()),
      ),
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const WelcomePage()),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        name: 'sign_in',
        pageBuilder: (context, state) {
          // 大屏桌面/Web 环境使用 WebLoginPage（阈值与 AppBreakpoints.wide 对齐）
          final useSplitView = AppBreakpoints.isWide(
            MediaQuery.sizeOf(context).width,
          );
          return CupertinoPage(
            key: state.pageKey,
            child: useSplitView ? const WebLoginPage() : const LoginPage(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.signUp,
        name: 'sign_up',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const SignupPage()),
      ),
      GoRoute(
        path: '/sign_up/continue',
        name: 'sign_up_continue',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const SignupContinuePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgot_password',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const ForgotPasswordPage(),
        ),
      ),
      GoRoute(
        path: '/set_password',
        name: 'set_password',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: SetPasswordPage()),
      ),
      GoRoute(
        path: '/manage_account',
        name: 'manage_account',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const ManageAccountPage()),
      ),

      // ==================== 主框架 ====================
      GoRoute(
        path: '/bottom_navigation',
        name: 'bottom_navigation',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const BottomNavigationPage(),
        ),
      ),
      // Web Shell 三栏壳（Phase 1.1.h.1+i）— Web 登录成功后跳转的入口
      // 内部按响应式断点决定：< 900px → 回退 BottomNavigationPage，>= 900px → 三栏
      // 深链支持：/web_shell?tab=chat&id=xxx&type=C2C 由 1.1.m parseShellRouteParams 解析
      GoRoute(
        path: '/web_shell',
        name: 'web_shell',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const WebShellBootstrap()),
      ),

      // ==================== 会话列表 ====================
      GoRoute(
        path: '/conversation',
        name: 'conversation',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: ConversationPage()),
      ),

      // ==================== 朋友圈相关 ====================
      GoRoute(
        path: AppRoutes.momentFeed,
        name: 'moment_feed',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const MomentFeedPage()),
      ),
      GoRoute(
        path: AppRoutes.momentCreate,
        name: 'moment_create',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const MomentCreatePage()),
      ),
      GoRoute(
        path: '/moment_notify',
        name: 'moment_notify',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const MomentNotifyPage()),
      ),
      GoRoute(
        path: '${AppRoutes.momentRoot}/:momentId',
        name: 'moment_detail',
        pageBuilder: (context, state) {
          final momentId = state.pathParameters['momentId'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: MomentDetailPage(momentId: momentId),
          );
        },
      ),

      // ==================== 聊天相关 ====================
      // 聊天页面路由 - 使用 CupertinoPage 支持 iOS 风格滑动返回
      GoRoute(
        path: '/chat/:peerId',
        name: 'chat',
        pageBuilder: (context, state) {
          final peerId = state.pathParameters['peerId'] ?? '';
          // 支持两种传参方式：queryParameters 和 extra
          final type = state.uri.queryParameters['type'] ?? 'C2C';
          final msgId = state.uri.queryParameters['msg_id'] ?? '';
          final title = state.uri.queryParameters['title'] ?? '';
          final avatar = state.uri.queryParameters['avatar'] ?? '';
          final sign = state.uri.queryParameters['sign'] ?? '';
          final extra = state.extra as Map<String, dynamic>? ?? {};
          // extra 参数优先级更高
          return CupertinoPage(
            key: state.pageKey,
            child: ChatPage(
              peerId: peerId,
              type: extra['type']?.toString() ?? type,
              peerTitle: extra['title']?.toString() ?? title,
              peerAvatar: extra['avatar']?.toString() ?? avatar,
              peerSign: extra['sign']?.toString() ?? sign,
              msgId: extra['msg_id']?.toString() ?? msgId,
              options: extra['options'] as Map<String, dynamic>?,
            ),
          );
        },
      ),
      // 聊天设置页 - 使用 CupertinoPage 支持 iOS 风格滑动返回
      GoRoute(
        path: '/chat_setting/:peerId',
        name: 'chat_setting',
        pageBuilder: (context, state) {
          final peerId = state.pathParameters['peerId'] ?? '';
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CupertinoPage(
            key: state.pageKey,
            child: ChatSettingPage(
              peerId,
              type: extra['type']?.toString() ?? 'C2C',
              options: extra['options'] as Map<String, dynamic>?,
            ),
          );
        },
      ),
      // 转发消息页 - 使用 CupertinoPage 支持 iOS 风格滑动返回
      GoRoute(
        path: '/chat/send_to',
        name: 'send_to',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CupertinoPage(
            key: state.pageKey,
            child: SendToPage(msg: extra?['msg'] as Message),
          );
        },
      ),
      // 发起聊天页（顶层路由，用于从任何地方发起聊天）
      GoRoute(
        path: '/launch_chat',
        name: 'launch_chat',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const LaunchChatPage()),
      ),
      // ==================== 联系人相关 ====================
      GoRoute(
        path: '/contact',
        name: 'contact',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const ContactPage()),
        routes: [
          GoRoute(
            path: '/people/:id',
            name: 'people_info',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              final scene =
                  state.uri.queryParameters['scene'] ?? 'contact_page';
              return CupertinoPage(
                key: state.pageKey,
                child: PeopleInfoPage(id: id, scene: scene),
              );
            },
          ),
          GoRoute(
            path: '/new_friend',
            name: 'new_friend',
            pageBuilder: (context, state) =>
                CupertinoPage(key: state.pageKey, child: NewFriendPage()),
          ),
          GoRoute(
            path: '/add_friend',
            name: 'add_friend',
            pageBuilder: (context, state) =>
                CupertinoPage(key: state.pageKey, child: AddFriendPage()),
          ),
          GoRoute(
            path: '/select_friend',
            name: 'select_friend',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CupertinoPage(
                key: state.pageKey,
                child: SelectFriendPage(
                  peer: (extra['peer'] as Map<String, String>?) ?? {},
                  peerIsReceiver: extra['peerIsReceiver'] as bool? ?? false,
                ),
              );
            },
          ),
          GoRoute(
            path: '/people_nearby',
            name: 'people_nearby',
            pageBuilder: (context, state) =>
                CupertinoPage(key: state.pageKey, child: PeopleNearbyPage()),
          ),
          GoRoute(
            path: '/recently_registered_user',
            name: 'recently_registered_user',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: RecentlyRegisteredUserPage(),
            ),
          ),
          GoRoute(
            path: '/people_info_more/:id',
            name: 'people_info_more',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return CupertinoPage(
                key: state.pageKey,
                child: PeopleInfoMorePage(id: id),
              );
            },
          ),
          GoRoute(
            path: '/tags',
            name: 'user_tag_list',
            pageBuilder: (context, state) =>
                CupertinoPage(key: state.pageKey, child: ContactTagListPage()),
          ),
        ],
      ),

      // 群组路由
      ...groupRoutes(),

      // 频道路由
      ...channelRoutes(),

      // 个人中心路由
      ...mineRoutes(),

      // ==================== Single 页面 ====================
      GoRoute(
        path: '/markdown',
        name: 'markdown',
        pageBuilder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? '';
          final rawUrl = state.uri.queryParameters['url'] ?? '';
          final url = isTrustedResourceUrl(rawUrl) ? rawUrl : '';
          final selectable = state.uri.queryParameters['selectable'] == 'true';
          return CupertinoPage(
            key: state.pageKey,
            child: MarkdownPage(title: title, url: url, selectable: selectable),
          );
        },
      ),
      GoRoute(
        path: '/video_viewer',
        name: 'video_viewer',
        pageBuilder: (context, state) {
          final rawUrl = state.uri.queryParameters['url'] ?? '';
          final rawThumb = state.uri.queryParameters['thumb'] ?? '';
          final url = isTrustedResourceUrl(rawUrl) ? rawUrl : '';
          final thumb = isTrustedResourceUrl(rawThumb) ? rawThumb : '';
          return CupertinoPage(
            key: state.pageKey,
            child: VideoViewerPage(url: url, thumb: thumb),
          );
        },
      ),
      GoRoute(
        path: '/upgrade',
        name: 'upgrade',
        pageBuilder: (context, state) {
          final rawDownLoadUrl = state.uri.queryParameters['downLoadUrl'] ?? '';
          final downLoadUrl = isTrustedResourceUrl(rawDownLoadUrl)
              ? rawDownLoadUrl
              : '';
          final message = state.uri.queryParameters['message'] ?? '';
          final version = state.uri.queryParameters['version'] ?? '';
          final isForce = state.uri.queryParameters['isForce'] == 'true';
          return CupertinoPage(
            key: state.pageKey,
            child: UpgradePage(
              downLoadUrl: downLoadUrl,
              message: message,
              version: version,
              isForce: isForce,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        name: 'privacy_policy',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const PrivacyPolicyPage()),
      ),
      GoRoute(
        path: AppRoutes.termsOfService,
        name: 'terms_of_service',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const TermsOfServicePage(),
        ),
      ),
      GoRoute(
        path: '/network_failure_guidance',
        name: 'network_failure_guidance',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const NetworkFailureGuidancePage(),
        ),
      ),
      GoRoute(
        path: '/map_location_picker',
        name: 'map_location_picker',
        pageBuilder: (context, state) {
          // 从 state.extra 获取参数
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final lat = extra['lat'] as double? ?? 39.909187;
          final lng = extra['lng'] as double? ?? 116.397451;
          final citycode = extra['citycode']?.toString() ?? '';
          final isMapImage = extra['isMapImage'] as bool? ?? false;

          return CupertinoPage(
            key: state.pageKey,
            child: MapLocationPicker(
              arguments: {
                'lat': lat,
                'lng': lng,
                'citycode': citycode,
                'isMapImage': isMapImage,
              },
            ),
          );
        },
      ),

      // ==================== 直播间相关 ====================
      GoRoute(
        path: '/live_room',
        name: 'live_room',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const LiveRoomListPage()),
        routes: [
          GoRoute(
            path: '/publisher',
            name: 'live_room_publisher',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: PublisherPage(room: state.extra as LiveRoomModel?),
            ),
          ),
          GoRoute(
            path: '/subscriber',
            name: 'live_room_subscriber',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: SubscriberPage(room: state.extra as LiveRoomModel?),
            ),
          ),
        ],
      ),

      // ==================== 二维码和扫描相关 ====================
      GoRoute(
        path: '/scanner',
        name: 'scanner',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const ScannerPage()),
      ),
      GoRoute(
        path: '/scanner/result',
        name: 'scanner_result',
        pageBuilder: (context, state) {
          final scanResult = state.uri.queryParameters['result'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: ScannerResultPage(scanResult: scanResult),
          );
        },
      ),
      GoRoute(
        path: '/qrcode',
        name: 'qrcode',
        redirect: (context, state) => '/qrcode/user',
      ),
      GoRoute(
        path: '/qrcode/user',
        name: 'qrcode_user',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: UserQrCodePage()),
      ),
      GoRoute(
        path: '/qrcode/group',
        name: 'qrcode_group',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final group = extra?['group'] as GroupModel?;
          if (group == null) {
            return CupertinoPage(
              key: state.pageKey,
              child: Scaffold(
                body: Center(child: Text('Group data not found')),
              ),
            );
          }
          return CupertinoPage(
            key: state.pageKey,
            child: GroupQrCodePage(group: group),
          );
        },
      ),
      GoRoute(
        path: '/qrcode/channel',
        name: 'qrcode_channel',
        pageBuilder: (context, state) {
          // 从 state.extra 获取频道数据
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null) {
            return CupertinoPage(
              key: state.pageKey,
              child: Scaffold(
                body: Center(child: Text('Channel data not found')),
              ),
            );
          }
          return CupertinoPage(
            key: state.pageKey,
            child: ChannelQrCodePage(channelData: extra),
          );
        },
      ),

      // ==================== 个人信息相关 ====================
      GoRoute(
        path: '/personal_info',
        name: 'personal_info',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const PersonalInfoPage()),
        routes: [
          GoRoute(
            path: '/set_nickname',
            name: 'set_nickname',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: const SetNicknamePage(),
            ),
          ),
          GoRoute(
            path: '/set_gender',
            name: 'set_gender',
            pageBuilder: (context, state) =>
                CupertinoPage(key: state.pageKey, child: const SetGenderPage()),
          ),
          GoRoute(
            path: '/set_region',
            name: 'set_region',
            pageBuilder: (context, state) {
              final title = state.uri.queryParameters['title'] ?? '';
              final currentValue =
                  state.uri.queryParameters['currentValue'] ?? '';

              return CupertinoPage(
                key: state.pageKey,
                child: SetRegionPage(
                  title: title.isNotEmpty ? title : t.common.setRegion,
                  currentValue: currentValue,
                  onSave: (val) =>
                      UserProfileService.updateField('region', val),
                ),
              );
            },
          ),
          GoRoute(
            path: '/update',
            name: 'update',
            pageBuilder: (context, state) {
              final title = state.uri.queryParameters['title'] ?? '';
              final value = state.uri.queryParameters['value'] ?? '';
              final field = state.uri.queryParameters['field'] ?? 'input';
              // 目标后端字段名（如 sign/profession/school），与 [field]
              // （UpdatePage 的控件类型 input/text/gender）是两个不同概念。
              final apiField = state.uri.queryParameters['apiField'] ?? '';
              final maxLength =
                  int.tryParse(
                    state.uri.queryParameters['maxLength'] ?? '56',
                  ) ??
                  56;

              return CupertinoPage(
                key: state.pageKey,
                child: UpdatePage(
                  title: title.isNotEmpty ? title : '',
                  value: value,
                  field: field,
                  maxLength: maxLength,
                  callback: apiField.isEmpty
                      ? (val) async => false
                      : (val) => UserProfileService.updateField(apiField, val),
                ),
              );
            },
          ),
          GoRoute(
            path: '/more',
            name: 'more',
            pageBuilder: (context, state) =>
                CupertinoPage(key: state.pageKey, child: const MorePage()),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (context, state) =>
                CupertinoPage(key: state.pageKey, child: const ProfilePage()),
          ),
          GoRoute(
            path: '/privacy_settings',
            name: 'privacy_settings',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: const PrivacySettingsPage(),
            ),
          ),
        ],
      ),

      // ==================== 搜索相关 ====================
      GoRoute(
        path: '/search_chat',
        name: 'search_chat',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CupertinoPage(
            key: state.pageKey,
            child: SearchChatPage(
              conversationUk3: extra['conversationUk3']?.toString() ?? '',
              type: extra['type']?.toString() ?? 'C2C',
              peerId: extra['peerId']?.toString() ?? '',
              peerTitle: extra['peerTitle']?.toString() ?? '',
              peerAvatar: extra['peerAvatar']?.toString() ?? '',
              peerSign: extra['peerSign']?.toString() ?? '',
            ),
          );
        },
      ),

      // 消息搜索页面
      GoRoute(
        path: '/message_search',
        name: 'message_search',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CupertinoPage(
            key: state.pageKey,
            child: MessageSearchPage(
              conversationUk3: extra?['conversationUk3']?.toString(),
              conversationTitle: extra?['conversationTitle']?.toString(),
              conversationType: extra?['conversationType']?.toString(),
              peerId: extra?['peerId']?.toString(),
              peerAvatar: extra?['peerAvatar']?.toString(),
            ),
          );
        },
      ),

      // Web 端全局搜索
      GoRoute(
        path: '/web_search',
        name: 'web_search',
        pageBuilder: (context, state) {
          final query = state.uri.queryParameters['q'];
          final scope = state.uri.queryParameters['scope'];
          return CupertinoPage(
            key: state.pageKey,
            child: WebSearchPage(initialQuery: query, scope: scope),
          );
        },
      ),

      // 群功能增强路由
      ...groupFeatureRoutes(),

      // ==================== @提及 ====================
      GoRoute(
        path: '/mention',
        name: 'mention_list',
        pageBuilder: (context, state) {
          final groupId = state.uri.queryParameters['groupId'];
          return CupertinoPage(
            key: state.pageKey,
            child: MentionListPage(groupId: groupId),
          );
        },
      ),

      // ==================== 用户信息相关 ====================
      GoRoute(
        path: '/people_info/:id',
        name: 'people_info_top',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final scene = state.uri.queryParameters['scene'] ?? 'contact_page';
          return CupertinoPage(
            key: state.pageKey,
            child: PeopleInfoPage(id: id, scene: scene),
          );
        },
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.iosRed),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              // fontSize 20 最近档位 extraLarge(20)
              style: context.textStyle(FontSizeType.extraLarge),
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.path,
              style: TextStyle(
                fontSize: FontSizeType.normal.size,
                color: AppColors.iosGray,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.initial),
              child: Text(t.common.buttonBackHome),
            ),
          ],
        ),
      ),
    ),
  );
}
