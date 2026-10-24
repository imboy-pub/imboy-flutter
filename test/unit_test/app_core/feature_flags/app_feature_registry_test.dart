import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/routing/route_feature_guard.dart';
import 'package:imboy/config/routes.dart';

void main() {
  test('normalizes supported feature flag payload values', () {
    final normalized = AppFeatureRegistry.normalizeFlags({
      FeatureKeys.channel: true,
      FeatureKeys.channelDiscover: 1,
      FeatureKeys.channelInvitation: 'off',
      FeatureKeys.channelOrder: 'YES',
      'ignored': {'enabled': true},
    });

    expect(normalized, {
      FeatureKeys.channel: true,
      FeatureKeys.channelDiscover: true,
      FeatureKeys.channelInvitation: false,
      FeatureKeys.channelOrder: true,
    });
  });

  test('inherits parent feature state for child features', () {
    AppFeatureRegistry.replaceSnapshotForTest({
      FeatureKeys.channel: false,
      FeatureKeys.channelDiscover: true,
    });

    expect(AppFeatureRegistry.isEnabled(FeatureKeys.channelDiscover), isFalse);
  });

  test('server cannot enable a feature absent from the compiled build', () {
    AppFeatureRegistry.replaceSnapshotForTest({'not_compiled': true});
    expect(AppFeatureRegistry.isEnabled('not_compiled'), isFalse);
  });

  test('server cannot enable a locally disabled feature', () {
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.liveRoom: true});
    expect(AppFeatureRegistry.isEnabled(FeatureKeys.liveRoom), isFalse);
  });

  // E2EE 收藏能力门（PLAN 2026-10-24-e2ee-collect §9/A7）：门查 e2ee 域键
  // （与服务端 enabled(e2ee_collect) -> enabled(e2ee) 同构）。本哨兵锚定
  // 当前 canonical 组合（phase1_delivery 未选 e2ee 域）——若组合选入 e2ee，
  // 此测试变红即是提醒：收藏门随组合打开，A7 正向场景须同步验证。
  test('e2ee collect gate is composition-coupled (A7 fail-closed)', () {
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.e2ee: true});
    expect(AppFeatureRegistry.isEnabled(FeatureKeys.e2ee), isFalse);
  });

  test('maps route paths to feature keys', () {
    expect(
      RouteFeatureGuard.featureForPath('/channel/discover'),
      FeatureKeys.channelDiscover,
    );
    expect(
      RouteFeatureGuard.featureForPath('${AppRoutes.momentRoot}/m1'),
      FeatureKeys.moment,
    );
    expect(
      RouteFeatureGuard.featureForPath('/group/g1/task/detail'),
      FeatureKeys.groupTask,
    );
    expect(RouteFeatureGuard.featureForPath('/chat/u1'), isNull);
  });

  test('returns bottom navigation redirect for disabled feature routes', () {
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.moment: false});

    expect(
      RouteFeatureGuard.redirectPath(
        isLoggedIn: true,
        currentPath: AppRoutes.momentFeed,
      ),
      '/bottom_navigation',
    );
  });
}
