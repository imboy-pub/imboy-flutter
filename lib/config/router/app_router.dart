import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:feedback/feedback.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/app_core/routing/route_feature_guard.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';

// ============================================================================
// 页面 Barrel exports - 统一导入所有页面
// ============================================================================
import 'barrel/pages_barrel.dart';

// 组件
import 'package:imboy/component/location/widget.dart';

// 数据模型
import 'package:imboy/store/model/feedback_model.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/live_room_model.dart';

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

/// GoRouter 路由配置
///
/// 此配置文件已添加路由守卫，实现自动登录检查
///
/// 路由规范：
/// - 使用 RESTful 风格的路径命名
/// - 参数通过 GoRoute 的 path 参数或 state.extra 传递
/// - 所有路由必须有清晰的 name 用于程序化导航
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: AppRoutes.initial,
    debugLogDiagnostics: kDebugMode, // 仅开发环境开启路由日志
    // 路由重定向（认证守卫）
    redirect: (context, state) {
      final isLogin = UserRepoLocal.to.isLoggedIn;
      final currentPath = state.matchedLocation;

      if (_isPublicPath(currentPath)) {
        return null;
      }

      if (!isLogin) {
        Future.delayed(const Duration(seconds: 1), () {
          if (context.mounted) {
            final t = context.t;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t.loginExpiredMessage),
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
        RouteFeatureGuard.notifyBlocked(
          context,
          (reason: blocked.reason, name: blocked.name),
        );
        return blocked.redirect;
      }

      return null;
    },

    routes: [
      // ==================== 认证和启动页面 ====================
      GoRoute(
        path: AppRoutes.initial,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        name: 'sign_in',
        builder: (context, state) {
          // Web 平台且宽屏使用 WebLoginPage
          if (kIsWeb) {
            return const WebLoginPage();
          }
          return const LoginPage();
        },
      ),
      GoRoute(
        path: AppRoutes.signUp,
        name: 'sign_up',
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: '/sign_up/continue',
        name: 'sign_up_continue',
        builder: (context, state) => const SignupContinuePage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgot_password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/set_password',
        name: 'set_password',
        builder: (context, state) => SetPasswordPage(),
      ),
      GoRoute(
        path: '/manage_account',
        name: 'manage_account',
        builder: (context, state) => const ManageAccountPage(),
      ),

      // ==================== 主框架 ====================
      GoRoute(
        path: '/bottom_navigation',
        name: 'bottom_navigation',
        builder: (context, state) => const BottomNavigationPage(),
      ),
      // Web Shell 三栏壳（Phase 1.1.h.1+i）— Web 登录成功后跳转的入口
      // 内部按响应式断点决定：< 900px → 回退 BottomNavigationPage，>= 900px → 三栏
      // 深链支持：/web_shell?tab=chat&id=xxx&type=C2C 由 1.1.m parseShellRouteParams 解析
      GoRoute(
        path: '/web_shell',
        name: 'web_shell',
        builder: (context, state) => const WebShellBootstrap(),
      ),

      // ==================== 会话列表 ====================
      GoRoute(
        path: '/conversation',
        name: 'conversation',
        builder: (context, state) => ConversationPage(),
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
            child: SendToPage(msg: extra?['msg']),
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
      // 新路由（使用 Riverpod 版本的 ChatPageRiverpod）
      // 示例：/chat_riverpod/user123?type=C2C&title=测试&avatar=xxx
      GoRoute(
        path: '/chat_riverpod/:peerId',
        name: 'chat_riverpod',
        pageBuilder: (context, state) {
          final peerId = state.pathParameters['peerId'] ?? '';
          final type = state.uri.queryParameters['type'] ?? 'C2C';
          final msgId = state.uri.queryParameters['msg_id'] ?? '';
          final title = state.uri.queryParameters['title'] ?? '';
          final avatar = state.uri.queryParameters['avatar'] ?? '';
          final sign = state.uri.queryParameters['sign'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: ChatPage(
              peerId: peerId,
              type: type,
              peerTitle: title,
              peerAvatar: avatar,
              peerSign: sign,
              msgId: msgId,
            ),
          );
        },
      ),

      // ==================== 联系人相关 ====================
      GoRoute(
        path: '/contact',
        name: 'contact',
        builder: (context, state) => const ContactPage(),
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

      // ==================== 群组相关 ====================
      GoRoute(
        path: '/group',
        name: 'group',
        builder: (context, state) => const GroupListPage(),
        routes: [
          GoRoute(
            path: '/list',
            name: 'group_list',
            builder: (context, state) => const GroupListPage(),
          ),
          GoRoute(
            path: '/detail/:groupId',
            name: 'group_detail',
            pageBuilder: (context, state) {
              final groupId = state.pathParameters['groupId']!;
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CupertinoPage(
                key: state.pageKey,
                child: GroupDetailPage(
                  groupId: groupId,
                  title: extra['title']?.toString() ?? '',
                  memberCount:
                      int.tryParse(extra['memberCount']?.toString() ?? '0') ??
                      0,
                  options: extra['options'] as Map<String, dynamic>?,
                ),
              );
            },
          ),
          GoRoute(
            path: '/member',
            name: 'group_member',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CupertinoPage(
                key: state.pageKey,
                child: GroupMemberPage(
                  groupId: extra['groupId']?.toString() ?? '',
                ),
              );
            },
          ),
          GoRoute(
            path: '/member_detail',
            name: 'group_member_detail',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CupertinoPage(
                key: state.pageKey,
                child: GroupMemberDetailPage(
                  groupId: extra['groupId']?.toString() ?? '',
                  userId: extra['userId']?.toString() ?? '',
                ),
              );
            },
          ),
          GoRoute(
            path: '/add_member',
            name: 'group_add_member',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CupertinoPage(
                key: state.pageKey,
                child: AddMemberPage(
                  groupId: extra['groupId']?.toString() ?? '',
                ),
              );
            },
          ),
          GoRoute(
            path: '/remove_member',
            name: 'group_remove_member',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CupertinoPage(
                key: state.pageKey,
                child: RemoveMemberPage(
                  groupId: extra['groupId']?.toString() ?? '',
                ),
              );
            },
          ),
          GoRoute(
            path: '/announcement',
            name: 'group_announcement',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CupertinoPage(
                key: state.pageKey,
                child: GroupAnnouncementPage(
                  groupId: extra['groupId']?.toString() ?? '',
                ),
              );
            },
          ),
          GoRoute(
            path: '/launch_chat',
            name: 'group_launch_chat',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: const LaunchChatPage(),
            ),
          ),
          GoRoute(
            path: '/select',
            name: 'group_select',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: const GroupSelectPage(),
            ),
          ),
          GoRoute(
            path: '/face_to_face',
            name: 'face_to_face',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: const FaceToFacePage(),
            ),
          ),
          GoRoute(
            path: '/face_to_face_confirm',
            name: 'face_to_face_confirm',
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final code = extra?['code']?.toString() ?? '';
              final gid = extra?['gid']?.toString() ?? '';
              final memberList = extra?['memberList'] as List<dynamic>? ?? [];
              return CupertinoPage(
                key: state.pageKey,
                child: FaceToFaceConfirmPage(
                  gid: gid,
                  code: code,
                  memberList: memberList.cast(),
                ),
              );
            },
          ),
        ],
      ),

      // ==================== 频道相关 ====================
      GoRoute(
        path: '/channel',
        name: 'channel_list',
        builder: (context, state) => const ChannelListPage(),
        routes: [
          // 具体路径必须放在动态参数路由之前，否则 /discover 会被当作 channelId
          GoRoute(
            path: '/discover',
            name: 'channel_discover',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: const ChannelDiscoverPage(),
            ),
          ),
          GoRoute(
            path: '/create',
            name: 'channel_create',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: const ChannelCreatePage(),
            ),
          ),
          GoRoute(
            path: '/invitations',
            name: 'channel_invitations',
            pageBuilder: (context, state) => CupertinoPage(
              key: state.pageKey,
              child: const ChannelInvitationPage(),
            ),
          ),
          GoRoute(
            path: '/:channelId',
            name: 'channel_detail',
            pageBuilder: (context, state) {
              final channelId = state.pathParameters['channelId']!;
              return CupertinoPage(
                key: state.pageKey,
                child: ChannelDetailPage(channelId: channelId),
              );
            },
            routes: [
              GoRoute(
                path: '/edit',
                name: 'channel_edit',
                pageBuilder: (context, state) {
                  final channelId = state.pathParameters['channelId']!;
                  final extra = state.extra;
                  return CupertinoPage(
                    key: state.pageKey,
                    child: ChannelEditPage(
                      channelId: channelId,
                      channel: extra is ChannelModel ? extra : null,
                    ),
                  );
                },
              ),
              GoRoute(
                path: '/admins',
                name: 'channel_admins',
                pageBuilder: (context, state) {
                  final channelId = state.pathParameters['channelId']!;
                  return CupertinoPage(
                    key: state.pageKey,
                    child: ChannelAdminPage(channelId: channelId),
                  );
                },
              ),
              GoRoute(
                path: '/subscribers',
                name: 'channel_subscribers',
                pageBuilder: (context, state) {
                  final channelId = state.pathParameters['channelId']!;
                  final extra = state.extra as Map<String, dynamic>?;
                  final canInvite = extra?['canInvite'] as bool? ?? false;
                  return CupertinoPage(
                    key: state.pageKey,
                    child: ChannelSubscriberPage(
                      channelId: channelId,
                      canInvite: canInvite,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),

      // ==================== 个人中心相关 ====================
      GoRoute(
        path: AppRoutes.mine,
        name: 'mine',
        builder: (context, state) => const MinePage(),
      ),
      GoRoute(
        path: '/mine/setting',
        name: 'mine_setting',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const SettingPage()),
      ),
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const WalletPage()),
      ),
      GoRoute(
        path: '/favorites',
        name: 'favorites',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const UserCollectPage()),
      ),
      GoRoute(
        path: '/denylist',
        name: 'denylist',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: DenylistPage()),
      ),
      GoRoute(
        path: '/storage_space',
        name: 'storage_space',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: StorageSpacePage()),
      ),
      GoRoute(
        path: '/devices',
        name: 'devices',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const UserDevicePage()),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: SettingPage()),
      ),
      GoRoute(
        path: '/account_security',
        name: 'account_security',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const AccountSecurityPage(),
        ),
      ),
      GoRoute(
        path: '/language',
        name: 'language',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const LanguagePage()),
      ),
      GoRoute(
        path: '/dark_model',
        name: 'dark_model',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const DarkModelPage()),
      ),
      GoRoute(
        path: '/font_size',
        name: 'font_size',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const FontSizePage()),
      ),
      GoRoute(
        path: '/logout_account',
        name: 'logout_account',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const LogoutAccountPage()),
      ),
      GoRoute(
        path: '/e2ee_key_recovery',
        name: 'e2ee_key_recovery',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const E2EEKeyRecoveryPage(),
        ),
      ),
      GoRoute(
        path: '/e2ee_transfer',
        name: 'e2ee_transfer',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const E2EETransferPage()),
      ),
      GoRoute(
        path: '/e2ee_social',
        name: 'e2ee_social',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const E2EESocialPage()),
      ),
      GoRoute(
        path: '/e2ee_social_create',
        name: 'e2ee_social_create',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const E2EESocialCreatePage(),
        ),
      ),
      GoRoute(
        path: '/e2ee_social_recover',
        name: 'e2ee_social_recover',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const E2EESocialRecoverPage(),
        ),
      ),
      GoRoute(
        path: '/e2ee_social_manage',
        name: 'e2ee_social_manage',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const E2EESocialManagePage(),
        ),
      ),
      GoRoute(
        path: '/e2ee_proxy_selector',
        name: 'e2ee_proxy_selector',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final selectedUids = extra['selectedUids'] as List<String>? ?? [];
          final requiredCount = extra['requiredCount'] as int? ?? 3;
          return CupertinoPage(
            key: state.pageKey,
            child: E2EEProxySelectorPage(
              selectedUids: selectedUids,
              requiredCount: requiredCount,
            ),
          );
        },
      ),
      GoRoute(
        path: '/e2ee_backup_export',
        name: 'e2ee_backup_export',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const E2EEBackupExportPage(),
        ),
      ),
      GoRoute(
        path: '/e2ee_backup_import',
        name: 'e2ee_backup_import',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final initialFilePath = extra['initialFilePath'] as String?;
          return CupertinoPage(
            key: state.pageKey,
            child: E2EEBackupImportPage(initialFilePath: initialFilePath),
          );
        },
      ),
      GoRoute(
        path: '/e2ee_transfer_send',
        name: 'e2ee_transfer_send',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const E2EETransferSendPage(),
        ),
      ),
      GoRoute(
        path: '/e2ee_transfer_receive',
        name: 'e2ee_transfer_receive',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final sessionId = extra['sessionId'] as String?;
          return CupertinoPage(
            key: state.pageKey,
            child: E2EETransferReceivePage(sessionId: sessionId),
          );
        },
      ),
      GoRoute(
        path: '/change_password',
        name: 'change_password',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const ChangePasswordPage(),
        ),
      ),
      GoRoute(
        path: '/feedback',
        name: 'feedback',
        pageBuilder: (context, state) => CupertinoPage(
          key: state.pageKey,
          child: const BetterFeedback(
            mode: FeedbackMode.navigate,
            child: FeedbackPage(),
          ),
        ),
        routes: [
          GoRoute(
            path: '/detail/:feedbackId',
            name: 'feedback_detail',
            pageBuilder: (context, state) {
              // 从状态管理或其他方式获取 model 数据
              // 这里需要传递 FeedbackModel，可以通过 state.extra 或其他方式
              final extra = state.extra as Map<String, dynamic>?;
              final model = extra?['model'] as FeedbackModel?;
              if (model == null) {
                return CupertinoPage(
                  key: state.pageKey,
                  child: Scaffold(
                    body: Center(child: Text('Feedback model not found')),
                  ),
                );
              }
              return CupertinoPage(
                key: state.pageKey,
                child: FeedbackDetailPage(model: model),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/select_region',
        name: 'select_region',
        pageBuilder: (context, state) {
          // 从 state.extra 获取参数
          final extra = state.extra as Map<String, dynamic>?;
          final parent = extra?['parent']?.toString() ?? '';
          final children = extra?['children'] as List? ?? [];
          final callback =
              extra?['callback'] as Future<bool> Function(String, String)? ??
              (a, b) async => true;
          final outCallback =
              extra?['outCallback'] as Future<bool> Function(String)? ??
              (a) async => true;

          return CupertinoPage(
            key: state.pageKey,
            child: SelectRegionPage(
              parent: parent,
              children: children,
              callback: callback,
              outCallback: outCallback,
            ),
          );
        },
      ),

      // ==================== Single 页面 ====================
      GoRoute(
        path: '/markdown',
        name: 'markdown',
        pageBuilder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? '';
          final url = state.uri.queryParameters['url'] ?? '';
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
          final url = state.uri.queryParameters['url'] ?? '';
          final thumb = state.uri.queryParameters['thumb'] ?? '';
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
          final downLoadUrl = state.uri.queryParameters['downLoadUrl'] ?? '';
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
        builder: (context, state) => const LiveRoomListPage(),
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
          // 从 state.extra 获取 GroupModel
          final extra = state.extra;
          if (extra == null) {
            return CupertinoPage(
              key: state.pageKey,
              child: Scaffold(
                body: Center(child: Text('Group data not found')),
              ),
            );
          }
          return CupertinoPage(
            key: state.pageKey,
            child: GroupQrCodePage(group: extra as dynamic),
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
                  title: title.isNotEmpty ? title : t.setRegion,
                  currentValue: currentValue,
                  onSave: (val) async => true,
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
                  callback: (val) async => true,
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

      // ==================== 群功能增强 ====================
      // 群分组
      GoRoute(
        path: '/group/category',
        name: 'group_category',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const GroupCategoryPage()),
      ),
      // 群标签
      GoRoute(
        path: '/group/:groupId/tag',
        name: 'group_tag',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['groupId'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: GroupTagPage(groupId: groupId),
          );
        },
      ),
      // 群文件
      GoRoute(
        path: '/group/:groupId/file',
        name: 'group_file',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['groupId'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: GroupFilePage(groupId: groupId),
          );
        },
      ),
      // 群相册
      GoRoute(
        path: '/group/:groupId/album',
        name: 'group_album',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['groupId'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: GroupAlbumPage(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: '/group/:groupId/album/:albumId/photos',
        name: 'group_album_photos',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['groupId'] ?? '';
          final albumId = state.pathParameters['albumId'] ?? '';
          final albumName = state.uri.queryParameters['album_name'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: GroupAlbumPhotoPage(
              groupId: groupId,
              albumId: albumId,
              albumName: albumName,
            ),
          );
        },
      ),
      GoRoute(
        path: '/group/:groupId/album/:albumId/photo/:photoId',
        name: 'group_album_photo_detail',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['groupId'] ?? '';
          final albumId = state.pathParameters['albumId'] ?? '';
          final photoId = state.pathParameters['photoId'] ?? '';
          final albumName = state.uri.queryParameters['album_name'] ?? '';
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final rawPhotoIds = extra['photo_ids'];
          final photoIds = rawPhotoIds is List
              ? rawPhotoIds
                    .where((item) => item != null)
                    .map((item) => item.toString().trim())
                    .where((id) => id.isNotEmpty)
                    .toList()
              : const <String>[];
          final rawIndex = extra['index'];
          final initialIndex = rawIndex is int
              ? rawIndex
              : int.tryParse(rawIndex?.toString() ?? '') ?? 0;
          return CupertinoPage(
            key: state.pageKey,
            child: GroupAlbumPhotoDetailPage(
              groupId: groupId,
              albumId: albumId,
              photoId: photoId,
              albumName: albumName,
              photoIds: photoIds,
              initialIndex: initialIndex,
            ),
          );
        },
      ),
      // 群投票
      GoRoute(
        path: '/group/:groupId/vote',
        name: 'group_vote',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['groupId'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: GroupVotePage(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: '/group/:groupId/vote/:voteId',
        name: 'group_vote_detail',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['groupId'] ?? '';
          final voteId = state.pathParameters['voteId'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: GroupVoteDetailPage(groupId: groupId, voteId: voteId),
          );
        },
      ),
      // 群日程
      GoRoute(
        path: '/group/:groupId/schedule',
        name: 'group_schedule',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['groupId'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: GroupSchedulePage(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: '/group/:groupId/schedule/:scheduleId',
        name: 'group_schedule_detail',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['groupId'] ?? '';
          final scheduleId = state.pathParameters['scheduleId'] ?? '';
          if (scheduleId.isEmpty) {
            return CupertinoPage(
              key: state.pageKey,
              child: const Scaffold(
                body: Center(child: Text('Invalid schedule id')),
              ),
            );
          }
          return CupertinoPage(
            key: state.pageKey,
            child: GroupScheduleDetailPage(
              groupId: groupId,
              scheduleId: scheduleId,
            ),
          );
        },
      ),
      // 群作业
      GoRoute(
        path: '/group/:groupId/task',
        name: 'group_task',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['groupId'] ?? '';
          return CupertinoPage(
            key: state.pageKey,
            child: GroupTaskPage(groupId: groupId),
          );
        },
      ),
      GoRoute(
        path: '/group/:groupId/task/:taskId',
        name: 'group_task_detail',
        pageBuilder: (context, state) {
          final groupId = state.pathParameters['groupId'] ?? '';
          final taskId = state.pathParameters['taskId'] ?? '';
          if (taskId.isEmpty) {
            return CupertinoPage(
              key: state.pageKey,
              child: const Scaffold(
                body: Center(child: Text('Invalid task id')),
              ),
            );
          }
          return CupertinoPage(
            key: state.pageKey,
            child: GroupTaskDetailPage(groupId: groupId, taskId: taskId),
          );
        },
      ),

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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Page not found', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              state.uri.path,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.initial),
              child: Text(t.buttonBackHome),
            ),
          ],
        ),
      ),
    ),
  );
});
