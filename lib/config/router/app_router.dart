import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:xid/xid.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/app_core/routing/route_feature_guard.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/service/geo_regions/geo_regions_host.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/service/user_profile_service.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_breakpoints.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:imboy/modules/enterprise_oa/presentation/oa_login_page.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';

import 'generated_product_feature_routes.dart';

// ============================================================================
// 页面 Barrel exports - 统一导入所有页面
// ============================================================================
import 'barrel/pages_barrel.dart';

// 数据模型
import 'package:imboy/store/model/live_room_model.dart';

// 分域路由
import 'routes/group_routes.dart';
import 'routes/talk_record_routes.dart';
import 'routes/mine_routes.dart';
import 'routes/group_feature_routes.dart';
import 'routes/workspace_routes.dart';

// 企业+客服纵切（app-amendment-001）：路由定义在 owned path 内，此处仅注册
import 'package:imboy/modules/enterprise/presentation/enterprise_routes.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_routes.dart';

// Organization V1（ORG-13）：路由定义在 owned path 内，此处仅注册（精确行租约）
import 'package:imboy/modules/organization/presentation/organization_routes.dart';

part 'app_router_pages.dart';

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
    '/oa/login',
    AppRoutes.forgotPassword,
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
    (host) => uri.host == host || uri.host.endsWith('.$host'), // nosemgrep: request-host-used — Dart 插值 $host 取自 Env 配置的可信域名白名单（apiBaseUrl/publicBaseUrl），非请求方可控输入
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

/// 空 bundle 提示一次性守卫（进程级）：go_router rebuild 会重跑
/// pageBuilder，同一 pageKey 只提示一次（W5-R2 复审 L-1，空页停留期
/// 防重复 toast）。仅空 bundle 路径写入，量级有界。
final Set<String> _emptyBundleToastKeys = <String>{};

/// 创建应用 GoRouter / Create the app GoRouter.
///
/// 生产环境用默认参数（initialLocation=/，全局 navigatorKey）。
/// 测试可注入 [initialLocation] 与独立 [navigatorKeyOverride]，
/// 以便对单条路由做「无 splash、无跨用例 GlobalKey 污染」的烟雾测试。
GoRouter createAppRouter({
  String initialLocation = AppRoutes.initial,
  GlobalKey<NavigatorState>? navigatorKeyOverride,
}) {
  String? pendingLocation;
  const loginLandings = {'/bottom_navigation', '/web_shell', '/chat_shell'};
  return GoRouter(
    refreshListenable: AppFeatureRegistry.revision,
    navigatorKey: navigatorKeyOverride ?? navigatorKey,
    initialLocation: initialLocation,
    // Callback locations contain one-time login proofs, including in debug builds.
    debugLogDiagnostics: false,
    // 路由重定向（认证守卫）
    redirect: (context, state) {
      final isLogin = UserRepoLocal.to.isLoggedIn;
      final currentPath = state.matchedLocation;

      if (_isPublicPath(currentPath)) {
        return null;
      }

      if (!isLogin) {
        final uri = state.uri;
        if (!uri.hasScheme &&
            !uri.hasAuthority &&
            uri.path.startsWith('/') &&
            !uri.path.startsWith('//') &&
            (!loginLandings.contains(currentPath) ||
                uri.hasQuery ||
                uri.hasFragment)) {
          pendingLocation = uri.toString();
        }
        Future<dynamic>.delayed(const Duration(seconds: 1), () {
          if (context.mounted) {
            final t = context.t;
            AppLoading.showToast(t.chat.loginExpiredMessage);
          }
        });

        return AppRoutes.signIn;
      }

      if (pendingLocation != null && loginLandings.contains(currentPath)) {
        final target = pendingLocation;
        pendingLocation =
            null; // Consume before the target re-enters normal guards.
        return target;
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

    routes: buildAppRoutes(),

    errorBuilder: appRouterErrorBuilder,
  );
}
