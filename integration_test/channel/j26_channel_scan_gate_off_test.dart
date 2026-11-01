// integration_test/channel/j26_channel_scan_gate_off_test.dart
//
// plan-v2.2 §9 J26.a/b/c（频道订阅扫描/失败恢复/退订重订）功能关闭态负例门
// 脚本（真合成部署只读验证，无业务写、无第三方影响）。
//
// C-channel 口径（§9）：J26.a–e 正例须实际交付功能开启后验收（Required）；
// 关闭态 N/A 的前提 = 功能门证据 + J27.f 负例 PASS。本脚本在真合成部署上
// 取「不误启」负例门证据：
//   ① 部署 manifest 未声明 list_contracts → listCursorGateEnabled=false
//      （能力门关闭，J26 逐页扫描机制的协议前提不成立）
//   ② 打开频道订阅列表（demo_alice，合成库订阅 0 行）→ provider 终态
//      cursor=null / hasMore=false（legacy envelope 无游标，扫描不可继续）
//   ③ 显式触发 loadMoreSubscribedChannels() → 状态不变、本地
//      channel_subscription 行数不变（扫描不误启、不伪造订阅关系）
//
// 单测层同源负例（已在仓内跑绿，本脚本为部署面补充证据）：
//   - test/unit_test/page/channel/channel_list_state_sync_test.dart
//     「J26.a/b/c: 清单合同未声明（功能关闭态）→ 扫描不误启…」
//   - test/unit_test/page/channel/channel_list_legacy_contract_test.dart
//     （J27.f ×3：missing / version=2 / boolean true 均 legacy 合法读）
//
// 运行（真机，勿在本窗口执行；验收批次统一编排）：
//   flutter test integration_test/channel/j26_channel_scan_gate_off_test.dart \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws \
//     --dart-define=TEST_PHONE=<demo_alice 手机号> \
//     --dart-define=TEST_PASSWORD=<demo_alice 密码> \
//     --dart-define=TEST_EXPECTED_UID=120619870873454592 \
//     -d <device>
//   （WS_URL_OVERRIDE 必带：合成节点直连须覆盖为真实路由 /api/v1/ws，
//    同 J16.c 双机批次环境注记）

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/page/channel/channel_list_page.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');

Future<({int count, Map<String, int> unreadById})>
_subscriptionSnapshot() async {
  final db = await SqliteService.to.db;
  if (db == null) return (count: 0, unreadById: <String, int>{});
  final rows = await db.query(ChannelRepo.subscriptionTableName);
  final unreadById = <String, int>{
    for (final row in rows)
      '${row[ChannelRepo.subChannelId]}':
          (row[ChannelRepo.unreadCount] as int?) ?? 0,
  };
  return (count: rows.length, unreadById: unreadById);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'J26.a/b/c 功能关闭态负例门：能力门关闭、扫描不误启、不伪造订阅',
    (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) {
        fail('J26 负例门前置失败：登录未进入主界面');
      }
      if (_expectedUid.isNotEmpty &&
          UserRepoLocal.to.currentUid != _expectedUid) {
        fail('登录账号 UID=${UserRepoLocal.to.currentUid} 与授权操作者不一致');
      }
      await settle(tester, maxSeconds: 2);

      // ① 能力门取证：合成部署 manifest 未声明 list_contracts → 门关闭。
      final gate = AppManifestService.manifest?.listCursorGateEnabled ?? false;
      flowLog(
        'J26_GATE_OFF manifestGate=$gate '
        'channelTabEnabled=${AppFeatureRegistry.isEnabled(FeatureKeys.channel)}',
      );
      expect(
        gate,
        isFalse,
        reason:
            '部署已声明 list_contracts（功能开启态）——本负例门脚本不再适用，'
            '应按 §9 改跑 J26.a–e 正例向量',
      );

      // ② 本地订阅基线：打开列表前后行数不得变化（扫描不伪造关系）。
      final before = await _subscriptionSnapshot();
      flowLog(
        'J26_GATE_OFF dbBefore count=${before.count} ${before.unreadById}',
      );

      final navigatorFinder = find.byType(Navigator).first;
      if (!tester.any(navigatorFinder)) {
        markTestSkipped('App 未找到 Navigator，跳过频道订阅负例门');
        return;
      }
      final navigatorState = Navigator.of(
        tester.element(navigatorFinder),
        rootNavigator: true,
      );
      final routeResult = navigatorState.push<void>(
        CupertinoPageRoute<void>(builder: (_) => const ChannelListPage()),
      );
      var mounted = false;
      for (var i = 0; i < 30 && !mounted; i++) {
        mounted = tester.any(find.byType(ChannelListPage));
        if (!mounted) await settle(tester, maxSeconds: 1);
      }
      expect(mounted, isTrue, reason: '频道订阅列表页应成功挂载');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChannelListPage)),
      );
      // 等首页读结束（legacy 路径），以 provider 终态为准。
      var loaded = false;
      for (var i = 0; i < 40 && !loaded; i++) {
        final state = container.read(channelListProvider);
        loaded = !state.isLoading;
        if (!loaded) await settle(tester, maxSeconds: 1);
      }
      expect(loaded, isTrue, reason: '订阅列表首页读应结束');

      final state = container.read(channelListProvider);
      flowLog(
        'J26_GATE_OFF listState channels=${state.channels.length} '
        'cursor=${state.cursor} hasMore=${state.hasMore} '
        'syncError=${state.syncError} error=${state.error}',
      );
      expect(
        state.cursor,
        isNull,
        reason:
            'legacy envelope 不签发游标——逐页扫描（J26.a/b/c 正例前提）'
            '在关闭态结构上不可继续',
      );
      expect(state.hasMore, isFalse);
      expect(state.isLoading, isFalse);

      // ③ 扫描不误启：显式触发 loadMore → 状态与本地订阅均不变。
      await container
          .read(channelListProvider.notifier)
          .loadMoreSubscribedChannels();
      final afterLoadMore = container.read(channelListProvider);
      expect(afterLoadMore.cursor, isNull);
      expect(afterLoadMore.hasMore, isFalse);
      expect(
        afterLoadMore.channels.length,
        state.channels.length,
        reason: 'loadMore 在关闭态必须无请求（不追加、不重启扫描）',
      );
      final after = await _subscriptionSnapshot();
      flowLog('J26_GATE_OFF dbAfter count=${after.count} ${after.unreadById}');
      expect(
        after.count,
        before.count,
        reason:
            '关闭态读+loadMore 不得伪造或删除本地订阅关系'
            '（J26.c 关闭态对应物：无扫描可删关系，既有关系保留）',
      );
      expect(after.unreadById, before.unreadById);

      if (navigatorState.canPop()) navigatorState.pop();
      await settle(tester, maxSeconds: 1);
      await routeResult;
      flowLog('J26_GATE_OFF_PASS gate=$gate subs=${after.count}');
      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
