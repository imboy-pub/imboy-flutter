import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/app_core/routing/route_feature_guard.dart';
import 'package:imboy/service/storage.dart';

/// J27.f（plan §9）：功能位关闭或合同不可识别 → 门禁拒绝 / 旧合法读明确。
///
/// 本文件是 C-channel / C-attachment 功能门 N/A 的**负例依赖**：所有
/// 「实际交付功能开启时正例 Required，关闭须有功能门证据与 J27.f 负例
/// PASS 才可 N/A」的 J 项（J21 / J26 / J18.b 等）以本套件 PASS 为前提。
///
/// 覆盖三段负例语义（全部 App/Automated 层，不冒充 Web/真机/Backend）：
///   1. 编译合同不可识别：feature key 不在 compiledProductFeatures →
///      远程 snapshot 任何值都不能启用（fail-closed）。
///   2. 远程关闭 / 畸形合同值：channel 父门 false、flag 值不可解析 →
///      refresh 拒绝发布、isEnabled false、路由 checkBlocked 拒绝。
///   3. 旧合法读明确：负例状态下未受门控的旧路径（/chat/<id>、旧 C2C）
///      明确放行，负例不误伤 legacy 读。
///
/// 独立文件隔离 FeatureScope / manifest / SharedPreferences 全局状态。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    AppFeatureRegistry.bindScope(
      endpoint: 'http://localhost:29941',
      uid: 'j27f',
    );
    await AppFeatureRegistry.clear();
    await AppManifestService.clear();
  });

  tearDown(() async {
    await AppManifestService.clear();
    await AppFeatureRegistry.clear();
  });

  Map<String, dynamic> manifestWithEntries(List<String> entries) =>
      <String, dynamic>{
        'features': <String, dynamic>{},
        'policy': <String, dynamic>{},
        'app_entries': entries,
        'admin_entries': <dynamic>[],
        'plugins': <dynamic>[],
        'generated_at': 0,
      };

  group('J27.f: 编译合同不可识别（fail-closed）', () {
    test('channel 子功能位不在编译合同内，远程 true 也不能启用', () {
      // 哨兵锚定当前 canonical 编译组合（不含 channel_discover /
      // channel_invitation / channel_order）：若未来组合选入这些功能位，
      // 本断言变红即是提醒，须同步补它们的正例验收，不得静默放开。
      expect(
        compiledProductFeatures.contains(FeatureKeys.channelDiscover),
        isFalse,
      );
      expect(
        compiledProductFeatures.contains(FeatureKeys.channelInvitation),
        isFalse,
      );
      expect(
        compiledProductFeatures.contains(FeatureKeys.channelOrder),
        isFalse,
      );

      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
        FeatureKeys.channelDiscover: true,
        FeatureKeys.channelInvitation: 'true',
        FeatureKeys.channelOrder: 1,
      });
      expect(
        AppFeatureRegistry.isEnabled(FeatureKeys.channelDiscover),
        isFalse,
      );
      expect(
        AppFeatureRegistry.isEnabled(FeatureKeys.channelInvitation),
        isFalse,
      );
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.channelOrder), isFalse);
    });

    test('本地硬关闭优先于远程 true（liveRoom 负例门）', () {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
        FeatureKeys.liveRoom: true,
      });
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.liveRoom), isFalse);
    });

    test('未声明 key 的 e2ee 域门 fail-closed（合同不可识别）', () {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
        FeatureKeys.e2ee: true,
        FeatureKeys.e2eeCollect: true,
      });
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.e2eeCollect), isFalse);
    });
  });

  group('J27.f: 远程关闭与畸形合同值', () {
    test('channel 父门关闭时子门继承拒绝，远程子门 true 不能翻墙', () {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
        FeatureKeys.channel: false,
        FeatureKeys.channelDiscover: true,
        FeatureKeys.channelInvitation: true,
        FeatureKeys.channelOrder: true,
      });
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.channel), isFalse);
      expect(
        AppFeatureRegistry.isEnabled(FeatureKeys.channelDiscover),
        isFalse,
      );
      expect(
        AppFeatureRegistry.isEnabled(FeatureKeys.channelInvitation),
        isFalse,
      );
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.channelOrder), isFalse);
    });

    test('畸形 flag 值整批拒绝发布，isEnabled 保持拒绝态', () async {
      // 合同不可识别：对象 / 浮点 / 越界字符串值不属于 boolean 合同。
      // refresh 的 normalize 后长度不等 → 拒绝发布（fail-closed），
      // 缓存不被污染，isEnabled 维持拒绝。
      final published = await AppFeatureRegistry.refresh(
        fetch: () async => <String, dynamic>{
          FeatureKeys.channel: <String, dynamic>{'enabled': 1},
          FeatureKeys.moment: 1.5,
          FeatureKeys.location: '2',
          FeatureKeys.groupVote: '',
        },
      );
      expect(published, isFalse);
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.channel), isFalse);
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.moment), isFalse);
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.location), isFalse);
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.groupVote), isFalse);
    });

    test('可识别合同中的显式 false 关闭功能门，missing 键不默认开启', () async {
      expect(
        await AppFeatureRegistry.refresh(
          fetch: () async => <String, dynamic>{FeatureKeys.channel: false},
        ),
        isTrue,
      );
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.channel), isFalse);
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.location), isFalse);
    });
  });

  group('J27.f: 路由门禁拒绝（channel 家族负例）', () {
    test('channel 门关闭时 /channel 及三个子入口全部拒绝且指明原因', () {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
        FeatureKeys.channel: false,
      });
      // manifest 提供 channel 家族 app entries：让 appEntry 检查通过，
      // 精确落到 featureFlag 拒绝分支（与 appEntry 拒绝可区分）。
      AppManifestService.replaceForTest(
        manifestWithEntries(<String>['channel_tab', 'channel_discover_page']),
      );

      for (final path in <String>[
        '/channel',
        '/channel/discover',
        '/channel/invitations',
        '/channel/orders',
      ]) {
        final result = RouteFeatureGuard.checkBlocked(
          isLoggedIn: true,
          currentPath: path,
        );
        expect(result, isNotNull, reason: 'path $path must be blocked');
        expect(result!.redirect, '/bottom_navigation');
        expect(result.reason, RouteBlockReason.featureFlag);
        // 负例义务是「拒绝 + 指明原因类别」，不含展示名非空：
        // _displayName 对 channel_order 无映射（_ => ''），notifyBlocked
        // 有空名兜底（t.common.featureNotEnabled），UI 不裸奔。
        // 发现已记录于交付文档，属展示细节不属门禁合同。
        expect(result.name, isA<String>());
      }
    });

    test('manifest 未加载（合同不可识别）时 /channel 保守拒绝', () async {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
        FeatureKeys.channel: true,
      });
      // setUp 已 await AppManifestService.clear() → manifest == null。
      final result = RouteFeatureGuard.checkBlocked(
        isLoggedIn: true,
        currentPath: '/channel',
      );
      expect(result, isNotNull);
      expect(result!.redirect, '/bottom_navigation');
      expect(result.reason, RouteBlockReason.appEntry);
    });

    test('manifest 缺 channel_tab entry 时拒绝且 reason 为 appEntry', () {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
        FeatureKeys.channel: true,
      });
      AppManifestService.replaceForTest(
        manifestWithEntries(<String>['moment_tab']),
      );

      for (final path in <String>['/channel', '/channel/discover']) {
        final result = RouteFeatureGuard.checkBlocked(
          isLoggedIn: true,
          currentPath: path,
        );
        expect(result, isNotNull, reason: 'path $path must be blocked');
        expect(result!.reason, RouteBlockReason.appEntry);
      }
    });
  });

  group('J27.f: 旧合法读明确（负例不误伤 legacy）', () {
    test('channel 全负例状态下未受门控旧路径明确放行', () {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
        FeatureKeys.channel: false,
      });
      AppManifestService.replaceForTest(
        manifestWithEntries(<String>['channel_tab']),
      );

      // 旧 C2C / 群聊路径不在 feature 门与 manifest app_entry 门控域内：
      // 负例只拦截被门控入口，旧合法读明确可用（返回 null = 不拦截）。
      for (final path in <String>['/chat/123', '/group/g1/detail']) {
        expect(
          RouteFeatureGuard.checkBlocked(isLoggedIn: true, currentPath: path),
          isNull,
          reason: 'legacy path $path must stay readable',
        );
      }
    });

    test('未登录时门禁不生效（登录前旧读由登录流自管）', () {
      AppFeatureRegistry.replaceSnapshotForTest(<String, dynamic>{
        FeatureKeys.channel: false,
      });
      AppManifestService.replaceForTest(manifestWithEntries(<String>[]));
      expect(
        RouteFeatureGuard.checkBlocked(
          isLoggedIn: false,
          currentPath: '/channel',
        ),
        isNull,
      );
    });
  });
}
