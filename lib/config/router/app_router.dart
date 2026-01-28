import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    debugLogDiagnostics: true, // 开发环境开启路由日志
    // 路由重定向（认证守卫）
    redirect: (context, state) {
      final isLogin = UserRepoLocal.to.isLoggedIn;
      final currentPath = state.matchedLocation;

      // 免登录页面列表
      const publicPaths = [
        AppRoutes.initial,
        AppRoutes.signIn,
        AppRoutes.signUp,
        '/welcome',
        AppRoutes.forgotPassword,
      ];

      // 如果是免登录页面，直接放行
      if (publicPaths.any((path) => currentPath.startsWith(path))) {
        return null;
      }

      // 如果已登录，放行
      if (isLogin) {
        return null;
      }

      // 未登录且不是免登录页面，跳转到登录页
      // 显示登录过期提示
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
        builder: (context, state) => const LoginPage(),
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

      // ==================== 会话列表 ====================
      GoRoute(
        path: '/conversation',
        name: 'conversation',
        builder: (context, state) => ConversationPage(),
      ),

      // ==================== 聊天相关 ====================
      // 聊天页面路由
      GoRoute(
        path: '/chat/:peerId',
        name: 'chat',
        builder: (context, state) {
          final peerId = state.pathParameters['peerId'] ?? '';
          // 支持两种传参方式：queryParameters 和 extra
          final type = state.uri.queryParameters['type'] ?? 'C2C';
          final title = state.uri.queryParameters['title'] ?? '';
          final avatar = state.uri.queryParameters['avatar'] ?? '';
          final sign = state.uri.queryParameters['sign'] ?? '';
          final extra = state.extra as Map<String, dynamic>? ?? {};
          // extra 参数优先级更高
          return ChatPage(
            peerId: peerId,
            type: extra['type']?.toString() ?? type,
            peerTitle: extra['title']?.toString() ?? title,
            peerAvatar: extra['avatar']?.toString() ?? avatar,
            peerSign: extra['sign']?.toString() ?? sign,
            options: extra['options'] as Map<String, dynamic>?,
          );
        },
      ),
      // 聊天设置页
      GoRoute(
        path: '/chat_setting/:peerId',
        name: 'chat_setting',
        builder: (context, state) {
          final peerId = state.pathParameters['peerId'] ?? '';
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatSettingPage(
            peerId,
            type: extra['type']?.toString() ?? 'C2C',
            options: extra['options'] as Map<String, dynamic>?,
          );
        },
      ),
      // 转发消息页
      GoRoute(
        path: '/chat/send_to',
        name: 'send_to',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SendToPage(msg: extra?['msg']);
        },
      ),
      // 新路由（使用 Riverpod 版本的 ChatPageRiverpod）
      // 示例：/chat_riverpod/user123?type=C2C&title=测试&avatar=xxx
      GoRoute(
        path: '/chat_riverpod/:peerId',
        name: 'chat_riverpod',
        builder: (context, state) {
          final peerId = state.pathParameters['peerId'] ?? '';
          final type = state.uri.queryParameters['type'] ?? 'C2C';
          final title = state.uri.queryParameters['title'] ?? '';
          final avatar = state.uri.queryParameters['avatar'] ?? '';
          final sign = state.uri.queryParameters['sign'] ?? '';
          return ChatPage(
            peerId: peerId,
            type: type,
            peerTitle: title,
            peerAvatar: avatar,
            peerSign: sign,
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
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              final scene =
                  state.uri.queryParameters['scene'] ?? 'contact_page';
              return PeopleInfoPage(id: id, scene: scene);
            },
          ),
          GoRoute(
            path: '/new_friend',
            name: 'new_friend',
            builder: (context, state) => NewFriendPage(),
          ),
          GoRoute(
            path: '/add_friend',
            name: 'add_friend',
            builder: (context, state) => AddFriendPage(),
          ),
          GoRoute(
            path: '/people_nearby',
            name: 'people_nearby',
            builder: (context, state) => PeopleNearbyPage(),
          ),
          GoRoute(
            path: '/recently_registered_user',
            name: 'recently_registered_user',
            builder: (context, state) => RecentlyRegisteredUserPage(),
          ),
          GoRoute(
            path: '/people_info_more/:id',
            name: 'people_info_more',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return PeopleInfoMorePage(id: id);
            },
          ),
          GoRoute(
            path: '/tags',
            name: 'user_tag_list',
            builder: (context, state) => ContactTagListPage(),
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
            builder: (context, state) {
              final groupId = state.pathParameters['groupId']!;
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return GroupDetailPage(
                groupId: groupId,
                title: extra['title']?.toString() ?? '',
                memberCount:
                    int.tryParse(extra['memberCount']?.toString() ?? '0') ?? 0,
                options: extra['options'] as Map<String, dynamic>?,
              );
            },
          ),
          GoRoute(
            path: '/launch_chat',
            name: 'launch_chat',
            builder: (context, state) => const LaunchChatPage(),
          ),
          GoRoute(
            path: '/select',
            name: 'group_select',
            builder: (context, state) => const GroupSelectPage(),
          ),
          GoRoute(
            path: '/face_to_face',
            name: 'face_to_face',
            builder: (context, state) => const FaceToFacePage(),
          ),
          GoRoute(
            path: '/face_to_face_confirm',
            name: 'face_to_face_confirm',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final code = extra?['code']?.toString() ?? '';
              final gid = extra?['gid']?.toString() ?? '';
              final memberList = extra?['memberList'] as List<dynamic>? ?? [];
              return FaceToFaceConfirmPage(
                gid: gid,
                code: code,
                memberList: memberList.cast(),
              );
            },
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
        builder: (context, state) => const SettingPage(),
      ),
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (context, state) => const WalletPage(),
      ),
      GoRoute(
        path: '/favorites',
        name: 'favorites',
        builder: (context, state) => const UserCollectPage(),
      ),
      GoRoute(
        path: '/denylist',
        name: 'denylist',
        builder: (context, state) => DenylistPage(),
      ),
      GoRoute(
        path: '/storage_space',
        name: 'storage_space',
        builder: (context, state) => StorageSpacePage(),
      ),
      GoRoute(
        path: '/devices',
        name: 'devices',
        builder: (context, state) => const UserDevicePage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => SettingPage(),
      ),
      GoRoute(
        path: '/account_security',
        name: 'account_security',
        builder: (context, state) => const AccountSecurityPage(),
      ),
      GoRoute(
        path: '/language',
        name: 'language',
        builder: (context, state) => const LanguagePage(),
      ),
      GoRoute(
        path: '/dark_model',
        name: 'dark_model',
        builder: (context, state) => const DarkModelPage(),
      ),
      GoRoute(
        path: '/font_size',
        name: 'font_size',
        builder: (context, state) => const FontSizePage(),
      ),
      GoRoute(
        path: '/logout_account',
        name: 'logout_account',
        builder: (context, state) => const LogoutAccountPage(),
      ),
      GoRoute(
        path: '/change_password',
        name: 'change_password',
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: '/feedback',
        name: 'feedback',
        builder: (context, state) => const FeedbackPage(),
        routes: [
          GoRoute(
            path: '/detail/:feedbackId',
            name: 'feedback_detail',
            builder: (context, state) {
              // 从状态管理或其他方式获取 model 数据
              // 这里需要传递 FeedbackModel，可以通过 state.extra 或其他方式
              final extra = state.extra as Map<String, dynamic>?;
              final model = extra?['model'] as FeedbackModel?;
              if (model == null) {
                return Scaffold(
                  body: Center(child: Text('Feedback model not found')),
                );
              }
              return FeedbackDetailPage(model: model);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/select_region',
        name: 'select_region',
        builder: (context, state) {
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

          return SelectRegionPage(
            parent: parent,
            children: children,
            callback: callback,
            outCallback: outCallback,
          );
        },
      ),

      // ==================== Single 页面 ====================
      GoRoute(
        path: '/markdown',
        name: 'markdown',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? '';
          final url = state.uri.queryParameters['url'] ?? '';
          final selectable = state.uri.queryParameters['selectable'] == 'true';
          return MarkdownPage(title: title, url: url, selectable: selectable);
        },
      ),
      GoRoute(
        path: '/video_viewer',
        name: 'video_viewer',
        builder: (context, state) {
          final url = state.uri.queryParameters['url'] ?? '';
          final thumb = state.uri.queryParameters['thumb'] ?? '';
          return VideoViewerPage(url: url, thumb: thumb);
        },
      ),
      GoRoute(
        path: '/upgrade',
        name: 'upgrade',
        builder: (context, state) {
          final downLoadUrl = state.uri.queryParameters['downLoadUrl'] ?? '';
          final message = state.uri.queryParameters['message'] ?? '';
          final version = state.uri.queryParameters['version'] ?? '';
          final isForce = state.uri.queryParameters['isForce'] == 'true';
          return UpgradePage(
            downLoadUrl: downLoadUrl,
            message: message,
            version: version,
            isForce: isForce,
          );
        },
      ),
      GoRoute(
        path: '/network_failure_guidance',
        name: 'network_failure_guidance',
        builder: (context, state) => const NetworkFailureGuidancePage(),
      ),
      GoRoute(
        path: '/map_location_picker',
        name: 'map_location_picker',
        builder: (context, state) {
          // 从 state.extra 获取参数
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final lat = extra['lat'] as double? ?? 39.909187;
          final lng = extra['lng'] as double? ?? 116.397451;
          final citycode = extra['citycode']?.toString() ?? '';
          final isMapImage = extra['isMapImage'] as bool? ?? false;

          return MapLocationPicker(
            arguments: {
              'lat': lat,
              'lng': lng,
              'citycode': citycode,
              'isMapImage': isMapImage,
            },
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
            builder: (context, state) => const PublisherPage(),
          ),
          GoRoute(
            path: '/subscriber',
            name: 'live_room_subscriber',
            builder: (context, state) => const SubscriberPage(),
          ),
        ],
      ),

      // ==================== 二维码和扫描相关 ====================
      GoRoute(
        path: '/scanner',
        name: 'scanner',
        builder: (context, state) => const ScannerPage(),
      ),
      GoRoute(
        path: '/scanner/result',
        name: 'scanner_result',
        builder: (context, state) {
          final scanResult = state.uri.queryParameters['result'] ?? '';
          return ScannerResultPage(scanResult: scanResult);
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
        builder: (context, state) => UserQrCodePage(),
      ),
      GoRoute(
        path: '/qrcode/group',
        name: 'qrcode_group',
        builder: (context, state) {
          // 从 state.extra 获取 GroupModel
          final extra = state.extra;
          if (extra == null) {
            return Scaffold(body: Center(child: Text('Group data not found')));
          }
          return GroupQrCodePage(group: extra as dynamic);
        },
      ),

      // ==================== 个人信息相关 ====================
      GoRoute(
        path: '/personal_info',
        name: 'personal_info',
        builder: (context, state) => const PersonalInfoPage(),
        routes: [
          GoRoute(
            path: '/set_nickname',
            name: 'set_nickname',
            builder: (context, state) => const SetNicknamePage(),
          ),
          GoRoute(
            path: '/set_gender',
            name: 'set_gender',
            builder: (context, state) => const SetGenderPage(),
          ),
          GoRoute(
            path: '/set_region',
            name: 'set_region',
            builder: (context, state) {
              final title = state.uri.queryParameters['title'] ?? '';
              final currentValue =
                  state.uri.queryParameters['currentValue'] ?? '';

              return SetRegionPage(
                title: title.isNotEmpty ? title : t.setRegion,
                currentValue: currentValue,
                onSave: (val) async => true,
              );
            },
          ),
          GoRoute(
            path: '/update',
            name: 'update',
            builder: (context, state) {
              final title = state.uri.queryParameters['title'] ?? '';
              final value = state.uri.queryParameters['value'] ?? '';
              final field = state.uri.queryParameters['field'] ?? 'input';
              final maxLength =
                  int.tryParse(
                    state.uri.queryParameters['maxLength'] ?? '56',
                  ) ??
                  56;

              return UpdatePage(
                title: title.isNotEmpty ? title : '',
                value: value,
                field: field,
                maxLength: maxLength,
                callback: (val) async => true,
              );
            },
          ),
          GoRoute(
            path: '/more',
            name: 'more',
            builder: (context, state) => const MorePage(),
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/privacy_settings',
            name: 'privacy_settings',
            builder: (context, state) => const PrivacySettingsPage(),
          ),
        ],
      ),

      // ==================== 搜索相关 ====================
      GoRoute(
        path: '/search_chat',
        name: 'search_chat',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return SearchChatPage(
            conversationUk3: extra['conversationUk3']?.toString() ?? '',
            type: extra['type']?.toString() ?? 'C2C',
            peerId: extra['peerId']?.toString() ?? '',
            peerTitle: extra['peerTitle']?.toString() ?? '',
            peerAvatar: extra['peerAvatar']?.toString() ?? '',
            peerSign: extra['peerSign']?.toString() ?? '',
          );
        },
      ),

      // ==================== 用户信息相关 ====================
      GoRoute(
        path: '/people_info/:id',
        name: 'people_info_top',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final scene = state.uri.queryParameters['scene'] ?? 'contact_page';
          return PeopleInfoPage(id: id, scene: scene);
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
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
  );
});
