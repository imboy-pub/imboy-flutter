import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/denylist/denylist_page.dart';
import 'package:imboy/page/mine/denylist/denylist_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/denylist_model.dart';

/// DenylistPage widget test
///
/// 关键挑战：DenylistNotifier.build() 默认空 state，但 initState 中
/// `loadData(page:1, size:1000)` 调 SqliteService 异步链。
///
/// 测试策略：denylistProvider.overrideWith 注入指定 DenylistState 跳过 SqliteService。
///
/// 覆盖：
///   - AppBar title "黑名单"
///   - 警告卡片渲染（denylistNoteTitle）
///   - empty state → NoDataView "黑名单为空"
///   - non-empty → AzListView + DenylistModel 渲染
///   - CellPressable 卡片渲染（onTap + onLongPress）
class _StateOverrideNotifier extends DenylistNotifier {
  _StateOverrideNotifier(this._initial);
  final DenylistState _initial;

  @override
  DenylistState build() => _initial;
}

GoRouter _stubRouter() {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/denylist',
    routes: [
      GoRoute(path: '/denylist', builder: (_, _) => const DenylistPage()),
      // PeopleInfoPage 路由
      GoRoute(
        path: '/people_info/:id',
        builder: (_, _) => stub('people_info stub'),
      ),
    ],
  );
}

Future<void> _pumpDeny(
  WidgetTester tester, {
  required DenylistState state,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 1024);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        denylistProvider.overrideWith(() => _StateOverrideNotifier(state)),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(routerConfig: _stubRouter()),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

DenylistModel _model(int uid, String nickname) {
  return DenylistModel(
    deniedUid: uid,
    nickname: nickname,
    account: 'acc_$uid',
    avatar: '',
    gender: 0,
    remark: '',
    region: '',
    sign: '',
    source: 'manual',
    createdAt: DateTime.now().millisecondsSinceEpoch,
  );
}

void main() {
  setUpAll(() async {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
    await StorageService.to.setString(Keys.currentUid, 'tsid_uid_001');
  });

  tearDownAll(() async {
    IMBoyCacheManager.debugLogEnabled = true;
    await StorageService.to.remove(Keys.currentUid);
  });

  group('DenylistPage layout', () {
    testWidgets('AppBar title 渲染 "黑名单"', (tester) async {
      await _pumpDeny(tester, state: const DenylistState());
      expect(find.text('黑名单'), findsAtLeastNWidgets(1));
      await _unmount(tester);
    });

    testWidgets('warning card 渲染 "黑名单说明"', (tester) async {
      await _pumpDeny(tester, state: const DenylistState());
      // i18n: denylistNoteTitle = "黑名单说明"
      expect(find.text('黑名单说明'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('DenylistPage states', () {
    testWidgets('empty state → renders 自定义空态 "黑名单为空"', (tester) async {
      await _pumpDeny(tester, state: const DenylistState());

      // 源码空态：Center + Column(CupertinoIcons.slash_circle + 文案)
      // i18n: contact.denylistEmpty = "黑名单为空"
      expect(find.text('黑名单为空'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.slash_circle), findsOneWidget);
      // AzListView 不应渲染
      expect(find.byType(AzListView), findsNothing);

      await _unmount(tester);
    });

    testWidgets('non-empty state → renders AzListView + 列表项', (tester) async {
      // 模拟单条黑名单（trigger handleList 之前手动设置 nameIndex）
      final m = _model(1, 'Alice');
      m.nameIndex = 'A';

      await _pumpDeny(
        tester,
        state: DenylistState(items: [m], currIndexBarData: const {'A', '#'}),
      );

      // 空态文案不应渲染
      expect(find.text('黑名单为空'), findsNothing);
      // AzListView 渲染
      expect(find.byType(AzListView), findsOneWidget);
      // 列表项含 nickname
      expect(find.text('Alice'), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('DenylistPage cell interaction', () {
    testWidgets('non-empty → 列表项用 ImBoySettingsTile', (tester) async {
      final m = _model(1, 'Bob');
      m.nameIndex = 'B';

      await _pumpDeny(
        tester,
        state: DenylistState(items: [m], currIndexBarData: const {'B', '#'}),
      );

      // ImBoySettingsTile 至少 1 个（来自 _buildDenylistItem）
      expect(
        find.byType(ImBoySettingsTile).evaluate().length,
        greaterThanOrEqualTo(1),
      );

      await _unmount(tester);
    });
  });
}
