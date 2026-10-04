import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_detail/remove_member_page.dart';
import 'package:imboy/page/group/group_detail/remove_member_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';

import '../../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

/// 移除成员页 widget 流程测试（group 域 F00 remove_member_page）。
///
/// 覆盖（对应 fn:group:remove_member_page 判定行；校准注记登记用，
/// 格验收仍以正式设备格为准）：
///   流程A 打开正常 + 成员列表排除自己与非Join（:001/:002）
///   流程B 勾选切换 + 完成按钮随选中数变化 + 未选不触发请求（:003/:004/:005）
///   流程C 提交移除并回传结果（:010）：group_detail 壳页经 router.push 的
///         Future 捕获 context.pop(selects) 的回传名单。
///   流程D 点取消返回群详情（:007）
///   流程E 点信息图标查看成员资料（:006）：路由 /people_info/:id
///   流程F 成员为空展示暂无数据（:008）
///   流程G 移除失败不离开页面（:009；toast 文案受 EasyLoading 时序限制，
///         以「仍在本页」作为失败路径断言）
///
/// 数据隔离：ffi no-isolate 内存库 + setDbForTest（登录态先注入）；
/// removeMembers 由 Spy 拦截（Completer 闸门可选）。
/// 运行：flutter test test/unit_test/page/group/group_detail/remove_member_widget_flow_test.dart

class SpyRemoveMemberNotifier extends RemoveMemberNotifier {
  SpyRemoveMemberNotifier({this.removeResult = true});

  final bool removeResult;
  Completer<bool>? gate;

  int removeCalls = 0;
  String? lastGroupId;

  @override
  RemoveMemberState build() => const RemoveMemberState();

  @override
  Future<bool> removeMembers(String groupId) async {
    removeCalls++;
    lastGroupId = groupId;
    if (gate != null) return gate!.future;
    return removeResult;
  }
}

const _me = '990001';

class _GroupDetailCapture extends StatelessWidget {
  const _GroupDetailCapture();

  @override
  Widget build(BuildContext context) {
    final state = GoRouterState.of(context);
    return Scaffold(body: Text('group-detail-capture:${state.uri}'));
  }
}

class _PeopleInfoCapture extends StatelessWidget {
  const _PeopleInfoCapture();

  @override
  Widget build(BuildContext context) {
    final state = GoRouterState.of(context);
    return Scaffold(
      body: Text('people-info-capture:${state.pathParameters['id']}'),
    );
  }
}

