/// 群设置/管理导航回归（ux-plan imboyapp-uiux-v1 T13）。
///
/// - 0026：群分类入口从单群详情九宫格迁入群列表长按菜单（动作映射
///   步数不变：详情九宫格 1 步 ↔ 列表长按→菜单项 1 步）；
/// - 0017：ChangeInfoPage 由 CupertinoPageRoute 直 push 迁 go_router
///   `/group/change-info`（extra 传 GroupModel），导航统一。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/config/router/routes/group_feature_routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/category/group_category_page.dart';
import 'package:imboy/page/group/group_detail/change_info_page.dart';
import 'package:imboy/page/group/group_detail/widgets/group_app_grid.dart';
import 'package:imboy/page/group/group_detail/widgets/group_app_items.dart';
import 'package:imboy/page/group/group_list/group_list_page.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/group_model.dart';

import 'package:flutter/services.dart';

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

class _FakeGroupListService extends GroupListService {
  @override
  Future<List<GroupModel>> page({
    int page = 1,
    int size = 10,
    bool onRefresh = false,
    String attr = 'all',
  }) async => [_group(7001, '群甲')];

  @override
  Future<String> computeTitle(String groupId) async => '';
}

Future<void> _initTestEnv() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await StorageService.init();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => null,
      );
}

void main() {
  setUp(_initTestEnv);
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
    // GroupDetailService 缓存若跨用例残留，交给各断言的独立性即可。
  });

  testWidgets('0026：详情九宫格不再含「群分类」项', (tester) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => SingleChildScrollView(
                  child: GroupAppGrid(
                    items: buildGroupAppItems(ctx, '7001', _group(7001, '群甲')),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(t.groupCategory.title),
      findsNothing,
      reason: '0026：分类入口移出单群详情九宫格',
    );
    // 其余高频入口仍在
    expect(find.text(t.chat.groupFile), findsOneWidget);
    expect(find.text(t.group.groupAlbum), findsOneWidget);
  });

  testWidgets('0026：列表长按菜单含「群分类」，点击跳转分类页', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/group/list',
      routes: [
        GoRoute(path: '/group/list', builder: (c, s) => const GroupListPage()),
        ...groupFeatureRoutes(),
      ],
    );
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            groupListServiceProvider.overrideWithValue(_FakeGroupListService()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    // 列表初装 + 分页等异步链收敛
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('群甲'), findsOneWidget);

    await tester.longPress(find.text('群甲'));
    await tester.pumpAndSettle();
    expect(
      find.text(t.groupCategory.title),
      findsOneWidget,
      reason: '0026：分类入口迁入列表长按菜单',
    );

    await tester.tap(find.text(t.groupCategory.title));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // uri 读数非即时快照（push 已生效、配置 uri 滞后），以页面类型断言。
    expect(
      find.byType(GroupCategoryPage),
      findsOneWidget,
      reason: '菜单项一步到达分类页（步数不变）',
    );
  });

  testWidgets('0017：/group/change-info 经 go_router 可达并渲染编辑页', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/group/launch-pad',
      routes: [
        GoRoute(
          path: '/group/launch-pad',
          builder: (c, s) => const Scaffold(body: Text('pad')),
        ),
        ...groupFeatureRoutes(),
      ],
    );
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(child: MaterialApp.router(routerConfig: router)),
      ),
    );
    await tester.pump();

    // GoRouter.push 的 Future 等路由 pop 才完成，不 await（防测试挂死）；
    // uri 读数非即时快照，导航结果以下方页面类型断言。
    // GoRouter.push 的 Future 等 pop 才完成；不 await（挂死防护），忽略 lint。
    // ignore: discarded_futures, unawaited_futures
    router.push('/group/change-info', extra: _group(7001, '群甲'));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      find.byType(ChangeInfoPage),
      findsOneWidget,
      reason: '0017：编辑群信息页经 go_router 导航可达',
    );
    expect(find.text('群甲'), findsWidgets, reason: 'extra 传入的群名进入编辑框');
  });
}
