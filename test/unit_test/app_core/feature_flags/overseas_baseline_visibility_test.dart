import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/routing/route_feature_guard.dart';
import 'package:imboy/config/routes.dart';

/// L-01 overseas_baseline 三端可见性验收（Flutter 侧）。
///
/// 后端 overseas_baseline 预设（imboy_profile_preset:profile_defaults）下，
/// /api/v1/app/features 与 /api/v1/init 均下发 effective features：
/// 敏感键 false（location / channel_discover / channel_order / bot_webhook /
/// live_room / ai_marketplace），基线键 true（channel / moment / group_*）。
/// 验收口径：被禁功能在 direct route / deep link 层缺席，基线功能照常。
void main() {
  // 与后端 profile_defaults(overseas_baseline) 对齐的 effective snapshot。
  const overseasSnapshot = <String, bool>{
    FeatureKeys.channel: true,
    FeatureKeys.channelDiscover: false,
    FeatureKeys.channelInvitation: true,
    FeatureKeys.channelOrder: false,
    FeatureKeys.moment: true,
    FeatureKeys.location: false,
    FeatureKeys.groupVote: true,
    FeatureKeys.groupSchedule: true,
    FeatureKeys.groupTask: true,
    'bot_webhook': false,
  };

  // overseas_baseline 编译全集照旧、app_entries 齐全：manifest 层放行，
  // 使下方拦截断言精确落在 feature flag 层而非 manifest 保守拒绝层。
  const fullManifest = <String, dynamic>{
    'manifest_hash': 'sha256:test-overseas-baseline',
    'manifest_schema_version': 1,
    'compiled_features': [
      'channel',
      'channel_discover',
      'channel_invitation',
      'channel_order',
      'e2ee',
      'group_schedule',
      'group_task',
      'group_vote',
      'location',
      'moment',
      'bot_webhook',
    ],
    'features': <String, dynamic>{},
    'policy': <String, dynamic>{},
    'app_entries': [
      'moment_tab',
      'channel_tab',
      'channel_discover_page',
      'people_nearby_page',
      'group_vote_page',
      'group_schedule_page',
      'group_task_page',
    ],
    'admin_entries': <String>[],
    'plugins': <Map<String, dynamic>>[],
    'generated_at': 0,
  };

  setUp(() {
    AppManifestService.replaceForTest(fullManifest);
  });

  tearDown(() async {
    await AppManifestService.clear();
    AppFeatureRegistry.replaceSnapshotForTest(const {});
  });

  group('overseas_baseline effective features', () {
    test('sensitive features are off', () {
      AppFeatureRegistry.replaceSnapshotForTest(overseasSnapshot);

      expect(AppFeatureRegistry.isEnabled(FeatureKeys.location), isFalse);
      expect(
        AppFeatureRegistry.isEnabled(FeatureKeys.channelDiscover),
        isFalse,
      );
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.channelOrder), isFalse);
      expect(AppFeatureRegistry.isEnabled('bot_webhook'), isFalse);
    });

    test('baseline features stay on', () {
      AppFeatureRegistry.replaceSnapshotForTest(overseasSnapshot);

      expect(AppFeatureRegistry.isEnabled(FeatureKeys.channel), isTrue);
      expect(
        AppFeatureRegistry.isEnabled(FeatureKeys.channelInvitation),
        isTrue,
      );
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.moment), isTrue);
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.groupVote), isTrue);
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.groupSchedule), isTrue);
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.groupTask), isTrue);
    });

    test('live_room stays off via local kill switch', () {
      AppFeatureRegistry.replaceSnapshotForTest(overseasSnapshot);

      // live_room 本地硬关闭（_localDisabledKeys），与预设双保险。
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.liveRoom), isFalse);
    });
  });

  group('overseas_baseline route visibility', () {
    test('disabled feature deep links are redirected', () {
      AppFeatureRegistry.replaceSnapshotForTest(overseasSnapshot);

      const redirect = '/bottom_navigation';
      expect(
        RouteFeatureGuard.redirectPath(
          isLoggedIn: true,
          currentPath: '/contact/people_nearby',
        ),
        redirect,
      );
      expect(
        RouteFeatureGuard.redirectPath(
          isLoggedIn: true,
          currentPath: '/channel/discover',
        ),
        redirect,
      );
      // 付费频道订单列表与详情：featureForPath 必须映射到 channel_order
      // （而非父级 channel），否则预设关闭付费能力后 deep link 仍可达。
      expect(
        RouteFeatureGuard.redirectPath(
          isLoggedIn: true,
          currentPath: '/channel/orders',
        ),
        redirect,
      );
      expect(
        RouteFeatureGuard.redirectPath(
          isLoggedIn: true,
          currentPath: '/channel/order/00000001',
        ),
        redirect,
      );
    });

    test('baseline routes pass through', () {
      AppFeatureRegistry.replaceSnapshotForTest(overseasSnapshot);

      expect(
        RouteFeatureGuard.redirectPath(
          isLoggedIn: true,
          currentPath: '/channel',
        ),
        isNull,
      );
      expect(
        RouteFeatureGuard.redirectPath(
          isLoggedIn: true,
          currentPath: '/channel/invitations',
        ),
        isNull,
      );
      expect(
        RouteFeatureGuard.redirectPath(
          isLoggedIn: true,
          currentPath: AppRoutes.momentFeed,
        ),
        isNull,
      );
      expect(
        RouteFeatureGuard.redirectPath(
          isLoggedIn: true,
          currentPath: '/chat/u1',
        ),
        isNull,
      );
    });

    test('channel order routes map to channel_order feature key', () {
      expect(
        RouteFeatureGuard.featureForPath('/channel/orders'),
        FeatureKeys.channelOrder,
      );
      expect(
        RouteFeatureGuard.featureForPath('/channel/order/00000001'),
        FeatureKeys.channelOrder,
      );
    });
  });
}