Future<(SpyRemoveMemberNotifier, GoRouter, Completer<Object?>)> _openPage(
  WidgetTester tester, {
  bool removeResult = true,
}) async {
  await StorageService.setMap(Keys.currentUser, {
    'uid': _me,
    'account': '50008',
    'nickname': '当前用户',
    'avatar': '',
    'sign': '',
    'gender': 1,
    'mobile': '13800000001',
    'email': '',
  });
  await StorageService.to.setString(Keys.currentUid, _me);

  final spy = SpyRemoveMemberNotifier(removeResult: removeResult);
  final popCompleter = Completer<Object?>();
  final router = GoRouter(
    initialLocation: '/group_detail',
    routes: [
      GoRoute(
        path: '/group_detail',
        builder: (_, _) => const _GroupDetailCapture(),
      ),
      GoRoute(
        path: '/remove_member',
        builder: (_, _) => const RemoveMemberPage(groupId: '7001'),
      ),
      GoRoute(
        path: '/people_info/:id',
        builder: (_, _) => const _PeopleInfoCapture(),
      ),
    ],
  );

  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [removeMemberProvider.overrideWith(() => spy)],
        child: MaterialApp.router(
          routerConfig: router,
          builder: AppLoading.init(),
        ),
      ),
    ),
  );
  await tester.pump();

  // push 并捕获 pop 回传（:010 的 context.pop(selects)）
  unawaited(
    router.push('/remove_member').then((r) {
      if (!popCompleter.isCompleted) popCompleter.complete(r);
    }),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  return (spy, router, popCompleter);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() async {
    await StorageService.setMap(Keys.currentUser, {
      'uid': _me,
      'account': '50008',
      'nickname': '当前用户',
      'avatar': '',
      'sign': '',
      'gender': 1,
      'mobile': '13800000001',
      'email': '',
    });
    await StorageService.to.setString(Keys.currentUid, _me);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    db = await openFixtureDatabaseAtVersion(version: 32);
    // 群 7001 成员：8001 普通成员（可见）、990001 自己（排除）、
    // 8004 isJoin=0（非Join，排除）
    await db.insert('group_member', {
      'id': 1,
      'group_id': 7001,
      'user_id': 8001,
      'nickname': '成员甲',
      'avatar': '',
      'sign': '',
      'account': '8001',
      'invite_code': '',
      'alias': '',
      'role': 1,
      'is_join': 1,
      'created_at': 1790000000000,
      'updated_at': 1790000000000,
    });
    await db.insert('group_member', {
      'id': 2,
      'group_id': 7001,
      'user_id': 990001,
      'nickname': '我自己',
      'avatar': '',
      'sign': '',
      'account': '990001',
      'invite_code': '',
      'alias': '',
      'role': 2,
      'is_join': 1,
      'created_at': 1790000000000,
      'updated_at': 1790000000000,
    });
    await db.insert('group_member', {
      'id': 3,
      'group_id': 7001,
      'user_id': 8004,
      'nickname': '非Join成员',
      'avatar': '',
      'sign': '',
      'account': '8004',
      'invite_code': '',
      'alias': '',
      'role': 1,
      'is_join': 0,
      'created_at': 1790000000000,
      'updated_at': 1790000000000,
    });
    SqliteService.setDbForTest(db);
  });

  tearDownAll(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  testWidgets('流程A 打开正常，列表排除自己与非Join成员', (tester) async {
    await _openPage(tester);

    expect(
      find.text(t.common.removeMember),
      findsOneWidget,
      reason: '页面应正常打开并渲染标题',
    );
    expect(find.text('成员甲'), findsOneWidget, reason: '普通成员应可见');
    expect(find.text('我自己'), findsNothing, reason: '自己应被排除');
    expect(find.text('非Join成员'), findsNothing, reason: 'isJoin=0 应被排除');
  });

  testWidgets('流程B 勾选切换 + 完成按钮随选中变化 + 未选不触发请求', (tester) async {
    final (spy, _, _) = await _openPage(tester);

    expect(
      tester
          .widget<CupertinoButton>(
            find
                .ancestor(
                  of: find.textContaining(t.common.buttonAccomplish),
                  matching: find.byType(CupertinoButton),
                )
                .first,
          )
          .onPressed,
      isNull,
      reason: '未选中时完成按钮应禁用（:005 不触发请求的前提）',
    );
    await tester.tap(find.text('成员甲'));
    await tester.pump();
    expect(
      find.textContaining('(1)'),
      findsOneWidget,
      reason: '勾选后完成按钮应带 (1) 提示（:004 随选中数变化）',
    );
    expect(spy.removeCalls, 0, reason: '勾选本身不触发移除请求');
  });

  testWidgets('流程C 提交移除并回传结果', (tester) async {
    final (_, _, popDone) = await _openPage(tester);

    await tester.tap(find.text('成员甲'));
    await tester.pump();
    await tester.tap(find.textContaining(t.common.buttonAccomplish));
    await tester.pump();
    // pop 转场 300ms，多 pump 等动画走完
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(RemoveMemberPage), findsNothing, reason: '移除成功后应返回群详情');
    expect(find.textContaining('group-detail-capture'), findsOneWidget);
    // context.pop(state.selects) 的回传：被选中成员名单
    final returned = await popDone.future;
    expect(returned, isA<List<dynamic>>(), reason: 'pop 应回传已选成员列表');
    expect((returned as List).length, 1, reason: '回传名单应含被移除的 1 人');
  });

  testWidgets('流程D 点取消返回群详情', (tester) async {
    await _openPage(tester);
    await tester.tap(find.text(t.common.buttonCancel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(RemoveMemberPage), findsNothing, reason: '取消后应返回');
    expect(
      find.textContaining('group-detail-capture'),
      findsOneWidget,
      reason: '应回到群详情壳页',
    );
  });

  testWidgets('流程E 点信息图标查看成员资料', (tester) async {
    await _openPage(tester);

    await tester.tap(find.byTooltip(t.channel.viewProfile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('people-info-capture:8001'),
      findsOneWidget,
      reason: '应路由到 /people_info/8001（scene=group_member）',
    );
  });

  testWidgets('流程F 成员为空展示暂无数据空态', (tester) async {
    await db.delete('group_member');
    await _openPage(tester);

    expect(find.text(t.common.noData), findsOneWidget, reason: '无成员应渲染「暂无数据」');
  });

  testWidgets('流程G 移除失败不离开页面', (tester) async {
    // 流程F 清过 group_member 表：恢复本用例所需的成员行
    await db.insert('group_member', {
      'id': 1,
      'group_id': 7001,
      'user_id': 8001,
      'nickname': '成员甲',
      'avatar': '',
      'sign': '',
      'account': '8001',
      'invite_code': '',
      'alias': '',
      'role': 1,
      'is_join': 1,
      'created_at': 1790000000000,
      'updated_at': 1790000000000,
    });
    await _openPage(tester, removeResult: false);

    await tester.tap(find.text('成员甲'));
    await tester.pump();
    await tester.tap(find.textContaining(t.common.buttonAccomplish));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byType(RemoveMemberPage),
      findsOneWidget,
      reason:
          'removeMembers 返回 false 时应留在本页（错误 toast 由 '
          'AppLoading 展示，FakeAsync 下不对其文案做断言）',
    );
  });
}
