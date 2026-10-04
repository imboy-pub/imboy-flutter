import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/launch_chat/launch_chat_page.dart';
import 'package:imboy/page/group/launch_chat/launch_chat_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

/// 发起聊天页（选择联系人建群）widget 流程测试（group 域 F00 launch_chat_page）。
///
/// 覆盖（对应 fn:group:launch_chat_page 判定行；校准注记登记用，
/// 格验收仍以正式设备格为准）：
///   流程A 未选人时完成按钮真正禁用（:006）：selects 空时 onPressed null。
///   流程B 点预览头像移除已选成员（:005）：列表行点选后预览条出现同名
///         头像；点预览头像（onRemove -> toggleSelection）即移除。
///   流程C 提交建群并防重复点击（:011）：提交走 groupAdd；groupAdd 在途
///         （Completer 闸门）时完成按钮因 _isCreatingGroup 置 null，重复
///         tap 不产生第二次提交。
///   流程D 点取消退出选择联系人页（:009）。
///
/// 数据隔离：sqflite_common_ffi（no-isolate）内存库 + SqliteService
/// .setDbForTest；登录态先于 setDbForTest 注入（同 add_member 套件）。
/// groupAdd 由 Spy 拦截（Completer 闸门模拟在途）；loadContacts 走真实
/// Repo 读 seed 库。
/// 运行：flutter test test/unit_test/page/group/launch_chat_widget_flow_test.dart

class _HostPage extends StatelessWidget {
  const _HostPage();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('host'));
}

class SpyLaunchChatNotifier extends LaunchChatNotifier {
  SpyLaunchChatNotifier({this.groupAddResult});

  /// 非 null 时 groupAdd 挂起直到 complete —— 模拟网络在途
  Completer<GroupModel?>? gate;
  GroupModel? groupAddResult;

  int groupAddCalls = 0;
  List<int> lastMemberIds = <int>[];

  @override
  LaunchChatState build() => const LaunchChatState();

  @override
  Future<GroupModel?> groupAdd(items) async {
    groupAddCalls++;
    lastMemberIds = items.map((e) => e.peerId).toList();
    if (gate != null) return gate!.future;
    return groupAddResult;
  }
}

const _me = '990001';

Future<void> _seedContact(Database db, int peerId, String nickname) async {
  await db.insert('contact', {
    'user_id': _me,
    'peer_id': peerId,
    'nickname': nickname,
    'avatar': '',
    'gender': 1,
    'account': '$peerId',
    'status': 1,
    'remark': '',
    'tag': '',
    'region': '',
    'sign': '',
    'source': 'test',
    'updated_at': 1790000000000,
    'is_friend': 1,
    'category_id': '',
    'is_from': 1,
    'account_type': 'normal',
  });
}

CupertinoButton _doneButton(WidgetTester tester) =>
    tester.widget<CupertinoButton>(
      find
          .ancestor(
            of: find.textContaining(t.common.buttonAccomplish),
            matching: find.byType(CupertinoButton),
          )
          .first,
    );

Future<SpyLaunchChatNotifier> _openPage(WidgetTester tester) async {
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

  final spy = SpyLaunchChatNotifier();
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [launchChatProvider.overrideWith(() => spy)],
        child: MaterialApp(builder: AppLoading.init(), home: const _HostPage()),
      ),
    ),
  );
  await tester.pump();

  final ctx = tester.element(find.byType(_HostPage));
  unawaited(
    Navigator.of(ctx)
        .push(MaterialPageRoute<void>(builder: (_) => const LaunchChatPage())),
  );
  // postFrameCallback 触发 loadContacts（Repo 直读 SQLite；no-isolate 下
  // 查询 Future 经 microtask 落定，pump 即可驱齐）
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  return spy;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() async {
    // 普通 async zone：真实 IO 只允许发生在这里；登录态先于 setDbForTest
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
    await _seedContact(db, 8001, '成员甲');
    await _seedContact(db, 8002, '好友乙');
    SqliteService.setDbForTest(db);
    // 自检：注入句柄 + 登录态就位后 Repo 可读
    final check = await ContactRepo().findFriend();
    assert(check.length == 2, 'seed 自检失败: findFriend=${check.length}');
  });

  tearDownAll(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  testWidgets('流程A 未选人时完成按钮真正禁用', (tester) async {
    await _openPage(tester);

    expect(find.text('好友乙'), findsOneWidget, reason: '列表应从本地库渲染');
    expect(
      _doneButton(tester).onPressed,
      isNull,
      reason: 'selects 为空时完成按钮应禁用（onPressed null）',
    );
  });

  testWidgets('流程B 点预览头像移除已选成员', (tester) async {
    await _openPage(tester);

    // 列表行点选 -> 预览条出现同名头像（预览区在列表之前渲染，取 .first）
    await tester.tap(find.text('好友乙'));
    await tester.pump();
    expect(find.text('好友乙'), findsNWidgets(2), reason: '选中后列表行与预览条各有一处「好友乙」');
    expect(
      find.textContaining('(1)'),
      findsOneWidget,
      reason: '完成按钮应带 (1) 已选人数',
    );

    // 点预览头像（预览区实例）-> toggleSelection 移除
    await tester.tap(find.text('好友乙').first);
    await tester.pump();
    expect(find.text('好友乙'), findsOneWidget, reason: '预览移除后仅剩列表行一处');
    expect(find.textContaining('(1)'), findsNothing, reason: '移除后完成按钮人数提示应消失');
    expect(_doneButton(tester).onPressed, isNull, reason: '移除后回到未选状态，完成按钮应禁用');
  });

  testWidgets('流程C 提交建群并防重复点击', (tester) async {
    final spy = await _openPage(tester);
    spy.gate = Completer<GroupModel?>();

    await tester.tap(find.text('好友乙'));
    await tester.pump();
    await tester.tap(find.textContaining(t.common.buttonAccomplish));
    await tester.pump();

    expect(spy.groupAddCalls, 1, reason: '首次点击应提交一次');
    expect(spy.lastMemberIds, [8002], reason: '提交名单应为选中成员');

    // 在途（gate 未完成）：_isCreatingGroup 置完成按钮为 null
    expect(
      _doneButton(tester).onPressed,
      isNull,
      reason: 'groupAdd 在途时完成按钮应禁用（防重复提交）',
    );

    // 重复 tap 不产生第二次提交
    await tester.tap(
      find.textContaining(t.common.buttonAccomplish),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(spy.groupAddCalls, 1, reason: '在途期间重复 tap 不应二次提交');

    // 闸门放行 -> finally 复位防抖
    spy.gate!.complete(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      _doneButton(tester).onPressed,
      isNotNull,
      reason: 'groupAdd 返回 null（失败）后防抖复位，按钮恢复可点（仍选中）',
    );
  });

  testWidgets('流程D 点取消退出选择联系人页', (tester) async {
    await _openPage(tester);

    await tester.tap(find.text(t.common.buttonCancel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LaunchChatPage), findsNothing, reason: '取消后应退出');
    expect(find.text('host'), findsOneWidget, reason: '应回到宿主页');
  });
}
