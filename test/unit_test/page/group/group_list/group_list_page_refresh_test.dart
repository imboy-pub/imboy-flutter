/// 群列表刷新通道行为回归（ux-plan imboyapp-uiux-v1 T11 / UX-ISSUE-0020）。
///
/// 0020：右上刷新按钮与下拉刷新统一走「membership self-heal + initData」。
/// 两通道共用页面同一方法 `_refreshWithSelfHeal`（调用同一性由代码路径
/// 保证）；本测试验证统一后的两个入口在完整 initData 链路上都能正确
/// 重载列表且不卡加载态。self-heal 在测试环境走未登录 401 静默分支，
/// 其真实请求行为归 O01 联调验证。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_list/group_list_page.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/group_model.dart';

GroupModel _group(int id, String title) => GroupModel(
  groupId: id,
  type: 2,
  joinLimit: 0,
  contentLimit: 0,
  ownerUid: 1,
  creatorUid: 1,
  memberMax: 500,
  memberCount: 8,
  title: title,
  createdAt: 1700000000,
);

/// 网络隔离：page 只回静态 fixture，并记录调用参数供断言。
class _FakeGroupListService extends GroupListService {
  int pageCalls = 0;
  bool lastOnRefresh = false;

  @override
  Future<List<GroupModel>> page({
    int page = 1,
    int size = 10,
    bool onRefresh = false,
    String attr = 'all',
  }) async {
    pageCalls++;
    lastOnRefresh = onRefresh;
    return [_group(7001, '群甲'), _group(7002, '群乙')];
  }

  @override
  Future<String> computeTitle(String groupId) async => '';
}

Future<void> _pumpPage(
  WidgetTester tester,
  _FakeGroupListService service,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [groupListServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: GroupListPage()),
      ),
    ),
  );
}

/// 有界 pump：等下拉刷新的 arm/refresh/settle 动画全部收敛。
Future<void> _pumpRefreshSettle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 未登录（currentUid 空）→ self-heal 走 401 静默分支，不触网。
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  testWidgets('右上刷新按钮：self-heal + initData(onRefresh) 后列表重载不卡加载', (
    tester,
  ) async {
    final service = _FakeGroupListService();
    await _pumpPage(tester, service);
    await _pumpRefreshSettle(tester);
    expect(find.text('群甲'), findsOneWidget, reason: 'initState 初次装载');

    await tester.tap(find.byIcon(CupertinoIcons.refresh));
    await _pumpRefreshSettle(tester);

    expect(service.pageCalls, greaterThanOrEqualTo(2), reason: '初次+刷新至少两次');
    expect(service.lastOnRefresh, isTrue, reason: '刷新走 onRefresh 通道');
    expect(find.text('群甲'), findsOneWidget, reason: '刷新后列表正确重载');
    expect(
      find.byType(CupertinoActivityIndicator),
      findsNothing,
      reason: '刷新完成不得残留加载态',
    );
  });

  testWidgets('下拉刷新：与右上按钮同通道，onRefresh 语义一致', (tester) async {
    final service = _FakeGroupListService();
    await _pumpPage(tester, service);
    await _pumpRefreshSettle(tester);
    expect(find.text('群乙'), findsOneWidget);
    final callsAfterInit = service.pageCalls;

    // CustomScrollView 顶部向下拖拽触发 CupertinoSliverRefreshControl。
    await tester.drag(find.text('群甲'), const Offset(0, 150));
    await _pumpRefreshSettle(tester);

    expect(service.pageCalls, greaterThan(callsAfterInit), reason: '下拉触发列表重载');
    expect(service.lastOnRefresh, isTrue, reason: '下拉与右上同走 onRefresh 通道（0020）');
    expect(find.text('群甲'), findsOneWidget, reason: '下拉刷新后列表正确重载');
    expect(
      find.byType(CupertinoActivityIndicator),
      findsNothing,
      reason: '刷新完成不得残留加载态',
    );
  });
}
